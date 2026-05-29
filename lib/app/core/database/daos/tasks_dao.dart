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

  Future<int> insertOrReplace(TasksCompanion entry) =>
      into(tasks).insertOnConflictUpdate(entry);

  Future<bool> updateTask(TasksCompanion entry) => update(tasks).replace(entry);

  Future<int> deleteTaskById(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  /// Reactive stream of per-status counts for one event. Backed by
  /// Drift's `.watch()` on the `tasks` table, so the result re-emits
  /// whenever a task row mutates locally (insert / update / delete).
  /// Used by the Dashboard progress ring.
  Stream<({int todo, int doing, int done})> watchCountsByEventId(
    String eventId,
  ) {
    return watchTasksByEventId(eventId).map((rows) {
      var todo = 0;
      var doing = 0;
      var done = 0;
      for (final row in rows) {
        switch (row.status) {
          case 'todo':
            todo++;
          case 'inProgress':
            doing++;
          case 'done':
            done++;
        }
      }
      return (todo: todo, doing: doing, done: done);
    });
  }
}
