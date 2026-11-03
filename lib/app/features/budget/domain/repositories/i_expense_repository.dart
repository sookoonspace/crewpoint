import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

/// Calls the `saveExpense` Cloud Function. Injected so tests never reach it.
typedef SaveExpenseCall = Future<void> Function(ExpenseModel expense);

/// Calls the `recordSettlement` Cloud Function, which writes the payment and its
/// chat notice together. Injected so tests never reach it.
typedef RecordSettlementCall =
    Future<void> Function({
      required String eventId,
      required String settlementId,
      required String payerId,
      required String payeeId,
      required double amount,
    });

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
