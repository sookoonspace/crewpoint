import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

/// Abstract expense repository.
abstract class IExpenseRepository {
  Stream<List<ExpenseModel>> watchExpensesByEventId(String eventId);
  Future<List<ExpenseModel>> getExpensesByEventId(String eventId);
  Future<bool> createExpense(ExpenseModel expense);
  Future<bool> deleteExpense(String id);
}
