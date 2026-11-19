import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/layout/cp_list_detail.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/crew.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_tile.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/tasks_filter_bar.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/tasks_group_header.dart';

/// The event's Tasks screen (Spec #186): progress, filters, then the tasks
/// in groups. From 840 px the chosen task ([detail]) sits beside the list
/// ([CpListDetail]); narrower the list shows alone.
///
/// Pure presentation: the parent (`EventTasksPage`) keeps the filter and
/// passes the already filtered, sorted and grouped [groups].
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({
    super.key,
    required this.groups,
    required this.event,
    required this.currentUserId,
    required this.filter,
    required this.onFilterChanged,
    this.progress,
    this.crews = const [],
    this.assigneeNames = const {},
    this.selectedId,
    this.detail,
    this.scrollController,
    this.onTaskTap,
    this.onStatusChanged,
    this.onCreateTask,
    this.onUnauthorizedStatusTap,
    this.onExportPdf,
    this.onBack,
    this.banner,
  });

  final List<TasksGroup> groups;
  final EventModel event;
  final String currentUserId;
  final TasksFilter filter;
  final ValueChanged<TasksFilter> onFilterChanged;

  /// Every task's progress, before filtering, for the card at the top.
  final ({int done, int total, int overdue, int dueThisWeek})? progress;

  /// The event's crews (Req 72). With none, nothing about crews shows.
  final List<CrewModel> crews;

  /// Names of the assignees shown, read one by one (Req 43a).
  final Map<String, String> assigneeNames;

  /// The task open beside the list, from the route.
  final String? selectedId;
  final Widget? detail;
  final ScrollController? scrollController;
  final ValueChanged<TaskModel>? onTaskTap;
  final void Function(TaskModel task, TaskStatus newStatus)? onStatusChanged;
  final VoidCallback? onCreateTask;
  final VoidCallback? onUnauthorizedStatusTap;
  final VoidCallback? onExportPdf;
  final VoidCallback? onBack;

  /// Shown above the list, such as the offline note (Req 74).
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.tasks;
    final roles = context.strings.roles;
    final managesTasks = event.can(currentUserId, 'tasks.manage');
    final crewNames = {for (final c in crews) c.id: c.name};
    // Observers and Vendors cannot create tasks (Req 34).
    final creates =
        event.canEditTasks(currentUserId) && event.contributes(currentUserId);
    final p = progress;

    final list = ListView(
      key: const Key('tasks.list'),
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        cp.space.lg,
        cp.space.sm,
        cp.space.lg,
        cp.space.xxl,
      ),
      children: [
        ?banner,
        if (p != null && p.total > 0)
          Padding(
            padding: EdgeInsets.only(bottom: cp.space.md),
            child: _ProgressCard(progress: p),
          ),
        TasksFilterBar(
          filter: filter,
          onFilterChanged: onFilterChanged,
          crews: crews,
          crewWords: (
            one: event.words.one('crew'),
            other: event.words.other('crew'),
          ),
          readsBudgets: event.can(currentUserId, 'budget.read'),
        ),
        if (groups.isEmpty)
          KeyedSubtree(
            key: const Key('tasks.list.emptyState'),
            child: Padding(
              padding: EdgeInsets.only(top: cp.space.xl),
              child: filter.hasActiveFilters
                  ? CpEmptyState(
                      icon: CpIcons.navTasks,
                      title: s.emptyNoMatch,
                      actionLabel: s.clearFilters,
                      actionKey: const Key('tasks.list.emptyState.clear'),
                      onAction: () => onFilterChanged(const TasksFilter()),
                    )
                  : CpEmptyState(
                      icon: CpIcons.navTasks,
                      title: s.emptyNoTasksYet,
                      message: s.emptyNoTasksHelp,
                    ),
            ),
          ),
        for (final group in groups) ...[
          TasksGroupHeader(
            key: Key('tasks.list.groupHeader.${group.key}'),
            label: group.label,
            count: group.tasks.length,
          ),
          CpCard(
            child: CpRowGroup(
              children: [
                for (final task in group.tasks)
                  Builder(
                    builder: (row) => TaskTile(
                      task: task,
                      canChangeStatus: task.canChangeStatus(
                        managesTasks: managesTasks,
                        currentUserId: currentUserId,
                      ),
                      currencyCode: event.currency,
                      crewName: crewNames[task.crewId],
                      assigneeName: assigneeNames[task.assigneeId],
                      selected: task.id == selectedId,
                      // Asks first when the open task has unsaved edits.
                      onTap: () =>
                          CpListDetail.select(row, () => onTaskTap?.call(task)),
                      onStatusChanged: (status) =>
                          onStatusChanged?.call(task, status),
                      onUnauthorizedTap: onUnauthorizedStatusTap,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: s.tasksAppBarTitle,
        leadingKey: const Key('tasks.list.back'),
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: onBack,
        actions: [
          if (onExportPdf != null)
            CpTopBarAction(
              key: const Key('tasks.export.pdf'),
              icon: CpIcons.actionShare,
              tooltip: s.exportPdfTooltip,
              onPressed: onExportPdf!,
            ),
          if (creates)
            CpTopBarAction(
              key: const Key('tasks.list.create'),
              icon: CpIcons.actionAdd,
              tooltip: s.createTaskTitle,
              primary: true,
              onPressed: onCreateTask ?? () {},
            ),
        ],
      ),
      body: CpListDetail(
        list: ContentMaxWidth(
          key: const Key('eventTasks.body.clamped'),
          maxWidth: cp.sizes.phoneColumn,
          child: list,
        ),
        detail: detail,
        placeholder: context.strings.nav.selectToSee(s.taskWord),
        unsavedText: CpUnsavedText(
          title: roles.discardTitle,
          body: roles.discardBody,
          keep: roles.keepEditing,
          discard: roles.discard,
        ),
      ),
    );
  }
}

/// "18 of 26 done" with a ring, and what is overdue or due this week.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final ({int done, int total, int overdue, int dueThisWeek}) progress;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.tasks;
    final p = progress;
    final headline = s.doneOf(p.done, p.total);
    return CpCard(
      key: const Key('tasks.list.progress'),
      padding: EdgeInsets.all(cp.space.lg),
      child: Row(
        spacing: cp.space.lg,
        children: [
          CpProgressRing(
            value: p.total == 0 ? 0 : p.done / p.total,
            semanticLabel: headline,
            size: cp.sizes.ringLg,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: cp.space.xs / 2,
              children: [
                Text(
                  headline,
                  style: cp.type.titleMedium.copyWith(color: cp.colors.text),
                ),
                Text(
                  s.progressDetail(p.overdue, p.dueThisWeek),
                  style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
