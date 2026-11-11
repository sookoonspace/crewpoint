import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/schedule_robot.dart';

/// #82 (Req 50, 51; J-05, J-06): an organizer builds a schedule and records
/// exceptions, and each person's agenda follows from the event's policy,
/// each session's rule and those exceptions, with what is on now and next.
void main() {
  late RolesHarness harness;
  const e = 'events/${RolesHarness.eventId}';
  const base = '/dashboard/event/${RolesHarness.eventId}';

  Future<void> session(
    String id,
    String title,
    DateTime start, {
    DateTime? end,
    String? attendance,
    List<String> categoryIds = const [],
  }) => harness.firestore.doc('$e/sessions/$id').set({
    'title': title,
    'startAt': Timestamp.fromDate(start),
    'endAt': end == null ? null : Timestamp.fromDate(end),
    'timeTbc': false,
    'venueId': null,
    'locationTba': false,
    'type': null,
    'tags': <String>[],
    'capacity': null,
    'eligibility': {'categoryIds': categoryIds, 'filterTags': <String>[]},
    'hidden': false,
    'attendance': attendance,
  });

  Future<void> person(
    String id,
    String name, {
    String? groupId,
    String? uid,
    String categoryId = 'adult',
    DateTime? arrivalAt,
    List<String> optOuts = const [],
    List<String> signUps = const [],
  }) => harness.firestore.doc('$e/participants/$id').set({
    'name': name,
    'sortName': name.toLowerCase(),
    'groupId': groupId,
    'isChild': categoryId == 'child',
    'status': 'active',
    'createdBy': 'owner',
    'categoryId': categoryId,
    'uid': ?uid,
    'arrivalAt': arrivalAt == null ? null : Timestamp.fromDate(arrivalAt),
    'optOuts': optOuts,
    'signUps': signUps,
  });

  /// The convention's Saturday, in Chicago (UTC-5 in July).
  DateTime sat(int hour, [int minute = 0]) =>
      DateTime.utc(2027, 7, 17, hour + 5, minute);

  Future<ScheduleRobot> open(
    WidgetTester tester, {
    required String as,
    required String location,
    DateTime? now,
    Future<void> Function()? seed,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(375, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: as, initialLocation: location);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: {
        'owner': const ['owner'],
        'kunal': const ['participant'],
        'savita': const ['participant'],
      },
      groupIds: {
        'kunal': const ['f3'],
        'savita': const ['f4'],
      },
    );
    await harness.firestore.doc(e).update({
      'timeZone': 'America/Chicago',
      'startDate': Timestamp.fromDate(DateTime.utc(2027, 7, 16)),
      'dateOnly': true,
      'settings': {
        'attendancePolicy': 'arrivalToDeparture',
        'categories': [
          {'id': 'child', 'name': 'Child', 'maxAge': 17, 'isChild': true},
          {'id': 'adult', 'name': 'Adult', 'minAge': 18},
        ],
      },
    });
    await harness.firestore.doc('$e/groups/f3').set({
      'name': 'Desai',
      'sortName': 'desai',
      'adultUids': ['kunal'],
    });
    await harness.firestore.doc('$e/groups/f4').set({
      'name': 'Mistry',
      'sortName': 'mistry',
      'adultUids': ['savita'],
    });
    await session('m2', 'Breakfast', sat(8), end: sat(9));
    await session('m3', 'Lunch', sat(12, 30), end: sat(13, 30));
    await session(
      'k1',
      'Kids activities',
      sat(13, 30),
      end: sat(15),
      attendance: 'bySession',
      categoryIds: const ['child'],
    );
    await person('kunal', 'Kunal', groupId: 'f3', uid: 'kunal');
    await person('ramesh', 'Ramesh', groupId: 'f3', optOuts: const ['m3']);
    await person(
      'asha',
      'Asha',
      groupId: 'f3',
      categoryId: 'child',
      signUps: const ['k1'],
    );
    await person('neel', 'Neel', groupId: 'f3', categoryId: 'child');
    await person(
      'savita',
      'Savita',
      groupId: 'f4',
      uid: 'savita',
      arrivalAt: sat(11),
    );
    await seed?.call();
    await tester.pumpWidget(
      harness.buildApp(
        overrides: [
          clockProvider.overrideWithValue(Clock.fixed(now ?? sat(7))),
          ...overrides,
        ],
      ),
    );
    final robot = ScheduleRobot(tester);
    await robot.settle();
    return robot;
  }

  testWidgets('J-06 a linked adult sees their group\'s agenda, by person', (
    tester,
  ) async {
    final robot = await open(tester, as: 'kunal', location: '$base/agenda');
    await robot.expectFound(const Key('agenda.day.2027-07-17'));
    for (final id in ['m2', 'm3', 'k1']) {
      await robot.expectFound(Key('schedule.tile.$id'));
    }
    // Who from the group goes to each.
    expect(
      tester
          .widget<Text>(find.byKey(const Key('schedule.tile.k1.note')).last)
          .data,
      'Asha',
    );

    // Ramesh opted out of lunch, and has no kids activity.
    await robot.tap(const Key('agenda.person.ramesh'));
    robot.expectHidden(const Key('schedule.tile.m3'));
    robot.expectHidden(const Key('schedule.tile.k1'));
    // Neel did not sign up for the kids activity.
    await robot.tap(const Key('agenda.person.neel'));
    robot.expectHidden(const Key('schedule.tile.k1'));
    await robot.tap(const Key('agenda.person.asha'));
    await robot.expectFound(const Key('schedule.tile.k1'));
    await robot.finish();
  });

  testWidgets('J-06 someone arriving later sees nothing earlier', (
    tester,
  ) async {
    final robot = await open(tester, as: 'savita', location: '$base/agenda');
    await robot.expectFound(const Key('schedule.tile.m3'));
    robot.expectHidden(const Key('schedule.tile.m2'));
    robot.expectHidden(const Key('schedule.tile.k1'));
    robot.expectHidden(const Key('agenda.person.all'));
    await robot.finish();
  });

  testWidgets('J-05 shows what is on now and next', (tester) async {
    final robot = await open(
      tester,
      as: 'kunal',
      location: '$base/agenda',
      now: sat(12, 45),
    );
    robot.expectVisible(const Key('agenda.now.m3'));
    robot.expectVisible(const Key('agenda.next.k1'));
    await robot.finish();
  });

  testWidgets('J-05 after the last session nothing is next', (tester) async {
    final robot = await open(
      tester,
      as: 'kunal',
      location: '$base/agenda',
      now: sat(20),
    );
    robot.expectVisible(const Key('agenda.now.none'));
    robot.expectVisible(const Key('agenda.next.none'));
    await robot.finish();
  });

  testWidgets('an organizer with no attendee record sees the whole schedule', (
    tester,
  ) async {
    final robot = await open(tester, as: 'owner', location: '$base/agenda');
    robot.expectVisible(const Key('agenda.noRecord'));
    await robot.expectFound(const Key('schedule.tile.m2'));
    await robot.expectFound(const Key('schedule.tile.k1'));
    await robot.finish();
  });

  testWidgets('an organizer builds a schedule and it reaches the agenda', (
    tester,
  ) async {
    final robot = await open(tester, as: 'owner', location: '$base/schedule');
    await robot.addSession();
    await robot.enter('title', 'Bhajan');
    await robot.pickDay(17);
    await robot.pickTime('start', 16, 0);
    await robot.save();
    await robot.expectFound(const Key('schedule.day.2027-07-17'));
    final saved = (await harness.firestore.collection('$e/sessions').get()).docs
        .firstWhere((d) => d.data()['title'] == 'Bhajan');
    harness.router.go('$base/agenda');
    await robot.finishTransition();
    await robot.expectFound(Key('schedule.tile.${saved.id}'));
    await robot.finish();
  });

  testWidgets('an organizer opts someone out, storing only the exception', (
    tester,
  ) async {
    final robot = await open(
      tester,
      as: 'owner',
      location: '$base/people/kunal',
    );
    await robot.tap(const Key('people.edit.session.m3'));
    await robot.tap(const Key('people.edit.save'));
    await robot.finishTransition();
    final data = (await harness.firestore.doc('$e/participants/kunal').get())
        .data()!;
    expect(data['optOuts'], ['m3']);
    expect(data['signUps'], isEmpty);
    expect(data['invitedTo'], isEmpty);
    await robot.finish();
  });

  testWidgets("a linked adult signs a child up, but can't invite", (
    tester,
  ) async {
    final robot = await open(
      tester,
      as: 'kunal',
      location: '$base/people/neel',
    );
    await robot.tap(const Key('people.edit.session.k1'));
    await robot.tap(const Key('people.edit.save'));
    await robot.finishTransition();
    final data = (await harness.firestore.doc('$e/participants/neel').get())
        .data()!;
    expect(data['signUps'], ['k1']);
    expect(data['invitedTo'], isEmpty);
    await robot.finish();
  });

  testWidgets('a linked adult cannot add a session outside a stay', (
    tester,
  ) async {
    final robot = await open(
      tester,
      as: 'savita',
      location: '$base/people/savita',
    );
    await robot.reveal(find.byKey(const Key('people.edit.session.m2')));
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('people.edit.session.m2')),
    );
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);
    expect(find.textContaining('Only organizers can invite.'), findsWidgets);
    await robot.finish();
  });

  testWidgets('an organizer invites a whole group to a session', (
    tester,
  ) async {
    final robot = await open(tester, as: 'owner', location: '$base/people');
    await robot.tap(const Key('people.roster.groupFilter'));
    await robot.tap(const Key('people.groupPicker.f4'));
    await robot.tap(const Key('people.roster.groupManage'));
    await robot.tap(const Key('people.group.invite.m2'));
    await robot.tap(const Key('people.group.saveInvitations'));
    final data = (await harness.firestore.doc('$e/groups/f4').get()).data()!;
    expect(data['invitedTo'], ['m2']);
    await robot.finish();
  });
}
