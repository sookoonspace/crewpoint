import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/sessions_dao.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart'
    show EventWriteResult, settleEventWrite;
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;

/// An event's schedule (Req 48): Firestore is the source of truth, mirrored
/// into Drift per event. Someone without `schedule.edit` must list with
/// `hidden == false`, because rules refuse a query that could return a
/// hidden session.
class SessionRepository {
  SessionRepository({
    required SessionsDao dao,
    required FirebaseFirestore firestore,
  }) : _dao = dao,
       _firestore = firestore;

  final SessionsDao _dao;
  final FirebaseFirestore _firestore;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _subs = {};

  /// Whether each event's mirror includes hidden sessions.
  final Map<String, bool> _scopes = {};

  CollectionReference<Map<String, dynamic>> _ref(String eventId) =>
      _firestore.collection('events').doc(eventId).collection('sessions');

  Query<Map<String, dynamic>> _query(String eventId, bool withHidden) =>
      withHidden
      ? _ref(eventId)
      : _ref(eventId).where('hidden', isEqualTo: false);

  /// The event's sessions, unordered. [withHidden] for `schedule.edit`.
  Stream<List<SessionModel>> watchSessions(
    String eventId, {
    required bool withHidden,
  }) {
    // Drift on web is in-memory, so the mirror buys nothing there.
    if (kIsWeb) {
      return _query(eventId, withHidden).snapshots().map(
        (snap) => [
          for (final doc in snap.docs)
            SessionModel.fromFirestore(doc.id, doc.data()),
        ],
      );
    }
    _ensureMirror(eventId, withHidden);
    return _dao
        .watchByEvent(eventId, withHidden: withHidden)
        .map((rows) => [for (final r in rows) _fromRow(r)]);
  }

  /// Starts the mirror, or restarts it when the reader's access changed. A
  /// narrower mirror replaces the rows, dropping hidden ones.
  void _ensureMirror(String eventId, bool withHidden) {
    if (_subs.containsKey(eventId) && _scopes[eventId] == withHidden) return;
    _subs.remove(eventId)?.cancel();
    _scopes[eventId] = withHidden;
    _subs[eventId] = _query(eventId, withHidden).snapshots().listen(
      (snap) => _dao
          .replaceForEvent(eventId, [
            for (final doc in snap.docs)
              _toRow(eventId, SessionModel.fromFirestore(doc.id, doc.data())),
          ])
          .catchError((Object e, StackTrace st) {
            log('Mirror failed', error: e, stackTrace: st, name: 'sessions');
          }),
      onError: (Object e, StackTrace st) {
        log(
          'Firestore stream error',
          error: e,
          stackTrace: st,
          name: 'sessions',
        );
      },
    );
  }

  void disposeMirror(String eventId) {
    _subs.remove(eventId)?.cancel();
    _scopes.remove(eventId);
  }

  Future<void> dispose() async {
    for (final sub in _subs.values) {
      await sub.cancel();
    }
    _subs.clear();
    _scopes.clear();
  }

  /// Saves [session], creating it when its ID is empty. Returns the result
  /// and the session's ID. Offline the write is queued and reports pending.
  Future<(EventWriteResult, String)> save(
    String eventId,
    SessionModel session, {
    required String uid,
  }) async {
    final doc = session.id.isEmpty
        ? _ref(eventId).doc()
        : _ref(eventId).doc(session.id);
    final result = await settleEventWrite(
      doc.set(session.toFirestore(updatedBy: uid)),
    );
    return (result, doc.id);
  }

  Future<EventWriteResult> remove(String eventId, String sessionId) =>
      settleEventWrite(_ref(eventId).doc(sessionId).delete());

  SessionsCompanion _toRow(String eventId, SessionModel s) => SessionsCompanion(
    id: Value(s.id),
    eventId: Value(eventId),
    title: Value(s.title),
    startAt: Value(s.startAt),
    endAt: Value(s.endAt),
    timeTbc: Value(s.timeTbc),
    venueId: Value(s.venueId),
    locationTba: Value(s.locationTba),
    type: Value(s.type),
    tags: Value(jsonEncode(s.tags)),
    capacity: Value(s.capacity),
    eligibility: Value(jsonEncode(s.eligibility.toMap())),
    hidden: Value(s.hidden),
  );

  SessionModel _fromRow(Session r) {
    Object? decode(String raw) {
      try {
        return jsonDecode(raw);
      } on FormatException {
        return null;
      }
    }

    final tags = decode(r.tags);
    return SessionModel(
      id: r.id,
      title: r.title,
      startAt: r.startAt.toUtc(),
      endAt: r.endAt?.toUtc(),
      timeTbc: r.timeTbc,
      venueId: r.venueId,
      locationTba: r.locationTba,
      type: r.type,
      tags: [
        if (tags is List)
          for (final t in tags)
            if (t is String) t,
      ],
      capacity: r.capacity,
      eligibility: SessionEligibility.fromMap(decode(r.eligibility)),
      hidden: r.hidden,
    );
  }
}
