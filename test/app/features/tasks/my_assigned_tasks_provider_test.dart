import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_assigned_tasks_provider.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Drain the AsyncValue out of a `Provider<AsyncValue<T>>` family entry.
/// First read primes the stream subscription; the second tick reads the
/// resolved value.
/// Drain the cascading stream emissions through the composed provider.
/// `dashboardEventsProvider` emits first, then each per-event
/// `taskListProvider(...)` emits, so we wait long enough for all the
/// AsyncValue propagations to settle.
Future<AsyncValue<List<MyAssignedTaskRow>>> _readAfterPump(
  ProviderContainer container,
  String uid,
) async {
  container.listen<AsyncValue<List<MyAssignedTaskRow>>>(
    myAssignedTasksProvider(uid),
    (_, _) {},
    fireImmediately: true,
  );
  // Two macro ticks > all microtask hops between stream layers + Riverpod
  // re-evaluation.
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await Future<void>.delayed(const Duration(milliseconds: 10));
  return container.read(myAssignedTasksProvider(uid));
}

void main() {
  const eventA = EventModel(
    id: 'evt-a',
    title: 'Trip',
    creatorId: 'owner',
    memberIds: ['owner', 'me'],
  );
  const eventB = EventModel(
    id: 'evt-b',
    title: 'Project',
    creatorId: 'owner',
    memberIds: ['owner', 'me'],
  );

  const myTaskInA = TaskModel(
    id: 't-a1',
    eventId: 'evt-a',
    title: 'Buy snacks',
    assigneeId: 'me',
  );
  const otherTaskInB = TaskModel(
    id: 't-b1',
    eventId: 'evt-b',
    title: 'Write spec',
    assigneeId: 'owner',
  );

  test(
    'returns a single MyAssignedTaskRow for the matching uid across events',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA, eventB]),
          ),
          taskListProvider.overrideWith((ref, eventId) {
            return switch (eventId) {
              'evt-a' => Stream.value(const [myTaskInA]),
              'evt-b' => Stream.value(const [otherTaskInB]),
              _ => Stream.value(const <TaskModel>[]),
            };
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      expect(result, isA<AsyncData<List<MyAssignedTaskRow>>>());
      final rows = result.requireValue;
      expect(rows, hasLength(1));
      expect(rows.single.task.id, 't-a1');
      expect(rows.single.event.id, 'evt-a');
    },
  );

  test(
    'excludes tasks whose assigneeId does not match the uid even when in the user\'s event',
    () async {
      const myTask = TaskModel(
        id: 't-mine',
        eventId: 'evt-a',
        title: 'Mine',
        assigneeId: 'me',
      );
      const someoneElsesTask = TaskModel(
        id: 't-theirs',
        eventId: 'evt-a',
        title: 'Theirs',
        assigneeId: 'someone-else',
      );
      const unassignedTask = TaskModel(
        id: 't-none',
        eventId: 'evt-a',
        title: 'Free agent',
      );

      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          taskListProvider.overrideWith((ref, eventId) {
            return Stream.value(const [
              myTask,
              someoneElsesTask,
              unassignedTask,
            ]);
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      final rows = result.requireValue;
      expect(rows, hasLength(1));
      expect(rows.single.task.id, 't-mine');
    },
  );

  test(
    'orders rows by event order from dashboard, then by task order within each event',
    () async {
      const myTaskA1 = TaskModel(
        id: 't-a1',
        eventId: 'evt-a',
        title: 'A1',
        assigneeId: 'me',
      );
      const myTaskA2 = TaskModel(
        id: 't-a2',
        eventId: 'evt-a',
        title: 'A2',
        assigneeId: 'me',
      );
      const myTaskB1 = TaskModel(
        id: 't-b1',
        eventId: 'evt-b',
        title: 'B1',
        assigneeId: 'me',
      );

      final container = ProviderContainer(
        overrides: [
          // Events arrive in [eventA, eventB] order. Their flat ids should
          // come out as [t-a1, t-a2, t-b1] regardless of map iteration order.
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA, eventB]),
          ),
          taskListProvider.overrideWith((ref, eventId) {
            return switch (eventId) {
              'evt-a' => Stream.value(const [myTaskA1, myTaskA2]),
              'evt-b' => Stream.value(const [myTaskB1]),
              _ => Stream.value(const <TaskModel>[]),
            };
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      final ids = result.requireValue.map((r) => r.task.id).toList();
      expect(ids, ['t-a1', 't-a2', 't-b1']);
    },
  );

  test('returns loading while the events stream has not emitted yet', () async {
    final container = ProviderContainer(
      overrides: [
        // Stream never emits → events stays in loading.
        dashboardEventsProvider.overrideWith(
          (ref) => const Stream<List<EventModel>>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    expect(result, isA<AsyncLoading<List<MyAssignedTaskRow>>>());
  });

  test(
    'returns loading while any per-event tasks stream has not emitted yet',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          // Events arrives, but the per-event task stream never emits.
          taskListProvider.overrideWith(
            (ref, eventId) => const Stream<List<TaskModel>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      expect(result, isA<AsyncLoading<List<MyAssignedTaskRow>>>());
    },
  );

  test('propagates an error from the events stream', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream<List<EventModel>>.error(StateError('events boom')),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    expect(result, isA<AsyncError<List<MyAssignedTaskRow>>>());
    expect((result as AsyncError).error, isA<StateError>());
  });

  test('propagates an error from any per-event tasks stream', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [eventA]),
        ),
        taskListProvider.overrideWith(
          (ref, eventId) =>
              Stream<List<TaskModel>>.error(StateError('tasks boom')),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    expect(result, isA<AsyncError<List<MyAssignedTaskRow>>>());
    expect((result as AsyncError).error, isA<StateError>());
  });

  test(
    'returns empty data (NOT loading or error) when the user belongs to zero events',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const <EventModel>[]),
          ),
          // Should never be invoked — guard via throw if it is.
          taskListProvider.overrideWith((ref, eventId) {
            throw StateError(
              'taskListProvider must not be subscribed when events list is empty',
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      expect(result, isA<AsyncData<List<MyAssignedTaskRow>>>());
      expect(result.requireValue, isEmpty);
    },
  );
}
