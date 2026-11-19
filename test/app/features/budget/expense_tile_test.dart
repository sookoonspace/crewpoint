import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_tile.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';

void main() {
  testWidgets(
    'donation-mode expense renders the shared DonatedPill — keeps the '
    'per-event Budget detail consistent with the global Budget tab',
    (tester) async {
      const expense = ExpenseModel(
        id: 'exp-donated',
        eventId: 'evt-1',
        payerId: 'user-1',
        amount: 1000,
        description: "Let's keep it affordable",
        isDonation: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ExpenseTile(expense: expense)),
        ),
      );

      expect(
        find.byKey(const Key('budget.expense.donatedPill')),
        findsOneWidget,
      );
      expect(find.text('Donated'), findsOneWidget);
    },
  );

  testWidgets('non-donation expense does NOT render the DonatedPill', (
    tester,
  ) async {
    const expense = ExpenseModel(
      id: 'exp-regular',
      eventId: 'evt-1',
      payerId: 'user-1',
      amount: 25,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ExpenseTile(expense: expense)),
      ),
    );

    expect(find.byKey(const Key('budget.expense.donatedPill')), findsNothing);
  });

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
      expect(find.byIcon(CpIcons.receipt), findsOneWidget);
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

  group('row (Spec #186)', () {
    Widget pump(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, child: child)),
    );

    testWidgets('tapping the row opens the expense', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        pump(
          ExpenseTile(
            expense: const ExpenseModel(
              id: 'exp-1',
              eventId: 'evt-1',
              payerId: 'payer-1',
              amount: 25,
              description: 'Lunch',
            ),
            payerName: 'Priya',
            onTap: () => opened = true,
          ),
        ),
      );
      expect(find.text('Paid by Priya'), findsOneWidget);
      await tester.tap(find.byKey(const Key('budget.expense.tile.exp-1')));
      expect(opened, isTrue);
    });

    testWidgets('a settlement reads "Ravi paid Priya" with the green Paid '
        'chip and its icon', (tester) async {
      await tester.pumpWidget(
        pump(
          const ExpenseTile(
            expense: ExpenseModel(
              id: 'pay-1',
              eventId: 'evt-1',
              payerId: 'ravi',
              amount: 50,
              isPayment: true,
            ),
            payerName: 'Ravi',
            payeeName: 'Priya',
          ),
        ),
      );
      expect(find.text('Ravi paid Priya'), findsOneWidget);
      final chip = find.byKey(const Key('budget.expense.tile.pay-1.paid'));
      expect(tester.widget<CpStatusChip>(chip).status, CpStatus.done);
      expect(
        find.descendant(of: chip, matching: find.byIcon(CpIcons.statusDone)),
        findsOneWidget,
      );
    });
  });
}
