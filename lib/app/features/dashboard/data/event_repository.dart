import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Firestore-Write / Drift-Read repository for events.
///
/// - Writes go to Firestore. Firestore SDK offline persistence handles
///   write-queuing and replays on reconnect.
/// - A per-uid Firestore listener mirrors snapshots into Drift on
///   mobile/desktop. The UI reads from Drift for fast, un-evicted local
///   access.
/// - On web there is no Drift persistence (Wasm is in-memory), so
///   `watchEventsForUser` returns the raw Firestore stream directly.
class EventRepository {
  EventRepository({
    required EventsDao eventsDao,
    required FirebaseFirestore firestore,
  }) : _eventsDao = eventsDao,
       _firestore = firestore;

  final EventsDao _eventsDao;
  final FirebaseFirestore _firestore;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _firestoreSubs = {};

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('events');

  Query<Map<String, dynamic>> _userEventsQuery(String uid) =>
      _eventsRef.where('memberIds', arrayContains: uid);

  /// Writes the event document to Firestore at `events/{id}` with server
  /// timestamps for `createdAt` / `updatedAt`. Throws on failure — the
  /// caller is responsible for surfacing the error to the UI.
  Future<void> createEvent(EventModel event) async {
    await _eventsRef.doc(event.id).set(_toFirestore(event));
  }

  /// Streams the events the user is a member of. Starts/reuses a Firestore
  /// listener that mirrors snapshots into Drift on mobile/desktop; returns
  /// a Drift-backed stream on those platforms. On web, returns the
  /// Firestore snapshot stream directly.
  Stream<List<EventModel>> watchEventsForUser(String uid) {
    if (kIsWeb) {
      return _userEventsQuery(uid).snapshots().map(
        (snap) =>
            snap.docs.map((doc) => _fromFirestore(doc.id, doc.data())).toList(),
      );
    }
    _ensureFirestoreMirror(uid);
    return _eventsDao.watchAllEvents().map(
      (rows) => rows.map(_toDomain).toList(),
    );
  }

  void _ensureFirestoreMirror(String uid) {
    if (_firestoreSubs.containsKey(uid)) return;
    _firestoreSubs[uid] = _userEventsQuery(uid).snapshots().listen(
      (snap) {
        _mirrorSnapshot(snap).catchError((Object e, StackTrace st) {
          log('Mirror failed', error: e, stackTrace: st, name: 'events');
        });
      },
      onError: (Object e, StackTrace st) {
        log('Firestore stream error', error: e, stackTrace: st, name: 'events');
      },
    );
  }

  Future<void> _mirrorSnapshot(QuerySnapshot<Map<String, dynamic>> snap) async {
    final remoteIds = <String>{};
    for (final doc in snap.docs) {
      remoteIds.add(doc.id);
      final event = _fromFirestore(doc.id, doc.data());
      await _upsertDrift(event);
    }
    final localRows = await _eventsDao.allEvents();
    for (final row in localRows) {
      if (!remoteIds.contains(row.id)) {
        await _eventsDao.deleteEventById(row.id);
      }
    }
  }

  void disposeMirror(String uid) {
    _firestoreSubs.remove(uid)?.cancel();
  }

  Future<void> dispose() async {
    for (final sub in _firestoreSubs.values) {
      await sub.cancel();
    }
    _firestoreSubs.clear();
  }

  Future<void> _upsertDrift(EventModel event) async {
    await _eventsDao.insertOrReplace(
      EventsCompanion.insert(
        id: event.id,
        title: event.title,
        creatorId: event.creatorId,
        description: Value(event.description),
        eventType: Value(event.eventType.name),
        startDate: Value(event.startDate),
        endDate: Value(event.endDate),
        adminIds: Value(jsonEncode(event.adminIds)),
        memberIds: Value(jsonEncode(event.memberIds)),
        status: Value(event.status.name),
        currency: Value(event.currency),
        createdAt: event.createdAt != null
            ? Value(event.createdAt!)
            : const Value.absent(),
        updatedAt: event.updatedAt != null
            ? Value(event.updatedAt!)
            : const Value.absent(),
      ),
    );
  }

  Map<String, dynamic> _toFirestore(EventModel event) => {
    'id': event.id,
    'title': event.title,
    'description': event.description,
    'eventType': event.eventType.name,
    'creatorId': event.creatorId,
    'adminIds': event.adminIds,
    'memberIds': event.memberIds,
    'status': event.status.name,
    'currency': event.currency,
    'startDate': event.startDate != null
        ? Timestamp.fromDate(event.startDate!)
        : null,
    'endDate': event.endDate != null
        ? Timestamp.fromDate(event.endDate!)
        : null,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  EventModel _fromFirestore(String id, Map<String, dynamic> data) => EventModel(
    id: id,
    title: (data['title'] as String?) ?? '',
    description: data['description'] as String?,
    eventType: EventType.fromString(data['eventType'] as String?),
    creatorId: (data['creatorId'] as String?) ?? '',
    startDate: (data['startDate'] as Timestamp?)?.toDate(),
    endDate: (data['endDate'] as Timestamp?)?.toDate(),
    adminIds: _parseStringList(data['adminIds']),
    memberIds: _parseStringList(data['memberIds']),
    status: EventStatus.fromString(data['status'] as String?),
    currency: (data['currency'] as String?) ?? 'USD',
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
  );

  EventModel _toDomain(Event row) => EventModel(
    id: row.id,
    title: row.title,
    description: row.description,
    eventType: EventType.fromString(row.eventType),
    creatorId: row.creatorId,
    startDate: row.startDate,
    endDate: row.endDate,
    adminIds: _decodeJsonStringList(row.adminIds),
    memberIds: _decodeJsonStringList(row.memberIds),
    status: EventStatus.fromString(row.status),
    currency: row.currency,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  List<String> _parseStringList(Object? raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  List<String> _decodeJsonStringList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.cast<String>();
      return const [];
    } catch (_) {
      return const [];
    }
  }
}
