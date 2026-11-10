import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/link_request.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';

/// What the roster lists: everyone, one group, or (for someone who may see
/// only their own) the viewer's groups. [search] matches the start of a name.
class RosterQuery {
  const RosterQuery({
    this.search = '',
    this.groupId,
    this.groupIds,
    this.categoryId,
    this.tag,
  });

  final String search;
  final String? groupId;

  /// Only one category (Req 43).
  final String? categoryId;

  /// Only people with this answer, a `filterTag` such as `diet=Jain`.
  final String? tag;

  /// The viewer's own groups, for a linked adult without `participants.read`.
  /// Firestore takes at most 30 in one query.
  final List<String>? groupIds;

  @override
  bool operator ==(Object other) =>
      other is RosterQuery &&
      other.search == search &&
      other.groupId == groupId &&
      other.categoryId == categoryId &&
      other.tag == tag &&
      _sameList(other.groupIds, groupIds);

  @override
  int get hashCode => Object.hash(
    search,
    groupId,
    categoryId,
    tag,
    Object.hashAll(groupIds ?? const []),
  );

  static bool _sameList(List<String>? a, List<String>? b) {
    if (a == null || b == null) return a == b;
    return a.length == b.length &&
        [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);
  }
}

/// One page of the roster, and where the next starts.
class RosterPage {
  const RosterPage({required this.items, required this.hasMore, this.cursor});

  final List<ParticipantModel> items;
  final bool hasMore;

  /// The last document read, where the next page starts. Firestore breaks
  /// ties between equal names by document ID, so no one is skipped.
  final Object? cursor;
}

/// Participants and groups, read online and a page at a time (Req 43, 74).
/// Rosters are never mirrored into Drift, for size and privacy.
class ParticipantRepository {
  ParticipantRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  static const pageSize = 50;

  DocumentReference<Map<String, dynamic>> _event(String eventId) =>
      _firestore.collection('events').doc(eventId);

  CollectionReference<Map<String, dynamic>> _people(String eventId) =>
      _event(eventId).collection('participants');

  DocumentReference<Map<String, dynamic>> _private(String eventId, String id) =>
      _people(eventId).doc(id).collection('private').doc('details');

