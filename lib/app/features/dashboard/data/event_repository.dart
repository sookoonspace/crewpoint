import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Calls the `createEvent` Cloud Function. Injected so tests never reach it.
typedef CreateEventCall = Future<void> Function(EventModel event);

/// Calls the `changeEventCurrency` Cloud Function. Injected so tests never
/// reach it.
typedef ChangeEventCurrencyCall =
    Future<void> Function(String eventId, String currency);

/// What happened to a write, which Firestore holds offline until it can send.
enum EventWriteResult {
  saved,

  /// Queued on this device, and sent when the connection returns.
  pending,
  failed,
}

/// Waits a bounded time for [write], because a queued write never completes
/// while offline. The write carries on after the wait ends.
Future<EventWriteResult> settleEventWrite(
  Future<void> write, {
  Duration wait = const Duration(seconds: 8),
}) async {
  try {
    await write.timeout(wait);
    return EventWriteResult.saved;
  } on TimeoutException {
    return EventWriteResult.pending;
  } catch (e, st) {
    log('Event write failed', error: e, stackTrace: st, name: 'events');
    return EventWriteResult.failed;
  }
}

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
    required CreateEventCall createEventCall,
  }) : _eventsDao = eventsDao,
       _firestore = firestore,
       _createEventCall = createEventCall;

  final EventsDao _eventsDao;
  final FirebaseFirestore _firestore;
  final CreateEventCall _createEventCall;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _firestoreSubs = {};

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('events');

  Query<Map<String, dynamic>> _userEventsQuery(String uid) =>
      _eventsRef.where('memberIds', arrayContains: uid);

  /// Creates the event through the `createEvent` callable, which makes the
  /// caller its Owner. Throws on failure — the caller is responsible for
  /// surfacing the error to the UI. Safe to retry with the same event ID.
  Future<void> createEvent(EventModel event) => _createEventCall(event);

  /// Updates the client-editable fields on `events/{id}`.
  ///
  /// Editable: `title`, `description`, `startDate`, `endDate`, `status`. NOT
  /// writable here (server-gatekept or data-integrity locked): `currency`,
  /// `memberIds`, `adminIds`, `creatorId`, `organizerId`, `templateId`,
  /// `createdAt`.
  ///
  /// Returns `false` on caught failure (log + bool), matching the rest of
  /// the app's mutation pattern. `createEvent` retains its throw signature
  /// for backward compatibility.
  Future<bool> updateEvent(EventModel updated) async {
    try {
      final docRef = _eventsRef.doc(updated.id);
      final existing = await docRef.get();
      if (!existing.exists) return false;
      await docRef.update({
        'title': updated.title,
        'description': updated.description,
        'startDate': updated.startDate != null
            ? Timestamp.fromDate(updated.startDate!)
            : null,
        'endDate': updated.endDate != null
            ? Timestamp.fromDate(updated.endDate!)
            : null,
        'status': updated.status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e, st) {
      log('updateEvent failed', error: e, stackTrace: st, name: 'events');
      return false;
    }
  }

  /// Saves what the settings screen edits. Currency goes through
  /// `changeEventCurrency` instead, because it can be refused.
  Future<EventWriteResult> saveConfiguration(EventModel updated) =>
      settleEventWrite(
        _eventsRef.doc(updated.id).update({
          'timeZone': updated.timeZone,
          'venues': updated.venues.map((v) => v.toMap()).toList(),
          'languages': updated.languages,
          'capacity': updated.capacity,
          'memberLimit': updated.memberLimit,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );

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
        eventType: Value(event.displayType ?? ''),
        startDate: Value(event.startDate),
        endDate: Value(event.endDate),
        adminIds: Value(jsonEncode(event.adminIds)),
        memberIds: Value(jsonEncode(event.memberIds)),
        status: Value(event.status.name),
        currency: Value(event.currency),
        templateId: Value(event.templateId),
        organizerId: Value(event.organizerId),
        timeZone: Value(event.timeZone),
        venues: Value(jsonEncode(event.venues.map((v) => v.toMap()).toList())),
        languages: Value(jsonEncode(event.languages)),
        modules: Value(jsonEncode(event.modules)),
        labels: Value(jsonEncode(event.labels)),
        settings: Value(jsonEncode(event.settings)),
        capacity: Value(event.capacity),
        memberLimit: Value(event.memberLimit),
        createdAt: event.createdAt != null
            ? Value(event.createdAt!)
            : const Value.absent(),
        updatedAt: event.updatedAt != null
            ? Value(event.updatedAt!)
            : const Value.absent(),
      ),
    );
  }

  EventModel _fromFirestore(String id, Map<String, dynamic> data) => EventModel(
    id: id,
    title: (data['title'] as String?) ?? '',
    description: data['description'] as String?,
    templateId: (data['templateId'] as String?) ?? EventModel.defaultTemplateId,
    displayType: data['eventType'] as String?,
    organizerId: data['organizerId'] as String?,
    timeZone: (data['timeZone'] as String?) ?? EventModel.defaultTimeZone,
    venues: _parseVenues(data['venues']),
    languages: data['languages'] is List
        ? _parseStringList(data['languages'])
        : EventModel.defaultLanguages,
    modules: _parseModules(data['modules']),
    labels: _parseMap(data['labels']),
    settings: _parseMap(data['settings']),
    capacity: (data['capacity'] as num?)?.toInt(),
    memberLimit: (data['memberLimit'] as num?)?.toInt(),
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
    templateId: row.templateId,
    displayType: row.eventType.isEmpty ? null : row.eventType,
    organizerId: row.organizerId,
    timeZone: row.timeZone,
    venues: _parseVenues(_decodeJson(row.venues)),
    languages: _decodeJsonStringList(row.languages),
    modules: _parseModules(_decodeJson(row.modules)),
    labels: _parseMap(_decodeJson(row.labels)),
    settings: _parseMap(_decodeJson(row.settings)),
    capacity: row.capacity,
    memberLimit: row.memberLimit,
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

  Object? _decodeJson(String json) {
    try {
      return jsonDecode(json);
    } catch (_) {
      return null;
    }
  }

  List<EventVenue> _parseVenues(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((v) => EventVenue.fromMap(v.cast<String, dynamic>()))
        .toList();
  }

  Map<String, bool> _parseModules(Object? raw) {
    if (raw is! Map) return EventModel.defaultModules;
    return {
      for (final entry in raw.entries)
        if (entry.value is bool) entry.key.toString(): entry.value as bool,
    };
  }

  Map<String, dynamic> _parseMap(Object? raw) =>
      raw is Map ? raw.cast<String, dynamic>() : const {};

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
