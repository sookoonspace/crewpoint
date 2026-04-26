import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expense_splits_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/task_checklist_items_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/users_dao.dart';

void main() {
  late AppDatabase db;
  late EventsDao eventsDao;
  late TasksDao tasksDao;
  late UsersDao usersDao;
  late TaskChecklistItemsDao checklistDao;
  late ExpenseSplitsDao splitsDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    eventsDao = EventsDao(db);
    tasksDao = TasksDao(db);
    usersDao = UsersDao(db);
    checklistDao = TaskChecklistItemsDao(db);
    splitsDao = ExpenseSplitsDao(db);
  });

  tearDown(() => db.close());

  UsersCompanion testUser({String id = 'user-1'}) =>
      UsersCompanion.insert(id: id, email: 'test@example.com');

  EventsCompanion testEvent({
    String id = 'event-1',
    String creatorId = 'user-1',
  }) => EventsCompanion.insert(
    id: id,
    title: 'Test Event',
    creatorId: creatorId,
    startDate: Value(DateTime(2026, 5, 1)),
  );

  TasksCompanion testTask({String id = 'task-1', String eventId = 'event-1'}) =>
      TasksCompanion.insert(id: id, eventId: eventId, title: 'Test Task');

  group('EventsDao', () {
    test('insert event and retrieve by ID', () async {
      await usersDao.insertUser(testUser());
      await eventsDao.insertEvent(testEvent());

      final result = await eventsDao.eventById('event-1');
      expect(result, isNotNull);
      expect(result!.title, equals('Test Event'));
      expect(result.id, equals('event-1'));
    });

    test('query empty table returns empty list', () async {
      final results = await eventsDao.allEvents();
      expect(results, isEmpty);
    });

    test('insert duplicate primary key throws', () async {
      await usersDao.insertUser(testUser());
      await eventsDao.insertEvent(testEvent());

      expect(
        () => eventsDao.insertEvent(testEvent()),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('TasksDao', () {
    test('insert task with event FK and query by event', () async {
      await usersDao.insertUser(testUser());
      await eventsDao.insertEvent(testEvent());
      await tasksDao.insertTask(testTask());
      await tasksDao.insertTask(testTask(id: 'task-2'));

      final results = await tasksDao.tasksByEventId('event-1');
      expect(results, hasLength(2));
    });

    test('query tasks for non-existent event returns empty', () async {
      final results = await tasksDao.tasksByEventId('no-such-event');
      expect(results, isEmpty);
    });
  });

  group('UsersDao', () {
    test('insert and retrieve user', () async {
      await usersDao.insertUser(testUser());

      final result = await usersDao.userById('user-1');
      expect(result, isNotNull);
      expect(result!.email, equals('test@example.com'));
    });
  });

  group('Schema v4 — Events.currency', () {
    test('Events.currency defaults to USD', () async {
      await usersDao.insertUser(testUser());
      await eventsDao.insertEvent(testEvent());

      final row = await eventsDao.eventById('event-1');
      expect(row!.currency, equals('USD'));
    });
  });

  group('Schema v4 — TaskChecklistItems', () {
    test('upsert + query by taskId returns ordered items', () async {
      await usersDao.insertUser(testUser());
      await eventsDao.insertEvent(testEvent());
      await tasksDao.insertTask(testTask());

      await checklistDao.upsert(
        TaskChecklistItemsCompanion.insert(
          id: 'item-2',
          taskId: 'task-1',
          content: 'Second',
          sortOrder: const Value(2),
        ),
      );
      await checklistDao.upsert(
        TaskChecklistItemsCompanion.insert(
          id: 'item-1',
          taskId: 'task-1',
          content: 'First',
          sortOrder: const Value(1),
        ),
      );

      final items = await checklistDao.byTaskId('task-1');
      expect(items.map((i) => i.id).toList(), equals(['item-1', 'item-2']));
    });
  });

  group('Schema v4 — ExpenseSplits', () {
    test('upsert + query by expenseId', () async {
      await usersDao.insertUser(testUser());
      await usersDao.insertUser(testUser(id: 'user-2'));
      await eventsDao.insertEvent(testEvent());

      // Insert expense first via direct DB insert (no expenses dao used here)
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-1',
              eventId: 'event-1',
              payerId: 'user-1',
              amount: 30.0,
            ),
          );
      await splitsDao.upsert(
        ExpenseSplitsCompanion.insert(
          expenseId: 'exp-1',
          userId: 'user-1',
          amount: 15.0,
        ),
      );
      await splitsDao.upsert(
        ExpenseSplitsCompanion.insert(
          expenseId: 'exp-1',
          userId: 'user-2',
          amount: 15.0,
        ),
      );

      final splits = await splitsDao.byExpenseId('exp-1');
      expect(splits, hasLength(2));
      expect(splits.map((s) => s.userId).toSet(), {'user-1', 'user-2'});
    });
  });
}
