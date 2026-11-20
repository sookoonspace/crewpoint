import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart' show authProvider;
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';

/// Persistent banner shown above the main shell body when the
/// signed-in user has an unverified email AND only the `password`
/// provider attached.
///
/// Hidden in every other case:
///   - signed-out users (the auth gate is showing instead),
///   - email-verified accounts,
///   - OAuth-linked accounts (Google/Apple verify the email at
///     first sign-in, so they never trip this banner).
///
/// The banner offers two actions: **Resend** (calls
/// `resendVerificationEmail` on the auth notifier) and **I've verified
/// — refresh** (calls `reloadCurrentUser` so the new `emailVerified`
/// flag is pulled from Firebase).
class EmailUnverifiedBanner extends ConsumerWidget {
  const EmailUnverifiedBanner({super.key});

  static const _key = Key('auth.verifyBanner');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authProvider);
    if (state is! Authenticated) return const SizedBox.shrink();
    final user = state.user;
    if (user.emailVerified) return const SizedBox.shrink();
    if (!user.isPasswordOnly) return const SizedBox.shrink();

    final cp = context.cp;
    final auth = context.strings.auth;
    return Material(
      key: _key,
      color: cp.colors.accentSoft,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: cp.space.lg,
          vertical: cp.space.sm,
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: cp.space.sm,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: cp.space.md,
              children: [
                Icon(
                  CpIcons.emailUnread,
                  size: cp.sizes.iconMd,
                  color: cp.colors.accent,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: cp.space.xs / 2,
                    children: [
                      Text(
                        auth.verifyBannerTitle,
                        style: cp.type.titleSmall.copyWith(
                          color: cp.colors.text,
                        ),
                      ),
                      Text(
                        auth.verifyBannerBody(user.email),
                        style: cp.type.bodySmall.copyWith(
                          color: cp.colors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            CpButton.text(
              key: const Key('auth.verifyBanner.resend'),
              label: auth.verifyBannerResend,
              onPressed: () =>
                  ref.read(authProvider.notifier).resendVerificationEmail(),
            ),
            CpButton.text(
              key: const Key('auth.verifyBanner.refresh'),
              label: auth.verifyBannerRefresh,
              onPressed: () =>
                  ref.read(authProvider.notifier).reloadCurrentUser(),
            ),
          ],
        ),
      ),
    );
  }
}
