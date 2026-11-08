import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Abstract task repository.
abstract class ITaskRepository {
  /// An event's tasks, or only those assigned to [assigneeId] when set, for
  /// a Vendor or Observer (Req 32).
  Stream<List<TaskModel>> watchTasksByEventId(
    String eventId, {
    String? assigneeId,
  });
  Future<List<TaskModel>> getTasksByEventId(String eventId);
  Future<bool> createTask(TaskModel task);
  Future<bool> updateTask(TaskModel task);
  Future<bool> deleteTask(String id);
}
