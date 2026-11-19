import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// One task in a list (Spec #186): a status button, the title, who and
/// which crew, then its budget figure and a status chip (green done, amber
/// due this week, red overdue, each with an icon). Use inside a
/// [CpRowGroup] in a [CpCard].
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.canChangeStatus,
    this.currencyCode = 'USD',
    this.onTap,
    this.onStatusChanged,
    this.onUnauthorizedTap,
    this.crewName,
    this.assigneeName,
    this.showAssignee = true,
    this.selected = false,
  });

  final TaskModel task;
  final bool canChangeStatus;
  final String currencyCode;
  final VoidCallback? onTap;
  final ValueChanged<TaskStatus>? onStatusChanged;
  final VoidCallback? onUnauthorizedTap;

  /// The task's crew name (Req 72), when crews are in use.
  final String? crewName;

  /// The assignee's name, once read (Req 43a).
  final String? assigneeName;

  /// False where every task is the viewer's own, as in My tasks.
  final bool showAssignee;

  /// The task open beside the list (Req 23).
  final bool selected;

  int get _completedCount =>
      task.checklistItems.where((i) => i.isCompleted).length;

  /// Checklist progress shows only while the task is open, so a done task
  /// never carries a part-filled bar (spec edge case 33).
  bool get _showProgressBar =>
      task.checklistItems.isNotEmpty && task.status != TaskStatus.done;

  void _cycleStatus() {
    if (!canChangeStatus) {
      onUnauthorizedTap?.call();
      return;
    }
    onStatusChanged?.call(switch (task.status) {
      TaskStatus.todo => TaskStatus.inProgress,
      TaskStatus.inProgress => TaskStatus.done,
      TaskStatus.done => TaskStatus.todo,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.tasks;
    final muted = cp.type.bodySmall.copyWith(color: cp.colors.textMuted);
    final who = !showAssignee
        ? null
        : task.assigneeId == null
        ? s.assigneeUnassigned
        : (assigneeName == null || assigneeName!.isEmpty)
        ? null
        : assigneeName;
    final subtitle = <Widget>[
      if (who != null) Text(who, style: muted),
      if (crewName != null)
        Text(crewName!, key: Key('tasks.tile.${task.id}.crew'), style: muted),
    ];
    final chip = taskDueChip(context, task);
    final trailing = <Widget>[
      if (task.budgetEstimate != null)
        MoneyText(
          key: Key('tasks.tile.${task.id}.budget'),
          amount: task.budgetEstimate!,
          currencyCode: currencyCode,
          style: cp.type.labelMedium.copyWith(color: cp.colors.textMuted),
        ),
      ?chip,
    ];
    // At large text on a narrow row the figure and chip go under the
    // title, so no word breaks mid-way (Req 45).
    final scale = MediaQuery.textScalerOf(context).scale(1);

    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: cp.sizes.rowMinHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: cp.space.xs,
          end: cp.space.lg,
          top: cp.space.sm,
          bottom: cp.space.sm,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth / scale < 260;
            return Row(
              children: [
                _StatusButton(
                  key: Key('tasks.tile.${task.id}.status'),
                  status: task.status,
                  enabled: canChangeStatus,
                  onTap: _cycleStatus,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: cp.space.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: cp.space.xs / 2,
                      children: [
                        Text(
                          task.title,
                          style: cp.type.titleSmall.copyWith(
                            color: cp.colors.text,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Wrap(
                            children: [
                              for (var i = 0; i < subtitle.length; i++) ...[
                                if (i > 0) Text(' · ', style: muted),
                                subtitle[i],
                              ],
                            ],
                          ),
                        if (task.priority > 0 || _showProgressBar)
                          Padding(
                            padding: EdgeInsets.only(top: cp.space.xs / 2),
                            child: Wrap(
                              spacing: cp.space.sm,
                              runSpacing: cp.space.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (task.priority > 0)
                                  _PriorityTag(
                                    key: Key(
                                      'tasks.tile.${task.id}.priorityBadge',
                                    ),
                                    level: task.priority,
                                  ),
                                if (_showProgressBar)
                                  _ChecklistProgress(
                                    key: Key(
                                      'tasks.tile.${task.id}.progressBar',
                                    ),
                                    completed: _completedCount,
                                    total: task.checklistItems.length,
                                  ),
                              ],
                            ),
                          ),
                        if (stacked && trailing.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: cp.space.xs / 2),
                            child: Wrap(
                              spacing: cp.space.sm,
                              runSpacing: cp.space.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: trailing,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // The figure and chip take at most half the row, so the title
                // keeps room at large text sizes, and sit at the row's end.
                if (!stacked && trailing.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth / 2,
                    ),
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(start: cp.space.sm),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: cp.space.sm,
                        runSpacing: cp.space.xs,
                        children: trailing,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );

    return Semantics(
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('tasks.tile.${task.id}'),
          onTap: onTap,
          child: selected
              ? ColoredBox(color: cp.colors.accentSoft, child: row)
              : row,
        ),
      ),
    );
  }
}

/// The task's status chip (green done, amber due this week, red overdue,
/// a quiet tag further off), or nothing when it has no due date.
Widget? taskDueChip(BuildContext context, TaskModel task) {
  final s = context.strings.tasks;
  final now = clock.now();
  final due = task.dueDate;
  String day(DateTime d) {
    final date = startOfDay(d);
    final days = date.difference(startOfDay(now)).inDays.abs();
    return days < 7
        ? DateFormat.E().format(date)
        : DateFormat.MMMd().format(date);
  }

  return switch (taskDueState(task, now)) {
    TaskDueState.done => CpStatusChip(
      key: Key('tasks.tile.${task.id}.done'),
      status: CpStatus.done,
      label: s.statusDone,
    ),
    TaskDueState.overdue => CpStatusChip(
      key: Key('tasks.tile.${task.id}.overdueBadge'),
      status: CpStatus.overdue,
      label: s.overdueOn(day(due!)),
    ),
    TaskDueState.soon => CpStatusChip(
      key: Key('tasks.tile.${task.id}.due'),
      status: CpStatus.due,
      label: startOfDay(due!) == startOfDay(now)
          ? s.dueToday
          : s.dueOn(day(due)),
    ),
    TaskDueState.later => CpTag(
      key: Key('tasks.tile.${task.id}.due'),
      label: s.dueOn(day(due!)),
      tone: CpTagTone.quiet,
    ),
    TaskDueState.none => null,
  };
}

/// The round status button at the start of a row: empty to do, a play
/// sign in progress, a filled tick done. Tapping moves to the next status.
class _StatusButton extends StatelessWidget {
  const _StatusButton({
    super.key,
    required this.status,
    required this.enabled,
    required this.onTap,
  });

  final TaskStatus status;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final c = cp.colors;
    final size = cp.sizes.iconLg;
    final mark = switch (status) {
      TaskStatus.todo => Icon(
        CpIcons.statusTodo,
        size: size,
        color: c.textMuted,
      ),
      TaskStatus.inProgress => Icon(
        CpIcons.statusDoing,
        size: size,
        color: enabled ? c.accent : c.textMuted,
      ),
      TaskStatus.done => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: enabled ? c.done : c.textMuted,
          shape: BoxShape.circle,
        ),
        child: Icon(CpIcons.check, size: cp.sizes.iconSm, color: c.surface),
      ),
    };
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${context.strings.tasks.statusChange}: ${_label(context)}',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: cp.sizes.tapMin / 2,
        child: SizedBox.square(
          dimension: cp.sizes.tapMin,
          child: Center(child: mark),
        ),
      ),
    );
  }

  String _label(BuildContext context) {
    final s = context.strings.tasks;
    return switch (status) {
      TaskStatus.todo => s.statusTodo,
      TaskStatus.inProgress => s.statusInProgress,
      TaskStatus.done => s.statusDone,
    };
  }
}

