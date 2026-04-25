import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/users_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_repository.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

void main() {
  late AppDatabase db;
  late TaskRepository repository;

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
    repository = TaskRepository(tasksDao: TasksDao(db));
  });

  tearDown(() => db.close());

  test('creates task linked to event and retrieves by event ID', () async {
    const task = TaskModel(
      id: 'task-1',
      eventId: 'event-1',
      title: 'Buy supplies',
    );

    final created = await repository.createTask(task);
    expect(created, isTrue);

    final tasks = await repository.getTasksByEventId('event-1');
    expect(tasks, hasLength(1));
    expect(tasks.first.title, equals('Buy supplies'));
    expect(tasks.first.eventId, equals('event-1'));
  });

  test('status transitions todo -> inProgress -> done', () async {
    const task = TaskModel(
      id: 'task-1',
      eventId: 'event-1',
      title: 'Setup venue',
    );
    await repository.createTask(task);

    // todo -> inProgress
    await repository.updateTask(task.copyWith(status: TaskStatus.inProgress));
    var tasks = await repository.getTasksByEventId('event-1');
    expect(tasks.first.status, equals(TaskStatus.inProgress));

    // inProgress -> done
    await repository.updateTask(task.copyWith(status: TaskStatus.done));
    tasks = await repository.getTasksByEventId('event-1');
    expect(tasks.first.status, equals(TaskStatus.done));
  });

  test('filter returns only matching status', () async {
    await repository.createTask(
      const TaskModel(id: 't1', eventId: 'event-1', title: 'A'),
    );
    await repository.createTask(
      const TaskModel(
        id: 't2',
        eventId: 'event-1',
        title: 'B',
        status: TaskStatus.done,
      ),
    );

    final all = await repository.getTasksByEventId('event-1');
    expect(all, hasLength(2));

    final todoOnly = all.where((t) => t.status == TaskStatus.todo).toList();
    expect(todoOnly, hasLength(1));
    expect(todoOnly.first.title, equals('A'));
  });

  test('checklist item toggle via copyWith', () {
    const task = TaskModel(
      id: 'task-1',
      eventId: 'event-1',
      title: 'With checklist',
      checklistItems: [
        ChecklistItem(text: 'Step 1'),
        ChecklistItem(text: 'Step 2'),
      ],
    );

    final updated = task.copyWith(
      checklistItems: [
        task.checklistItems[0].copyWith(isCompleted: true),
        task.checklistItems[1],
      ],
    );

    expect(updated.checklistItems[0].isCompleted, isTrue);
    expect(updated.checklistItems[1].isCompleted, isFalse);
  });
}
