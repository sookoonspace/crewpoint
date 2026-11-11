import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../harness/roles_harness.dart';
import '../../../robots/schedule_robot.dart';

/// #81: the schedule and session screens fit from 375 px to desktop with
/// 200% text, and their buttons are at least 48 px.
void main() {
  const e = 'events/${RolesHarness.eventId}';
  const base = '/dashboard/event/${RolesHarness.eventId}';

  Future<ScheduleRobot> open(
    WidgetTester tester,
    String location, {
    String as = 'owner',
    double width = 375,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = RolesHarness(signedInAs: as, initialLocation: location);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: {
        'owner': const ['owner'],
        'sam': const ['participant'],
      },
    );
    await harness.firestore.doc(e).update({
      'timeZone': 'America/Chicago',
      'venues': [
        {
          'id': 'hall',
          'name': 'Garland Hall Conference Center',
          'address': '5101 N George Bush Hwy, Garland, TX 75040',
          'directions': 'Enter through the east doors, by the fountain.',
        },
      ],
    });
    await harness.firestore.doc('$e/sessions/m1').set({
      'title': 'Gala Night Dinner and DJ with dancing',
      'startAt': Timestamp.fromDate(DateTime.utc(2027, 7, 19)),
      'endAt': Timestamp.fromDate(DateTime.utc(2027, 7, 19, 4)),
      'timeTbc': true,
      'venueId': 'hall',
      'locationTba': false,
      'type': 'Dinner',
      'tags': ['outdoor', 'formal'],
      'capacity': 400,
      'eligibility': {'categoryIds': <String>[], 'filterTags': <String>[]},
      'hidden': true,
    });
    await tester.pumpWidget(harness.buildApp());
    final robot = ScheduleRobot(tester);
    await robot.settle();
    return robot;
  }

  testWidgets('the schedule fits by day and by venue', (tester) async {
    final robot = await open(tester, '$base/schedule');
    expect(tester.takeException(), isNull);
    await robot.expectFound(const Key('schedule.tile.m1'));
    await robot.showByVenue();
    await robot.expectFound(const Key('schedule.venue.hall.map'));
    expect(
      tester.getSize(find.byKey(const Key('schedule.venue.hall.map'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
    await robot.finish();
  });

  testWidgets('the form fits, with 48 px buttons', (tester) async {
    final robot = await open(tester, '$base/schedule/m1');
    expect(tester.takeException(), isNull);
    await robot.expectFound(const Key('schedule.edit.save'));
    expect(
      tester.getSize(find.byKey(const Key('schedule.edit.save'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
    await robot.finish();
  });

  testWidgets('the details fit for a member', (tester) async {
    final robot = await open(tester, '$base/schedule/m1', as: 'sam');
    // Hidden, so a member does not see it at all.
    robot.expectVisible(const Key('schedule.detail.missing'));
    expect(tester.takeException(), isNull);
    await robot.finish();
  });

  testWidgets('the schedule fits on a desktop', (tester) async {
    final robot = await open(tester, '$base/schedule', width: 1440);
    expect(tester.takeException(), isNull);
    await robot.expectFound(const Key('schedule.tile.m1'));
    await robot.finish();
  });

  testWidgets('the agenda fits', (tester) async {
    final robot = await open(tester, '$base/agenda');
    expect(tester.takeException(), isNull);
    // The only session is a hidden draft, which no agenda shows.
    robot.expectVisible(const Key('agenda.noRecord'));
    robot.expectVisible(const Key('agenda.empty'));
    expect(tester.takeException(), isNull);
    await robot.finish();
  });

  testWidgets('the counts fit, with a 48 px recalculate button', (
    tester,
  ) async {
    final robot = await open(tester, '$base/counts');
    expect(tester.takeException(), isNull);
    // Not counted yet.
    await robot.expectFound(const Key('counts.recalculate'));
    expect(
      tester.getSize(find.byKey(const Key('counts.recalculate'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
    await robot.finish();
  });
}
