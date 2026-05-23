import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:crewpoint_app/app/core/constants/app_assets.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Sign-out confirmation bottom sheet with Lottie animation.
///
/// Colors resolve from `Theme.of(context).colorScheme` so the sheet
/// renders correctly under either theme.
class SignOutSheet extends StatelessWidget {
  const SignOutSheet({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

  static Future<void> show({
    required BuildContext context,
    VoidCallback? onSignOut,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (_) => SignOutSheet(onSignOut: onSignOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          Lottie.asset(
            AppAssets.lottieSignOut,
            width: 80,
            height: 80,
            errorBuilder: (_, _, _) =>
                Icon(AppIcons.wavingHand, size: 48, color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'Sign out of CrewPoint?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your local data will be preserved for next time.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onSurface,
                    side: BorderSide(color: colors.outline),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.borderLg,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSignOut?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.borderLg,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                  child: const Text('Sign Out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
