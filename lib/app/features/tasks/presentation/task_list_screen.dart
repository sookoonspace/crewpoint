import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_tile.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({
    super.key,
    required this.tasks,
    required this.event,
    required this.currentUserId,
    this.selectedFilter,
    this.onFilterChanged,
    this.onTaskTap,
    this.onStatusChanged,
    this.onCreateTask,
    this.onUnauthorizedStatusTap,
    this.onExportPdf,
  });

  final List<TaskModel> tasks;
  final EventModel event;
  final String currentUserId;
  final TaskStatus? selectedFilter;
  final ValueChanged<TaskStatus?>? onFilterChanged;
  final ValueChanged<TaskModel>? onTaskTap;
  final void Function(TaskModel task, TaskStatus newStatus)? onStatusChanged;
  final VoidCallback? onCreateTask;
  final VoidCallback? onUnauthorizedStatusTap;
  final VoidCallback? onExportPdf;

  @override
  Widget build(BuildContext context) {
    final filteredTasks = selectedFilter == null
        ? tasks
        : tasks.where((t) => t.status == selectedFilter).toList();

    final isOwner = event.isOwner(currentUserId);
    final isAdmin = event.isAdmin(currentUserId);

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _FilterBar(
            selected: selectedFilter,
            onChanged: onFilterChanged,
          ),
        ),
      ),
      body: ContentMaxWidth(
        key: const Key('eventTasks.body.clamped'),
        maxWidth: 720,
        child: filteredTasks.isEmpty
            ? const Center(
                key: Key('tasks.list.empty'),
                child: Text(
                  'No tasks yet',
                  style: TextStyle(color: AppColors.mediumGrey),
                ),
              )
            : ListView.builder(
                key: const Key('tasks.list'),
                padding: EdgeInsets.symmetric(
                  horizontal: Breakpoints.screenHorizontalPadding(context),
                  vertical: AppSpacing.xl,
                ),
                itemCount: filteredTasks.length,
                itemBuilder: (_, index) {
                  final task = filteredTasks[index];
                  final canChange = task.canChangeStatus(
                    isOwner: isOwner,
                    isAdmin: isAdmin,
                    currentUserId: currentUserId,
                  );
                  return TaskTile(
                    task: task,
                    canChangeStatus: canChange,
                    currencyCode: event.currency,
                    onTap: () => onTaskTap?.call(task),
                    onStatusChanged: (status) =>
                        onStatusChanged?.call(task, status),
                    onUnauthorizedTap: onUnauthorizedStatusTap,
                  );
                },
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({this.selected, this.onChanged});

  final TaskStatus? selected;
  final ValueChanged<TaskStatus?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onChanged?.call(null),
          ),
          for (final status in TaskStatus.values)
            FilterChip(
              label: Text(status.label),
              selected: selected == status,
              onSelected: (_) => onChanged?.call(status),
            ),
        ],
      ),
    );
  }
}
