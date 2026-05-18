import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/tasks/application/event_task_counts_provider.dart';

void main() {
  late AppDatabase db;
  late TasksDao dao;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = TasksDao(db);
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
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

  test('emits zero counts initially, then updates after a write', () async {
    final emissions = <AsyncValue<({int todo, int doing, int done})>>[];
    final sub = container.listen(
      eventTaskCountsProvider('evt-a'),
      (_, next) => emissions.add(next),
      fireImmediately: true,
    );

    // Drain initial stream emission.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(emissions.last.value, (todo: 0, doing: 0, done: 0));

    // Insert two tasks through the same Drift instance.
    await dao.insertTask(task('t1', 'evt-a', 'inProgress'));
    await dao.insertTask(task('t2', 'evt-a', 'done'));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emissions.last.value, (todo: 0, doing: 1, done: 1));
    sub.close();
  });
}
