import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

part 'expense_splits_dao.g.dart';

@DriftAccessor(tables: [ExpenseSplits])
class ExpenseSplitsDao extends DatabaseAccessor<AppDatabase>
    with _$ExpenseSplitsDaoMixin {
  ExpenseSplitsDao(super.db);

  Future<List<ExpenseSplit>> byExpenseId(String expenseId) => (select(
    expenseSplits,
  )..where((s) => s.expenseId.equals(expenseId))).get();

  Future<int> upsert(ExpenseSplitsCompanion entry) =>
      into(expenseSplits).insertOnConflictUpdate(entry);

  Future<int> deleteByExpenseId(String expenseId) =>
      (delete(expenseSplits)..where((s) => s.expenseId.equals(expenseId))).go();
}
