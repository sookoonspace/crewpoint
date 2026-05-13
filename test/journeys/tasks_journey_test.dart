import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

import '../harness/tasks_harness.dart';
import '../robots/tasks_robot.dart';

void main() {
  testWidgets('owner creates a task and toggles it through to done', (
    tester,
  ) async {
    const user = AppUser(uid: 'owner-1', email: 'owner@example.com');
    const event = EventModel(
      id: 'evt-1',
      title: 'Trip',
      creatorId: 'owner-1',
      memberIds: ['owner-1'],
    );

    final harness = TasksHarness(event: event, currentUser: user);
    addTearDown(() async => harness.database.close());
    await harness.seed();

    await tester.pumpWidget(harness.buildApp());
    // Task list empty state now renders the `EmptyStatePlaceholder` whose
    // lottie animation loops forever — pumpAndSettle would hang.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final robot = TasksRobot(tester);
    robot.expectEmptyState();

    // Create a task
    await robot.tapCreate();
    await robot.enterTitle('Buy snacks');
    await robot.tapSave();

    // The list re-renders via Drift watch
    await tester.pumpAndSettle();
    robot.expectTaskTitle('Buy snacks');

    // Find the just-created task to drive status toggles by id
    final remoteSnap = await harness.firestore
        .collection('events/evt-1/tasks')
        .get();
    expect(remoteSnap.docs, hasLength(1));
    final taskId = remoteSnap.docs.first.id;

    // todo -> inProgress (direct Firestore write, no CF call)
    await robot.tapStatus(taskId);
    await tester.pumpAndSettle();
    expect(harness.markCompleteCalls, isEmpty);
    expect(
      (await harness.firestore.doc('events/evt-1/tasks/$taskId').get())
          .data()!['status'],
      'inProgress',
    );

    // inProgress -> done (routes through markTaskComplete CF stub)
    await robot.tapStatus(taskId);
    await tester.pumpAndSettle();
    expect(harness.markCompleteCalls, hasLength(1));
    expect(harness.markCompleteCalls.first['taskId'], equals(taskId));
    robot.expectStatusIcon(icon: Icons.check_circle);

    // Unmount the tree under test before the test framework's invariants
    // run; this lets Drift's StreamQueryStore cleanup timer fire during pump.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
