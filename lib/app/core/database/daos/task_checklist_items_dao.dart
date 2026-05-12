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

  /// Returns a map from `taskId` → ordered checklist items for every task
  /// id in [taskIds]. Single query — used by `TaskRepository`'s list path
  /// to populate `TaskModel.checklistItems` without N+1 selects.
  Future<Map<String, List<TaskChecklistItem>>> itemsByTaskIds(
    List<String> taskIds,
  ) async {
    if (taskIds.isEmpty) return const {};
    final rows =
        await (select(taskChecklistItems)
              ..where((c) => c.taskId.isIn(taskIds))
              ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
            .get();
    final out = <String, List<TaskChecklistItem>>{};
    for (final row in rows) {
      out.putIfAbsent(row.taskId, () => []).add(row);
    }
    return out;
  }
}
