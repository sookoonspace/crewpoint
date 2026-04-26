import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
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
  });
}
