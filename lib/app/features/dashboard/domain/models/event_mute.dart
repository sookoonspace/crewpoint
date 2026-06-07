/// Per-user, per-event push-notification mute. Persisted at
/// `users/{uid}/private/eventMutes/{eventId}` with a single field —
/// [mutedUntil] — as an ISO-8601 UTC string.
///
/// `sendCategorizedPush` looks this doc up per recipient and skips the
/// push when [isMutedAt] returns true, with one exception: a
/// `chat_urgent` push from a sender the recipient has opted into
/// (`criticalOptIn=true`) bypasses the mute (Phase 5 semantics).
class EventMute {
  const EventMute({required this.mutedUntil});

  final DateTime mutedUntil;

  /// Convenience constructor — mute for [duration] starting at [now]
  /// (defaults to `DateTime.now().toUtc()`).
  factory EventMute.forDuration(Duration duration, {DateTime? now}) {
    final base = (now ?? DateTime.now()).toUtc();
    return EventMute(mutedUntil: base.add(duration));
  }

  /// Returns true while [at] is at or before [mutedUntil] (inclusive
  /// boundary — server-side enforcement uses the same semantics).
  bool isMutedAt(DateTime at) => !at.isAfter(mutedUntil);

  /// Reads the Firestore subdoc shape. Accepts either an ISO-8601 string
  /// (the canonical write shape — `toMap` produces this) or a
  /// `{seconds, nanoseconds}` map (Firestore Timestamp SDK shape).
  /// Returns null when the field is missing or wrong-typed so callers
  /// can treat "no mute" as the absence of an [EventMute] rather than a
  /// half-populated one.
  static EventMute? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final raw = map['mutedUntil'];
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;
      return EventMute(mutedUntil: parsed.toUtc());
    }
    if (raw is Map<String, dynamic>) {
      final seconds = raw['seconds'];
      if (seconds is int) {
        final nanos = raw['nanoseconds'];
        final nanosPart = (nanos is int ? nanos : 0) ~/ 1000;
        return EventMute(
          mutedUntil: DateTime.fromMicrosecondsSinceEpoch(
            seconds * 1000000 + nanosPart,
            isUtc: true,
          ),
        );
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'mutedUntil': mutedUntil.toUtc().toIso8601String(),
  };
}
