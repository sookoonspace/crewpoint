import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

part 'tasks_dao.g.dart';

@DriftAccessor(tables: [Tasks])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  Future<List<Task>> allTasks() => select(tasks).get();

  Stream<List<Task>> watchAllTasks() => select(tasks).watch();

  Future<List<Task>> tasksByEventId(String eventId) =>
      (select(tasks)..where((t) => t.eventId.equals(eventId))).get();

  Stream<List<Task>> watchTasksByEventId(String eventId) =>
      (select(tasks)..where((t) => t.eventId.equals(eventId))).watch();

  Future<Task?> taskById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTask(TasksCompanion entry) => into(tasks).insert(entry);

  Future<bool> updateTask(TasksCompanion entry) => update(tasks).replace(entry);

  Future<int> deleteTaskById(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();
}
