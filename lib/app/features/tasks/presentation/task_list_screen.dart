import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/empty_state_placeholder.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_tile.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/tasks_filter_bar.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/tasks_group_header.dart';

/// Tasks screen: filter bar + grouped list + empty state + FAB.
///
/// Pure presentation — parent (`EventTasksPage`) owns the `TasksFilter`
/// state and feeds in the already-filtered/sorted `groups` for rendering.
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({
    super.key,
    required this.groups,
    required this.event,
    required this.currentUserId,
    required this.filter,
    required this.onFilterChanged,
    this.onTaskTap,
    this.onStatusChanged,
    this.onCreateTask,
    this.onUnauthorizedStatusTap,
    this.onExportPdf,
  });

  final List<TasksGroup> groups;
  final EventModel event;
  final String currentUserId;
  final TasksFilter filter;
  final ValueChanged<TasksFilter> onFilterChanged;
  final ValueChanged<TaskModel>? onTaskTap;
  final void Function(TaskModel task, TaskStatus newStatus)? onStatusChanged;
  final VoidCallback? onCreateTask;
  final VoidCallback? onUnauthorizedStatusTap;
  final VoidCallback? onExportPdf;

  @override
  Widget build(BuildContext context) {
    final isOwner = event.isOwner(currentUserId);
    final isAdmin = event.isAdmin(currentUserId);
    final isEmpty = groups.isEmpty;
    final s = context.strings.tasks;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tasksAppBarTitle),
        actions: [
          if (onExportPdf != null)
            IconButton(
              key: const Key('tasks.export.pdf'),
              icon: Icon(AppIcons.actionShare),
              tooltip: s.exportPdfTooltip,
              onPressed: onExportPdf,
            ),
        ],
      ),
      body: ContentMaxWidth(
        key: const Key('eventTasks.body.clamped'),
        maxWidth: 720,
        child: Column(
          children: [
            TasksFilterBar(filter: filter, onFilterChanged: onFilterChanged),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: isEmpty
                  ? KeyedSubtree(
                      key: const Key('tasks.list.emptyState'),
                      // Per-event Tasks empty state — bypass the generic
                      // empty Lottie (the tent/house-shape flagged in
                      // 2026-06-11 QA) and fall through to the icon
                      // path, matching Phase 8 of the 2026-06-08 plan
                      // that fixed the global MyTasksScreen.
                      child: filter.hasActiveFilters
                          ? EmptyStatePlaceholder(
                              title: s.emptyNoMatch,
                              ctaLabel: s.clearFilters,
                              onCta: () => onFilterChanged(const TasksFilter()),
                              ctaKey: const Key('tasks.list.emptyState.clear'),
                              lottieAsset: null,
                              iconFallback: AppIcons.navTasks,
                            )
                          : EmptyStatePlaceholder(
                              title: s.emptyNoTasksYet,
                              subtitle: s.emptyNoTasksHelp,
                              lottieAsset: null,
                              iconFallback: AppIcons.navTasks,
                            ),
                    )
                  : ListView(
                      key: const Key('tasks.list'),
                      padding: EdgeInsets.symmetric(
                        horizontal: Breakpoints.screenHorizontalPadding(
                          context,
                        ),
                        vertical: AppSpacing.lg,
                      ),
                      children: [
                        for (final group in groups) ...[
                          TasksGroupHeader(
                            key: Key('tasks.list.groupHeader.${group.key}'),
                            label: group.label,
                          ),
                          for (final task in group.tasks)
                            TaskTile(
                              task: task,
                              canChangeStatus: task.canChangeStatus(
                                isOwner: isOwner,
                                isAdmin: isAdmin,
                                currentUserId: currentUserId,
                              ),
                              currencyCode: event.currency,
                              onTap: () => onTaskTap?.call(task),
                              onStatusChanged: (status) =>
                                  onStatusChanged?.call(task, status),
                              onUnauthorizedTap: onUnauthorizedStatusTap,
                            ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('tasks.list.create'),
        onPressed: onCreateTask,
        backgroundColor: AppColors.sage,
        foregroundColor: AppColors.white,
        child: const Icon(AppIcons.actionAdd),
      ),
    );
  }
}
