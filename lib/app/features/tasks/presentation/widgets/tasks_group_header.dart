import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Shared group-header strip used by the per-event `TaskListScreen` and
/// the cross-event `MyTasksScreen`. Label + thin sage divider.
class TasksGroupHeader extends StatelessWidget {
  const TasksGroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.charcoal,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Container(height: 1, color: AppColors.sage.withValues(alpha: 0.25)),
        ],
      ),
    );
  }
}
