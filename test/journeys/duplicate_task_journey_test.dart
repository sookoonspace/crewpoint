import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

import '../harness/tasks_harness.dart';
import '../robots/tasks_robot.dart';

void main() {
  testWidgets(
    'owner duplicates a task; new Firestore doc gets " (copy)" suffix + checklist copied',
    (tester) async {
      // Tall canvas: form has three AppFormSections + inline AppDateField.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Seed a task + 3 checklist items in Firestore.
      await harness.firestore
          .collection('events/evt-1/tasks')
          .doc('source-task')
          .set({
            'eventId': 'evt-1',
            'title': 'Buy snacks',
            'createdBy': 'owner-1',
            'status': 'todo',
            'priority': 2,
          });
      for (final (id, text) in [
        ('i1', 'Apple'),
        ('i2', 'Banana'),
        ('i3', 'Crackers'),
      ]) {
        await harness.firestore
            .collection('events/evt-1/tasks/source-task/checklist')
            .doc(id)
            .set({'text': text, 'isCompleted': false, 'sortOrder': 0});
      }

      await tester.pumpWidget(harness.buildDetailPage(taskId: 'source-task'));
      // Drive enough frames to render + populate via the mirror.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final robot = TasksRobot(tester);

      // Open overflow → Duplicate. The CreateTaskScreen opens pre-filled.
      await robot.tapDuplicateOnDetail();

      // Title is pre-filled with " (copy)" suffix.
      final titleField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('tasks.create.title')),
          matching: find.byType(TextField),
        ),
      );
      expect(titleField.controller!.text, 'Buy snacks (copy)');

      // Save the duplicate.
      await robot.tapSave();

      // Firestore now has 2 task docs.
      final tasksSnap = await harness.firestore
          .collection('events/evt-1/tasks')
          .get();
      expect(tasksSnap.docs.length, 2);

      // Find the new doc (the non-source one), confirm shape.
      final newDoc = tasksSnap.docs.firstWhere((d) => d.id != 'source-task');
      final newData = newDoc.data();
      expect(newData['title'], 'Buy snacks (copy)');
      expect(newData['createdBy'], 'owner-1');
      expect(newData['priority'], 2);
      expect(newData['status'], 'todo');

      // The new task's checklist has all 3 items (fresh ids).
      final newChecklist = await harness.firestore
          .collection('events/evt-1/tasks/${newDoc.id}/checklist')
          .get();
      expect(newChecklist.docs.length, 3);
      final newTexts = newChecklist.docs.map((d) => d['text']).toSet();
      expect(newTexts, {'Apple', 'Banana', 'Crackers'});

      // Tear down to drain Drift StreamQueryStore timers.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
