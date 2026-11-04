import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase;
import 'package:crewpoint_app/app/core/database/daos/task_checklist_items_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_repository.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const task = TaskModel(
    id: 't1',
    eventId: 'e1',
    title: 'Buy snacks',
    createdBy: 'creator',
    assigneeId: 'assignee',
  );

  group('canChangeStatus matches the rules', () {
    bool can(String uid, {bool owner = false, bool admin = false}) => task
        .canChangeStatus(isOwner: owner, isAdmin: admin, currentUserId: uid);

    test('owner, admin, creator and assignee may', () {
      expect(can('x', owner: true), isTrue);
      expect(can('x', admin: true), isTrue);
      expect(can('creator'), isTrue);
      expect(can('assignee'), isTrue);
    });

    test('another member may not', () => expect(can('other'), isFalse));
  });

  group('canEditOrDelete matches the rules', () {
    bool can(String uid, {bool owner = false, bool admin = false}) => task
        .canEditOrDelete(isOwner: owner, isAdmin: admin, currentUserId: uid);

    test('owner, admin and creator may', () {
      expect(can('x', owner: true), isTrue);
      expect(can('x', admin: true), isTrue);
      expect(can('creator'), isTrue);
    });

    test('an assignee and other members may not', () {
      expect(can('assignee'), isFalse);
      expect(can('other'), isFalse);
    });
  });

  group('client writes never carry completion', () {
    late AppDatabase db;
    late FakeFirebaseFirestore firestore;
    late TaskRepository repo;
    const doc = 'events/e1/tasks/t1';

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      firestore = FakeFirebaseFirestore();
      repo = TaskRepository(
        tasksDao: TasksDao(db),
        checklistDao: TaskChecklistItemsDao(db),
        firestore: firestore,
        markTaskComplete: ({required eventId, required taskId}) async {},
      );
    });
    tearDown(() => db.close());

    test('editing a finished task leaves its completion alone', () async {
      final completedAt = DateTime.utc(2027);
      await firestore.doc(doc).set({
        'title': 'Old',
        'status': 'done',
        'completedBy': 'assignee',
        'completedAt': completedAt,
      });

      await repo.updateTask(
        TaskModel(
          id: 't1',
          eventId: 'e1',
          title: 'New',
          status: TaskStatus.done,
          completedBy: 'someone else',
          completedAt: DateTime.utc(2030),
        ),
      );

      final data = (await firestore.doc(doc).get()).data()!;
      expect(data['title'], 'New');
      expect(data['status'], 'done');
      expect(data['completedBy'], 'assignee');
    });

    test('a new task carries no completion', () async {
      await repo.createTask(
        const TaskModel(
          id: 't1',
          eventId: 'e1',
          title: 'New',
          completedBy: 'someone',
        ),
      );
      final data = (await firestore.doc(doc).get()).data()!;
      expect(data['completedBy'], isNull);
      expect(data['completedAt'], isNull);
    });
  });
}
