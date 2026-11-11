import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/schedule_robot.dart';

/// #83 (Req 52, B-04, B-05): organizers read headcounts for the event and
/// each session, by category and field, with when they were last updated,
/// and can recalculate now. Counts are worked out on the server.
void main() {
  late RolesHarness harness;
  const e = 'events/${RolesHarness.eventId}';
  const base = '/dashboard/event/${RolesHarness.eventId}';

  const counts = <String, Object?>{
    'event': {
      'total': 26,
      'groups': 7,
      'byCategory': {'adult': 16, 'child': 10},
      'byField': {
        'diet': {'Veg': 18, 'Jain': 2, 'Non-veg': 6},
        'kids': {'yes': 7, 'no': 19},
      },
    },
    'sessions': {
      'm3': {
        'total': 24,
        'byCategory': {'adult': 14, 'child': 10},
        'byField': {
          'diet': {'Veg': 18, 'Non-veg': 6},
        },
      },
    },
  };

  Future<ScheduleRobot> open(
    WidgetTester tester, {
    String as = 'owner',
    bool counted = true,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(375, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: as, initialLocation: '$base/counts');
    addTearDown(() async => harness.database.close());
    harness.calls.counts = counts;
    await harness.seed(
      roles: {
        'owner': const ['owner'],
        'lead': const ['crewLead'],
        'sam': const ['participant'],
      },
    );
    final db = harness.firestore;
    await db.doc(e).update({
      'timeZone': 'America/Chicago',
      'settings': {
        'categories': [
          {'id': 'child', 'name': 'Child', 'maxAge': 17},
          {'id': 'adult', 'name': 'Adult', 'minAge': 18},
        ],
      },
    });
    for (final (id, label, type, options) in [
      ('diet', 'Diet', 'singleChoice', ['Veg', 'Jain', 'Non-veg']),
      ('kids', 'Kids activity', 'yesNo', <String>[]),
    ]) {
      await db.doc('$e/fields/$id').set({
        'label': label,
        'type': type,
        'options': options,
        'required': false,
        'scope': 'participant',
        'visibility': 'standard',
        'order': 0,
      });
    }
    await db.doc('$e/sessions/m3').set({
      'title': 'Lunch',
      'startAt': Timestamp.fromDate(DateTime.utc(2027, 7, 17, 17, 30)),
      'timeTbc': false,
      'locationTba': false,
      'tags': <String>[],
      'eligibility': {'categoryIds': <String>[], 'filterTags': <String>[]},
      'hidden': false,
    });
    if (counted) {
      await db.doc('$e/stats/current').set({
        ...counts,
        'updatedAt': Timestamp.fromDate(DateTime(2027, 7, 10, 9, 30)),
      });
    }
    await tester.pumpWidget(harness.buildApp(overrides: overrides));
    final robot = ScheduleRobot(tester);
    await robot.settle();
    return robot;
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('B-04 shows headcounts, by category and by field', (
    tester,
  ) async {
    final robot = await open(tester);
    expect(text(tester, 'counts.event.total'), '26 people · 7 groups');
    expect(text(tester, 'counts.event.category.adult'), '16');
    expect(text(tester, 'counts.event.category.child'), '10');
    expect(text(tester, 'counts.event.field.diet.Jain'), '2');
    expect(text(tester, 'counts.event.field.kids.yes'), '7');
    robot.expectText('Adult');
    robot.expectText('Kids activity');
    expect(text(tester, 'counts.updated'), startsWith('Last updated Jul 10'));
    await robot.finish();
  });

  testWidgets('B-05 shows each session, by diet', (tester) async {
    final robot = await open(tester, as: 'lead');
    await robot.expectFound(const Key('counts.session.m3'));
    expect(text(tester, 'counts.session.m3.total'), '24');
    await robot.tap(const Key('counts.session.m3'));
    expect(text(tester, 'counts.s.m3.field.diet.Veg'), '18');
    await robot.finish();
  });

  testWidgets('before the first count, counting now fills it in', (
    tester,
  ) async {
    final robot = await open(tester, counted: false);
    robot.expectVisible(const Key('counts.empty'));
    await robot.tap(const Key('counts.recalculate'));
    expect(harness.calls.calls, contains('recalculateCounts:evt'));
    await robot.expectFound(const Key('counts.event.total'));
    await robot.finish();
  });

  testWidgets('recalculating offline explains, and keeps the last counts', (
    tester,
  ) async {
    final robot = await open(tester);
    harness.calls.failNext = FirebaseFunctionsException(
      message: 'offline',
      code: 'unavailable',
    );
    await robot.tap(const Key('counts.recalculate'));
    expect(
      text(tester, 'counts.recalculateError'),
      contains('needs a connection'),
    );
    robot.expectVisible(const Key('counts.event.total'));
    // Trying again works.
    await robot.tap(const Key('counts.recalculate'));
    robot.expectHidden(const Key('counts.recalculateError'));
    await robot.finish();
  });

  testWidgets('a load failure explains and retries', (tester) async {
    var attempts = 0;
    final robot = await open(
      tester,
      overrides: [
        eventStatsProvider.overrideWith((ref, _) {
          attempts++;
          return attempts == 1
              ? Stream.error(StateError('offline'))
              : Stream.value(null);
        }),
      ],
    );
    robot.expectVisible(const Key('counts.error'));
    await robot.tap(const Key('counts.retry'));
    robot.expectVisible(const Key('counts.empty'));
    await robot.finish();
  });

  testWidgets('without counts.read, there is nothing to see', (tester) async {
    final robot = await open(tester, as: 'sam');
    robot.expectHidden(const Key('counts.event'));
    robot.expectHidden(const Key('counts.recalculate'));
    await robot.finish();
  });
}
