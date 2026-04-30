import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
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
        final providerLabel = _providerLabel(suggested);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: Key('auth.suggestProvider.${_providerSlug(suggested)}'),
            content: Text(
              'This email is registered with $providerLabel. '
              'Tap "Continue with $providerLabel" above.',
            ),
            backgroundColor: AppColors.terracotta,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.failure.message),
          backgroundColor: AppColors.terracotta,
        ),
      );
    });

    return Form(
      key: _formKey,
      child: Column(
        spacing: AppSpacing.lg,
        children: [
          if (_isSignUp)
            CustomTextField(
              hintText: 'Full Name',
              controller: _nameController,
              prefixIcon: const Icon(Icons.person_outline),
              enabled: !isLoading,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
          CustomTextField(
            hintText: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            enabled: !isLoading,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          CustomTextField(
            hintText: 'Password',
            controller: _passwordController,
            obscureText: true,
            prefixIcon: const Icon(Icons.lock_outline),
            enabled: !isLoading,
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          PrimaryButton(
            label: _isSignUp ? 'Create Account' : 'Sign In',
            onPressed: isLoading ? null : _submit,
            isLoading: isLoading,
          ),
          TextButton(
            onPressed: isLoading ? null : _toggleMode,
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign In'
                  : "Don't have an account? Sign Up",
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps a Firebase provider ID to a human-friendly label for snackbar
/// copy. Falls back to "your existing provider" for unknown IDs so the
/// message stays grammatical.
String _providerLabel(String providerId) => switch (providerId) {
  'google.com' => 'Google',
  'apple.com' => 'Apple',
  _ => 'your existing provider',
};

/// Shortens a Firebase provider ID for use in stable widget Keys.
String _providerSlug(String providerId) => switch (providerId) {
  'google.com' => 'google',
  'apple.com' => 'apple',
  _ => 'other',
};
