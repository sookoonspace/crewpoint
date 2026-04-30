import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
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

    return Container(
      key: _key,
      width: double.infinity,
      color: AppColors.terracottaLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread, color: AppColors.charcoal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.strings.auth.verifyBannerTitle,
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  context.strings.auth.verifyBannerBody(user.email),
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('auth.verifyBanner.resend'),
            onPressed: () =>
                ref.read(authProvider.notifier).resendVerificationEmail(),
            child: Text(context.strings.auth.verifyBannerResend),
          ),
          TextButton(
            key: const Key('auth.verifyBanner.refresh'),
            onPressed: () =>
                ref.read(authProvider.notifier).reloadCurrentUser(),
            child: Text(context.strings.auth.verifyBannerRefresh),
          ),
        ],
      ),
    );
  }
}
