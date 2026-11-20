import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/account_deletion_service.dart';
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
      final strings = context.strings.profile;
      setState(() {
        _errorMessage = provider == AuthProviderType.email
            ? strings.deleteWrongPassword
            : strings.deleteAuthFailed;
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
      _errorMessage = result.message ?? context.strings.profile.deleteFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.profile;
    final stepBody = switch (_step) {
      0 => const _WarningStep(),
      1 => _ReAuthStep(
        provider: ref.read(accountDeletionServiceProvider).currentAuthProvider,
        passwordController: _passwordController,
        errorMessage: _errorMessage,
      ),
      _ => const _ProcessingStep(),
    };

    return CpDialog(
      title: switch (_step) {
        0 => s.deleteTitle,
        1 => s.deleteConfirmTitle,
        _ => s.deleting,
      },
      content: stepBody,
      actions: [
        if (_step < 2)
          CpButton.text(
            key: const Key('deleteAccount.dialog.cancel'),
            label: s.cancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        if (_step == 0)
          CpButton.destructive(
            key: const Key('deleteAccount.dialog.continue'),
            label: s.deleteContinue,
            onPressed: () => setState(() => _step = 1),
          )
        else if (_step == 1)
          CpButton.destructive(
            key: const Key('deleteAccount.dialog.confirm'),
            label: s.deleteForever,
            icon: CpIcons.actionDeletePermanent,
            onPressed: _onDeleteForever,
          ),
      ],
    );
  }
}

class _WarningStep extends StatelessWidget {
  const _WarningStep();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Row(
      key: const Key('deleteAccount.dialog.warn'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.md,
      children: [
        Icon(
          CpIcons.statusUrgent,
          size: cp.sizes.iconMd,
          color: cp.colors.overdue,
        ),
        Expanded(
          child: Text(
            context.strings.profile.deleteWarning,
            style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
          ),
        ),
      ],
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
    final cp = context.cp;
    final s = context.strings.profile;
    final body = cp.type.bodyMedium.copyWith(color: cp.colors.text);
    return Column(
      key: const Key('deleteAccount.dialog.reauth'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.lg,
      children: [
        if (errorMessage != null) CpFieldError(errorMessage!),
        switch (provider) {
          AuthProviderType.email => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.md,
            children: [
              Text(s.deletePasswordPrompt, style: body),
              CpTextField(
                fieldKey: const Key('deleteAccount.dialog.password'),
                label: s.deletePasswordLabel,
                controller: passwordController,
                obscureText: true,
                prefixIcon: CpIcons.authPassword,
                autofillHints: const [AutofillHints.password],
              ),
            ],
          ),
          AuthProviderType.google => _ProviderReAuthPrompt(
            icon: CpIcons.authGoogle,
            label: s.deleteReauthGoogle,
          ),
          AuthProviderType.apple => _ProviderReAuthPrompt(
            icon: CpIcons.authApple,
            label: s.deleteReauthApple,
          ),
          AuthProviderType.unknown => Text(
            s.deleteUnknownProvider,
            style: body,
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
    final cp = context.cp;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.md,
      children: [
        Text(
          context.strings.profile.deleteReauthPrompt,
          style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
        ),
        Row(
          spacing: cp.space.sm,
          children: [
            Icon(icon, size: cp.sizes.iconMd, color: cp.colors.text),
            Expanded(
              child: Text(
                label,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
              ),
            ),
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
    final cp = context.cp;
    return Padding(
      key: const Key('deleteAccount.dialog.processing'),
      padding: EdgeInsets.symmetric(vertical: cp.space.xl),
      child: Center(
        child: CircularProgressIndicator(
          color: cp.colors.accent,
          semanticsLabel: context.strings.profile.deleting,
        ),
      ),
    );
  }
}
