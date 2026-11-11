import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/core/database/daos/sessions_dao.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/url_launcher_service.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart'
    show EventWriteResult;
import 'package:crewpoint_app/app/features/schedule/data/session_repository.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/schedule_robot.dart';

class _Launcher implements IUrlLauncher {
  final opened = <Uri>[];

  @override
  Future<bool> launch(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

/// A repository whose saves fail, as when the server refuses one.
class _FailingSessions extends SessionRepository {
  _FailingSessions({required super.dao, required super.firestore});

  var attempts = 0;

  @override
  Future<(EventWriteResult, String)> save(
    String eventId,
    SessionModel session, {
    required String uid,
  }) async {
    attempts++;
    return (EventWriteResult.failed, session.id);
  }
}

/// #81 (Req 48, 49; A-02, A-05, GAP-WED-12): an organizer builds a schedule
/// over several days and venues, changes times as plans move, and hides a
/// draft. Members read the rest, by day or by venue, with map links and
/// directions.
void main() {
  late RolesHarness harness;
  late _Launcher launcher;
  const e = 'events/${RolesHarness.eventId}';
  const base = '/dashboard/event/${RolesHarness.eventId}';

  Future<void> addSession(
    String id,
    String title,
    DateTime startUtc, {
    String? venueId,
    bool hidden = false,
    bool timeTbc = false,
    bool locationTba = false,
    List<String> tags = const [],
  }) => harness.firestore.doc('$e/sessions/$id').set({
    'title': title,
    'startAt': Timestamp.fromDate(startUtc),
    'endAt': null,
    'timeTbc': timeTbc,
    'venueId': venueId,
    'locationTba': locationTba,
    'type': null,
    'tags': tags,
    'capacity': null,
    'eligibility': {'categoryIds': <String>[], 'filterTags': <String>[]},
    'hidden': hidden,
  });

  Future<ScheduleRobot> open(
    WidgetTester tester, {
    String as = 'owner',
    String location = '$base/schedule',
    List<Override> overrides = const [],
    Future<void> Function()? seed,
  }) async {
    tester.view.physicalSize = const Size(375, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: as, initialLocation: location);
    addTearDown(() async => harness.database.close());
    launcher = _Launcher();
    await harness.seed(
      roles: {
        'owner': const ['owner'],
        'lead': const ['crewLead'],
        'sam': const ['participant'],
      },
    );
    await harness.firestore.doc(e).update({
      'timeZone': 'America/Chicago',
      'startDate': Timestamp.fromDate(DateTime.utc(2027, 7, 16)),
      'endDate': Timestamp.fromDate(DateTime.utc(2027, 7, 19)),
      'dateOnly': true,
      'venues': [
        {
          'id': 'hall',
          'name': 'Garland Hall',
          'address': '5101 N George Bush Hwy, Garland, TX',
        },
        {
          'id': 'park',
          'name': 'Picnic park',
          'address': null,
          'directions': 'Follow the signs from the hotel lobby.',
        },
        {
          'id': 'parking',
          'name': 'Parking',
          'address': '5101 N George Bush Hwy, Garland, TX',
          'mapUrl': 'https://maps.example.com/parking',
          'directions': 'Free parking behind the hotel.',
        },
      ],
      'settings': {
        'categories': [
          {'id': 'child', 'name': 'Child', 'maxAge': 17, 'isChild': true},
          {'id': 'adult', 'name': 'Adult', 'minAge': 18},
        ],
      },
    });
    await seed?.call();
    await tester.pumpWidget(
      harness.buildApp(
        overrides: [
          urlLauncherProvider.overrideWithValue(launcher),
          ...overrides,
        ],
      ),
    );
    final robot = ScheduleRobot(tester);
    await robot.settle();
    return robot;
  }

  Future<Map<String, dynamic>> stored(String title) async {
    final docs = (await harness.firestore.collection('$e/sessions').get()).docs;
    return docs.firstWhere((d) => d.data()['title'] == title).data();
  }

  testWidgets('an organizer adds a session with a placeholder time', (
    tester,
  ) async {
    final robot = await open(tester);
    robot.expectVisible(const Key('schedule.empty'));

    await robot.addSession();
    await robot.enter('title', 'Lunch');
    await robot.pickDay(17);
    await robot.pickTime('start', 12, 30);
    await robot.pickTime('end', 13, 30);
    await robot.tap(const Key('schedule.edit.timeTbc'));
    await robot.tap(const Key('schedule.edit.venue'));
    await tester.tap(find.text('Picnic park').last);
    await robot.settle();
    await robot.addTag('outdoor');
    await robot.tap(const Key('schedule.edit.category.adult'));
    await robot.save();

    final data = await stored('Lunch');
    // 12:30 in Chicago in July is 17:30 UTC.
    expect(
      (data['startAt'] as Timestamp).toDate().toUtc(),
      DateTime.utc(2027, 7, 17, 17, 30),
    );
    expect(
      (data['endAt'] as Timestamp).toDate().toUtc(),
      DateTime.utc(2027, 7, 17, 18, 30),
    );
    expect(data['timeTbc'], isTrue);
    expect(data['venueId'], 'park');
    expect(data['tags'], ['outdoor']);
    expect(data['eligibility'], {
      'categoryIds': ['adult'],
      'filterTags': <String>[],
    });
    expect(data['updatedBy'], 'owner');

    await robot.expectFound(const Key('schedule.day.2027-07-17'));
    final id = (await harness.firestore.collection('$e/sessions').get())
        .docs
        .single
        .id;
    await robot.expectFound(Key('schedule.tile.$id.tbc'));
    await robot.finish();
  });

  testWidgets('times change as plans move, and the placeholder is confirmed', (
    tester,
  ) async {
    final robot = await open(
      tester,
      as: 'lead',
      seed: () => addSession(
        'm3',
        'Lunch',
        DateTime.utc(2027, 7, 17, 17, 30),
        venueId: 'park',
        timeTbc: true,
      ),
    );
    await robot.openSession('m3');
    await robot.pickTime('start', 13, 0);
    await robot.tap(const Key('schedule.edit.timeTbc'));
    await robot.save();

    final data = await stored('Lunch');
    expect(
      (data['startAt'] as Timestamp).toDate().toUtc(),
      DateTime.utc(2027, 7, 17, 18),
    );
    expect(data['timeTbc'], isFalse);
    expect(data['updatedBy'], 'lead');
    await robot.finish();
  });

  testWidgets('a session that runs past midnight ends the next day', (
    tester,
  ) async {
    final robot = await open(tester);
    await robot.addSession();
    await robot.enter('title', 'Garba');
    await robot.pickDay(17);
    await robot.pickTime('start', 21, 0);
    await robot.pickTime('end', 1, 0);
    robot.expectText('Ends the next day');
    await robot.save();
    final data = await stored('Garba');
    expect(
      (data['endAt'] as Timestamp).toDate().toUtc(),
      DateTime.utc(2027, 7, 18, 6),
    );
    await robot.finish();
  });

  testWidgets('members read the schedule by day, without hidden drafts', (
    tester,
  ) async {
    final robot = await open(
      tester,
      as: 'sam',
      seed: () async {
        await addSession(
          'm1',
          'Welcome dinner',
          DateTime.utc(2027, 7, 17),
          venueId: 'hall',
        );
        await addSession(
          'm8',
          'Farewell breakfast',
          DateTime.utc(2027, 7, 19, 13),
          locationTba: true,
        );
        await addSession(
          'gala',
          'Gala night',
          DateTime.utc(2027, 7, 19),
          hidden: true,
        );
      },
    );
    robot.expectHidden(const Key('schedule.add'));
    // 7 pm on the 16th in Chicago, though the 17th in UTC.
    await robot.expectFound(const Key('schedule.day.2027-07-16'));
    await robot.expectFound(const Key('schedule.tile.m1'));
    await robot.expectFound(const Key('schedule.tile.m8'));
    robot.expectHidden(const Key('schedule.tile.gala'));

    await robot.openSession('m8');
    robot.expectVisible(const Key('schedule.detail.locationTba'));
    robot.expectText('For everyone');
    robot.expectHidden(const Key('schedule.edit.save'));
    await robot.finish();
  });

  testWidgets('an editor sees hidden drafts, marked as hidden', (tester) async {
    final robot = await open(
      tester,
      seed: () => addSession(
        'gala',
        'Gala night',
        DateTime.utc(2027, 7, 19),
        hidden: true,
      ),
    );
    await robot.expectFound(const Key('schedule.tile.gala.hidden'));
    await robot.finish();
  });

  testWidgets('by venue, every venue shows with its map and directions', (
    tester,
  ) async {
    final robot = await open(
      tester,
      as: 'sam',
      seed: () async {
        await addSession(
          'm1',
          'Welcome dinner',
          DateTime.utc(2027, 7, 17),
          venueId: 'hall',
        );
        await addSession(
          'm8',
          'Farewell breakfast',
          DateTime.utc(2027, 7, 19, 13),
          locationTba: true,
        );
      },
    );
    await robot.showByVenue();
    await robot.expectFound(const Key('schedule.venue.hall'));
    await robot.expectFound(const Key('schedule.venue.park.directions'));
    robot.expectText('Address to be announced');
    // No address yet, so no map.
    robot.expectHidden(const Key('schedule.venue.park.map'));
    await robot.expectFound(const Key('schedule.venue.parking.directions'));
    await robot.tap(const Key('schedule.venue.parking.map'));
    expect(
      launcher.opened.single.toString(),
      'https://maps.example.com/parking',
    );
    await robot.tap(const Key('schedule.venue.hall.map'));
    expect(launcher.opened.last.host, 'www.google.com');
    await robot.expectFound(const Key('schedule.venue.none'));
    await robot.finish();
  });

  testWidgets('a failed save keeps what was entered, and can be retried', (
    tester,
  ) async {
    late _FailingSessions failing;
    final robot = await open(
      tester,
      location: '$base/schedule/new',
      overrides: [
        sessionRepositoryProvider.overrideWith((ref) {
          failing = _FailingSessions(
            dao: SessionsDao(ref.watch(databaseProvider)),
            firestore: ref.watch(firestoreProvider),
          );
          return failing;
        }),
      ],
    );
    await robot.enter('title', 'Bhajan');
    await robot.pickDay(17);
    await robot.pickTime('start', 16, 0);
    await robot.tap(const Key('schedule.edit.save'));
    await robot.expectFound(const Key('schedule.edit.error'));
    robot.expectText('Bhajan');
    await robot.tap(const Key('schedule.edit.save'));
    expect(failing.attempts, 2);
    await robot.finish();
  });

  testWidgets('leaving with unsaved changes asks first', (tester) async {
    final robot = await open(tester);
    await robot.addSession();
    await robot.enter('title', 'Lunch');
    await robot.back();
    robot.expectVisible(const Key('schedule.edit.keepEditing'));
    await robot.tap(const Key('schedule.edit.keepEditing'));
    robot.expectText('Lunch');
    await robot.back();
    await robot.tap(const Key('schedule.edit.discard'));
    await robot.finishTransition();
    robot.expectVisible(const Key('schedule.empty'));
    await robot.finish();
  });

  testWidgets('a load failure explains and retries', (tester) async {
    var calls = 0;
    final robot = await open(
      tester,
      overrides: [
        sessionListProvider.overrideWith((ref, _) {
          calls++;
          return calls == 1
              ? Stream.error(StateError('offline'))
              : Stream.value(const []);
        }),
      ],
    );
    robot.expectVisible(const Key('schedule.error'));
    await robot.tap(const Key('schedule.retry'));
    robot.expectVisible(const Key('schedule.empty'));
    await robot.finish();
  });
}
