import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/my_tasks_screen.dart';

/// Lottie animations loop forever — bounded pumps, not pumpAndSettle.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  const event = EventModel(
    id: 'evt-a',
    title: 'Tahoe Trip',
    creatorId: 'uid-1',
    eventType: EventType.trip,
    memberIds: ['uid-1'],
  );
  const tTodo = TaskModel(
    id: 't-todo',
    eventId: 'evt-a',
    title: 'Buy snacks',
    assigneeId: 'uid-1',
  );
  const tDoing = TaskModel(
    id: 't-doing',
    eventId: 'evt-a',
    title: 'Book cabin',
    assigneeId: 'uid-1',
    status: TaskStatus.inProgress,
  );
  const tDone = TaskModel(
    id: 't-done',
    eventId: 'evt-a',
    title: 'Rent skis',
    assigneeId: 'uid-1',
    status: TaskStatus.done,
  );
  final tOverdue = TaskModel(
    id: 't-overdue',
    eventId: 'evt-a',
    title: 'Reserve dinner',
    assigneeId: 'uid-1',
    status: TaskStatus.todo,
    dueDate: DateTime(2026, 5, 10),
  );

  ProviderScope harness(List<TaskModel> tasks) {
    return ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => 'uid-1'),
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [event]),
        ),
        taskListProvider.overrideWith((ref, eventId) => Stream.value(tasks)),
      ],
      child: const MaterialApp(home: MyTasksScreen()),
    );
  }

  testWidgets('progress summary reflects all assigned tasks by default', (
    tester,
  ) async {
    await tester.pumpWidget(harness([tTodo, tDoing, tDone]));
    await _pumpFrames(tester);

    // Progress ring shows 1/3 done (1 done out of 3 total).
    expect(find.text('1/3'), findsOneWidget);
    // All four pills present.
    expect(find.byKey(const Key('myTasks.filter.all')), findsOneWidget);
    expect(find.byKey(const Key('myTasks.filter.todo')), findsOneWidget);
    expect(find.byKey(const Key('myTasks.filter.doing')), findsOneWidget);
    expect(find.byKey(const Key('myTasks.filter.done')), findsOneWidget);
  });

  testWidgets('tapping Todo segment narrows the list and updates the summary', (
    tester,
  ) async {
    await tester.pumpWidget(harness([tTodo, tDoing, tDone]));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('myTasks.filter.todo')));
    await _pumpFrames(tester);

    // Only Todo row visible; progress summary recomputes from filtered rows.
    expect(find.byKey(const Key('tasks.tile.t-todo')), findsOneWidget);
    expect(find.byKey(const Key('tasks.tile.t-doing')), findsNothing);
    expect(find.byKey(const Key('tasks.tile.t-done')), findsNothing);
    // Filtered set has 1 todo + 0 doing + 0 done = "0/1".
    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('tapping the Overdue toggle keeps only past-due active rows', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 5, 17, 12)), () async {
      await tester.pumpWidget(harness([tTodo, tDoing, tDone, tOverdue]));
      await _pumpFrames(tester);

      await tester.tap(find.byKey(const Key('myTasks.filter.overdueToggle')));
      await _pumpFrames(tester);

      // Only the overdue todo survives.
      expect(find.byKey(const Key('tasks.tile.t-overdue')), findsOneWidget);
      expect(find.byKey(const Key('tasks.tile.t-todo')), findsNothing);
      expect(find.byKey(const Key('tasks.tile.t-doing')), findsNothing);
      expect(find.byKey(const Key('tasks.tile.t-done')), findsNothing);
    });
  });

  testWidgets('no-matches state appears when the filter excludes every task', (
    tester,
  ) async {
    // User has tasks but none are Done.
    await tester.pumpWidget(harness([tTodo, tDoing]));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('myTasks.filter.done')));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('myTasks.noMatches')), findsOneWidget);
    expect(find.byKey(const Key('myTasks.list')), findsNothing);
  });
}
