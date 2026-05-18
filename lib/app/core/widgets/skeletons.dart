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

/// Header skeleton: a single section label + 3 stacked row blocks that
/// approximate the height/shape of `MyTasksScreen` rows.
class MyTasksSkeleton extends StatelessWidget {
  const MyTasksSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 140, height: 12),
          SizedBox(height: AppSpacing.md),
          _MyTasksRowSkeleton(),
          SizedBox(height: AppSpacing.sm),
          _MyTasksRowSkeleton(),
          SizedBox(height: AppSpacing.sm),
          _MyTasksRowSkeleton(),
        ],
      ),
    );
  }
}

class _MyTasksRowSkeleton extends StatelessWidget {
  const _MyTasksRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 24, height: 24, radius: 12),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 180, height: 14),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: 120, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder matching the layout of `ConversationTile` — emoji slot +
/// stacked title/preview blocks + small trailing column.
class ConversationTileSkeleton extends StatelessWidget {
  const ConversationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SkeletonBox(width: 32, height: 32, radius: 16),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 14),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: 200, height: 10),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          SkeletonBox(width: 32, height: 12),
        ],
      ),
    );
  }
}

/// Placeholder matching the layout of `BalanceTile` — two big-number
/// blocks with a thin ratio-bar placeholder beneath.
class BalanceTileSkeleton extends StatelessWidget {
  const BalanceTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 80, height: 10),
                      SizedBox(height: AppSpacing.xs),
                      SkeletonBox(width: 120, height: 28),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SkeletonBox(width: 60, height: 10),
                      SizedBox(height: AppSpacing.xs),
                      SkeletonBox(width: 100, height: 28),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(width: double.infinity, height: 6, radius: 4),
          ],
        ),
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
