import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_pdf_builder.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

const _event = EventModel(
  id: 'evt-1',
  title: 'Trip',
  creatorId: 'u1',
  memberIds: ['u1', 'u2'],
  currency: 'USD',
);

final _ledger = BalanceLedger.calculate(expenses: [], memberIds: const []);

void main() {
  test(
    'produces a non-empty PDF byte buffer with the standard %PDF magic',
    () async {
      final bytes = await buildExpenseReport(
        event: _event,
        expenses: const [],
        memberNames: const {},
        ledger: _ledger,
      );

      expect(bytes, isNotEmpty);
      // %PDF magic header — first 4 bytes of any valid PDF document.
      expect(
        String.fromCharCodes(bytes.take(4)),
        equals('%PDF'),
        reason: 'Output should be a real PDF document, not arbitrary bytes',
      );
    },
  );

  group('truncateExpensesForRender', () {
    ExpenseModel stub(int i) =>
        ExpenseModel(id: 'e$i', eventId: 'evt-1', payerId: 'u1', amount: 1);

    test('passes the list through unchanged when at or below the cap', () {
      final list = List.generate(5, stub);
      final result = truncateExpensesForRender(list, maxRendered: 5);
      expect(result.rendered, hasLength(5));
      expect(result.truncated, isFalse);
    });

    test('caps at maxRendered and reports truncated when over', () {
      final list = List.generate(7, stub);
      final result = truncateExpensesForRender(list, maxRendered: 5);
      expect(result.rendered, hasLength(5));
      expect(result.rendered.last.id, equals('e4'));
      expect(result.truncated, isTrue);
    });

    test('default maxRendered is the public 200-row cap', () {
      expect(kMaxRenderedExpenses, equals(200));
      final list = List.generate(201, stub);
      final result = truncateExpensesForRender(list);
      expect(result.rendered, hasLength(200));
      expect(result.truncated, isTrue);
    });
  });

  test(
    'survives a throwing receipt loader without bubbling the error',
    () async {
      const expense = ExpenseModel(
        id: 'e1',
        eventId: 'evt-1',
        payerId: 'u1',
        amount: 12.5,
        receiptPath: 'receipts/e1.jpg',
        splits: [ExpenseSplit(userId: 'u2', amount: 12.5)],
      );

      final ledger = BalanceLedger.calculate(
        expenses: [expense],
        memberIds: const ['u1', 'u2'],
      );

      final bytes = await buildExpenseReport(
        event: _event,
        expenses: [expense],
        memberNames: const {'u1': 'Alice', 'u2': 'Bob'},
        ledger: ledger,
        receiptLoader: (path) async =>
            throw StateError('simulated network failure for $path'),
      );

      // Builder must catch the loader's failure, fall back to a placeholder,
      // and still produce a valid PDF.
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
    },
  );
}