  Query<Map<String, dynamic>> _query(String eventId, RosterQuery q) {
    Query<Map<String, dynamic>> query = _people(eventId);
    if (q.groupIds != null) {
      query = query.where('groupId', whereIn: q.groupIds);
    } else if (q.groupId != null) {
      query = query.where('groupId', isEqualTo: q.groupId);
    }
    if (q.categoryId != null) {
      query = query.where('categoryId', isEqualTo: q.categoryId);
    }
    if (q.tag != null) query = query.where('filterTags', arrayContains: q.tag);
    final search = q.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      query = query
          .where('sortName', isGreaterThanOrEqualTo: search)
          .where('sortName', isLessThan: '$search');
    }
    return query.orderBy('sortName');
  }

  /// The page after [after], or the first page.
  Future<RosterPage> fetchPage(
    String eventId,
    RosterQuery q, {
    RosterPage? after,
  }) async {
    if (q.groupIds != null && q.groupIds!.isEmpty) {
      return const RosterPage(items: [], hasMore: false);
    }
    var query = _query(eventId, q);
    if (after?.cursor case final DocumentSnapshot<Map<String, dynamic>> last) {
      query = query.startAfterDocument(last);
    }
    final snap = await query.limit(pageSize + 1).get();
    final docs = snap.docs.take(pageSize).toList();
    return RosterPage(
      items: [
        for (final doc in docs)
          ParticipantModel.fromFirestore(eventId, doc.id, doc.data()),
      ],
      hasMore: snap.docs.length > pageSize,
      cursor: docs.lastOrNull,
    );
  }

  Stream<ParticipantModel?> watch(String eventId, String id) =>
      _people(eventId).doc(id).snapshots().map((doc) {
        final data = doc.data();
        return data == null
            ? null
            : ParticipantModel.fromFirestore(eventId, doc.id, data);
      });

  /// Null when there are none, or the viewer may not read them.
  Future<ParticipantPrivate?> readPrivate(String eventId, String id) async {
    try {
      final doc = await _private(eventId, id).get();
      final data = doc.data();
      if (data == null) return null;
      return ParticipantPrivate.fromFirestore(data);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Creates or updates [person], and [privateDetails] when given, together.
  /// [definitions] are the event's fields, to work out the filter tags from
  /// standard answers.
  Future<void> save(
    ParticipantModel person, {
    ParticipantPrivate? privateDetails,
    List<CustomField> definitions = const [],
  }) async {
    final ref = _people(person.eventId).doc(person.id);
    final existing = await ref.get();
    final batch = _firestore.batch();
    final fields = <String, Object?>{
      'name': person.name.trim(),
      'sortName': person.sortName,
      'groupId': person.groupId,
      'isChild': person.isChild,
      'status': person.status,
      'categoryId': person.categoryId,
      'fields': person.fields,
      'filterTags': filterTagsFor([
        for (final f in definitions)
          if (f.scope == FieldScope.participant) f,
      ], person.fields),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (existing.exists) {
      batch.update(ref, fields);
    } else {
      batch.set(ref, {
        ...fields,
        'createdBy': person.createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (privateDetails != null) {
      batch.set(_private(person.eventId, person.id), {
        'birthDate': privateDetails.birthDate,
        // Kept from what was read, because linking an account reads it
        // (Req 46).
        'email': ?privateDetails.email,
        'fields': privateDetails.fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> delete(String eventId, String id) async {
    final batch = _firestore.batch()
      ..delete(_private(eventId, id))
      ..delete(_people(eventId).doc(id));
    await batch.commit();
  }

  /// How many people are attending, for capacity (Req 18b). Cancelled people
  /// are left out.
  Future<int> count(String eventId) async {
    final snap = await _people(
      eventId,
    ).where('status', isEqualTo: 'active').count().get();
    return snap.count ?? 0;
  }

  CollectionReference<Map<String, dynamic>> _fields(String eventId) =>
      _event(eventId).collection('fields');

  /// The event's custom fields, in order (Req 41).
  Stream<List<CustomField>> watchFields(String eventId) =>
      _fields(eventId).snapshots().map(
        (snap) =>
            [
              for (final doc in snap.docs)
                CustomField.fromFirestore(doc.id, doc.data()),
            ]..sort(
              (a, b) => a.order != b.order
                  ? a.order.compareTo(b.order)
                  : a.label.compareTo(b.label),
            ),
      );

  Future<void> saveField(String eventId, CustomField field) => _fields(eventId)
      .doc(field.id)
      .set({...field.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> deleteField(String eventId, String fieldId) =>
      _fields(eventId).doc(fieldId).delete();

  /// The event's categories, in `settings.categories`, keeping other settings.
  Future<void> saveCategories(String eventId, List<EventCategory> categories) =>
      _event(eventId).update({
        'settings.categories': [for (final c in categories) c.toMap()],
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// A group's answers: standard ones with filter tags on the group, and
  /// private ones in its private document.
  Future<void> saveGroupAnswers(
    String eventId,
    String groupId, {
    required Map<String, Object?> standard,
    Map<String, Object?>? private,
    List<CustomField> definitions = const [],
  }) async {
    final ref = _event(eventId).collection('groups').doc(groupId);
    final batch = _firestore.batch()
      ..update(ref, {
        'fields': standard,
        'filterTags': filterTagsFor([
          for (final f in definitions)
            if (f.scope == FieldScope.group) f,
        ], standard),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    if (private != null) {
      batch.set(ref.collection('private').doc('details'), {
        'fields': private,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// A group's private answers, or null when the viewer may not read them.
  Future<Map<String, Object?>?> readGroupPrivate(
    String eventId,
    String groupId,
  ) async {
    try {
      final doc = await _event(eventId)
          .collection('groups')
          .doc(groupId)
          .collection('private')
          .doc('details')
          .get();
      final data = doc.data();
      return data == null
          ? const {}
          : ParticipantPrivate.fromFirestore(data).fields;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Groups whose name starts with [search], for a picker.
  Future<List<GroupModel>> searchGroups(
    String eventId,
    String search, {
    int limit = 30,
  }) async {
    final q = search.trim().toLowerCase();
    Query<Map<String, dynamic>> query = _event(eventId).collection('groups');
    if (q.isNotEmpty) {
      query = query
          .where('sortName', isGreaterThanOrEqualTo: q)
          .where('sortName', isLessThan: '$q');
    }
    final snap = await query.orderBy('sortName').limit(limit).get();
    return [
      for (final doc in snap.docs) GroupModel.fromFirestore(doc.id, doc.data()),
    ];
  }

  /// Groups by ID, in chunks of 30 as Firestore requires. Missing ones, and
  /// ones the viewer may not read, are left out.
  Future<Map<String, GroupModel>> groupsByIds(
    String eventId,
    List<String> ids,
  ) async {
    final unique = ids.toSet().toList();
    final result = <String, GroupModel>{};
    for (var i = 0; i < unique.length; i += 30) {
      final chunk = unique.sublist(i, (i + 30).clamp(0, unique.length));
      final snap = await _event(
        eventId,
      ).collection('groups').where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        result[doc.id] = GroupModel.fromFirestore(doc.id, doc.data());
      }
    }
    return result;
  }

  /// People by ID, in chunks of 30. Missing ones, and ones the viewer may not
  /// read, are left out.
  Future<Map<String, ParticipantModel>> participantsByIds(
    String eventId,
    List<String> ids,
  ) async {
    final unique = ids.toSet().toList();
    final result = <String, ParticipantModel>{};
    for (var i = 0; i < unique.length; i += 30) {
      final chunk = unique.sublist(i, (i + 30).clamp(0, unique.length));
      final snap = await _people(
        eventId,
      ).where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        result[doc.id] = ParticipantModel.fromFirestore(
          eventId,
          doc.id,
          doc.data(),
        );
      }
    }
    return result;
  }

  /// Accounts waiting for an organizer to link them (Req 46), oldest first.
  Stream<List<LinkRequest>> watchLinkRequests(String eventId) => _event(eventId)
      .collection('linkRequests')
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map(
        (snap) => [
          for (final doc in snap.docs)
            LinkRequest.fromFirestore(doc.id, doc.data()),
        ]..sort((a, b) => (a.name ?? a.email).compareTo(b.name ?? b.email)),
      );
}
