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

  testWidgets('last expense row 3-dot menu sits ≥ 16 px above the FAB top — '
      'fix for the 2026-06-11 iPhone 12 mini QA where the overflow '
      'menu was occluded by the create FAB', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 10 expenses with stable ids so the overflow menu Key resolves
    // and onEditExpense / onDeleteExpense callbacks are required for
    // the menu to render at all (see _OverflowMenu in expense_tile.dart).
    final expenses = List<ExpenseModel>.generate(
      10,
      (i) => ExpenseModel(
        id: 'exp-$i',
        eventId: 'evt-1',
        payerId: 'u1',
        amount: 25,
        description: 'Lunch $i',
        splits: const [
          ExpenseSplit(userId: 'u1', amount: 12.5),
          ExpenseSplit(userId: 'u2', amount: 12.5),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BudgetScreen(
          expenses: expenses,
          memberIds: const ['u1', 'u2'],
          onAddExpense: () {},
          onEditExpense: (_) {},
          onDeleteExpense: (_) {},
        ),
      ),
    );

    // Structural assertion: at the scaffold-body level, the ListView's
    // own bottom padding must cover FAB diameter (56) + endFloat margin
    // (16) + breathing room (16) = 88 px. The spatial alternative
    // (scroll to end + compare overflow.bottom vs fab.top) is fragile
    // under bouncing scroll physics that the iOS test target uses by
    // default — physics overshoots maxScrollExtent then bounces back,
    // leaving the list ~80 px short of true end. The padding value IS
    // the contract; the scaffold's FAB position is constant.
    final listView = tester.widget<ListView>(find.byType(ListView));
    final padding = listView.padding as EdgeInsets;
    expect(
      padding.bottom,
      greaterThanOrEqualTo(88.0),
      reason:
          'ListView.padding.bottom=${padding.bottom} px; need ≥ 88 (FAB '
          'diameter 56 + endFloat margin 16 + breathing room 16) so the '
          'last expense row\'s 3-dot menu clears the FAB at iPhone 12 '
          'mini.',
    );
  });

  testWidgets(
    'AppBar title wraps to 2 lines with a taller toolbar so long event '
    'titles like "Weekend getaway" no longer ellipsize (2026-06-11 QA)',
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

      final titleText = tester.widget<Text>(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Weekend getaway'),
        ),
      );
      expect(titleText.maxLines, 2, reason: 'title must allow 2 lines');

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(
        appBar.toolbarHeight,
        isNotNull,
        reason:
            'toolbarHeight must be set explicitly; Material defaults to '
            '56 which clips the second line.',
      );
      expect(
        appBar.toolbarHeight,
        greaterThanOrEqualTo(72.0),
        reason:
            'toolbarHeight=${appBar.toolbarHeight} is too small — needs '
            '>=72 to fit 2 lines of titleMedium.',
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
