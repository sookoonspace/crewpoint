import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_assigned_tasks_provider.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/core/widgets/section_label.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/my_tasks_screen.dart';

/// Lottie animations loop forever — use bounded pumps, not pumpAndSettle.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
    'loading branch — renders LoadingAnimation, no empty state, no list',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'uid-1'),
            // dashboardEventsProvider never emits → composed provider stays
            // in loading.
            dashboardEventsProvider.overrideWith(
              (ref) => const Stream<List<EventModel>>.empty(),
            ),
          ],
          child: const MaterialApp(home: MyTasksScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byType(LoadingAnimation), findsOneWidget);
      expect(find.byKey(const Key('emptyState.title')), findsNothing);
    },
  );

  testWidgets(
    'empty-with-events branch — myTasksEmptySubtitle + openDashboardCta',
    (tester) async {
      const event = EventModel(
        id: 'evt-1',
        title: 'Trip',
        creatorId: 'uid-1',
        memberIds: ['uid-1'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'uid-1'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [event]),
            ),
            taskListProvider.overrideWith(
              (ref, eventId) => Stream.value(const []),
            ),
          ],
          child: const MaterialApp(home: MyTasksScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.text('Open an event from the Dashboard to view or create tasks.'),
        findsOneWidget,
      );
      expect(find.text('Open Dashboard'), findsOneWidget);
    },
  );

  testWidgets(
    'empty-no-events branch — myTasksEmptySubtitleNoEvents + createFromDashboardCta',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'uid-1'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const <EventModel>[]),
            ),
          ],
          child: const MaterialApp(home: MyTasksScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.text('Create an event from the Dashboard to get started.'),
        findsOneWidget,
      );
      expect(find.text('Create an event'), findsOneWidget);
      expect(find.text('Open Dashboard'), findsNothing);
    },
  );

  testWidgets(
    'null-uid short-circuit — signInRequiredTitle; dashboardEventsProvider never subscribed',
    (tester) async {
      var dashboardSubscriptions = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => null),
            // Counter-override: if the screen invokes the family provider,
            // it will subscribe to dashboardEventsProvider via the
            // composition. Bumping this counter on each subscription lets
            // the test prove the short-circuit holds.
            dashboardEventsProvider.overrideWith((ref) {
              dashboardSubscriptions++;
              return Stream.value(const <EventModel>[]);
            }),
          ],
          child: const MaterialApp(home: MyTasksScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(find.text('Sign in to view your tasks'), findsOneWidget);
      expect(find.byType(LoadingAnimation), findsNothing);
      expect(
        dashboardSubscriptions,
        0,
        reason: 'myAssignedTasksProvider must NOT be invoked when uid is null',
      );
    },
  );

  testWidgets(
    'non-empty branch — one TasksGroupHeader per distinct event; tile onTap fires seam',
    (tester) async {
      const eventA = EventModel(
        id: 'evt-a',
        title: 'Tahoe Trip',
        creatorId: 'uid-1',
        memberIds: ['uid-1'],
      );
      const eventB = EventModel(
        id: 'evt-b',
        title: 'Project Sync',
        creatorId: 'uid-1',
        memberIds: ['uid-1'],
      );
      const taskA = TaskModel(
        id: 't-a',
        eventId: 'evt-a',
        title: 'Buy snacks',
        assigneeId: 'uid-1',
      );
      const taskB = TaskModel(
        id: 't-b',
        eventId: 'evt-b',
        title: 'Write spec',
        assigneeId: 'uid-1',
      );

      MyAssignedTaskRow? captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'uid-1'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [eventA, eventB]),
            ),
            taskListProvider.overrideWith((ref, eventId) {
              return switch (eventId) {
                'evt-a' => Stream.value(const [taskA]),
                'evt-b' => Stream.value(const [taskB]),
                _ => Stream.value(const <TaskModel>[]),
              };
            }),
          ],
          child: MaterialApp(
            home: MyTasksScreen(onOpenTask: (_, row) => captured = row),
          ),
        ),
      );
      await _pumpFrames(tester);

      // One SectionLabel header per distinct event (groupHeader keys still
      // present so robot tests can target them by event id).
      expect(find.byType(SectionLabel), findsNWidgets(2));
      expect(
        find.byKey(const Key('myTasks.groupHeader.evt-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('myTasks.groupHeader.evt-b')),
        findsOneWidget,
      );
      // SectionLabel uppercases its text — assert via case-insensitive
      // match because the wireframe shows "TAHOE TRIP" all caps.
      expect(find.textContaining('TAHOE TRIP'), findsOneWidget);
      expect(find.textContaining('PROJECT SYNC'), findsOneWidget);
      // Both task tiles render.
      expect(find.byKey(const Key('tasks.tile.t-a')), findsOneWidget);
      expect(find.byKey(const Key('tasks.tile.t-b')), findsOneWidget);

      // Tap one tile → captures the right row.
      await tester.tap(find.byKey(const Key('tasks.tile.t-b')));
      await _pumpFrames(tester);
      expect(captured?.task.id, 't-b');
      expect(captured?.event.id, 'evt-b');
    },
  );
}
