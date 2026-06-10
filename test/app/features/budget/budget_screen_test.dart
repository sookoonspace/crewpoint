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

  testWidgets('AppBar title surfaces the supplied event title rather than the '
      'generic "Budget" — users in multiple events need to know which '
      'ledger they are looking at', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BudgetScreen(
          expenses: [],
          memberIds: ['u1', 'u2'],
          appBarTitle: 'Weekend getaway',
        ),
      ),
    );

    // The AppBar slot owns this title — restrict the finder to that
    // subtree so a body widget that happens to share the string can't
    // satisfy the assertion.
    final inAppBar = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Weekend getaway'),
    );
    expect(inAppBar, findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Budget')),
      findsNothing,
    );
  });

  testWidgets(
    'AppBar title falls back to "Budget" when no appBarTitle is supplied — '
    'covers callers that have not been migrated yet',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BudgetScreen(expenses: [], memberIds: ['u1', 'u2']),
        ),
      );

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Budget')),
        findsOneWidget,
      );
    },
  );

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

    // Total card and tile both display event currency now that tile is threaded.
    expect(find.text('€50.00'), findsAtLeastNWidgets(1));
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
