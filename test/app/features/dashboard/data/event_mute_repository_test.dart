import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_mute_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event_mute.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late EventMuteRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = EventMuteRepository(firestore: firestore);
  });

  // Path mirrors the existing chatReads convention
  // (`users/{uid}/chatReads/{eventId}`) — same shape, same per-user
  // ownership story for the rules tests.
  Future<Map<String, dynamic>?> readDoc(String uid, String eventId) async {
    final snap = await firestore
        .collection('users')
        .doc(uid)
        .collection('eventMutes')
        .doc(eventId)
        .get();
    return snap.exists ? snap.data() : null;
  }

  group('EventMuteRepository.muteEvent', () {
    test(
      'persists to users/{uid}/eventMutes/{eventId} as ISO-8601 string',
      () async {
        final until = DateTime.utc(2026, 6, 1, 12);

        await repo.muteEvent(uid: 'u1', eventId: 'evt-1', mutedUntil: until);

        final data = await readDoc('u1', 'evt-1');
        expect(data?['mutedUntil'], until.toIso8601String());
      },
    );

    test('overwrites a previous mute on the same (uid, eventId)', () async {
      await repo.muteEvent(
        uid: 'u1',
        eventId: 'evt-1',
        mutedUntil: DateTime.utc(2026, 5, 1),
      );
      await repo.muteEvent(
        uid: 'u1',
        eventId: 'evt-1',
        mutedUntil: DateTime.utc(2026, 6, 1),
      );

      final data = await readDoc('u1', 'evt-1');
      expect(data?['mutedUntil'], '2026-06-01T00:00:00.000Z');
    });
  });

  group('EventMuteRepository.unmuteEvent', () {
    test('deletes the (uid, eventId) doc', () async {
      await repo.muteEvent(
        uid: 'u1',
        eventId: 'evt-1',
        mutedUntil: DateTime.utc(2026, 6, 1),
      );

      await repo.unmuteEvent(uid: 'u1', eventId: 'evt-1');

      expect(await readDoc('u1', 'evt-1'), isNull);
    });

    test('no-op when the doc does not exist (no throw)', () async {
      await repo.unmuteEvent(uid: 'u1', eventId: 'evt-missing');
    });
  });

  group('EventMuteRepository.getEventMute', () {
    test('returns null when no mute is set', () async {
      final mute = await repo.getEventMute(uid: 'u1', eventId: 'evt-1');
      expect(mute, isNull);
    });

    test('returns an EventMute when one is set', () async {
      final until = DateTime.utc(2026, 6, 1, 12);
      await repo.muteEvent(uid: 'u1', eventId: 'evt-1', mutedUntil: until);

      final mute = await repo.getEventMute(uid: 'u1', eventId: 'evt-1');
      expect(mute, isNotNull);
      expect(mute!.mutedUntil, until);
    });
  });

  group('EventMuteRepository.watchEventMute', () {
    test('emits new state when the underlying doc changes', () async {
      final stream = repo.watchEventMute(uid: 'u1', eventId: 'evt-1');
      final emissions = <EventMute?>[];
      final sub = stream.listen(emissions.add);

      // Wait for the initial null emission.
      await Future<void>.delayed(Duration.zero);

      await repo.muteEvent(
        uid: 'u1',
        eventId: 'evt-1',
        mutedUntil: DateTime.utc(2026, 6, 1),
      );
      await Future<void>.delayed(Duration.zero);

      await repo.unmuteEvent(uid: 'u1', eventId: 'evt-1');
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();

      // Sequence: null (initial), mute set, mute cleared. Don't pin
      // exact emission count — fake_cloud_firestore may coalesce.
      final shapes = emissions
          .map((m) => m?.mutedUntil.toIso8601String() ?? 'null')
          .toList();
      expect(shapes, contains('null'));
      expect(shapes, contains('2026-06-01T00:00:00.000Z'));
      expect(shapes.last, 'null');
    });
  });
}
