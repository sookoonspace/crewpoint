import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';

/// Drift-backed reactive stream of per-event task status counts. Powers the
/// Dashboard `EventTile` progress ring. Must be a Stream backed by `.watch()`,
/// not a one-shot Future — the ring must re-render when tasks mutate locally.
void main() {
  late AppDatabase db;
  late TasksDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = TasksDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  TasksCompanion task(String id, String eventId, String status) {
    return TasksCompanion(
      id: Value(id),
      eventId: Value(eventId),
      title: Value('Task $id'),
      status: Value(status),
    );
  }

  test('emits zero counts when the event has no tasks', () async {
    final emission = await dao.watchCountsByEventId('evt-a').first;
    expect(emission, (todo: 0, doing: 0, done: 0));
  });

  test('counts mixed statuses, ignoring other events', () async {
    await dao.insertTask(task('t1', 'evt-a', 'todo'));
    await dao.insertTask(task('t2', 'evt-a', 'todo'));
    await dao.insertTask(task('t3', 'evt-a', 'inProgress'));
    await dao.insertTask(task('t4', 'evt-a', 'done'));
    await dao.insertTask(task('t5', 'evt-a', 'done'));
    await dao.insertTask(task('t6', 'evt-a', 'done'));
    // Same shape, different event — must NOT influence evt-a counts.
    await dao.insertTask(task('x1', 'evt-b', 'todo'));
    await dao.insertTask(task('x2', 'evt-b', 'done'));

    final emission = await dao.watchCountsByEventId('evt-a').first;
    expect(emission, (todo: 2, doing: 1, done: 3));
  });

  test('re-emits after insertTask (proves Stream reactivity)', () async {
    final stream = dao.watchCountsByEventId('evt-a');
    final emissions = <({int todo, int doing, int done})>[];
    final sub = stream.listen(emissions.add);

    // Initial empty emission.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await dao.insertTask(task('t1', 'evt-a', 'todo'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await dao.insertTask(task('t2', 'evt-a', 'done'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await sub.cancel();

    // Initial 0/0/0 + post-insert 1/0/0 + post-insert 1/0/1.
    // A `Future<T>` could not produce this sequence — must be a Stream.
    expect(emissions, [
      (todo: 0, doing: 0, done: 0),
      (todo: 1, doing: 0, done: 0),
      (todo: 1, doing: 0, done: 1),
    ]);
  });
}
