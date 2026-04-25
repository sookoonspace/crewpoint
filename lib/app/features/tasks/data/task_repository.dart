import 'dart:developer';

import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/domain/repositories/i_task_repository.dart';

class TaskRepository implements ITaskRepository {
  const TaskRepository({required TasksDao tasksDao}) : _tasksDao = tasksDao;

  final TasksDao _tasksDao;

  @override
  Stream<List<TaskModel>> watchTasksByEventId(String eventId) {
    return _tasksDao
        .watchTasksByEventId(eventId)
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<TaskModel>> getTasksByEventId(String eventId) async {
    try {
      final rows = await _tasksDao.tasksByEventId(eventId);
      return rows.map(_toDomain).toList();
    } catch (e, st) {
      log('Failed to get tasks', error: e, stackTrace: st, name: 'tasks');
      return [];
    }
  }

  @override
  Future<bool> createTask(TaskModel task) async {
    try {
      await _tasksDao.insertTask(
        TasksCompanion.insert(
          id: task.id,
          eventId: task.eventId,
          title: task.title,
          description: Value(task.description),
          assigneeId: Value(task.assigneeId),
          status: Value(task.status.name),
          priority: Value(task.priority),
          dueDate: Value(task.dueDate),
        ),
      );
      return true;
    } catch (e, st) {
      log('Failed to create task', error: e, stackTrace: st, name: 'tasks');
      return false;
    }
  }

  @override
  Future<bool> updateTask(TaskModel task) async {
    try {
      await _tasksDao.updateTask(
        TasksCompanion(
          id: Value(task.id),
          eventId: Value(task.eventId),
          title: Value(task.title),
          description: Value(task.description),
          assigneeId: Value(task.assigneeId),
          status: Value(task.status.name),
          priority: Value(task.priority),
          dueDate: Value(task.dueDate),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return true;
    } catch (e, st) {
      log('Failed to update task', error: e, stackTrace: st, name: 'tasks');
      return false;
    }
  }

  @override
  Future<bool> deleteTask(String id) async {
    try {
      await _tasksDao.deleteTaskById(id);
      return true;
    } catch (e, st) {
      log('Failed to delete task', error: e, stackTrace: st, name: 'tasks');
      return false;
    }
  }

  TaskModel _toDomain(Task row) => TaskModel(
    id: row.id,
    eventId: row.eventId,
    title: row.title,
    description: row.description,
    assigneeId: row.assigneeId,
    status: _parseStatus(row.status),
    priority: row.priority,
    dueDate: row.dueDate,
  );

  TaskStatus _parseStatus(String status) => switch (status) {
    'inProgress' => TaskStatus.inProgress,
    'done' => TaskStatus.done,
    _ => TaskStatus.todo,
  };
}
