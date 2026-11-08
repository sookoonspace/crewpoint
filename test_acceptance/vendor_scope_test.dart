// Acceptance test for the app half of WE-08 (#70). The rules half is in
// functions/test_acceptance/roles.test.ts. Test names start with the
// scenario ID.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/harness/roles_harness.dart';

void main() {
  testWidgets(
    'WE-08 a vendor sees only their own tasks and payments, and no chat',
    (tester) async {
      tester.view.physicalSize = const Size(375, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const e = 'events/${RolesHarness.eventId}';
      final harness = RolesHarness(
        signedInAs: 'florist',
        initialLocation: '/dashboard/event/${RolesHarness.eventId}/hub',
      );
      addTearDown(() async => harness.database.close());
      await harness.seed(
        roles: const {
          'owner': ['owner'],
          'florist': ['vendor'],
        },
      );
      final db = harness.firestore;
      for (final (id, title, assignee) in [
        ('flowers', 'Deliver flowers', 'florist'),
        ('cake', 'Collect cake', 'owner'),
      ]) {
        await db.doc('$e/tasks/$id').set({
          'eventId': RolesHarness.eventId,
          'title': title,
          'createdBy': 'owner',
          'assigneeId': assignee,
          'status': 'todo',
        });
      }
      for (final (id, what, people) in [
        ('deposit', 'Flower deposit', ['owner', 'florist']),
        ('venue', 'Venue hire', ['owner']),
      ]) {
        await db.doc('$e/expenses/$id').set({
          'payerId': 'owner',
          'amount': 300,
          'description': what,
          'isPayment': false,
          'splits': [
            for (final uid in people)
              {'userId': uid, 'amount': 300 / people.length},
          ],
          'involvedUids': people,
        });
      }
      Future<void> settle() async {
        for (var i = 0; i < 16; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await tester.pumpWidget(harness.buildApp());
      await settle();
      expect(find.byKey(const Key('events.hub.chat')), findsNothing);

      harness.router.go('/dashboard/event/${RolesHarness.eventId}/tasks');
      await settle();
      expect(find.text('Deliver flowers'), findsOneWidget);
      expect(find.text('Collect cake'), findsNothing);
      expect(find.byKey(const Key('tasks.list.create')), findsNothing);

      harness.router.go('/dashboard/event/${RolesHarness.eventId}/budget');
      await settle();
      expect(find.text('Flower deposit'), findsOneWidget);
      expect(find.text('Venue hire'), findsNothing);
      expect(find.byKey(const Key('budget.expense.create')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
