import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/recent_expense_tile.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

const _event = EventModel(
  id: 'evt-1',
  title: 'Tahoe Trip',
  creatorId: 'me',
  memberIds: ['me', 'alex'],
  currency: 'USD',
);

const _expense = ExpenseModel(
  id: 'exp-1',
  eventId: 'evt-1',
  payerId: 'me',
  amount: 45,
  description: 'Pizza',
);

const _row = RecentExpenseRow(
  expense: _expense,
  event: _event,
  payerName: 'You',
);

void main() {
  testWidgets('wraps content in a Card for the elevated-tile look', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentExpenseTile(row: _row, currentUserId: 'me', onTap: () {}),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(RecentExpenseTile),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );
  });
}
