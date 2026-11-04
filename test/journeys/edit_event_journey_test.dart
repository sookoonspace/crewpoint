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

  Future<DashboardJourneyHarness> openEvent(
    WidgetTester tester, {
    required String uid,
    String status = 'published',
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = DashboardJourneyHarness(
      currentUser: AppUser(uid: uid, email: '$uid@example.com'),
    );
    addTearDown(() async => harness.database.close());
    await harness.firestore.collection('events').doc('evt-1').set({
      'title': 'Convention',
      'creatorId': 'owner-1',
      'adminIds': ['owner-1'],
      'memberIds': ['owner-1', 'member-1'],
      'status': status,
      'currency': 'USD',
    });
    await tester.pumpWidget(harness.buildApp());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('Convention'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return harness;
  }

  testWidgets('an organizer reaches settings from the event and saves', (
    tester,
  ) async {
    final harness = await openEvent(tester, uid: 'owner-1');

    final entry = find.byKey(const Key('events.dashboard.settings'));
    await tester.ensureVisible(entry);
    await tester.pump();
    await tester.tap(entry);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.enterText(
      find.byKey(const Key('events.settings.timeZone')),
      'America/Chicago',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('events.settings.save')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final saved = await harness.firestore.doc('events/evt-1').get();
    expect(saved.data()!['timeZone'], 'America/Chicago');
    expect(find.byKey(const Key('events.settings.save')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('a plain member has no way into settings', (tester) async {
    await openEvent(tester, uid: 'member-1');

    expect(find.byKey(const Key('events.dashboard.settings')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('an organizer publishes a draft from the event', (tester) async {
    final harness = await openEvent(tester, uid: 'owner-1', status: 'draft');

    expect(find.byKey(const Key('events.dashboard.status')), findsOneWidget);
    expect(
      find.byKey(const Key('eventDashboard.inviteMembers.tile')),
      findsNothing,
    );
    final publish = find.byKey(const Key('events.dashboard.publish'));
    await tester.ensureVisible(publish);
    await tester.pump();
    await tester.tap(publish);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final saved = await harness.firestore.doc('events/evt-1').get();
    expect(saved.data()!['status'], 'published');
    expect(find.byKey(const Key('events.dashboard.publish')), findsNothing);
    expect(
      find.byKey(const Key('eventDashboard.inviteMembers.tile')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('a plain member does not see a draft listed', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = DashboardJourneyHarness(
      currentUser: const AppUser(uid: 'member-1', email: 'm@example.com'),
    );
    addTearDown(() async => harness.database.close());
    await harness.firestore.collection('events').doc('evt-1').set({
      'title': 'Secret draft',
      'creatorId': 'owner-1',
      'adminIds': ['owner-1'],
      'memberIds': ['owner-1', 'member-1'],
      'status': 'draft',
    });
    await tester.pumpWidget(harness.buildApp());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Secret draft'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
