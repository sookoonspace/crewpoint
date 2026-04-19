import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_repository.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Manages task list state for a given event.
class TaskListNotifier extends Notifier<List<TaskModel>> {
  TaskListNotifier({
    required TaskRepository taskRepository,
    required String eventId,
  }) : _taskRepository = taskRepository,
       _eventId = eventId;

  final TaskRepository _taskRepository;
  final String _eventId;
  StreamSubscription<List<TaskModel>>? _subscription;

  @override
  List<TaskModel> build() {
    _subscription?.cancel();
    _subscription = _taskRepository
        .watchTasksByEventId(_eventId)
        .listen((tasks) => state = tasks);
    ref.onDispose(() => _subscription?.cancel());
    return [];
  }

  Future<bool> createTask(TaskModel task) => _taskRepository.createTask(task);

  Future<bool> updateTaskStatus(TaskModel task, TaskStatus newStatus) =>
      _taskRepository.updateTask(task.copyWith(status: newStatus));

  Future<bool> deleteTask(String id) => _taskRepository.deleteTask(id);
}

/// Provides filtered view of tasks by status.
class TaskFilterNotifier extends Notifier<TaskStatus?> {
  @override
  TaskStatus? build() => null;

  void setFilter(TaskStatus? status) => state = status;
}
