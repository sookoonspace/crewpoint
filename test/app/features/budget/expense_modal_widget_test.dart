import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_modal.dart';

void main() {
  testWidgets('Add receipt button is hidden when onPickReceipt is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpenseModal(
            eventId: 'evt-1',
            payerId: 'u1',
            memberIds: ['u1', 'u2'],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('budget.expense.receipt.add')), findsNothing);
  });

  testWidgets(
    'Add receipt button visible + tap pulls picker; preview shown after',
    (tester) async {
      // The picker returns a placeholder File path. Image.file may fail
      // to decode in tests — the row's errorBuilder still renders.
      Future<File?> picker() async => File('/tmp/fake-receipt.jpg');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseModal(
              eventId: 'evt-1',
              payerId: 'u1',
              memberIds: const ['u1', 'u2'],
              onPickReceipt: picker,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('budget.expense.receipt.add')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('budget.expense.receipt.add')));
      await tester.pump();

      expect(
        find.byKey(const Key('budget.expense.receipt.preview')),
        findsOneWidget,
      );
    },
  );

  testWidgets('submit passes the picked file to onSubmit', (tester) async {
    Future<File?> picker() async => File('/tmp/fake-receipt.jpg');
    ExpenseModel? submitted;
    File? submittedReceipt;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ExpenseModal(
              eventId: 'evt-1',
              payerId: 'u1',
              memberIds: const ['u1', 'u2'],
              onPickReceipt: picker,
              onSubmit: (expense, receipt) {
                submitted = expense;
                submittedReceipt = receipt;
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('budget.expense.amount')),
      '12.34',
    );
    await tester.tap(find.byKey(const Key('budget.expense.receipt.add')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('budget.expense.save')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.amount, closeTo(12.34, 0.001));
    expect(submittedReceipt, isNotNull);
    expect(submittedReceipt!.path, equals('/tmp/fake-receipt.jpg'));
  });
}
