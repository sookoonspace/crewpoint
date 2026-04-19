import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.onTap,
    this.onStatusChanged,
  });

  final TaskModel task;
  final VoidCallback? onTap;
  final ValueChanged<TaskStatus>? onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            spacing: AppSpacing.md,
            children: [
              _StatusChip(
                status: task.status,
                onTap: () {
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        decoration: task.status == TaskStatus.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task.description != null)
                      Text(
                        task.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mediumGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (task.checklistItems.isNotEmpty)
                Text(
                  '${task.checklistItems.where((i) => i.isCompleted).length}/${task.checklistItems.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.mediumGrey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.onTap});

  final TaskStatus status;
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
      child: Icon(icon, color: color, size: 24),
    );
  }
}
