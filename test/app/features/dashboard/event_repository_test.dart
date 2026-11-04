import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

import '../../../harness/fake_create_event.dart';

void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late EventRepository repo;
  late List<EventModel> sentEvents;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    sentEvents = [];
    repo = EventRepository(
      eventsDao: EventsDao(db),
      firestore: firestore,
      createEventCall: (event) async => sentEvents.add(event),
    );
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  group('createEvent', () {
    const event = EventModel(
      id: 'evt-1',
      title: 'Trip to Tahoe',
      creatorId: 'uid-creator',
    );

    test('goes through the callable, and writes nothing directly', () async {
      await repo.createEvent(event);

      expect(sentEvents.single, same(event));
      final snap = await firestore.collection('events').get();
      expect(snap.docs, isEmpty);
    });

    test('passes on a failure for the screen to show', () async {
      final failing = EventRepository(
        eventsDao: EventsDao(db),
        firestore: firestore,
        createEventCall: (_) async => throw StateError('offline'),
      );
      addTearDown(failing.dispose);
      expect(() => failing.createEvent(event), throwsStateError);
    });
  });

  group('updateEvent', () {
    test('writes only the client-editable fields via update()', () async {
      // Seed an existing event with all immutable fields populated.
      await firestore.collection('events').doc('evt-1').set({
        'title': 'Original Title',
        'creatorId': 'uid-1',
        'eventType': 'trip',
        'adminIds': ['uid-1', 'uid-2'],
        'memberIds': ['uid-1', 'uid-2', 'uid-3'],
        'status': 'active',
        'currency': 'USD',
        'createdAt': Timestamp.fromDate(DateTime.utc(2025, 1, 1)),
      });

      final updated = EventModel(
        id: 'evt-1',
        title: 'New Title',
        creatorId: 'uid-1',
        description: 'New desc',
        displayType: 'project', // must NOT be written
        startDate: DateTime.utc(2026, 6, 1),
        endDate: DateTime.utc(2026, 6, 3),
        adminIds: ['hacker'], // must NOT be written
        memberIds: ['hacker'], // must NOT be written
        status: EventStatus.archived,
        currency: 'EUR', // must NOT be written
      );

      final ok = await repo.updateEvent(updated);
      expect(ok, isTrue);

      final data = (await firestore.collection('events').doc('evt-1').get())
          .data()!;
      expect(data['title'], 'New Title');
      expect(data['description'], 'New desc');
      expect(data['eventType'], 'trip');
      expect(
        (data['startDate'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 6, 1),
      );
      expect(
        (data['endDate'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 6, 3),
      );
      expect(data['status'], 'archived');

      // Immutables preserved.
      expect(data['adminIds'], ['uid-1', 'uid-2']);
      expect(data['memberIds'], ['uid-1', 'uid-2', 'uid-3']);
      expect(data['creatorId'], 'uid-1');
      expect(data['currency'], 'USD');
    });

    test('returns false when the document does not exist', () async {
      const event = EventModel(id: 'missing', title: 'X', creatorId: 'uid-1');
      final ok = await repo.updateEvent(event);
      expect(ok, isFalse);
    });
  });

  group('watchEventsForUser', () {
    test(
      'mirrors Firestore docs into Drift and emits matching EventModels',
      () async {
        // Seed Firestore with two events the user is a member of.
        await firestore.collection('events').doc('evt-1').set({
          'title': 'Tahoe',
          'creatorId': 'uid-1',
          'description': 'Snow weekend',
          'eventType': 'trip',
          'adminIds': ['uid-1'],
          'memberIds': ['uid-1', 'uid-2'],
          'status': 'active',
          'currency': 'USD',
        });
        await firestore.collection('events').doc('evt-2').set({
          'title': 'Project sync',
          'creatorId': 'uid-2',
          'eventType': 'project',
          'adminIds': ['uid-2'],
          'memberIds': ['uid-1', 'uid-2'],
          'status': 'active',
          'currency': 'USD',
        });
        // And one event the user is NOT in — must not be mirrored.
        await firestore.collection('events').doc('evt-other').set({
          'title': 'Not me',
          'creatorId': 'uid-3',
          'memberIds': ['uid-3'],
          'status': 'active',
        });

        final stream = repo.watchEventsForUser('uid-1');
        final emission = await stream.firstWhere(
          (events) => events.length == 2,
        );

        final titles = emission.map((e) => e.title).toSet();
        expect(titles, equals({'Tahoe', 'Project sync'}));

        final tahoe = emission.firstWhere((e) => e.id == 'evt-1');
        expect(tahoe.creatorId, 'uid-1');
        expect(tahoe.description, 'Snow weekend');
        expect(tahoe.displayType, 'trip');
        expect(tahoe.templateId, 'blank');
        expect(tahoe.adminIds, ['uid-1']);
        expect(tahoe.memberIds, ['uid-1', 'uid-2']);
        expect(tahoe.status, EventStatus.active);
        expect(tahoe.currency, 'USD');
      },
    );

    test(
      'removes Drift rows when their Firestore documents are deleted',
      () async {
        await firestore.collection('events').doc('evt-1').set({
          'title': 'Tahoe',
          'creatorId': 'uid-1',
          'memberIds': ['uid-1'],
          'status': 'active',
        });

        final stream = repo.watchEventsForUser('uid-1');
        await stream.firstWhere((events) => events.length == 1);

        // Delete the Firestore doc; the listener should propagate.
        await firestore.collection('events').doc('evt-1').delete();

        final afterDelete = await stream.firstWhere((events) => events.isEmpty);
        expect(afterDelete, isEmpty);
      },
    );

    test(
      'returned stream emits an updated list when a new event is added',
      () async {
        final stream = repo.watchEventsForUser('uid-1');
        final initial = await stream.first;
        expect(initial, isEmpty);

        await firestore.collection('events').doc('evt-new').set({
          'title': 'Just added',
          'creatorId': 'uid-1',
          'memberIds': ['uid-1'],
          'status': 'active',
        });

        final next = await stream.firstWhere((events) => events.isNotEmpty);
        expect(next.first.title, 'Just added');
      },
    );
  });

  group('lifecycle', () {
    test(
      'disposeMirror cancels the listener so re-watching starts fresh',
      () async {
        await firestore.collection('events').doc('evt-1').set({
          'title': 'Tahoe',
          'creatorId': 'uid-1',
          'memberIds': ['uid-1'],
          'status': 'active',
        });

        // First mirror.
        final firstStream = repo.watchEventsForUser('uid-1');
        await firstStream.firstWhere((e) => e.length == 1);

        // Tear down the listener; second call must be a no-op.
        repo.disposeMirror('uid-1');
        repo.disposeMirror('uid-1'); // idempotent — must not throw

        // Re-watching should re-establish the listener and re-emit.
        final secondStream = repo.watchEventsForUser('uid-1');
        final reEmission = await secondStream.firstWhere((e) => e.length == 1);
        expect(reEmission.first.title, 'Tahoe');
      },
    );
  });

  group('configuration (Req 18, 21)', () {
    late EventRepository configRepo;

    setUp(() {
      configRepo = EventRepository(
        eventsDao: EventsDao(db),
        firestore: firestore,
        createEventCall: fakeCreateEventCall(firestore),
      );
    });

    const venue = EventVenue(id: 'v', name: 'Garland Hall', address: '1 Main');

    Future<void> seed() => firestore.doc('events/evt').set({
      'title': 'Tahoe',
      'creatorId': 'owner',
      'eventType': 'trip',
      'memberIds': ['owner'],
      'adminIds': ['owner'],
      'currency': 'USD',
    });

    test('saves what settings edits, and nothing else', () async {
      await seed();
      final result = await configRepo.saveConfiguration(
        const EventModel(
          id: 'evt',
          title: 'NOT WRITTEN',
          creatorId: 'owner',
          currency: 'EUR',
          timeZone: 'America/Chicago',
          venues: [venue],
          languages: ['en', 'gu'],
          capacity: 500,
          memberLimit: 100,
        ),
      );
      expect(result, EventWriteResult.saved);
      final data = (await firestore.doc('events/evt').get()).data()!;
      expect(data['title'], 'Tahoe');
      expect(data['currency'], 'USD');
      expect(data['timeZone'], 'America/Chicago');
      expect(data['venues'], [venue.toMap()]);
      expect(data['languages'], ['en', 'gu']);
      expect(data['capacity'], 500);
      expect(data['memberLimit'], 100);
    });

    test('a missing event reports a failure', () async {
      final result = await configRepo.saveConfiguration(
        const EventModel(id: 'nope', title: 'T', creatorId: 'owner'),
      );
      expect(result, EventWriteResult.failed);
    });

    test('a write that cannot finish offline reports pending', () async {
      final result = await settleEventWrite(
        Completer<void>().future,
        wait: Duration.zero,
      );
      expect(result, EventWriteResult.pending);
    });

    test('an event from before these fields reads with defaults', () async {
      await seed();
      final events = await configRepo
          .watchEventsForUser('owner')
          .firstWhere((list) => list.isNotEmpty);
      final event = events.single;
      expect(event.templateId, 'blank');
      expect(event.displayType, 'trip');
      expect(event.organizerId, isNull);
      expect(event.timeZone, 'UTC');
      expect(event.languages, ['en']);
      expect(event.modules['tasks'], isTrue);
      configRepo.disposeMirror('owner');
    });

    test('configuration survives the Drift mirror', () async {
      await firestore.doc('events/evt').set({
        'title': 'Hall',
        'creatorId': 'owner',
        'organizerId': 'owner',
        'templateId': 'blank',
        'memberIds': ['owner'],
        'timeZone': 'America/Chicago',
        'venues': [venue.toMap()],
        'languages': ['gu'],
        'modules': {'tasks': false},
        'labels': {'group': 'Team'},
        'settings': {'urgentRatePerHour': 3},
        'capacity': 500,
        'memberLimit': 100,
      });
      final events = await configRepo
          .watchEventsForUser('owner')
          .firstWhere((list) => list.isNotEmpty);
      final event = events.single;
      expect(event.displayType, isNull);
      expect(event.organizerId, 'owner');
      expect(event.timeZone, 'America/Chicago');
      expect(event.venues, [venue]);
      expect(event.languages, ['gu']);
      expect(event.modules, {'tasks': false});
      expect(event.labels, {'group': 'Team'});
      expect(event.settings, {'urgentRatePerHour': 3});
      expect(event.capacity, 500);
      expect(event.memberLimit, 100);
      configRepo.disposeMirror('owner');
    });
  });
}
