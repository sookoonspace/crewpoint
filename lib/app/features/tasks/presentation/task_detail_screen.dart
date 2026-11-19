import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/money_text.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/checklist_editor.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_tile.dart';

enum _DetailAction { edit, duplicate, delete }

/// One task (Spec #186): its status, who has it, when it is due, its crew,
/// budget and description, then the checklist. Pure presentation: the
/// parent saves, and passes only the callbacks the viewer may use.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.event,
    required this.checklist,
    required this.canEditTask,
    required this.canChangeStatus,
    this.assigneeName,
    this.completedByName,
    this.crewName,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
    this.onBack,
    this.onChecklistToggle,
    this.onChecklistAdd,
    this.onChecklistEditText,
    this.onChecklistDelete,
    this.hasPendingWrites = false,
  });

  final TaskModel task;
  final EventModel event;
  final List<ChecklistItem> checklist;
  final bool canEditTask;
  final bool canChangeStatus;

  /// The assignee's name, read by the parent (Req 43a). Without it the
  /// screen says "Unknown member" rather than show an ID.
  final String? assigneeName;

  /// Who finished the task, read by the parent.
  final String? completedByName;

  /// The task's crew (Req 72), when crews are in use.
  final String? crewName;
  final VoidCallback? onEdit;

  /// Duplicating is open to every viewer (the copy is theirs).
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  /// Back, or closing the task beside the list. Pops by default.
  final VoidCallback? onBack;
  final void Function(ChecklistItem item, bool isCompleted)? onChecklistToggle;
  final void Function(String id, String text)? onChecklistAdd;
  final void Function(ChecklistItem item, String text)? onChecklistEditText;
  final void Function(ChecklistItem item)? onChecklistDelete;
  final bool hasPendingWrites;

  bool get _assigneeStillInEvent =>
      task.assigneeId == null || event.memberIds.contains(task.assigneeId);

  Future<void> _openMenu(BuildContext context) async {
    final s = context.strings.tasks;
    final action = await showCpSheet<_DetailAction>(
      context: context,
      title: task.title,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            if (canEditTask)
              CpListRow(
                key: const Key('tasks.detail.overflow.edit'),
                leading: const _MenuIcon(CpIcons.actionEdit),
                title: s.detailEdit,
                trailing: const SizedBox(),
                onTap: () => Navigator.of(sheet).pop(_DetailAction.edit),
              ),
            if (onDuplicate != null)
              CpListRow(
                key: const Key('tasks.detail.overflow.duplicate'),
                leading: const _MenuIcon(CpIcons.actionCopy),
                title: s.detailDuplicate,
                trailing: const SizedBox(),
                onTap: () => Navigator.of(sheet).pop(_DetailAction.duplicate),
              ),
            if (canEditTask)
              CpListRow(
                key: const Key('tasks.detail.overflow.delete'),
                leading: const _MenuIcon(CpIcons.actionDelete, danger: true),
                title: s.detailDelete,
                trailing: const SizedBox(),
                onTap: () => Navigator.of(sheet).pop(_DetailAction.delete),
              ),
          ],
        ),
      ),
    );
    switch (action) {
      case _DetailAction.edit:
        onEdit?.call();
      case _DetailAction.duplicate:
        onDuplicate?.call();
      case _DetailAction.delete:
        onDelete?.call();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.tasks;
    final muted = cp.type.bodySmall.copyWith(color: cp.colors.textMuted);
    final dateFormat = DateFormat.yMMMd();
    final chip = taskDueChip(context, task);
    final showChip =
        task.dueDate != null && task.status != TaskStatus.done && chip != null;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final assignee = (assigneeName != null && assigneeName!.isNotEmpty)
        ? assigneeName!
        : s.unknownMember;
    final completedBy = task.completedBy == null
        ? null
        : (completedByName != null && completedByName!.isNotEmpty)
        ? completedByName!
        : s.unknownMember;

    final facts = <Widget>[
      CpListRow(
        key: const Key('tasks.detail.status'),
        title: s.statusLabel,
        trailing: _StatusBadge(status: task.status),
      ),
      if (task.assigneeId != null)
        CpListRow(
          key: const Key('tasks.detail.assignee'),
          title: s.assigneeLabel,
          subtitle: _assigneeStillInEvent
              ? assignee
              : '$assignee ${s.noLongerInEvent}',
          leading: CpAvatar(name: assignee),
        ),
      if (task.dueDate != null)
        CpListRow(
          key: const Key('tasks.detail.due'),
          title: s.dueLabel,
          subtitle: dateFormat.format(event.inZone(task.dueDate!)),
          trailing: showChip && !large ? chip : null,
        ),
      // At large text the chip takes its own line, so neither it nor the
      // date breaks mid-word (Req 45).
      if (showChip && large)
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: cp.space.lg,
            vertical: cp.space.md,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: chip,
          ),
        ),
      if (crewName != null)
        CpListRow(
          key: const Key('tasks.detail.crew'),
          title: event.words.one('crew'),
          subtitle: crewName,
        ),
      if (task.priority > 0)
        CpListRow(
          key: const Key('tasks.detail.priority'),
          title: s.fieldPriority,
          subtitle: switch (task.priority) {
            1 => s.priorityLow,
            2 => s.priorityMedium,
            _ => s.priorityHigh,
          },
        ),
      if (task.budgetEstimate != null)
        CpListRow(
          key: const Key('tasks.detail.budget'),
          title: s.budgetLabel,
          trailing: MoneyText(
            amount: task.budgetEstimate!,
            currencyCode: event.currency,
            style: cp.type.titleSmall.copyWith(color: cp.colors.text),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: task.title,
        leadingKey: const Key('tasks.detail.back'),
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: onBack ?? () => Navigator.of(context).maybePop(),
        actions: [
          if (canEditTask || onDuplicate != null)
            CpTopBarAction(
              key: const Key('tasks.detail.overflow'),
              icon: CpIcons.actionMore,
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              onPressed: () => _openMenu(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        child: ContentMaxWidth(
          key: const Key('eventTaskDetail.body.clamped'),
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.lg,
            children: [
              if (hasPendingWrites)
                Row(
                  spacing: cp.space.sm,
                  children: [
                    Icon(
                      CpIcons.cloudOff,
                      size: cp.sizes.iconSm,
                      color: cp.colors.textMuted,
                    ),
                    Flexible(child: Text(s.willSync, style: muted)),
                  ],
                ),
              CpCard(child: CpRowGroup(children: facts)),
              if (task.status == TaskStatus.done && task.completedAt != null)
                Text(
                  s.completedOn(
                    dateFormat.format(event.inZone(task.completedAt!)),
                    completedBy,
                  ),
                  key: const Key('tasks.detail.completed'),
                  style: muted,
                ),
              if (task.description != null && task.description!.isNotEmpty)
                CpCard(
                  key: const Key('tasks.detail.description'),
                  padding: EdgeInsets.all(cp.space.lg),
                  child: Text(
                    task.description!,
                    style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                  ),
                ),
              ChecklistEditor(
                items: checklist,
                onToggle: canChangeStatus ? onChecklistToggle : null,
                onAdd: canEditTask ? onChecklistAdd : null,
                onEditText: canEditTask ? onChecklistEditText : null,
                onDelete: canEditTask ? onChecklistDelete : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A sheet row's icon; red for Delete.
class _MenuIcon extends StatelessWidget {
  const _MenuIcon(this.icon, {this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Icon(
      icon,
      size: cp.sizes.iconMd,
      color: danger ? cp.colors.overdue : cp.colors.textMuted,
    );
  }
}

/// The task's status: green with a tick when done, the accent while in
/// progress, quiet to do. Never colour alone: the label always shows.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.tasks;
    return KeyedSubtree(
      key: const Key('tasks.detail.statusBadge'),
      child: switch (status) {
        TaskStatus.done => CpStatusChip(
          status: CpStatus.done,
          label: s.statusDone,
        ),
        TaskStatus.inProgress => CpTag(
          label: s.statusInProgress,
          icon: CpIcons.statusDoing,
        ),
        TaskStatus.todo => CpTag(
          label: s.statusTodo,
          icon: CpIcons.statusTodo,
          tone: CpTagTone.quiet,
        ),
      },
    );
  }
}
