import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_tile.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/tasks_filter_bar.dart';

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
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: AppColors.cream,
        elevation: 0,
        actions: [
          if (onExportPdf != null)
            IconButton(
              key: const Key('tasks.export.pdf'),
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export PDF',
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
                  ? _EmptyState(
                      hasActiveFilters: filter.hasActiveFilters,
                      onClearFilters: () =>
                          onFilterChanged(const TasksFilter()),
                      noTasksLabel: s.emptyNoTasksYet,
                      noMatchLabel: s.emptyNoMatch,
                      clearLabel: s.clearFilters,
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
                          _GroupHeader(
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
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({super.key, required this.label});

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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasActiveFilters,
    required this.onClearFilters,
    required this.noTasksLabel,
    required this.noMatchLabel,
    required this.clearLabel,
  });

  final bool hasActiveFilters;
  final VoidCallback onClearFilters;
  final String noTasksLabel;
  final String noMatchLabel;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('tasks.list.emptyState'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasActiveFilters ? noMatchLabel : noTasksLabel,
            style: const TextStyle(color: AppColors.mediumGrey),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const Key('tasks.list.emptyState.clear'),
              onPressed: onClearFilters,
              child: Text(clearLabel),
            ),
          ],
        ],
      ),
    );
  }
}
