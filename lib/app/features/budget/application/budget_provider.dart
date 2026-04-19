import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_repository.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

class BudgetNotifier extends Notifier<List<ExpenseModel>> {
  BudgetNotifier({
    required ExpenseRepository expenseRepository,
    required String eventId,
  }) : _expenseRepository = expenseRepository,
       _eventId = eventId;

  final ExpenseRepository _expenseRepository;
  final String _eventId;
  StreamSubscription<List<ExpenseModel>>? _subscription;

  @override
  List<ExpenseModel> build() {
    _subscription?.cancel();
    _subscription = _expenseRepository
        .watchExpensesByEventId(_eventId)
        .listen((expenses) => state = expenses);
    ref.onDispose(() => _subscription?.cancel());
    return [];
  }

  double get totalExpenses => state.fold(0.0, (sum, e) => sum + e.amount);

  Future<bool> createExpense(ExpenseModel expense) =>
      _expenseRepository.createExpense(expense);

  Future<bool> deleteExpense(String id) => _expenseRepository.deleteExpense(id);
}
