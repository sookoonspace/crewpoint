import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';

import '../harness/dashboard_harness.dart';
import '../robots/dashboard_robot.dart';

/// Critical home-tour journey:
/// 1. Seed Drift with one event and a 2 todo / 1 doing / 3 done task split.
/// 2. Render the Dashboard.
/// 3. Assert the EventTile shows "3/6" inside `event.tile.<id>.ring`.
///
/// The progress ring is fed by the Drift-backed `eventTaskCountsProvider`,
/// so this also verifies the StreamProvider wiring end-to-end.
void main() {
  testWidgets('home tour — event tile shows live progress label from Drift', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = DashboardJourneyHarness(
      currentUser: const AppUser(
        uid: 'uid-1',
        email: 'alex@example.com',
        displayName: 'Alex',
      ),
    );
    addTearDown(() async => harness.database.close());

    // Seed Firestore with one event so dashboardEventsProvider emits it.
    const eventId = 'evt-1';
    await harness.firestore.collection('events').doc(eventId).set({
      'title': 'Tahoe Trip',
      'creatorId': 'uid-1',
      'adminIds': ['uid-1'],
      'memberIds': ['uid-1'],
      'eventType': 'trip',
      'status': 'active',
      'currency': 'USD',
    });

    // Seed Drift directly with tasks: 2 todo + 1 doing + 3 done = 3/6.
    final dao = TasksDao(harness.database);
    TasksCompanion task(String id, String status) => TasksCompanion(
      id: Value(id),
      eventId: const Value(eventId),
      title: Value('Task $id'),
      status: Value(status),
    );
    await dao.insertTask(task('t1', 'todo'));
    await dao.insertTask(task('t2', 'todo'));
    await dao.insertTask(task('t3', 'inProgress'));
    await dao.insertTask(task('t4', 'done'));
    await dao.insertTask(task('t5', 'done'));
    await dao.insertTask(task('t6', 'done'));

    await withClock(Clock.fixed(DateTime(2026, 5, 17, 8)), () async {
      await tester.pumpWidget(harness.buildApp());
      // Bounded pumps: dashboardEventsProvider + eventTaskCountsProvider are
      // both ongoing streams; pumpAndSettle would deadlock.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final robot = DashboardRobot(tester);
      robot.expectGreetingContains('Alex');
      robot.expectEventTile('Tahoe Trip');
      robot.expectProgressLabel(eventId, '3/6');
    });

    // Unmount cleanly before the test framework's invariants run.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
