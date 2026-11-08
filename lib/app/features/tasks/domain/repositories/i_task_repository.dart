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
  /// Saves [task]. A non-null [budgetEditedBy] also saves its budget figure,
  /// or clears it when empty, as that person (Req 36).
  Future<bool> updateTask(TaskModel task, {String? budgetEditedBy});

  /// Budget figures by task ID, for people holding `budget.read`.
  Stream<Map<String, double>> watchBudgets(String eventId);
  Future<bool> deleteTask(String id);
}
