import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

/// Calls the `saveExpense` Cloud Function. Injected so tests never reach it.
typedef SaveExpenseCall = Future<void> Function(ExpenseModel expense);

/// How saving an expense ended. Saving needs a connection, because the server
/// validates money before anything is written.
enum ExpenseSaveResult { saved, needsConnection, rejected }

/// Abstract expense repository.
abstract class IExpenseRepository {
  Stream<List<ExpenseModel>> watchExpensesByEventId(String eventId);
  Future<List<ExpenseModel>> getExpensesByEventId(String eventId);
  Future<ExpenseSaveResult> saveExpense(ExpenseModel expense);
  Future<bool> deleteExpense(String id);
}
