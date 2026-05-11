import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/task_checklist_items_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/users_dao.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_repository.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late TaskRepository repository;
  final markCompleteCalls = <Map<String, String>>[];

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
        startDate: Value(DateTime(2026, 6, 1)),
      ),
    );
    firestore = FakeFirebaseFirestore();
    markCompleteCalls.clear();
    repository = TaskRepository(
      tasksDao: TasksDao(db),
      checklistDao: TaskChecklistItemsDao(db),
      firestore: firestore,
      markTaskComplete: ({required eventId, required taskId}) async {
        markCompleteCalls.add({'eventId': eventId, 'taskId': taskId});
        // Simulate the CF effect by writing directly to Firestore
        await firestore
            .collection('events')
            .doc(eventId)
            .collection('tasks')
            .doc(taskId)
            .update({'status': 'done', 'completedBy': 'user-1'});
      },
    );
  });

  tearDown(() => db.close());

  group('TaskModel budgetEstimate', () {
    test('copyWith round-trips null and non-null budget', () {
      const base = TaskModel(
        id: 't',
        eventId: 'e',
        title: 'x',
        budgetEstimate: 25.5,
      );
      expect(base.copyWith().budgetEstimate, 25.5);
      expect(base.copyWith(budgetEstimate: 0).budgetEstimate, 0);
      expect(base.copyWith(clearBudgetEstimate: true).budgetEstimate, isNull);
    });
  });

  group('budget round-trip through Firestore + Drift', () {
    test('persists null, zero, and positive budgetEstimate', () async {
      for (final budget in <double?>[null, 0, 75.25]) {
        final task = TaskModel(
          id: 'budget-${budget ?? 'null'}',
          eventId: 'event-1',
          title: 'Budget round-trip',
          createdBy: 'user-1',
          budgetEstimate: budget,
        );
        final ok = await repository.createTask(task);
        expect(ok, isTrue);

        final fsDoc = await firestore
            .collection('events')
            .doc('event-1')
            .collection('tasks')
            .doc(task.id)
            .get();
        expect(fsDoc.data()!['budgetEstimate'], budget);

        final fromDrift = await repository.getTasksByEventId('event-1');
        final hydrated = fromDrift.firstWhere((t) => t.id == task.id);
        expect(hydrated.budgetEstimate, budget);
      }
    });
  });

  group('createTask', () {
    test('writes Firestore document AND mirrors to Drift', () async {
      const task = TaskModel(
        id: 'task-1',
        eventId: 'event-1',
        title: 'Buy supplies',
        createdBy: 'user-1',
      );

      final ok = await repository.createTask(task);
      expect(ok, isTrue);

      // Firestore got the doc
      final remote = await firestore
          .collection('events')
          .doc('event-1')
          .collection('tasks')
          .doc('task-1')
          .get();
      expect(remote.exists, isTrue);
      expect(remote.data()!['title'], equals('Buy supplies'));
      expect(remote.data()!['createdBy'], equals('user-1'));
      expect(remote.data()!['status'], equals('todo'));

      // Drift mirror happened
      final local = await repository.getTasksByEventId('event-1');
      expect(local, hasLength(1));
      expect(local.first.title, equals('Buy supplies'));
    });
  });

  group('updateStatus', () {
    test(
      'routes through markTaskComplete CF when transitioning to done',
      () async {
        const task = TaskModel(
          id: 'task-1',
          eventId: 'event-1',
          title: 'Setup venue',
          createdBy: 'user-1',
        );
        await repository.createTask(task);

        final ok = await repository.updateStatus(
          eventId: 'event-1',
          taskId: 'task-1',
          newStatus: TaskStatus.done,
        );
        expect(ok, isTrue);
        expect(markCompleteCalls, hasLength(1));
        expect(markCompleteCalls.first['taskId'], equals('task-1'));
      },
    );

    test(
      'writes Firestore directly when transitioning to inProgress',
      () async {
        const task = TaskModel(
          id: 'task-1',
          eventId: 'event-1',
          title: 'Setup venue',
          createdBy: 'user-1',
        );
        await repository.createTask(task);

        final ok = await repository.updateStatus(
          eventId: 'event-1',
          taskId: 'task-1',
          newStatus: TaskStatus.inProgress,
        );
        expect(ok, isTrue);
        expect(markCompleteCalls, isEmpty);

        final remote = await firestore
            .collection('events')
            .doc('event-1')
            .collection('tasks')
            .doc('task-1')
            .get();
        expect(remote.data()!['status'], equals('inProgress'));
      },
    );
  });

  group('Firestore mirror', () {
    test('subscribed stream mirrors Firestore snapshots into Drift', () async {
      // Simulate a remote write (e.g., from another client / Cloud Function)
      await firestore
          .collection('events')
          .doc('event-1')
          .collection('tasks')
          .doc('remote-1')
          .set({
            'eventId': 'event-1',
            'title': 'From server',
            'createdBy': 'user-2',
            'status': 'todo',
            'priority': 0,
          });

      final stream = repository.watchTasksByEventId('event-1');
      // Wait for first emission containing the remote task
      final tasks = await stream.firstWhere((list) => list.isNotEmpty);
      expect(tasks.first.title, equals('From server'));
      expect(tasks.first.id, equals('remote-1'));
    });
  });

  group('Checklist', () {
    test(
      'addChecklistItem writes Firestore subcollection doc and mirrors to Drift',
      () async {
        final ok = await repository.addChecklistItem(
          eventId: 'event-1',
          taskId: 'task-1',
          id: 'item-1',
          text: 'Step 1',
          sortOrder: 1,
        );
        expect(ok, isTrue);

        final remote = await firestore
            .collection('events/event-1/tasks/task-1/checklist')
            .doc('item-1')
            .get();
        expect(remote.exists, isTrue);
        expect(remote.data()!['text'], equals('Step 1'));
        expect(remote.data()!['isCompleted'], isFalse);
      },
    );

    test(
      'toggleChecklistItem only patches isCompleted (assignee-safe path)',
      () async {
        // Seed an item via the full add path
        await repository.addChecklistItem(
          eventId: 'event-1',
          taskId: 'task-1',
          id: 'item-1',
          text: 'Step 1',
        );

        final ok = await repository.toggleChecklistItem(
          eventId: 'event-1',
          taskId: 'task-1',
          itemId: 'item-1',
          isCompleted: true,
        );
        expect(ok, isTrue);

        final remote = await firestore
            .collection('events/event-1/tasks/task-1/checklist')
            .doc('item-1')
            .get();
        expect(remote.data()!['isCompleted'], isTrue);
        // text stays the same — assignee should not be able to mutate it
        expect(remote.data()!['text'], equals('Step 1'));
      },
    );

    test(
      'updateChecklistItem patches both text and isCompleted when caller is creator/admin',
      () async {
        await repository.addChecklistItem(
          eventId: 'event-1',
          taskId: 'task-1',
          id: 'item-1',
          text: 'Original',
        );

        final ok = await repository.updateChecklistItem(
          eventId: 'event-1',
          taskId: 'task-1',
          itemId: 'item-1',
          text: 'Edited',
          isCompleted: true,
        );
        expect(ok, isTrue);

        final remote = await firestore
            .collection('events/event-1/tasks/task-1/checklist')
            .doc('item-1')
            .get();
        expect(remote.data()!['text'], equals('Edited'));
        expect(remote.data()!['isCompleted'], isTrue);
      },
    );
  });

  group('TaskModel RBAC', () {
    test('owner, admin, or assignee can change status', () {
      const task = TaskModel(
        id: 't',
        eventId: 'e',
        title: 'x',
        assigneeId: 'user-2',
      );
      expect(
        task.canChangeStatus(
          isOwner: true,
          isAdmin: false,
          currentUserId: 'owner',
        ),
        isTrue,
      );
      expect(
        task.canChangeStatus(
          isOwner: false,
          isAdmin: true,
          currentUserId: 'admin',
        ),
        isTrue,
      );
      expect(
        task.canChangeStatus(
          isOwner: false,
          isAdmin: false,
          currentUserId: 'user-2',
        ),
        isTrue,
      );
      expect(
        task.canChangeStatus(
          isOwner: false,
          isAdmin: false,
          currentUserId: 'random',
        ),
        isFalse,
      );
    });

    test('only creator/owner/admin can edit or delete', () {
      const task = TaskModel(
        id: 't',
        eventId: 'e',
        title: 'x',
        createdBy: 'creator-1',
        assigneeId: 'user-2',
      );
      expect(
        task.canEditOrDelete(
          isOwner: true,
          isAdmin: false,
          currentUserId: 'owner',
        ),
        isTrue,
      );
      expect(
        task.canEditOrDelete(
          isOwner: false,
          isAdmin: false,
          currentUserId: 'creator-1',
        ),
        isTrue,
      );
      // Assignee cannot edit/delete (only toggle status / checklist)
      expect(
        task.canEditOrDelete(
          isOwner: false,
          isAdmin: false,
          currentUserId: 'user-2',
        ),
        isFalse,
      );
    });
  });
}
