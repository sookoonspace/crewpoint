import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

part 'task_checklist_items_dao.g.dart';

@DriftAccessor(tables: [TaskChecklistItems])
class TaskChecklistItemsDao extends DatabaseAccessor<AppDatabase>
    with _$TaskChecklistItemsDaoMixin {
  TaskChecklistItemsDao(super.db);

  Stream<List<TaskChecklistItem>> watchByTaskId(String taskId) =>
      (select(taskChecklistItems)
            ..where((c) => c.taskId.equals(taskId))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .watch();

  Future<List<TaskChecklistItem>> byTaskId(String taskId) =>
      (select(taskChecklistItems)
            ..where((c) => c.taskId.equals(taskId))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  Future<int> upsert(TaskChecklistItemsCompanion entry) =>
      into(taskChecklistItems).insertOnConflictUpdate(entry);

  Future<int> deleteById(String id) =>
      (delete(taskChecklistItems)..where((c) => c.id.equals(id))).go();

  Future<int> deleteByTaskId(String taskId) =>
      (delete(taskChecklistItems)..where((c) => c.taskId.equals(taskId))).go();
}
