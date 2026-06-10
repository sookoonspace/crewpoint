import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';
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
  testWidgets('donation-mode expense shows a "Donated" pill so the row reads '
      'differently from a cost-shared one — fixes the 2026-06-08 QA '
      'note where Budget_detail_screen.PNG had identical-looking rows '
      'next to all-zero balances', (tester) async {
    const donatedExpense = ExpenseModel(
      id: 'exp-donated',
      eventId: 'evt-1',
      payerId: 'me',
      amount: 1000,
      description: "Let's keep it affordable",
      isDonation: true,
    );
    const donatedRow = RecentExpenseRow(
      expense: donatedExpense,
      event: _event,
      payerName: 'You',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentExpenseTile(
            row: donatedRow,
            currentUserId: 'me',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('budget.expense.donatedPill')), findsOneWidget);
    expect(find.text('Donated'), findsOneWidget);
  });

  testWidgets('non-donation expense does NOT show the "Donated" pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentExpenseTile(row: _row, currentUserId: 'me', onTap: () {}),
        ),
      ),
    );

    expect(find.byKey(const Key('budget.expense.donatedPill')), findsNothing);
    expect(find.text('Donated'), findsNothing);
  });

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

  testWidgets(
    'renders payerName (other user); avatar shows display-name initial',
    (tester) async {
      const otherPayer = ExpenseModel(
        id: 'exp-2',
        eventId: 'evt-1',
        payerId: 'alex',
        amount: 30,
      );
      const row = RecentExpenseRow(
        expense: otherPayer,
        event: _event,
        payerName: 'Alex Chen',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentExpenseTile(
              row: row,
              currentUserId: 'me',
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      // Description fallback uses payerName, never payerId.
      expect(find.text('Alex Chen paid'), findsOneWidget);
      expect(find.textContaining('alex'), findsNothing);
      final avatarText =
          tester.widget<CircleAvatar>(find.byType(CircleAvatar)).child! as Text;
      expect(avatarText.data, 'A');
    },
  );

  testWidgets(
    'placeholder payerName → avatar reads "?" and UID never appears',
    (tester) async {
      const ghost = ExpenseModel(
        id: 'exp-3',
        eventId: 'evt-1',
        payerId: 'ghost-uid',
        amount: 10,
      );
      const row = RecentExpenseRow(
        expense: ghost,
        event: _event,
        payerName: kRemovedMemberPlaceholder,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentExpenseTile(
              row: row,
              currentUserId: 'me',
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('$kRemovedMemberPlaceholder paid'), findsOneWidget);
      expect(find.textContaining('ghost-uid'), findsNothing);
      final avatarText =
          tester.widget<CircleAvatar>(find.byType(CircleAvatar)).child! as Text;
      expect(avatarText.data, '?');
    },
  );
}
