import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Static placeholder block — no shimmer animation. Lightweight, themable
/// via `AppColors.lightGrey`. We trade animation for simplicity and zero
/// jank during tab switches; the LoadingAnimation (Lottie) remains for
/// full-screen empty/error animations.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder matching the layout of `EventTile` so the Dashboard list
/// doesn't reflow when real data arrives.
class EventTileSkeleton extends StatelessWidget {
  const EventTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            SkeletonBox(width: 40, height: 40, radius: 12),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 160, height: 18),
                  SizedBox(height: AppSpacing.xs),
                  SkeletonBox(width: 100, height: 12),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.md),
            SkeletonBox(width: 48, height: 48, radius: 24),
          ],
        ),
      ),
    );
  }
}
