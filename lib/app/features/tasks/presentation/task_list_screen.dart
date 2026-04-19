import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_tile.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({
    super.key,
    required this.tasks,
    this.selectedFilter,
    this.onFilterChanged,
    this.onTaskTap,
    this.onStatusChanged,
    this.onCreateTask,
  });

  final List<TaskModel> tasks;
  final TaskStatus? selectedFilter;
  final ValueChanged<TaskStatus?>? onFilterChanged;
  final ValueChanged<TaskModel>? onTaskTap;
  final void Function(TaskModel task, TaskStatus newStatus)? onStatusChanged;
  final VoidCallback? onCreateTask;

  @override
  Widget build(BuildContext context) {
    final filteredTasks = selectedFilter == null
        ? tasks
        : tasks.where((t) => t.status == selectedFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _FilterBar(
            selected: selectedFilter,
            onChanged: onFilterChanged,
          ),
        ),
      ),
      body: filteredTasks.isEmpty
          ? const Center(
              child: Text(
                'No tasks',
                style: TextStyle(color: AppColors.mediumGrey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: filteredTasks.length,
              itemBuilder: (_, index) => TaskTile(
                task: filteredTasks[index],
                onTap: () => onTaskTap?.call(filteredTasks[index]),
                onStatusChanged: (status) =>
                    onStatusChanged?.call(filteredTasks[index], status),
              ),
            ),
      floatingActionButton: FloatingActionButton(
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
