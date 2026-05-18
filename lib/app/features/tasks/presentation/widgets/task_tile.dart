import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_sizes.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
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

  int get _completedCount =>
      task.checklistItems.where((i) => i.isCompleted).length;

  /// Progress bar (and the X/Y text next to it) only render when the
  /// checklist has items AND the task isn't already done. Avoids the
  /// "60% bar under a done icon" inconsistency from spec edge case 33.
  bool get _showProgressBar =>
      task.checklistItems.isNotEmpty && task.status != TaskStatus.done;

  /// True when the task is past its due date and not already done.
  /// Uses `clock.now()` (CI3 seam) so tests can freeze time via
  /// `withClock(Clock.fixed(...))`. Comparison is start-of-day so the
  /// badge flips at midnight, not at the dueDate timestamp.
  bool get _isOverdue {
    final due = task.dueDate;
    if (due == null) return false;
    if (task.status == TaskStatus.done) return false;
    return startOfDay(due).isBefore(startOfDay(clock.now()));
  }

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
                          if (_isOverdue || task.priority > 0) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: 2,
                              children: [
                                if (_isOverdue)
                                  _Pill(
                                    key: Key(
                                      'tasks.tile.${task.id}.overdueBadge',
                                    ),
                                    label: context.strings.tasks.overdueBadge,
                                    bg: AppColors.terracotta,
                                    fg: AppColors.white,
                                  ),
                                if (task.priority > 0)
                                  _PriorityPill(
                                    key: Key(
                                      'tasks.tile.${task.id}.priorityBadge',
                                    ),
                                    level: task.priority,
                                  ),
                              ],
                            ),
                          ],
                          if (_showProgressBar) ...[
                            const SizedBox(height: AppSpacing.xs),
                            _ProgressBar(
                              key: Key('tasks.tile.${task.id}.progressBar'),
                              completed: _completedCount,
                              total: task.checklistItems.length,
                              color: _stripeColor(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (task.budgetEstimate != null)
                      MoneyText(
                        key: Key('tasks.tile.${task.id}.budget'),
                        amount: task.budgetEstimate!,
                        currencyCode: currencyCode,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    if (_showProgressBar)
                      Text(
                        '$_completedCount/${task.checklistItems.length}',
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
      TaskStatus.todo => (AppColors.lightGrey, AppIcons.statusTodo),
      TaskStatus.inProgress => (AppColors.sage, AppIcons.statusDoingAlt),
      TaskStatus.done => (AppColors.sage, AppIcons.statusDone),
    };

    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        color: enabled ? color : AppColors.lightGrey,
        size: AppSizes.iconLg,
      ),
    );
  }
}

/// Compact filled rounded label used for status pills (Overdue, Priority).
class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Priority pill: Low (sageLight), Medium (charcoal), High (terracotta).
class _PriorityPill extends StatelessWidget {
  const _PriorityPill({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final t = context.strings.tasks;
    final (label, bg, fg) = switch (level) {
      1 => (t.priorityLow, AppColors.sageLight, AppColors.charcoal),
      2 => (t.priorityMedium, AppColors.charcoal, AppColors.white),
      _ => (t.priorityHigh, AppColors.terracotta, AppColors.white),
    };
    return _Pill(label: label, bg: bg, fg: fg);
  }
}

/// Thin (3-px) progress bar showing checklist completion fraction.
///
/// Foreground tint matches the parent tile's status stripe so a glance
/// across the list communicates both status (left edge) and progress
/// (under the title) with the same colour.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    super.key,
    required this.completed,
    required this.total,
    required this.color,
  }) : assert(total > 0);

  final int completed;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = (completed / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(1.5),
      child: Container(
        height: 3,
        color: AppColors.lightGrey.withValues(alpha: 0.3),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction,
          child: Container(color: color),
        ),
      ),
    );
  }
}
