import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/cp_logo.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
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
    final cp = context.cp;
    return Scaffold(
      backgroundColor: cp.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(cp.space.xl),
                child: Center(
                  child: ConstrainedBox(
                    key: const Key('auth.gate.column'),
                    constraints: BoxConstraints(
                      maxWidth: cp.sizes.signInColumn,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: cp.space.xl,
                      children: [
                        SizedBox(height: cp.space.xxl),
                        const _Header(),
                        const SocialAuthButtons(),
                        const _Divider(),
                        const EmailAuthForm(),
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
    final cp = context.cp;
    return Column(
      spacing: cp.space.md,
      children: [
        CpLogo(size: cp.sizes.iconHero),
        Semantics(
          header: true,
          child: Text(
            context.strings.auth.heroTitle,
            textAlign: TextAlign.center,
            style: cp.type.headlineLarge.copyWith(color: cp.colors.text),
          ),
        ),
        Text(
          context.strings.auth.tagline,
          textAlign: TextAlign.center,
          style: cp.type.bodyLarge.copyWith(color: cp.colors.textMuted),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final line = Expanded(
      child: Divider(
        height: cp.sizes.hairline,
        thickness: cp.sizes.hairline,
        color: cp.colors.border,
      ),
    );
    return Row(
      spacing: cp.space.lg,
      children: [
        line,
        Flexible(
          flex: 3,
          child: Text(
            context.strings.auth.dividerLabel,
            textAlign: TextAlign.center,
            style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
          ),
        ),
        line,
      ],
    );
  }
}
