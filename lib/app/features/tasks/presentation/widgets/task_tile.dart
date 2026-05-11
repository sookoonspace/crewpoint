import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.canChangeStatus,
    this.currencyCode = 'USD',
    this.onTap,
    this.onStatusChanged,
    this.onUnauthorizedTap,
  });

  final TaskModel task;
  final bool canChangeStatus;
  final String currencyCode;
  final VoidCallback? onTap;
  final ValueChanged<TaskStatus>? onStatusChanged;
  final VoidCallback? onUnauthorizedTap;

  Color _stripeColor() => switch (task.status) {
    TaskStatus.todo => AppColors.lightGrey,
    TaskStatus.inProgress => AppColors.sage,
    TaskStatus.done => AppColors.sageDark,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('tasks.tile.${task.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              key: Key('tasks.tile.${task.id}.stripe'),
              width: 4,
              color: _stripeColor(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  spacing: AppSpacing.md,
                  children: [
                    _StatusChip(
                      key: Key('tasks.tile.${task.id}.status'),
                      status: task.status,
                      enabled: canChangeStatus,
                      onTap: () {
                        if (!canChangeStatus) {
                          onUnauthorizedTap?.call();
                          return;
                        }
                        final next = switch (task.status) {
                          TaskStatus.todo => TaskStatus.inProgress,
                          TaskStatus.inProgress => TaskStatus.done,
                          TaskStatus.done => TaskStatus.todo,
                        };
                        onStatusChanged?.call(next);
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            task.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  decoration: task.status == TaskStatus.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                          if (task.description != null)
                            Text(
                              task.description!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.mediumGrey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (task.budgetEstimate != null)
                      Text(
                        key: Key('tasks.tile.${task.id}.budget'),
                        NumberFormat.simpleCurrency(
                          name: currencyCode,
                        ).format(task.budgetEstimate),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    if (task.checklistItems.isNotEmpty)
                      Text(
                        '${task.checklistItems.where((i) => i.isCompleted).length}/${task.checklistItems.length}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    super.key,
    required this.status,
    required this.enabled,
    this.onTap,
  });

  final TaskStatus status;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      TaskStatus.todo => (AppColors.lightGrey, Icons.radio_button_unchecked),
      TaskStatus.inProgress => (AppColors.sage, Icons.timelapse),
      TaskStatus.done => (AppColors.sage, Icons.check_circle),
    };

    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: enabled ? color : AppColors.lightGrey, size: 24),
    );
  }
}
