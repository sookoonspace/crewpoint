import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';

/// What the roster lists: everyone, one group, or (for someone who may see
/// only their own) the viewer's groups. [search] matches the start of a name.
class RosterQuery {
  const RosterQuery({this.search = '', this.groupId, this.groupIds});

  final String search;
  final String? groupId;

  /// The viewer's own groups, for a linked adult without `participants.read`.
  /// Firestore takes at most 30 in one query.
  final List<String>? groupIds;

  @override
  bool operator ==(Object other) =>
      other is RosterQuery &&
      other.search == search &&
      other.groupId == groupId &&
      _sameList(other.groupIds, groupIds);

  @override
  int get hashCode =>
      Object.hash(search, groupId, Object.hashAll(groupIds ?? const []));

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
      return ParticipantPrivate(birthDate: data['birthDate'] as String?);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Creates or updates [person], and [privateDetails] when given, together.
  Future<void> save(
    ParticipantModel person, {
    ParticipantPrivate? privateDetails,
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
}
