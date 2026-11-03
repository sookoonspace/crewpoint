import 'dart:async';

import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/expense_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _amount = Key('budget.expense.amount');
const _save = Key('budget.expense.save');
const _error = Key('budget.expense.error');

Future<void> _openModal(
  WidgetTester tester,
  Future<ExpenseSaveResult> Function(ExpenseModel, PickedImage?) onSubmit,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => ExpenseModal.show(
              context: ctx,
              eventId: 'evt',
              payerId: 'u1',
              memberIds: const ['u1', 'u2'],
              onSubmit: onSubmit,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(_amount), '12.50');
}

void main() {
  testWidgets('closes once the expense is saved', (tester) async {
    await _openModal(tester, (_, _) async => ExpenseSaveResult.saved);
    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();
    expect(find.byKey(_amount), findsNothing);
  });

  testWidgets('stays open while saving, and cannot be sent twice', (
    tester,
  ) async {
    final result = Completer<ExpenseSaveResult>();
    var sends = 0;
    await _openModal(tester, (_, _) {
      sends++;
      return result.future;
    });
    await tester.tap(find.byKey(_save));
    await tester.pump();

    expect(find.byKey(_amount), findsOneWidget);
    await tester.tap(find.byKey(_save), warnIfMissed: false);
    await tester.pump();
    expect(sends, 1);

    result.complete(ExpenseSaveResult.saved);
    await tester.pumpAndSettle();
    expect(find.byKey(_amount), findsNothing);
  });

  testWidgets('without a connection, keeps the form and offers retry', (
    tester,
  ) async {
    final results = [
      ExpenseSaveResult.needsConnection,
      ExpenseSaveResult.saved,
    ];
    final sent = <ExpenseModel>[];
    await _openModal(tester, (expense, _) async {
      sent.add(expense);
      return results.removeAt(0);
    });

    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();

    expect(find.byKey(_error), findsOneWidget);
    expect(find.textContaining('needs a connection'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(_amount),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '12.50');

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(2));
    expect(sent[1].id, sent[0].id, reason: 'a retry must not duplicate');
    expect(find.byKey(_amount), findsNothing);
  });

  testWidgets('when rejected, keeps the form and explains', (tester) async {
    await _openModal(tester, (_, _) async => ExpenseSaveResult.rejected);
    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();

    expect(find.byKey(_error), findsOneWidget);
    expect(find.textContaining('could not be saved'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.byKey(_amount), findsOneWidget);
  });

  testWidgets('a thrown error keeps the form too', (tester) async {
    await _openModal(tester, (_, _) async => throw StateError('bug'));
    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();
    expect(find.byKey(_error), findsOneWidget);
    expect(find.byKey(_amount), findsOneWidget);
  });

  testWidgets('the error clears when saving again', (tester) async {
    final second = Completer<ExpenseSaveResult>();
    final results = [
      Future.value(ExpenseSaveResult.needsConnection),
      second.future,
    ];
    await _openModal(tester, (_, _) => results.removeAt(0));
    await tester.tap(find.byKey(_save));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_save));
    await tester.pump();
    expect(find.byKey(_error), findsNothing);
    second.complete(ExpenseSaveResult.saved);
    await tester.pumpAndSettle();
  });
}
