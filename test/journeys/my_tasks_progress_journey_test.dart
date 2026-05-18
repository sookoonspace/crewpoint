import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/my_tasks_screen.dart';

import '../robots/tasks_robot.dart';

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Critical My Tasks journey:
/// 1. Seed assigned tasks across two events with a known status split.
/// 2. Open `MyTasksScreen` (the bottom-tab entry).
/// 3. Assert the progress summary totals.
/// 4. Tap segment pills + Overdue toggle and verify the filtered effect.
void main() {
  testWidgets(
    'my tasks — progress summary and filter pills react to user input',
    (tester) async {
      const eventA = EventModel(
        id: 'evt-a',
        title: 'Tahoe Trip',
        creatorId: 'uid-1',
        eventType: EventType.trip,
        memberIds: ['uid-1'],
      );
      const eventB = EventModel(
        id: 'evt-b',
        title: 'Project Sync',
        creatorId: 'uid-1',
        eventType: EventType.project,
        memberIds: ['uid-1'],
      );

      final tasksA = [
        const TaskModel(
          id: 't-a1',
          eventId: 'evt-a',
          title: 'Book cabin',
          assigneeId: 'uid-1',
          status: TaskStatus.inProgress,
        ),
        TaskModel(
          id: 't-a2',
          eventId: 'evt-a',
          title: 'Buy snacks',
          assigneeId: 'uid-1',
          dueDate: DateTime(2026, 5, 10),
        ),
        const TaskModel(
          id: 't-a3',
          eventId: 'evt-a',
          title: 'Rent skis',
          assigneeId: 'uid-1',
          status: TaskStatus.done,
        ),
      ];
      const tasksB = [
        TaskModel(
          id: 't-b1',
          eventId: 'evt-b',
          title: 'Write spec',
          assigneeId: 'uid-1',
        ),
        TaskModel(
          id: 't-b2',
          eventId: 'evt-b',
          title: 'Get sign-off',
          assigneeId: 'uid-1',
          status: TaskStatus.done,
        ),
      ];

      await withClock(Clock.fixed(DateTime(2026, 5, 17, 12)), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserIdProvider.overrideWith((ref) => 'uid-1'),
              dashboardEventsProvider.overrideWith(
                (ref) => Stream.value(const [eventA, eventB]),
              ),
              taskListProvider.overrideWith((ref, eventId) {
                return switch (eventId) {
                  'evt-a' => Stream.value(tasksA),
                  'evt-b' => Stream.value(tasksB),
                  _ => Stream.value(const <TaskModel>[]),
                };
              }),
            ],
            child: const MaterialApp(home: MyTasksScreen()),
          ),
        );
        await _pumpFrames(tester);

        final robot = TasksRobot(tester);

        // Default segment is All — total split is 2 todo, 1 doing, 2 done.
        robot.expectSummary(done: 2, doing: 1, todo: 2);

        // Switch to Done — summary recomputes to 2/2 (filtered to done rows).
        await robot.tapSegment('done');
        robot.expectSummary(done: 2, doing: 0, todo: 0);

        // Switch back to All and turn on Overdue — only the overdue todo
        // survives → 0/1 (0 done, 0 doing, 1 todo).
        await robot.tapSegment('all');
        await robot.tapOverdueToggle();
        robot.expectSummary(done: 0, doing: 0, todo: 1);
        expect(find.byKey(const Key('tasks.tile.t-a2')), findsOneWidget);
        expect(find.byKey(const Key('tasks.tile.t-a1')), findsNothing);
      });

      // Unmount cleanly before the test framework's invariants run.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
