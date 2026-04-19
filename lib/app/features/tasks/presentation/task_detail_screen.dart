import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    super.key,
    required this.task,
    this.onChecklistToggle,
  });

  final TaskModel task;
  final void Function(int index, bool value)? onChecklistToggle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(task.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: .start,
          spacing: AppSpacing.lg,
          children: [
            _StatusBadge(status: task.status),
            if (task.description != null)
              Text(
                task.description!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            if (task.dueDate != null)
              Row(
                spacing: AppSpacing.sm,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.mediumGrey,
                  ),
                  Text(
                    'Due: ${task.dueDate.toString().split(' ')[0]}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            if (task.checklistItems.isNotEmpty) ...[
              Text('Checklist', style: Theme.of(context).textTheme.titleMedium),
              ...task.checklistItems.asMap().entries.map(
                (entry) => CheckboxListTile(
                  value: entry.value.isCompleted,
                  onChanged: (value) =>
                      onChecklistToggle?.call(entry.key, value ?? false),
                  title: Text(
                    entry.value.text,
                    style: TextStyle(
                      decoration: entry.value.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = switch (status) {
      TaskStatus.todo => (AppColors.charcoal, AppColors.lightGrey),
      TaskStatus.inProgress => (AppColors.white, AppColors.sage),
      TaskStatus.done => (AppColors.white, AppColors.sageDark),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}
