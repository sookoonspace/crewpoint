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
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';

void main() {
  group('ExpenseModel.calculateSplits', () {
    test('3 members, \$90 expense -> \$30 each', () {
      final splits = ExpenseModel.calculateSplits(
        amount: 90,
        payerId: 'u1',
        memberIds: ['u1', 'u2', 'u3'],
        isDonation: false,
      );

      expect(splits, hasLength(3));
      for (final split in splits) {
        expect(split.amount, closeTo(30.0, 0.01));
      }
    });

    test('donation toggle excludes payer from split', () {
      final splits = ExpenseModel.calculateSplits(
        amount: 90,
        payerId: 'u1',
        memberIds: ['u1', 'u2', 'u3'],
        isDonation: true,
      );

      expect(splits, hasLength(2));
      expect(splits.every((s) => s.userId != 'u1'), isTrue);
      for (final split in splits) {
        expect(split.amount, closeTo(45.0, 0.01));
      }
    });
  });

  group('ExpenseRepository', () {
    late AppDatabase db;
    late FakeFirebaseFirestore firestore;
    late ExpenseRepository repository;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      firestore = FakeFirebaseFirestore();
      await UsersDao(db).insertUser(
        UsersCompanion.insert(id: 'user-1', email: 'test@example.com'),
      );
      await UsersDao(db).insertUser(
        UsersCompanion.insert(id: 'user-2', email: 'two@example.com'),
      );
      await EventsDao(db).insertEvent(
        EventsCompanion.insert(
          id: 'event-1',
          title: 'Test Event',
          creatorId: 'user-1',
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

    test('persists and retrieves expense by event', () async {
      const expense = ExpenseModel(
        id: 'exp-1',
        eventId: 'event-1',
        payerId: 'user-1',
        amount: 50.0,
        description: 'Lunch',
      );

      final created = await repository.createExpense(expense);
      expect(created, isTrue);

      final expenses = await repository.getExpensesByEventId('event-1');
      expect(expenses, hasLength(1));
      expect(expenses.first.amount, equals(50.0));
      expect(expenses.first.description, equals('Lunch'));
    });

    test('_toDomain hydrates splits from ExpenseSplits DAO '
        '(regression: previously returned []) ', () async {
      const expense = ExpenseModel(
        id: 'exp-1',
        eventId: 'event-1',
        payerId: 'user-1',
        amount: 50.0,
        splits: [
          ExpenseSplit(userId: 'user-1', amount: 25.0),
          ExpenseSplit(userId: 'user-2', amount: 25.0),
        ],
      );

      await repository.createExpense(expense);

      final expenses = await repository.getExpensesByEventId('event-1');
      expect(expenses.first.splits, hasLength(2));
      expect(
        expenses.first.splits.map((s) => s.userId).toSet(),
        equals({'user-1', 'user-2'}),
      );
      for (final s in expenses.first.splits) {
        expect(s.amount, closeTo(25.0, 0.001));
      }
    });

    test('createExpense writes Firestore doc including splits array', () async {
      const expense = ExpenseModel(
        id: 'exp-1',
        eventId: 'event-1',
        payerId: 'user-1',
        amount: 30.0,
        splits: [
          ExpenseSplit(userId: 'user-1', amount: 15.0),
          ExpenseSplit(userId: 'user-2', amount: 15.0),
        ],
      );

      await repository.createExpense(expense);

      final remote = await firestore
          .collection('events/event-1/expenses')
          .doc('exp-1')
          .get();
      expect(remote.exists, isTrue);
      final remoteSplits = remote.data()!['splits'] as List<dynamic>;
      expect(remoteSplits, hasLength(2));
    });

    test(
      'Firestore mirror writes incoming docs (and their splits) into Drift',
      () async {
        // Simulate a remote-only expense created by another client / CF
        await firestore
            .collection('events/event-1/expenses')
            .doc('remote-1')
            .set({
              'eventId': 'event-1',
              'payerId': 'user-2',
              'amount': 80.0,
              'description': 'Groceries',
              'isDonation': false,
              'isPayment': false,
              'splits': [
                {'userId': 'user-1', 'amount': 40.0},
                {'userId': 'user-2', 'amount': 40.0},
              ],
            });

        final stream = repository.watchExpensesByEventId('event-1');
        final expenses = await stream.firstWhere((list) => list.isNotEmpty);
        expect(expenses.first.id, equals('remote-1'));
        expect(expenses.first.splits, hasLength(2));
      },
    );
  });
}
