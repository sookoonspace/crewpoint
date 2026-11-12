import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// My membership of one event: its ID, and my roles and permissions there.
typedef Membership = ({
  String eventId,
  List<String> roleIds,
  Set<String> perms,
});

/// Streams [uid]'s memberships across events. Production reads member
/// documents with a collection-group query. Injected so tests can change
/// memberships live, which the fake Firestore cannot do for that query.
typedef MembershipsSource = Stream<List<Membership>> Function(String uid);

/// Calls the `createEvent` Cloud Function. Injected so tests never reach it.
/// Calls `createEvent`. [savedTemplateId] names one of the caller's own
/// saved templates (Req 65) instead of the event's system template.
typedef CreateEventCall =
    Future<void> Function(EventModel event, {String? savedTemplateId});

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
    DateTime Function() now = DateTime.now,
    MembershipsSource? memberships,
  }) : _now = now,
       _membershipsOverride = memberships,
       _eventsDao = eventsDao,
       _firestore = firestore,
       _createEventCall = createEventCall;

  final EventsDao _eventsDao;
  final FirebaseFirestore _firestore;
  final CreateEventCall _createEventCall;
  final DateTime Function() _now;
  final MembershipsSource? _membershipsOverride;
  final Map<String, StreamSubscription<List<EventModel>>> _firestoreSubs = {};

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('events');

  /// "My events" (Req 25): my member documents across every event.
  Stream<List<Membership>> _myMemberships(String uid) =>
      _membershipsOverride?.call(uid) ??
      _firestore
          .collectionGroup('members')
          .where('uid', isEqualTo: uid)
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs)
                if (doc.reference.parent.parent?.id case final eventId?)
                  (
                    eventId: eventId,
                    roleIds: _parseStringList(doc.data()['roleIds']),
                    perms: _parseStringList(doc.data()['permissions']).toSet(),
                  ),
            ],
          );

  /// Events [uid] has a member document in, each carrying their roles and
  /// permissions. Reads every event document on its own, since rules check
  /// each one. Emits once every listed event has loaded or failed, and again
  /// on any change, including a role change.
  Stream<List<EventModel>> _myEvents(String uid) {
    late final StreamController<List<EventModel>> controller;
    StreamSubscription<List<Membership>>? membershipSub;
    final eventSubs =
        <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    final access = <String, ({List<String> roleIds, Set<String> perms})>{};
    final events = <String, EventModel?>{};
    var listed = false;

    void emit() {
      if (!listed || controller.isClosed) return;
      if (access.keys.any((id) => !events.containsKey(id))) return;
      controller.add([
        for (final MapEntry(key: id, value: mine) in access.entries)
          if (events[id] case final event?)
            event.copyWithAccess(
              viewerId: uid,
              roleIds: mine.roleIds,
              permissions: mine.perms,
            ),
      ]);
    }

    void watchEvent(String id) {
      eventSubs[id] = _eventsRef
          .doc(id)
          .snapshots()
          .listen(
            (doc) {
              final data = doc.data();
              events[id] = data == null ? null : _fromFirestore(doc.id, data);
              emit();
            },
            onError: (Object e, StackTrace st) {
              log(
                'Event $id unreadable',
                error: e,
                stackTrace: st,
                name: 'events',
              );
              events[id] = null;
              emit();
            },
          );
    }

    controller = StreamController<List<EventModel>>(
      onListen: () {
        membershipSub = _myMemberships(uid).listen(
          (memberships) {
            final ids = <String>{};
            for (final m in memberships) {
              ids.add(m.eventId);
              access[m.eventId] = (roleIds: m.roleIds, perms: m.perms);
              if (!eventSubs.containsKey(m.eventId)) watchEvent(m.eventId);
            }
            for (final gone in access.keys.toSet().difference(ids)) {
              access.remove(gone);
              events.remove(gone);
              eventSubs.remove(gone)?.cancel();
            }
            listed = true;
            emit();
          },
          onError: (Object e, StackTrace st) {
            log('Memberships failed', error: e, stackTrace: st, name: 'events');
            controller.addError(e, st);
          },
        );
      },
      onCancel: () async {
        await membershipSub?.cancel();
        for (final sub in eventSubs.values) {
          await sub.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// Creates the event through the `createEvent` callable, which makes the
  /// caller its Owner. Throws on failure — the caller is responsible for
  /// surfacing the error to the UI. Safe to retry with the same event ID.
  Future<void> createEvent(EventModel event, {String? savedTemplateId}) =>
      _createEventCall(event, savedTemplateId: savedTemplateId);

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
      final data = existing.data()!;
      final currentStatus = EventStatus.fromStored(
        data['status'] as String?,
        (data['endDate'] as Timestamp?)?.toDate(),
        _now(),
      );
      await docRef.update({
        'title': updated.title,
        'description': updated.description,
        'startDate': updated.startDate != null
            ? Timestamp.fromDate(updated.startDate!)
            : null,
        'endDate': updated.endDate != null
            ? Timestamp.fromDate(updated.endDate!)
            : null,
        'dateOnly': updated.dateOnly,
        if (updated.status != currentStatus) ..._statusChange(updated.status),
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
  ///
  /// Pass [previousStatus] when the status may have changed. An archived event
  /// allows only a restore, so nothing else is written then.
  ///
  /// [attendancePolicy] goes into `settings.attendancePolicy` (Req 50),
  /// leaving the event's other settings as they are.
  Future<EventWriteResult> saveConfiguration(
    EventModel updated, {
    EventStatus? previousStatus,
    AttendancePolicy? attendancePolicy,
  }) => settleEventWrite(
    _eventsRef.doc(updated.id).update({
      if (previousStatus != EventStatus.archived) ...{
        'timeZone': updated.timeZone,
        'venues': updated.venues.map((v) => v.toMap()).toList(),
        'languages': updated.languages,
        'labels': updated.labels,
        'modules': updated.modules,
        'capacity': updated.capacity,
        'memberLimit': updated.memberLimit,
        'settings.attendancePolicy': ?attendancePolicy?.name,
      },
      if (previousStatus != null && previousStatus != updated.status)
        ..._statusChange(updated.status),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  /// Changes status by hand. Times that have already passed then no longer
  /// move the event automatically.
  Future<EventWriteResult> setStatus(String eventId, EventStatus status) =>
      settleEventWrite(
        _eventsRef.doc(eventId).update({
          ..._statusChange(status),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );

  Map<String, Object> _statusChange(EventStatus status) => {
    'status': status.name,
    'statusSetAt': FieldValue.serverTimestamp(),
  };

  /// Streams the events the user is a member of. Starts/reuses a Firestore
  /// listener that mirrors snapshots into Drift on mobile/desktop; returns
  /// a Drift-backed stream on those platforms. On web, returns the
  /// Firestore snapshot stream directly.
  Stream<List<EventModel>> watchEventsForUser(String uid) {
    if (kIsWeb) return _myEvents(uid);
    _ensureFirestoreMirror(uid);
    return _eventsDao.watchAllEvents().map(
      (rows) => rows.map(_toDomain).toList(),
    );
  }

  void _ensureFirestoreMirror(String uid) {
    if (_firestoreSubs.containsKey(uid)) return;
    _firestoreSubs[uid] = _myEvents(uid).listen(
      (events) {
        _mirrorEvents(events).catchError((Object e, StackTrace st) {
          log('Mirror failed', error: e, stackTrace: st, name: 'events');
        });
      },
      onError: (Object e, StackTrace st) {
        log('Firestore stream error', error: e, stackTrace: st, name: 'events');
      },
    );
  }

  Future<void> _mirrorEvents(List<EventModel> events) async {
    final remoteIds = <String>{};
    for (final event in events) {
      remoteIds.add(event.id);
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
        memberCount: Value(event.memberCount),
        dateOnly: Value(event.dateOnly),
        viewerId: Value(event.viewerId),
        myRoleIds: Value(
          event.myRoleIds == null ? null : jsonEncode(event.myRoleIds),
        ),
        myPermissions: Value(
          event.myPermissions == null
              ? null
              : jsonEncode(event.myPermissions!.toList()),
        ),
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
    memberCount: (data['memberCount'] as num?)?.toInt(),
    dateOnly: data['dateOnly'] == true,
    creatorId: (data['creatorId'] as String?) ?? '',
    startDate: (data['startDate'] as Timestamp?)?.toDate(),
    endDate: (data['endDate'] as Timestamp?)?.toDate(),
    adminIds: _parseStringList(data['adminIds']),
    memberIds: _parseStringList(data['memberIds']),
    status: EventStatus.fromStored(
      data['status'] as String?,
      (data['endDate'] as Timestamp?)?.toDate(),
      _now(),
    ),
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
    memberCount: row.memberCount,
    dateOnly: row.dateOnly,
    creatorId: row.creatorId,
    startDate: row.startDate,
    endDate: row.endDate,
    adminIds: _decodeJsonStringList(row.adminIds),
    memberIds: _decodeJsonStringList(row.memberIds),
    status: EventStatus.fromStored(row.status, row.endDate, _now()),
    currency: row.currency,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    viewerId: row.viewerId,
    myRoleIds: row.myRoleIds == null
        ? null
        : _decodeJsonStringList(row.myRoleIds!),
    myPermissions: row.myPermissions == null
        ? null
        : _decodeJsonStringList(row.myPermissions!).toSet(),
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
