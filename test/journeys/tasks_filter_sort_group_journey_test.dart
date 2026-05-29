import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

import '../harness/tasks_harness.dart';

void main() {
  testWidgets('search → overdue chip → sort by Priority → group by Assignee', (
    tester,
  ) async {
    // Wide canvas — the filter bar uses a Wrap that needs room.
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const user = AppUser(uid: 'owner-1', email: 'owner@example.com');
    const event = EventModel(
      id: 'evt-1',
      title: 'Trip',
      creatorId: 'owner-1',
      memberIds: ['owner-1'],
    );

    // Freeze time so overdue / due-window are deterministic. CI3 seam.
    await withClock(Clock.fixed(DateTime(2026, 6, 15, 12, 0)), () async {
      final harness = TasksHarness(event: event, currentUser: user);
      addTearDown(() async => harness.database.close());
      await harness.seed();

      // Seed 4 tasks via Firestore so the mirror picks them up.
      await harness.firestore.collection('events/evt-1/tasks').doc('a').set({
        'eventId': 'evt-1',
        'title': 'Buy lunch supplies',
        'createdBy': 'owner-1',
        'assigneeId': 'owner-1',
        'status': 'todo',
        'priority': 3,
        'dueDate': Timestamp.fromDate(DateTime(2026, 6, 14)),
      });
      await harness.firestore.collection('events/evt-1/tasks').doc('b').set({
        'eventId': 'evt-1',
        'title': 'Plan dinner menu',
        'createdBy': 'owner-1',
        'status': 'todo',
        'priority': 1,
      });
      await harness.firestore.collection('events/evt-1/tasks').doc('c').set({
        'eventId': 'evt-1',
        'title': 'Lunch reservation',
        'createdBy': 'owner-1',
        'status': 'inProgress',
        'priority': 2,
        'dueDate': Timestamp.fromDate(DateTime(2026, 6, 20)),
      });
      await harness.firestore.collection('events/evt-1/tasks').doc('d').set({
        'eventId': 'evt-1',
        'title': 'Pack backpack',
        'createdBy': 'owner-1',
        'status': 'done',
        'priority': 0,
      });

      await tester.pumpWidget(harness.buildApp());

      // Drive enough frames for Firestore mirror + Drift watch to render.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // All 4 task titles visible at first.
      expect(find.text('Buy lunch supplies'), findsOneWidget);
      expect(find.text('Plan dinner menu'), findsOneWidget);
      expect(find.text('Lunch reservation'), findsOneWidget);
      expect(find.text('Pack backpack'), findsOneWidget);

      // 1) Search "lunch" → 2 hits.
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('tasks.list.search')),
          matching: find.byType(TextField),
        ),
        'lunch',
      );
      await tester.pump();
      expect(find.text('Buy lunch supplies'), findsOneWidget);
      expect(find.text('Lunch reservation'), findsOneWidget);
      expect(find.text('Plan dinner menu'), findsNothing);
      expect(find.text('Pack backpack'), findsNothing);

      // Clear search.
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('tasks.list.search')),
          matching: find.byType(TextField),
        ),
        '',
      );
      await tester.pump();

      // 2) Tap Overdue chip → only "Buy lunch supplies" (dueDate=2026-06-14).
      await tester.tap(find.byKey(const Key('tasks.list.filterChip.overdue')));
      await tester.pump();
      expect(find.text('Buy lunch supplies'), findsOneWidget);
      expect(find.text('Lunch reservation'), findsNothing);
      expect(find.text('Plan dinner menu'), findsNothing);
      expect(find.text('Pack backpack'), findsNothing);

      // Clear chip.
      await tester.tap(find.byKey(const Key('tasks.list.filterChip.overdue')));
      await tester.pump();

      // 3) Switch sort to Priority → SortKey changes; tiles still all 4
      //    visible (priority sort doesn't filter, just orders).
      await tester.tap(find.byKey(const Key('tasks.list.sortMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tasks.list.sortMenu.priority')));
      await tester.pumpAndSettle();
      expect(find.text('Buy lunch supplies'), findsOneWidget);
      expect(find.text('Plan dinner menu'), findsOneWidget);
      expect(find.text('Lunch reservation'), findsOneWidget);
      expect(find.text('Pack backpack'), findsOneWidget);

      // 4) Switch grouping to Assignee → groups render.
      await tester.tap(
        find.byKey(const Key('tasks.list.groupToggle.assignee')),
      );
      await tester.pump();
      // The assignee group for owner-1 + an Unassigned bucket exist.
      expect(
        find.byKey(const Key('tasks.list.groupHeader.unassigned')),
        findsOneWidget,
      );

      // Cleanup pumps to drain Drift StreamQueryStore timers.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });
}
