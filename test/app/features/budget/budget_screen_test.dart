import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
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

  testWidgets(
    'the top bar title surfaces the supplied event title rather than the '
    'generic "Budget" — users in multiple events need to know which '
    'ledger they are looking at',
    (tester) async {
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
        of: find.byType(CpTopBar),
        matching: find.text('Weekend getaway'),
      );
      expect(inAppBar, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CpTopBar),
          matching: find.text('Budget'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the top bar title falls back to "Budget" when no appBarTitle is supplied — '
    'covers callers that have not been migrated yet',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BudgetScreen(expenses: [], memberIds: ['u1', 'u2']),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(CpTopBar),
          matching: find.text('Budget'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('"+" sits in the top bar, so nothing floats over the last '
      'expense (Spec #186)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BudgetScreen(
          expenses: const [],
          memberIds: const ['u1', 'u2'],
          onAddExpense: () {},
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(CpTopBar),
        matching: find.byKey(const Key('budget.expense.create')),
      ),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('tapping an expense opens it', (tester) async {
    ExpenseModel? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: BudgetScreen(
          expenses: const [
            ExpenseModel(
              id: 'exp-1',
              eventId: 'evt-1',
              payerId: 'u1',
              amount: 25,
              description: 'Lunch',
            ),
          ],
          memberIds: const ['u1', 'u2'],
          onOpenExpense: (e) => opened = e,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('budget.expense.tile.exp-1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('budget.expense.tile.exp-1')));
    await tester.pump();
    expect(opened?.id, 'exp-1');
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

  // Req 43a: a 1,000-member event shows your balance and the largest 20,
  // and only your transfers and the largest 20, so the page stays quick.
  testWidgets('a large event shows you and the largest balances only', (
    tester,
  ) async {
    final members = [for (var i = 0; i < 1000; i++) 'u$i'];
    await tester.pumpWidget(
      MaterialApp(
        home: BudgetScreen(
          currentUserId: 'u500',
          memberIds: members,
          expenses: [
            ExpenseModel(
              id: 'dinner',
              eventId: 'e',
              payerId: 'u0',
              amount: 10000,
              splits: [
                for (final id in members) ExpenseSplit(userId: id, amount: 10),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('budget.balances.trimmed')), findsOneWidget);
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('budget.balance.'),
      skipOffstage: false,
    );
    expect(rows.evaluate().length, lessThanOrEqualTo(21));
    expect(
      find.byKey(const Key('budget.balance.u500'), skipOffstage: false),
      findsOneWidget,
    );
  });
}
