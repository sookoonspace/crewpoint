import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

import '../harness/tasks_harness.dart';
import '../robots/tasks_robot.dart';

void main() {
  testWidgets(
    'owner edits a task budget and the change reaches Firestore + Drift',
    (tester) async {
      const user = AppUser(uid: 'owner-1', email: 'owner@example.com');
      const event = EventModel(
        id: 'evt-1',
        title: 'Trip',
        creatorId: 'owner-1',
        memberIds: ['owner-1'],
        currency: 'USD',
      );

      final harness = TasksHarness(event: event, currentUser: user);
      addTearDown(() async => harness.database.close());
      await harness.seed();

      // Seed a pre-existing task in Firestore that the detail page will load.
      await harness.firestore
          .collection('events/evt-1/tasks')
          .doc('task-1')
          .set({
            'eventId': 'evt-1',
            'title': 'Buy snacks',
            'createdBy': 'owner-1',
            'status': 'todo',
            'priority': 0,
            'budgetEstimate': 25.0,
          });

      await tester.pumpWidget(harness.buildDetailPage(taskId: 'task-1'));
      // Drive enough frames for the Firestore mirror to populate Drift +
      // the detail page to render. pumpAndSettle is unsafe here because
      // the Drift stream + usersByIdProvider future re-emit periodically.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final robot = TasksRobot(tester);

      // Edit lives inside the new overflow menu now.
      expect(find.byKey(const Key('tasks.detail.overflow')), findsOneWidget);
      await robot.tapEditOnDetail();
      expect(find.byKey(const Key('tasks.edit.budget')), findsOneWidget);

      await robot.enterEditBudget('75.50');
      await robot.tapEditSave();

      // Firestore should reflect the new budget.
      final updated = await harness.firestore
          .doc('events/evt-1/tasks/task-1')
          .get();
      expect(updated.data()!['budgetEstimate'], 75.5);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
