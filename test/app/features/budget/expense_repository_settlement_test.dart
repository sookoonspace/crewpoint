import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase, EventsCompanion, UsersCompanion;
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expense_splits_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expenses_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/users_dao.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_repository.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/balance_ledger.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late ExpenseRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    await UsersDao(
      db,
    ).insertUser(UsersCompanion.insert(id: 'payer', email: 'p@example.com'));
    await UsersDao(
      db,
    ).insertUser(UsersCompanion.insert(id: 'payee', email: 'pa@example.com'));
    await EventsDao(db).insertEvent(
      EventsCompanion.insert(
        id: 'event-1',
        title: 'Trip',
        creatorId: 'payer',
        startDate: Value(DateTime(2026, 6, 1)),
      ),
    );
    repository = ExpenseRepository(
      expensesDao: ExpensesDao(db),
      splitsDao: ExpenseSplitsDao(db),
      firestore: firestore,
    );
  });

  tearDown(() => db.close());

  test('recordSettlement writes an isPayment expense with a single positive '
      'split addressed to the payee', () async {
    final id = await repository.recordSettlement(
      eventId: 'event-1',
      payerId: 'payer',
      payeeId: 'payee',
      amount: 25,
    );

    expect(id, isNotNull);

    final remote = await firestore
        .collection('events/event-1/expenses')
        .doc(id)
        .get();
    expect(remote.exists, isTrue);
    expect(remote.data()!['isPayment'], isTrue);
    expect(remote.data()!['payerId'], equals('payer'));
    expect(remote.data()!['amount'], closeTo(25, 0.001));

    final splits = (remote.data()!['splits'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(splits, hasLength(1));
    expect(splits.first['userId'], equals('payee'));
    expect(splits.first['amount'], closeTo(25, 0.001));
  });

  test('a recorded settlement clears the debt in the ledger', () async {
    const members = ['payer', 'payee'];
    await repository.createExpense(
      const ExpenseModel(
        id: 'dinner',
        eventId: 'event-1',
        payerId: 'payee',
        amount: 50,
        splits: [
          ExpenseSplit(userId: 'payer', amount: 25),
          ExpenseSplit(userId: 'payee', amount: 25),
        ],
      ),
    );
    await repository.recordSettlement(
      eventId: 'event-1',
      payerId: 'payer',
      payeeId: 'payee',
      amount: 25,
    );

    final stored = await repository
        .watchExpensesByEventId('event-1')
        .firstWhere((expenses) => expenses.length == 2);
    repository.disposeMirror('event-1');

    final ledger = BalanceLedger.calculate(
      expenses: stored,
      memberIds: members,
    );

    expect(ledger.netBalances['payer'], equals(0.0));
    expect(ledger.netBalances['payee'], equals(0.0));
    expect(ledger.settlements, isEmpty);
  });
}