/// Low, Medium or High, as a quiet tag.
class _PriorityTag extends StatelessWidget {
  const _PriorityTag({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final t = context.strings.tasks;
    return CpTag(
      label: switch (level) {
        1 => t.priorityLow,
        2 => t.priorityMedium,
        _ => t.priorityHigh,
      },
      icon: level >= 3 ? CpIcons.priorityHigh : null,
      tone: level >= 3 ? CpTagTone.accent : CpTagTone.quiet,
    );
  }
}

/// A short bar and "3/5" for the checklist.
class _ChecklistProgress extends StatelessWidget {
  const _ChecklistProgress({
    super.key,
    required this.completed,
    required this.total,
  }) : assert(total > 0);

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final fraction = (completed / total).clamp(0.0, 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: cp.space.xs,
      children: [
        ClipRRect(
          borderRadius: cp.radii.pill,
          child: SizedBox(
            width: cp.space.xxl * 1.5,
            height: cp.space.xs,
            child: ColoredBox(
              color: cp.colors.border,
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: fraction,
                child: ColoredBox(color: cp.colors.accent),
              ),
            ),
          ),
        ),
        Text(
          '$completed/$total',
          style: cp.type.labelSmall.copyWith(color: cp.colors.textMuted),
        ),
      ],
    );
  }
}
