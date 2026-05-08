import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late EventRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    repo = EventRepository(eventsDao: EventsDao(db), firestore: firestore);
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  group('createEvent', () {
    test(
      'writes one document at events/{id} with the expected fields',
      () async {
        const event = EventModel(
          id: 'evt-1',
          title: 'Trip to Tahoe',
          creatorId: 'uid-creator',
          description: 'Snow weekend',
          eventType: EventType.trip,
          adminIds: ['uid-creator'],
          memberIds: ['uid-creator'],
          currency: 'USD',
        );

        await repo.createEvent(event);

        final snap = await firestore.collection('events').get();
        expect(snap.docs, hasLength(1));
        final data = snap.docs.first.data();
        expect(snap.docs.first.id, 'evt-1');
        expect(data['title'], 'Trip to Tahoe');
        expect(data['creatorId'], 'uid-creator');
        expect(data['description'], 'Snow weekend');
        expect(data['eventType'], 'trip');
        expect(data['adminIds'], ['uid-creator']);
        expect(data['memberIds'], ['uid-creator']);
        expect(data['status'], 'active');
        expect(data['currency'], 'USD');
      },
    );

    test('serializes startDate/endDate as Firestore Timestamps', () async {
      final event = EventModel(
        id: 'evt-2',
        title: 'Conference',
        creatorId: 'uid-1',
        startDate: DateTime.utc(2026, 6, 1),
        endDate: DateTime.utc(2026, 6, 3),
      );

      await repo.createEvent(event);

      final data = (await firestore.collection('events').doc('evt-2').get())
          .data()!;
      expect(data['startDate'], isA<Timestamp>());
      expect(data['endDate'], isA<Timestamp>());
      expect(
        (data['startDate'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 6, 1),
      );
    });

    // The "throws on Firestore write failure" contract is exercised by the
    // CreateEventScreen widget tests, which override `eventRepositoryProvider`
    // with a fake whose `createEvent` throws. Unit-mocking `FirebaseFirestore`
    // here would mean implementing sealed SDK types — too brittle.
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
        expect(tahoe.eventType, EventType.trip);
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
}
