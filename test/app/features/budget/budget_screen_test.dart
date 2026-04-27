import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/budget_screen.dart';

void main() {
  testWidgets('shows empty state when no expenses', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BudgetScreen(expenses: [], memberIds: ['u1', 'u2']),
      ),
    );

    expect(find.text('No expenses yet'), findsOneWidget);
  });

  testWidgets('renders currency symbol from event currency', (tester) async {
    const expenses = [
      ExpenseModel(
        id: 'e1',
        eventId: 'evt-1',
        payerId: 'u1',
        amount: 50,
        splits: [
          ExpenseSplit(userId: 'u1', amount: 25),
          ExpenseSplit(userId: 'u2', amount: 25),
        ],
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: BudgetScreen(
          expenses: expenses,
          memberIds: ['u1', 'u2'],
          currency: 'EUR',
        ),
      ),
    );

    // Total card displays event currency.
    expect(find.text('€50.00'), findsOneWidget);
  });

  testWidgets('settlement row carries stable Key budget.settle.{payeeId} '
      'and renders with currency', (tester) async {
    // u2 paid 100 for the group, u1 owes u2 their share.
    const expenses = [
      ExpenseModel(
        id: 'e1',
        eventId: 'evt-1',
        payerId: 'u2',
        amount: 100,
        splits: [
          ExpenseSplit(userId: 'u1', amount: 50),
          ExpenseSplit(userId: 'u2', amount: 50),
        ],
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: BudgetScreen(
          expenses: expenses,
          memberIds: ['u1', 'u2'],
          currency: 'GBP',
        ),
      ),
    );

    expect(find.byKey(const Key('budget.settle.u2')), findsOneWidget);
    // Both the balance row ("u1 owes £50") and the settlement row render £50.
    expect(find.text('£50.00'), findsAtLeastNWidgets(1));
  });
}
