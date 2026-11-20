import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';

class EmailAuthForm extends ConsumerStatefulWidget {
  const EmailAuthForm({super.key});

  @override
  ConsumerState<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends ConsumerState<EmailAuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() => _isSignUp = !_isSignUp);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(authProvider.notifier);

    if (_isSignUp) {
      await notifier.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
    } else {
      await notifier.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;

    // Show error message if auth failed. Two snackbar variants:
    //   - default: the generic auth error message (e.g. "Incorrect email
    //     or password.")
    //   - provider hint: when AuthFailure.suggestedProvider is set, route
    //     the user to the right tile instead of leaving them stuck.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is! AuthError) return;
      final suggested = next.failure.suggestedProvider;
      if (suggested != null) {
        final providerLabel = _providerLabel(context, suggested);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: Key('auth.suggestProvider.${_providerSlug(suggested)}'),
            content: Text(context.strings.auth.suggestProvider(providerLabel)),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(next.failure.message)));
    });

    final cp = context.cp;
    final auth = context.strings.auth;
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: cp.space.lg,
          children: [
            if (_isSignUp)
              CpTextField(
                fieldKey: const Key('auth.email.name'),
                label: auth.fullNameHint,
                controller: _nameController,
                prefixIcon: CpIcons.navProfile,
                enabled: !isLoading,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return auth.validatorNameRequired;
                  }
                  return null;
                },
              ),
            CpTextField(
              fieldKey: const Key('auth.email.address'),
              label: auth.emailHint,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: CpIcons.authEmailField,
              enabled: !isLoading,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return auth.validatorEmailRequired;
                }
                if (!value.contains('@')) {
                  return auth.validatorEmailInvalid;
                }
                return null;
              },
            ),
            CpTextField(
              fieldKey: const Key('auth.email.password'),
              label: auth.passwordHint,
              controller: _passwordController,
              obscureText: true,
              prefixIcon: CpIcons.authPassword,
              enabled: !isLoading,
              textInputAction: TextInputAction.done,
              autofillHints: [
                _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
              ],
              onSubmitted: (_) => isLoading ? null : _submit(),
              validator: (value) {
                if (value == null || value.length < 6) {
                  return auth.validatorPasswordTooShort;
                }
                return null;
              },
            ),
            CpButton(
              key: const Key('auth.email.submit'),
              label: _isSignUp ? auth.createAccount : auth.signIn,
              expand: true,
              busy: isLoading,
              onPressed: _submit,
            ),
            CpButton.text(
              key: const Key('auth.email.toggle'),
              label: _isSignUp ? auth.toggleToSignIn : auth.toggleToSignUp,
              onPressed: isLoading ? null : _toggleMode,
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps a Firebase provider ID to a human-friendly label for snackbar
/// copy, falling back to "your existing provider" so the message stays
/// grammatical.
String _providerLabel(BuildContext context, String providerId) =>
    switch (providerId) {
      'google.com' => 'Google',
      'apple.com' => 'Apple',
      _ => context.strings.auth.existingProvider,
    };

/// Shortens a Firebase provider ID for use in stable widget Keys.
String _providerSlug(String providerId) => switch (providerId) {
  'google.com' => 'google',
  'apple.com' => 'apple',
  _ => 'other',
};
