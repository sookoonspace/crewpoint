import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// The key unanswered fields and people with no category count under.
const noAnswer = '_none';

/// How many people, by category and by each choice or yes/no field.
@immutable
class CountTally {
  const CountTally({
    this.total = 0,
    this.byCategory = const {},
    this.byField = const {},
  });

  factory CountTally.fromMap(Object? raw) {
    if (raw is! Map) return const CountTally();
    Map<String, int> counts(Object? m) => {
      if (m is Map)
        for (final e in m.entries)
          if (e.key is String && e.value is num)
            e.key as String: (e.value as num).toInt(),
    };
    final fields = raw['byField'];
    return CountTally(
      total: (raw['total'] as num?)?.toInt() ?? 0,
      byCategory: counts(raw['byCategory']),
      byField: {
        if (fields is Map)
          for (final e in fields.entries)
            if (e.key is String) e.key as String: counts(e.value),
      },
    );
  }

  final int total;
  final Map<String, int> byCategory;
  final Map<String, Map<String, int>> byField;

  /// A field's counts, largest first, with unanswered last.
  List<MapEntry<String, int>> sorted(String fieldId) =>
      _sorted(byField[fieldId]);

  List<MapEntry<String, int>> get categoriesSorted => _sorted(byCategory);

  static List<MapEntry<String, int>> _sorted(Map<String, int>? counts) =>
      (counts?.entries.toList() ?? [])..sort((a, b) {
        if (a.key == noAnswer) return 1;
        if (b.key == noAnswer) return -1;
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
}

/// `events/{id}/stats/current` (Req 52): counts for the event and each
/// session, worked out on the server, with when they were last updated.
@immutable
class EventStats {
  const EventStats({
    this.updatedAt,
    this.event = const CountTally(),
    this.groups = 0,
    this.sessions = const {},
  });

  factory EventStats.fromFirestore(Map<String, dynamic> data) {
    final event = data['event'];
    final sessions = data['sessions'];
    final updated = data['updatedAt'];
    return EventStats(
      updatedAt: updated is Timestamp ? updated.toDate().toUtc() : null,
      event: CountTally.fromMap(event),
      groups: event is Map ? (event['groups'] as num?)?.toInt() ?? 0 : 0,
      sessions: {
        if (sessions is Map)
          for (final e in sessions.entries)
            if (e.key is String) e.key as String: CountTally.fromMap(e.value),
      },
    );
  }

  final DateTime? updatedAt;
  final CountTally event;

  /// Groups with anyone still attending.
  final int groups;
  final Map<String, CountTally> sessions;
}
