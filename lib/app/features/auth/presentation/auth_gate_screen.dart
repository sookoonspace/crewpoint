import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/email_auth_form.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/legal_footer.dart';
import 'package:crewpoint_app/app/features/auth/presentation/widgets/social_auth_buttons.dart';

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 480px clamp on the form column: below this width the column fills
    // the viewport (mobile/tablet portrait); at or above it the column
    // centers and stops so buttons + text fields don't stretch
    // edge-to-edge on web.
    //
    // The legal footer is rendered OUTSIDE the ConstrainedBox so it
    // spans the full viewport width — legal copy reads edge-to-edge —
    // but inside SafeArea so it clears the home indicator on iOS.
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    key: const Key('auth.gate.column'),
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: const Column(
                      spacing: AppSpacing.xl,
                      children: [
                        SizedBox(height: AppSpacing.xxxl),
                        _Header(),
                        SocialAuthButtons(),
                        _Divider(),
                        EmailAuthForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const LegalFooter(key: Key('auth.gate.footer')),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppSpacing.sm,
      children: [
        Text(
          context.strings.auth.heroTitle,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        Text(
          context.strings.auth.tagline,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.mediumGrey),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            context.strings.auth.dividerLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mediumGrey),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
