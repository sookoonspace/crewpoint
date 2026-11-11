import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase, EventsCompanion, UsersCompanion;
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expense_splits_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expenses_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/task_checklist_items_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/users_dao.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_repository.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_repository.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 59: the expense and task mirrors apply only what changed, in one
/// transaction, so one changed document updates the screen once rather
/// than once per row.
void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  const rows = 60;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    await UsersDao(
      db,
    ).insertUser(UsersCompanion.insert(id: 'owner', email: 'o@example.com'));
    await EventsDao(db).insertEvent(
      EventsCompanion.insert(id: 'e1', title: 'Fest', creatorId: 'owner'),
    );
  });
  tearDown(() => db.close());

  /// Counts emissions from [stream] until it has been quiet for a while.
  Future<int> settle(List<Object?> seen) async {
    var last = -1;
    var quiet = 0;
    while (quiet < 5) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (seen.length == last) {
        quiet++;
      } else {
        last = seen.length;
        quiet = 0;
      }
    }
    return seen.length;
  }

  group('tasks', () {
    late TaskRepository repo;

    setUp(() async {
      repo = TaskRepository(
        tasksDao: TasksDao(db),
        checklistDao: TaskChecklistItemsDao(db),
        firestore: firestore,
      );
      for (var i = 0; i < rows; i++) {
        await firestore.doc('events/e1/tasks/t$i').set({
          'eventId': 'e1',
          'title': 'Task $i',
          'status': 'todo',
          'createdBy': 'owner',
        });
      }
    });
    tearDown(() => repo.dispose());

    test('the first snapshot fills the mirror in one update', () async {
      final seen = <Object?>[];
      final sub = repo.watchTasksByEventId('e1').listen(seen.add);
      addTearDown(sub.cancel);
      await settle(seen);
      expect((seen.last! as List).length, rows);
      // The empty table, then everything at once.
      expect(seen.length, lessThanOrEqualTo(2));
    });

    test('one changed task updates the screen once', () async {
      final seen = <Object?>[];
      final sub = repo.watchTasksByEventId('e1').listen(seen.add);
      addTearDown(sub.cancel);
      final before = await settle(seen);
      await firestore.doc('events/e1/tasks/t7').update({'title': 'Renamed'});
      expect(await settle(seen) - before, 1);
    });

    test('a deleted task leaves the mirror in one update', () async {
      final seen = <Object?>[];
      final sub = repo.watchTasksByEventId('e1').listen(seen.add);
      addTearDown(sub.cancel);
      final before = await settle(seen);
      await firestore.doc('events/e1/tasks/t3').delete();
      expect(await settle(seen) - before, 1);
      expect((seen.last! as List).length, rows - 1);
    });
  });

  group('expenses', () {
    late ExpenseRepository repo;

    setUp(() async {
      repo = ExpenseRepository(
        expensesDao: ExpensesDao(db),
        splitsDao: ExpenseSplitsDao(db),
        firestore: firestore,
        saveExpenseCall: (_) async {},
        recordSettlementCall:
            ({
              required eventId,
              required settlementId,
              required payerId,
              required payeeId,
              required amount,
            }) async {},
      );
      for (var i = 0; i < rows; i++) {
        await firestore.doc('events/e1/expenses/x$i').set({
          'payerId': 'owner',
          'amount': 10,
          'description': 'Cost $i',
          'splits': [
            {'userId': 'owner', 'amount': 10},
          ],
          'involvedUids': ['owner'],
        });
      }
    });
    tearDown(() => repo.dispose());

    test('the first snapshot fills the mirror in one update', () async {
      final seen = <Object?>[];
      final sub = repo.watchExpensesByEventId('e1').listen(seen.add);
      addTearDown(sub.cancel);
      await settle(seen);
      expect((seen.last! as List).length, rows);
      expect(seen.length, lessThanOrEqualTo(2));
    });

    test('one changed expense updates the screen once', () async {
      final seen = <Object?>[];
      final sub = repo.watchExpensesByEventId('e1').listen(seen.add);
      addTearDown(sub.cancel);
      final before = await settle(seen);
      await firestore.doc('events/e1/expenses/x9').update({
        'amount': 20,
        'splits': [
          {'userId': 'owner', 'amount': 20},
        ],
      });
      expect(await settle(seen) - before, 1);
    });

    test('a deleted expense leaves the mirror, with its splits', () async {
      final seen = <Object?>[];
      final sub = repo.watchExpensesByEventId('e1').listen(seen.add);
      addTearDown(sub.cancel);
      final before = await settle(seen);
      await firestore.doc('events/e1/expenses/x2').delete();
      expect(await settle(seen) - before, 1);
      expect((seen.last! as List).length, rows - 1);
      expect(await ExpenseSplitsDao(db).byExpenseId('x2'), isEmpty);
    });
  });
}
