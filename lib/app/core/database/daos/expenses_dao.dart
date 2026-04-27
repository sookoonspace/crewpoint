import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

part 'expenses_dao.g.dart';

@DriftAccessor(tables: [Expenses])
class ExpensesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpensesDaoMixin {
  ExpensesDao(super.db);

  Future<List<Expense>> allExpenses() => select(expenses).get();

  Future<List<Expense>> expensesByEventId(String eventId) =>
      (select(expenses)..where((e) => e.eventId.equals(eventId))).get();

  Stream<List<Expense>> watchExpensesByEventId(String eventId) =>
      (select(expenses)..where((e) => e.eventId.equals(eventId))).watch();

  Future<int> insertExpense(ExpensesCompanion entry) =>
      into(expenses).insert(entry);

  Future<int> insertOrReplace(ExpensesCompanion entry) =>
      into(expenses).insertOnConflictUpdate(entry);

  Future<int> deleteExpenseById(String id) =>
      (delete(expenses)..where((e) => e.id.equals(id))).go();
}
