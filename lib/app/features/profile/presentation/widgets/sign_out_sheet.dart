import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Sign-out confirmation bottom sheet with Lottie animation.
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Lottie animation
          Lottie.asset(
            'assets/animations/sign_out.json',
            width: 80,
            height: 80,
            errorBuilder: (_, _, _) => const Icon(
              AppIcons.wavingHand,
              size: 48,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'Sign out of CrewPoint?',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your local data will be preserved for next time.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Buttons
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.charcoal,
                    side: const BorderSide(color: AppColors.lightGrey),
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
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: AppColors.white,
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
