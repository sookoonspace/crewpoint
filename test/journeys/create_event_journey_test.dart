import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';

import '../harness/dashboard_harness.dart';
import '../robots/create_event_robot.dart';

void main() {
  testWidgets(
    'signed-in user creates an event and the new tile appears on the dashboard',
    (tester) async {
      // CreateEventScreen is a tall form; the default 800x600 viewport hides
      // its submit button below the fold. Use a tall canvas so taps land.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = DashboardJourneyHarness(
        currentUser: const AppUser(uid: 'uid-42', email: 'a@example.com'),
      );
      addTearDown(() async => harness.database.close());

      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();

      final robot = CreateEventRobot(tester);
      robot.expectEmptyDashboard();

      await robot.tapCreateFab();
      await robot.enterTitle('Tahoe Trip');
      await robot.tapSubmit();

      // Dashboard re-renders via the Firestore-Write / Drift-Read mirror.
      robot.expectEventTile('Tahoe Trip');

      // The Firestore document was written with the right ownership fields.
      final snap = await harness.firestore.collection('events').get();
      expect(snap.docs, hasLength(1));
      final data = snap.docs.first.data();
      expect(data['title'], 'Tahoe Trip');
      expect(data['creatorId'], 'uid-42');
      expect(data['adminIds'], ['uid-42']);
      expect(data['memberIds'], ['uid-42']);
      expect(data['status'], 'active');

      // Unmount before the test framework's invariants run; lets Drift's
      // StreamQueryStore cleanup timer fire.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
