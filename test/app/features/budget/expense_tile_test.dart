import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_tile.dart';

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

  group('overflow menu (Edit / Delete)', () {
    Widget pump(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, child: child)),
    );

    const exp = ExpenseModel(
      id: 'exp-1',
      eventId: 'evt-1',
      payerId: 'payer-1',
      amount: 25,
      description: 'Lunch',
    );
    const settlement = ExpenseModel(
      id: 'pay-1',
      eventId: 'evt-1',
      payerId: 'payer-1',
      amount: 50,
      isPayment: true,
    );

    testWidgets('hidden when both callbacks are null', (tester) async {
      await tester.pumpWidget(pump(const ExpenseTile(expense: exp)));
      expect(
        find.byKey(const Key('budget.expense.exp-1.overflow')),
        findsNothing,
      );
    });

    testWidgets('renders Edit + Delete when both callbacks non-null', (
      tester,
    ) async {
      await tester.pumpWidget(
        pump(ExpenseTile(expense: exp, onEdit: () {}, onDelete: () {})),
      );
      await tester.tap(find.byKey(const Key('budget.expense.exp-1.overflow')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('budget.expense.exp-1.edit')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('budget.expense.exp-1.delete')),
        findsOneWidget,
      );
    });

    testWidgets('hides Edit when expense.isPayment is true', (tester) async {
      await tester.pumpWidget(
        pump(ExpenseTile(expense: settlement, onEdit: () {}, onDelete: () {})),
      );
      await tester.tap(find.byKey(const Key('budget.expense.pay-1.overflow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('budget.expense.pay-1.edit')), findsNothing);
      expect(
        find.byKey(const Key('budget.expense.pay-1.delete')),
        findsOneWidget,
      );
    });

    testWidgets('Edit + Delete tap fires the matching callback', (
      tester,
    ) async {
      var editFired = false;
      var deleteFired = false;
      await tester.pumpWidget(
        pump(
          ExpenseTile(
            expense: exp,
            onEdit: () => editFired = true,
            onDelete: () => deleteFired = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('budget.expense.exp-1.overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('budget.expense.exp-1.edit')));
      await tester.pumpAndSettle();
      expect(editFired, isTrue);

      await tester.tap(find.byKey(const Key('budget.expense.exp-1.overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('budget.expense.exp-1.delete')));
      await tester.pumpAndSettle();
      expect(deleteFired, isTrue);
    });
  });
}
