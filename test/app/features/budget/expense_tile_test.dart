import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_tile.dart';

void main() {
  testWidgets(
    'expense without receipt shows the default receipt icon, no thumbnail',
    (tester) async {
      const expense = ExpenseModel(
        id: 'exp-1',
        eventId: 'evt-1',
        payerId: 'user-1',
        amount: 25,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ExpenseTile(expense: expense)),
        ),
      );

      expect(
        find.byKey(const Key('budget.expense.tile.exp-1.thumbnail')),
        findsNothing,
      );
      expect(find.byIcon(Icons.receipt), findsOneWidget);
    },
  );

  testWidgets(
    'expense with receiptPath renders a tappable thumbnail with stable Key',
    (tester) async {
      const expense = ExpenseModel(
        id: 'exp-1',
        eventId: 'evt-1',
        payerId: 'user-1',
        amount: 25,
        receiptPath: 'https://cdn.example/events/evt-1/receipts/exp-1.jpg',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ExpenseTile(expense: expense)),
        ),
      );

      expect(
        find.byKey(const Key('budget.expense.tile.exp-1.thumbnail')),
        findsOneWidget,
      );
    },
  );

  testWidgets('expense tile uses currencySymbol prop in amount', (
    tester,
  ) async {
    const expense = ExpenseModel(
      id: 'exp-1',
      eventId: 'evt-1',
      payerId: 'user-1',
      amount: 25,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpenseTile(expense: expense, currencySymbol: '€'),
        ),
      ),
    );

    expect(find.text('€25.00'), findsOneWidget);
  });
}
