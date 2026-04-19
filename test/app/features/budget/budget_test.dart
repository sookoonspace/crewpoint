import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
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
    late ExpenseRepository repository;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await UsersDao(db).insertUser(
        UsersCompanion.insert(id: 'user-1', email: 'test@example.com'),
      );
      await EventsDao(db).insertEvent(
        EventsCompanion.insert(
          id: 'event-1',
          title: 'Test Event',
          creatorId: 'user-1',
          startDate: DateTime(2026, 6, 1),
        ),
      );
      repository = ExpenseRepository(expensesDao: ExpensesDao(db));
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
  });
}
