import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Abstract task repository.
abstract class ITaskRepository {
  Stream<List<TaskModel>> watchTasksByEventId(String eventId);
  Future<List<TaskModel>> getTasksByEventId(String eventId);
  Future<bool> createTask(TaskModel task);
  Future<bool> updateTask(TaskModel task);
  Future<bool> deleteTask(String id);
}
