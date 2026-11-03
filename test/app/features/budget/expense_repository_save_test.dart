import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase;
import 'package:crewpoint_app/app/core/database/daos/expense_splits_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expenses_dao.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_repository.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;

  const expense = ExpenseModel(
    id: 'exp-1',
    eventId: 'event-1',
    payerId: 'payer',
    amount: 30,
    description: 'Dinner',
    receiptPath: 'https://x.test/r.jpg',
    isDonation: true,
    splits: [ExpenseSplit(userId: 'other', amount: 30)],
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
  });
  tearDown(() => db.close());

  ExpenseRepository repoWith(SaveExpenseCall call) => ExpenseRepository(
    expensesDao: ExpensesDao(db),
    splitsDao: ExpenseSplitsDao(db),
    firestore: firestore,
    saveExpenseCall: call,
  );

  ExpenseRepository failingWith(String code) => repoWith(
    (_) async => throw FirebaseFunctionsException(message: code, code: code),
  );

  test('saves through the callable, and writes nothing directly', () async {
    ExpenseModel? sent;
    final repo = repoWith((e) async => sent = e);

    expect(await repo.saveExpense(expense), ExpenseSaveResult.saved);

    expect(sent, same(expense));
    final remote = await firestore.collection('events/event-1/expenses').get();
    expect(remote.docs, isEmpty);
  });

  test('a saved expense reaches the local mirror straight away', () async {
    final repo = repoWith((_) async {});
    await repo.saveExpense(expense);

    final local = await repo.getExpensesByEventId('event-1');
    expect(local.single.amount, 30);
    expect(local.single.splits.single.userId, 'other');
  });

  for (final code in ['unavailable', 'deadline-exceeded', 'internal']) {
    test('$code means it needs a connection', () async {
      expect(
        await failingWith(code).saveExpense(expense),
        ExpenseSaveResult.needsConnection,
      );
    });
  }

  for (final code in [
    'invalid-argument',
    'permission-denied',
    'failed-precondition',
    'not-found',
    'unauthenticated',
  ]) {
    test('$code means the server rejected it', () async {
      expect(
        await failingWith(code).saveExpense(expense),
        ExpenseSaveResult.rejected,
      );
    });
  }

  test('an unexpected error is not reported as saved', () async {
    final repo = repoWith((_) async => throw StateError('bug'));
    expect(await repo.saveExpense(expense), ExpenseSaveResult.rejected);
  });

  test('a failed save leaves the local mirror untouched', () async {
    final repo = failingWith('unavailable');
    await repo.saveExpense(expense);
    expect(await repo.getExpensesByEventId('event-1'), isEmpty);
  });

  test(
    'a settlement still writes directly, not through the callable',
    () async {
      var calls = 0;
      final repo = repoWith((_) async => calls++);
      final id = await repo.recordSettlement(
        eventId: 'event-1',
        payerId: 'payer',
        payeeId: 'other',
        amount: 5,
      );
      expect(calls, 0);
      final doc = await firestore.doc('events/event-1/expenses/$id').get();
      expect(doc.data()!['isPayment'], isTrue);
    },
  );
}
