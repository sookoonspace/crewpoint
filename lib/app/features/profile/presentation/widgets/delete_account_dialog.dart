import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/account_deletion_service.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/destructive_button.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';

/// Multi-step account deletion dialog with dynamic re-authentication.
///
/// Step 0: Warning — explains what happens to shared data
/// Step 1: Re-auth — password field (email) or provider button (Google/Apple)
/// Step 2: Processing — loading overlay during Cloud Function call
/// Step 3: Done — success, caller handles navigation
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key, this.onDeleted});

  final VoidCallback? onDeleted;

  static Future<void> show({
    required BuildContext context,
    VoidCallback? onDeleted,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteAccountDialog(onDeleted: onDeleted),
    );
  }

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  int _step = 0;
  String? _errorMessage;
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _reAuthAndDelete() async {
    final service = ref.read(accountDeletionServiceProvider);

    setState(() {
      _step = 2;
      _errorMessage = null;
    });

    // Step 1: Re-authenticate based on provider
    final provider = service.currentAuthProvider;
    bool reAuthSuccess;

    switch (provider) {
      case AuthProviderType.email:
        final password = _passwordController.text.trim();
        if (password.isEmpty) {
          setState(() {
            _step = 1;
            _errorMessage = 'Please enter your password.';
          });
          return;
        }
        reAuthSuccess = await service.reAuthenticateWithEmail(password);
      case AuthProviderType.google:
        reAuthSuccess = await service.reAuthenticateWithGoogle();
      case AuthProviderType.apple:
        reAuthSuccess = await service.reAuthenticateWithApple();
      case AuthProviderType.unknown:
        reAuthSuccess = false;
    }

    if (!reAuthSuccess) {
      setState(() {
        _step = 1;
        _errorMessage = provider == AuthProviderType.email
            ? 'Incorrect password. Please try again.'
            : 'Authentication failed. Please try again.';
      });
      return;
    }

    // Step 2: Call Cloud Function
    final error = await service.executeAccountDeletion();

    if (error != null) {
      setState(() {
        _step = 1;
        _errorMessage = error;
      });
      return;
    }

    // Step 3: Success
    if (mounted) {
      Navigator.of(context).pop();
      widget.onDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _step == 2
          ? null
          : Text(
              _step == 0 ? 'Delete Account?' : 'Confirm Deletion',
              style: const TextStyle(color: AppColors.terracotta),
            ),
      content: switch (_step) {
        0 => const _WarningStep(),
        1 => _ReAuthStep(
          provider: ref
              .read(accountDeletionServiceProvider)
              .currentAuthProvider,
          passwordController: _passwordController,
          errorMessage: _errorMessage,
        ),
        2 => const _ProcessingStep(),
        _ => const SizedBox.shrink(),
      },
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
                    onPressed: _reAuthAndDelete,
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
    return const Text(
      'This action is permanent. Your profile, solo events, '
      'and local data will be erased.\n\n'
      'Financials and messages in shared events will be '
      'anonymized to protect group integrity.\n\n'
      'If you want specific messages deleted, please remove '
      'them manually before proceeding.',
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
      mainAxisSize: .min,
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
            mainAxisSize: .min,
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
      mainAxisSize: .min,
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
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        mainAxisSize: .min,
        spacing: AppSpacing.lg,
        children: [LoadingAnimation(), Text('Deleting your account...')],
      ),
    );
  }
}
