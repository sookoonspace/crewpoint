import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/account_deletion_service.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/destructive_button.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';

/// Multi-step account deletion dialog with dynamic re-authentication.
///
/// State machine:
/// - **Step 0**: warning copy (Cancel / Continue).
/// - **Step 1**: re-auth — password field for email, provider tile for
///   Google/Apple. (Cancel / Delete Forever.)
/// - **Step 2**: processing loader. The Cloud Function call runs here.
///
/// On Cloud Function success the dialog does **NOT** call
/// `Navigator.pop` and does **NOT** call `context.go` — the deletion of
/// the Firebase Auth user revokes the client token, `authStateChanges`
/// fires `null`, `AuthNotifier` flips to [Unauthenticated], `main.dart`
/// rebuilds `MaterialApp.router`, and the global GoRouter redirect
/// routes the entire app to `/auth`. The dialog is unmounted as part
/// of that route reconciliation. Trying to drive navigation from inside
/// the dialog races the global redirect and reproduces today's
/// "code-blob + Home link" symptom.
///
/// Mid-dialog auth-state-flip handling:
/// - On step 0 or 1 (no CF call in flight): pop the dialog so the
///   global redirect doesn't have to fight an open modal route. This
///   path covers token-expired and signed-out-elsewhere cases.
/// - On step 2: ignore the auth flip. The CF success path does not pop
///   or navigate; the global redirect handles it. Mounted guards on
///   every state update short-circuit cleanly if the global redirect
///   beats the awaited CF future.
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  static Future<void> show({required BuildContext context}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeleteAccountDialog(),
    );
  }

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  /// 0 = warning, 1 = re-auth, 2 = processing.
  int _step = 0;
  String? _errorMessage;
  final _passwordController = TextEditingController();
  ProviderSubscription<AuthState>? _authListener;

  @override
  void initState() {
    super.initState();
    // Step 0/1 only: if the auth state flips to Unauthenticated while
    // the user is still in the warning or re-auth screens (token
    // expired, signed out elsewhere), pop the dialog cleanly. Step 2
    // explicitly ignores this listener — the CF success path lets the
    // global GoRouter redirect tear the dialog down naturally.
    _authListener = ref.listenManual<AuthState>(authProvider, (prev, next) {
      if (!mounted) return;
      if (_step > 1) return;
      if (next is Unauthenticated) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  @override
  void dispose() {
    _authListener?.close();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onDeleteForever() async {
    final service = ref.read(accountDeletionServiceProvider);

    // Step 1: Re-authenticate FIRST. Do NOT flip to step 2 yet — the
    // processing loader must not flash while the OAuth sheet is open.
    final provider = service.currentAuthProvider;
    final reAuthSuccess = await switch (provider) {
      AuthProviderType.email => () async {
        final password = _passwordController.text.trim();
        if (password.isEmpty) return false;
        return service.reAuthenticateWithEmail(password);
      }(),
      AuthProviderType.google => service.reAuthenticateWithGoogle(),
      AuthProviderType.apple => service.reAuthenticateWithApple(),
      AuthProviderType.unknown => Future<bool>.value(false),
    };

    if (!mounted) return;

    if (!reAuthSuccess) {
      setState(() {
        _errorMessage = provider == AuthProviderType.email
            ? 'Incorrect password. Please try again.'
            : 'Authentication failed. Please try again.';
      });
      return;
    }

    // Step 2: Re-auth confirmed. Flip to processing loader and call CF.
    setState(() {
      _step = 2;
      _errorMessage = null;
    });

    final result = await service.executeAccountDeletion();

    // Critical: do NOT call Navigator.pop and do NOT call context.go on
    // the success path. The global authProvider redirect handles
    // navigation as the Auth user deletion revokes the token. Mounted
    // guards short-circuit cleanly if the global redirect already
    // unmounted the dialog.
    if (!mounted) return;

    if (result.errorCode == null) {
      // Success. Stay on step 2 until the global redirect reconciles
      // the route stack and unmounts us. The user sees: loader → /auth.
      return;
    }

    // CF failure. The Auth user wasn't deleted, the client token still
    // works, the global redirect is not firing — it's safe to update
    // our own UI and return to the re-auth step.
    setState(() {
      _step = 1;
      _errorMessage =
          result.message ?? 'Account deletion failed. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final stepBody = switch (_step) {
      0 => const _WarningStep(),
      1 => _ReAuthStep(
        provider: ref.read(accountDeletionServiceProvider).currentAuthProvider,
        passwordController: _passwordController,
        errorMessage: _errorMessage,
      ),
      2 => const _ProcessingStep(),
      _ => const SizedBox.shrink(),
    };

    return AlertDialog(
      title: _step == 2
          ? null
          : Text(
              _step == 0 ? 'Delete Account?' : 'Confirm Deletion',
              style: const TextStyle(color: AppColors.terracotta),
            ),
      content: stepBody,
      actions: _step == 2
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              if (_step == 0)
                TextButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text(
                    'Continue',
                    style: TextStyle(color: AppColors.terracotta),
                  ),
                )
              else if (_step == 1)
                SizedBox(
                  width: 140,
                  child: DestructiveButton(
                    label: 'Delete Forever',
                    onPressed: _onDeleteForever,
                  ),
                ),
            ],
    );
  }
}

class _WarningStep extends StatelessWidget {
  const _WarningStep();

  @override
  Widget build(BuildContext context) {
    // Verbatim retention clause from docs/legal/privacy-policy.md
    // (Account deletion section). Keeping the dialog and the policy
    // in lock-step prevents UI/policy drift; counsel review of either
    // side requires updating both.
    return const KeyedSubtree(
      key: Key('deleteAccount.dialog.warn'),
      child: Text(
        'Your solo events will be permanently deleted. In shared events, '
        "your name and account ID will be replaced with 'deleted user' "
        'so the historical record stays intact for the rest of your group. '
        'This is irreversible. To request full erasure of an anonymized '
        'record on a per-event basis, contact support after deletion.',
      ),
    );
  }
}

class _ReAuthStep extends StatelessWidget {
  const _ReAuthStep({
    required this.provider,
    required this.passwordController,
    this.errorMessage,
  });

  final AuthProviderType provider;
  final TextEditingController passwordController;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('deleteAccount.dialog.reauth'),
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.lg,
      children: [
        if (errorMessage != null)
          Text(
            errorMessage!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.terracotta),
          ),
        switch (provider) {
          AuthProviderType.email => Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.md,
            children: [
              const Text('Enter your password to confirm deletion.'),
              CustomTextField(
                hintText: 'Password',
                controller: passwordController,
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ],
          ),
          AuthProviderType.google => const _ProviderReAuthPrompt(
            icon: Icons.g_mobiledata,
            label: 'Sign in with Google to confirm',
          ),
          AuthProviderType.apple => const _ProviderReAuthPrompt(
            icon: Icons.apple,
            label: 'Sign in with Apple to confirm',
          ),
          AuthProviderType.unknown => const Text(
            'Unable to determine your sign-in method. '
            'Please sign out and sign in again.',
          ),
        },
      ],
    );
  }
}

class _ProviderReAuthPrompt extends StatelessWidget {
  const _ProviderReAuthPrompt({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.md,
      children: [
        const Text(
          'To confirm account deletion, please re-authenticate '
          'with your sign-in provider.',
        ),
        Row(
          spacing: AppSpacing.sm,
          children: [
            Icon(icon, color: AppColors.charcoal),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('deleteAccount.dialog.processing'),
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.lg,
        children: [LoadingAnimation(), Text('Deleting your account...')],
      ),
    );
  }
}
