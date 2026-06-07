import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event_mute.dart';

void main() {
  group('EventMute.isMutedAt', () {
    test('returns false when mutedUntil is in the past', () {
      final mute = EventMute(mutedUntil: DateTime.utc(2026, 5, 1));

      expect(mute.isMutedAt(DateTime.utc(2026, 5, 2)), isFalse);
    });

    test('returns true when mutedUntil is in the future', () {
      final mute = EventMute(mutedUntil: DateTime.utc(2026, 6, 1));

      expect(mute.isMutedAt(DateTime.utc(2026, 5, 30)), isTrue);
    });

    test('the mutedUntil boundary counts as still-muted (inclusive)', () {
      // Server-side enforcement uses the same boundary; pinning here so
      // a future tweak forces a deliberate decision.
      final mute = EventMute(mutedUntil: DateTime.utc(2026, 5, 1, 12));

      expect(mute.isMutedAt(DateTime.utc(2026, 5, 1, 12)), isTrue);
    });
  });

  group('EventMute.fromMap / toMap round-trip', () {
    test('reads an ISO-8601 mutedUntil string', () {
      final mute = EventMute.fromMap({
        'mutedUntil': '2026-05-01T12:00:00.000Z',
      });

      expect(mute, isNotNull);
      expect(mute!.mutedUntil, DateTime.utc(2026, 5, 1, 12));
    });

    test('reads a Firestore Timestamp-like map {seconds, nanoseconds}', () {
      // Firestore Timestamp serialises this way through the SDK; we
      // accept both shapes so the model can be hydrated from either a
      // raw map or a stamped doc.
      final epoch = DateTime.utc(2026, 5, 1).millisecondsSinceEpoch;
      final mute = EventMute.fromMap({
        'mutedUntil': {'seconds': epoch ~/ 1000, 'nanoseconds': 0},
      });

      expect(mute, isNotNull);
      expect(mute!.mutedUntil, DateTime.utc(2026, 5, 1));
    });

    test('returns null when mutedUntil is missing / wrong type', () {
      expect(EventMute.fromMap(const {}), isNull);
      expect(EventMute.fromMap(const {'mutedUntil': true}), isNull);
      expect(EventMute.fromMap(null), isNull);
    });

    test('toMap stores mutedUntil as ISO-8601 UTC string', () {
      // Plain string is cheaper to read than Firestore.Timestamp on the
      // CF side (no SDK-specific wrapper); the recipient lookup only
      // ever needs `Date.parse(...)`.
      final mute = EventMute(mutedUntil: DateTime.utc(2026, 5, 1, 12));

      expect(mute.toMap()['mutedUntil'], '2026-05-01T12:00:00.000Z');
    });
  });

  group('EventMute.forDuration', () {
    test('produces a mute that lasts the given Duration from "now"', () {
      final now = DateTime.utc(2026, 5, 1, 9);
      final mute = EventMute.forDuration(const Duration(hours: 1), now: now);

      expect(mute.mutedUntil, DateTime.utc(2026, 5, 1, 10));
    });
  });
}
