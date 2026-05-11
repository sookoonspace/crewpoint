import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';

import '../harness/dashboard_harness.dart';

void main() {
  testWidgets(
    'owner edits the event title from the settings gear and the change reaches Firestore',
    (tester) async {
      // Tall canvas so the save button stays on-screen.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = DashboardJourneyHarness(
        currentUser: const AppUser(uid: 'owner-1', email: 'owner@example.com'),
      );
      addTearDown(() async => harness.database.close());

      // Seed an existing event the user owns.
      await harness.firestore.collection('events').doc('evt-1').set({
        'title': 'Original Title',
        'creatorId': 'owner-1',
        'eventType': 'trip',
        'adminIds': ['owner-1'],
        'memberIds': ['owner-1'],
        'status': 'active',
        'currency': 'USD',
      });

      await tester.pumpWidget(harness.buildApp());
      // Let the dashboard mirror the Firestore event into Drift.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Tap the event tile → navigates to EventDashboardScreen.
      await tester.tap(find.text('Original Title'));
      await tester.pumpAndSettle();

      // Settings gear is admin-only. Owner is implicit admin.
      expect(
        find.byKey(const Key('event.dashboard.settingsIcon')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('event.dashboard.settingsIcon')));
      await tester.pumpAndSettle();

      // EditEventScreen renders.
      expect(find.byKey(const Key('editEvent.title')), findsOneWidget);

      // Change the title.
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('editEvent.title')),
          matching: find.byType(TextField),
        ),
        'Renamed Trip',
      );
      await tester.pump();

      // Save.
      await tester.ensureVisible(find.byKey(const Key('editEvent.save')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('editEvent.save')));
      await tester.pumpAndSettle();

      // Firestore reflects the new title; immutables preserved.
      final updated = await harness.firestore
          .collection('events')
          .doc('evt-1')
          .get();
      expect(updated.data()!['title'], 'Renamed Trip');
      expect(updated.data()!['creatorId'], 'owner-1');
      expect(updated.data()!['memberIds'], ['owner-1']);
      expect(updated.data()!['currency'], 'USD');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
