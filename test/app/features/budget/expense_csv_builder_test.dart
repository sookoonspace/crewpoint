import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_csv_builder.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

const _event = EventModel(
  id: 'evt-1',
  title: 'Trip',
  creatorId: 'u1',
  memberIds: ['u1', 'u2'],
  currency: 'USD',
);

void main() {
  test('emits header line with the documented column order', () {
    final csv = buildExpenseCsv(
      event: _event,
      expenses: const [],
      memberNames: const {},
    );

    final firstLine = csv.split('\n').first;
    expect(
      firstLine,
      equals(
        'id,createdAt,payerId,payerName,amount,currency,'
        'isDonation,isPayment,description,receiptPath,splits',
      ),
    );
  });

  test('escapes commas, quotes, and newlines per RFC-4180', () {
    final expense = ExpenseModel(
      id: 'e1',
      eventId: 'evt-1',
      payerId: 'u1',
      amount: 12.5,
      description: 'BBQ, "team night"\nand drinks',
      receiptPath: 'receipts/e1.jpg',
      splits: const [
        ExpenseSplit(userId: 'u1', amount: 6.25),
        ExpenseSplit(userId: 'u2', amount: 6.25),
      ],
      createdAt: DateTime.utc(2026, 4, 15, 12),
    );

    final csv = buildExpenseCsv(
      event: _event,
      expenses: [expense],
      memberNames: const {'u1': 'Alice', 'u2': 'Bob'},
    );

    // Embedded newlines stay inside the quoted field per RFC-4180.
    // Splitting on `\n` is therefore not a valid record-count proxy;
    // assert the escape pattern directly.
    expect(
      csv.contains('"BBQ, ""team night""\nand drinks"'),
      isTrue,
      reason:
          'description should be RFC-4180 quoted with doubled-up '
          'quotes and embedded newline preserved: $csv',
    );
    expect(csv.contains('Alice'), isTrue);
    expect(csv.contains('USD'), isTrue);
    // Splits column is a JSON-encoded array, itself CSV-quoted.
    expect(csv.contains('"[{""userId"":""u1""'), isTrue);
  });
}
