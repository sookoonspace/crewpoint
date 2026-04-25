import 'dart:developer';

import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/expenses_dao.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';

class ExpenseRepository implements IExpenseRepository {
  const ExpenseRepository({required ExpensesDao expensesDao})
    : _expensesDao = expensesDao;

  final ExpensesDao _expensesDao;

  @override
  Stream<List<ExpenseModel>> watchExpensesByEventId(String eventId) {
    return _expensesDao
        .watchExpensesByEventId(eventId)
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<ExpenseModel>> getExpensesByEventId(String eventId) async {
    try {
      final rows = await _expensesDao.expensesByEventId(eventId);
      return rows.map(_toDomain).toList();
    } catch (e, st) {
      log('Failed to get expenses', error: e, stackTrace: st, name: 'budget');
      return [];
    }
  }

  @override
  Future<bool> createExpense(ExpenseModel expense) async {
    try {
      await _expensesDao.insertExpense(
        ExpensesCompanion.insert(
          id: expense.id,
          eventId: expense.eventId,
          payerId: expense.payerId,
          amount: expense.amount,
          description: Value(expense.description),
          receiptPath: Value(expense.receiptPath),
          isDonation: Value(expense.isDonation),
        ),
      );
      return true;
    } catch (e, st) {
      log('Failed to create expense', error: e, stackTrace: st, name: 'budget');
      return false;
    }
  }

  @override
  Future<bool> deleteExpense(String id) async {
    try {
      await _expensesDao.deleteExpenseById(id);
      return true;
    } catch (e, st) {
      log('Failed to delete expense', error: e, stackTrace: st, name: 'budget');
      return false;
    }
  }

  ExpenseModel _toDomain(Expense row) => ExpenseModel(
    id: row.id,
    eventId: row.eventId,
    payerId: row.payerId,
    amount: row.amount,
    description: row.description,
    receiptPath: row.receiptPath,
    isDonation: row.isDonation,
    createdAt: row.createdAt,
  );
}
