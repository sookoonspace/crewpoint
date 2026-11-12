import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/harness/dashboard_harness.dart';
import '../test/robots/create_event_robot.dart';

/// #89 (Req 63, PA-01): on a phone, a host picks Party, types a title,
/// picks a date and creates the event, with no setup screens after.
void main() {
  testWidgets('PA-01 a host creates a party on a phone in under a minute, '
      'with no setup screens', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = DashboardJourneyHarness(
      currentUser: const AppUser(uid: 'host', email: 'host@example.com'),
    );
    addTearDown(() async => harness.database.close());
    await tester.pumpWidget(harness.buildApp());
    final robot = CreateEventRobot(tester);
    await robot.settle();

    final started = DateTime.now();
    var steps = 0;
    await robot.tapCreateFab();
    steps++;
    await robot.chooseTemplate('party');
    steps++;
    await robot.enterTitle("Lily's 7th birthday");
    steps++;
    // A day next month, so the party is upcoming whatever the clock says.
    await tester.tap(find.byKey(const Key('createEvent.date')));
    await robot.settle();
    await tester.tap(find.byTooltip('Next month'));
    await robot.settle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await robot.settle();
    steps++;
    await robot.tapSubmit();
    steps++;

    // Five taps or entries, then straight back to the event list.
    expect(steps, 5);
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(minutes: 1)),
    );
    // The event list fills from the device's mirror.
    for (var i = 0; i < 6; i++) {
      await robot.settle();
    }
    expect(find.byKey(const Key('createEvent.error')), findsNothing);
    expect(find.byKey(const Key('createEvent.submit')), findsNothing);
    expect(find.byKey(const Key('events.create.templates')), findsNothing);

    final event = (await harness.firestore.collection('events').get())
        .docs
        .single
        .data();
    expect(event['templateId'], 'party');
    expect(event['startDate'], isNotNull);
    expect(event['status'], 'draft');
    // Back on the event list, which shows the new party.
    expect(find.text("Lily's 7th birthday"), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
