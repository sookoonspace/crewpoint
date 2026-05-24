import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_sizes.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/checklist_editor.dart';

enum _DetailAction { edit, duplicate, delete }

/// Task detail screen — pure presentation. The parent owns mutation wiring and
/// passes only the callbacks the current user is authorized to use.
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
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
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

  /// Resolved display name for `task.assigneeId`. When null, the screen falls
  /// back to a truncated UID. Hydrated upstream by `event_task_detail_page.dart`
  /// via `usersByIdProvider` so this screen stays Riverpod-free.
  final String? assigneeName;

  /// Resolved display name for `task.completedBy`. Falls back to a truncated
  /// UID when null. Hydrated upstream by `event_task_detail_page.dart`.
  final String? completedByName;
  final VoidCallback? onEdit;

  /// Optional callback to duplicate the task. Visible to every viewer when
  /// non-null (any member can spawn a copy under their own `createdBy`).
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final void Function(ChecklistItem item, bool isCompleted)? onChecklistToggle;
  final void Function(String id, String text)? onChecklistAdd;
  final void Function(ChecklistItem item, String text)? onChecklistEditText;
  final void Function(ChecklistItem item)? onChecklistDelete;
  final bool hasPendingWrites;

  bool get _assigneeStillInEvent =>
      task.assigneeId == null || event.memberIds.contains(task.assigneeId);

  String _completedByLabel(String uid) {
    if (completedByName != null && completedByName!.isNotEmpty) {
      return completedByName!;
    }
    return uid.length > 8 ? uid.substring(0, 8) : uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(task.title),
        elevation: 0,
        actions: [
          if (canEditTask || onDuplicate != null)
            _DetailOverflowMenu(
              canEdit: canEditTask,
              onEdit: onEdit,
              onDuplicate: onDuplicate,
              onDelete: onDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.xl,
        ),
        child: ContentMaxWidth(
          key: const Key('eventTaskDetail.body.clamped'),
          maxWidth: 960,
          child: Column(
            crossAxisAlignment: .start,
            spacing: AppSpacing.lg,
            children: [
              _StatusBadge(status: task.status),
              if (hasPendingWrites)
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Icon(
                      AppIcons.cloudOff,
                      size: AppSizes.iconSm,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const Text(
                      'Will sync when online',
                      style: TextStyle(color: AppColors.mediumGrey),
                    ),
                  ],
                ),
              if (task.description != null && task.description!.isNotEmpty)
                Text(
                  task.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              if (task.assigneeId != null)
                _AssigneeRow(
                  assigneeId: task.assigneeId!,
                  displayName: assigneeName,
                  stillInEvent: _assigneeStillInEvent,
                ),
              if (task.dueDate != null)
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Icon(
                      AppIcons.calendar,
                      size: AppSizes.iconSm,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    Text(
                      'Due ${DateFormat.yMMMd().format(task.dueDate!)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              if (task.status == TaskStatus.done && task.completedAt != null)
                Text(
                  'Completed ${DateFormat.yMMMd().format(task.completedAt!)}'
                  '${task.completedBy != null ? ' by ${_completedByLabel(task.completedBy!)}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
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

class _AssigneeRow extends StatelessWidget {
  const _AssigneeRow({
    required this.assigneeId,
    required this.stillInEvent,
    this.displayName,
  });

  final String assigneeId;
  final String? displayName;
  final bool stillInEvent;

  @override
  Widget build(BuildContext context) {
    final label = (displayName != null && displayName!.isNotEmpty)
        ? displayName!
        : (assigneeId.length > 10
              ? '${assigneeId.substring(0, 10)}…'
              : assigneeId);
    return Row(
      spacing: AppSpacing.sm,
      children: [
        Icon(
          AppIcons.navProfile,
          size: AppSizes.iconSm,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        Text('Assigned to $label'),
        if (!stillInEvent)
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.sm),
            child: Text(
              '(no longer in event)',
              style: TextStyle(
                color: AppColors.terracotta,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ),
      ],
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

/// Detail-screen overflow menu. Items in spec'd order:
/// Edit (canEditTask only) → Duplicate (visible to any viewer with a
/// non-null callback) → Delete (canEditTask only).
class _DetailOverflowMenu extends StatelessWidget {
  const _DetailOverflowMenu({
    required this.canEdit,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.tasks;
    return PopupMenuButton<_DetailAction>(
      key: const Key('tasks.detail.overflow'),
      icon: const Icon(AppIcons.actionMore),
      onSelected: (action) {
        switch (action) {
          case _DetailAction.edit:
            onEdit?.call();
          case _DetailAction.duplicate:
            onDuplicate?.call();
          case _DetailAction.delete:
            onDelete?.call();
        }
      },
      itemBuilder: (_) => [
        if (canEdit)
          PopupMenuItem<_DetailAction>(
            key: const Key('tasks.detail.overflow.edit'),
            value: _DetailAction.edit,
            child: Text(s.detailEdit),
          ),
        if (onDuplicate != null)
          PopupMenuItem<_DetailAction>(
            key: const Key('tasks.detail.overflow.duplicate'),
            value: _DetailAction.duplicate,
            child: Text(s.detailDuplicate),
          ),
        if (canEdit)
          PopupMenuItem<_DetailAction>(
            key: const Key('tasks.detail.overflow.delete'),
            value: _DetailAction.delete,
            child: Text(
              s.detailDelete,
              style: const TextStyle(color: AppColors.terracotta),
            ),
          ),
      ],
    );
  }
}
