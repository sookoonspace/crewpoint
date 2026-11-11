import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Who a session is for (Req 48): age bands (category IDs, Req 42) and
/// standard field answers (filter tags such as `program=Ladies`, Req 41).
/// Empty means everyone. When both are named, someone needs one of each.
@immutable
class SessionEligibility {
  const SessionEligibility({
    this.categoryIds = const [],
    this.filterTags = const [],
  });

  factory SessionEligibility.fromMap(Object? raw) {
    if (raw is! Map) return const SessionEligibility();
    List<String> strings(Object? list) => [
      if (list is List)
        for (final v in list)
          if (v is String) v,
    ];
    return SessionEligibility(
      categoryIds: strings(raw['categoryIds']),
      filterTags: strings(raw['filterTags']),
    );
  }

  final List<String> categoryIds;
  final List<String> filterTags;

  bool get isEveryone => categoryIds.isEmpty && filterTags.isEmpty;

  /// Whether someone in [categoryId] with [tags] may attend.
  bool admits({String? categoryId, Iterable<String> tags = const []}) =>
      (categoryIds.isEmpty || categoryIds.contains(categoryId)) &&
      (filterTags.isEmpty || tags.any(filterTags.contains));

  Map<String, Object> toMap() => {
    'categoryIds': categoryIds,
    'filterTags': filterTags,
  };

  @override
  bool operator ==(Object other) =>
      other is SessionEligibility &&
      listEquals(other.categoryIds, categoryIds) &&
      listEquals(other.filterTags, filterTags);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(categoryIds), Object.hashAll(filterTags));
}

/// One entry on an event's schedule (Req 48), in
/// `events/{eventId}/sessions/{sessionId}`. Times are UTC instants, shown in
/// the event's zone. A hidden session is a draft only `schedule.edit` sees.
@immutable
class SessionModel {
  const SessionModel({
    required this.id,
    required this.title,
    required this.startAt,
    this.endAt,
    this.timeTbc = false,
    this.venueId,
    this.locationTba = false,
    this.type,
    this.tags = const [],
    this.capacity,
    this.eligibility = const SessionEligibility(),
    this.hidden = false,
  });

  factory SessionModel.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? time(Object? raw) =>
        raw is Timestamp ? raw.toDate().toUtc() : null;
    String? text(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;
    final capacity = data['capacity'];
    return SessionModel(
      id: id,
      title: data['title'] is String ? data['title'] as String : '',
      startAt: time(data['startAt']) ?? DateTime.utc(1970),
      endAt: time(data['endAt']),
      timeTbc: data['timeTbc'] == true,
      venueId: text(data['venueId']),
      locationTba: data['locationTba'] == true,
      type: text(data['type']),
      tags: [
        if (data['tags'] case final List<dynamic> tags)
          for (final t in tags)
            if (t is String) t,
      ],
      capacity: capacity is num ? capacity.toInt() : null,
      eligibility: SessionEligibility.fromMap(data['eligibility']),
      hidden: data['hidden'] == true,
    );
  }

  final String id;
  final String title;
  final DateTime startAt;
  final DateTime? endAt;

  /// A placeholder time, shown as "to be confirmed" (Req 48).
  final bool timeTbc;
  final String? venueId;

  /// The location is to be announced (Req 49).
  final bool locationTba;

  /// Free text, such as Program or Ceremony, suggested from types in use.
  final String? type;
  final List<String> tags;
  final int? capacity;
  final SessionEligibility eligibility;
  final bool hidden;

  /// The document as written, with blanks stored as null.
  Map<String, Object?> toFirestore({required String updatedBy}) {
    String? blankToNull(String? s) =>
        s == null || s.trim().isEmpty ? null : s.trim();
    return {
      'title': title.trim(),
      'startAt': Timestamp.fromDate(startAt),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt!),
      'timeTbc': timeTbc,
      'venueId': blankToNull(venueId),
      'locationTba': locationTba,
      'type': blankToNull(type),
      'tags': tags,
      'capacity': capacity,
      'eligibility': eligibility.toMap(),
      'hidden': hidden,
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is SessionModel &&
      other.id == id &&
      other.title == title &&
      other.startAt == startAt &&
      other.endAt == endAt &&
      other.timeTbc == timeTbc &&
      other.venueId == venueId &&
      other.locationTba == locationTba &&
      other.type == type &&
      listEquals(other.tags, tags) &&
      other.capacity == capacity &&
      other.eligibility == eligibility &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    startAt,
    endAt,
    timeTbc,
    venueId,
    locationTba,
    type,
    Object.hashAll(tags),
    capacity,
    eligibility,
    hidden,
  );
}
