import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/expense_detail_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// #202: an expense's own page, with Edit and Delete in its menu.
void main() {
  const event = EventModel(
    id: 'evt-1',
    title: 'Trip',
    creatorId: 'u1',
    memberIds: ['u1', 'u2', 'u3'],
  );
  const exp = ExpenseModel(
    id: 'exp-1',
    eventId: 'evt-1',
    payerId: 'u1',
    amount: 30,
    description: 'Lunch',
    splits: [
      ExpenseSplit(userId: 'u1', amount: 10),
      ExpenseSplit(userId: 'u2', amount: 10),
      ExpenseSplit(userId: 'u3', amount: 10),
    ],
  );
  const settlement = ExpenseModel(
    id: 'pay-1',
    eventId: 'evt-1',
    payerId: 'u1',
    amount: 50,
    isPayment: true,
    splits: [ExpenseSplit(userId: 'u2', amount: 50)],
  );

  Future<void> pump(
    WidgetTester tester,
    ExpenseModel expense, {
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) => tester.pumpWidget(
    MaterialApp(
      home: ExpenseDetailScreen(
        expense: expense,
        event: event,
        currencySymbol: r'$',
        payerName: 'Priya',
        payeeName: 'Ravi',
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    ),
  );

  testWidgets('shows the amount, who paid and the share', (tester) async {
    await pump(tester, exp);
    expect(find.text(r'$30.00'), findsOneWidget);
    expect(find.text('Priya'), findsOneWidget);
    expect(find.text(r'Everyone (3) · $10.00 each'), findsOneWidget);
  });

  testWidgets('no menu without Edit or Delete', (tester) async {
    await pump(tester, exp);
    expect(
      find.byKey(const Key('budget.expense.exp-1.overflow')),
      findsNothing,
    );
  });

  testWidgets('Edit and Delete fire their callbacks', (tester) async {
    var edited = false;
    var deleted = false;
    await pump(
      tester,
      exp,
      onEdit: () => edited = true,
      onDelete: () => deleted = true,
    );
    await tester.tap(find.byKey(const Key('budget.expense.exp-1.overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('budget.expense.exp-1.edit')));
    await tester.pumpAndSettle();
    expect(edited, isTrue);

    await tester.tap(find.byKey(const Key('budget.expense.exp-1.overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('budget.expense.exp-1.delete')));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('a settlement is never edited here, only deleted, and shows '
      'Paid', (tester) async {
    await pump(tester, settlement, onEdit: () {}, onDelete: () {});
    expect(find.text('Priya paid Ravi'), findsWidgets);
    expect(find.byType(CpStatusChip), findsWidgets);
    await tester.tap(find.byKey(const Key('budget.expense.pay-1.overflow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('budget.expense.pay-1.edit')), findsNothing);
    expect(
      find.byKey(const Key('budget.expense.pay-1.delete')),
      findsOneWidget,
    );
  });
}
