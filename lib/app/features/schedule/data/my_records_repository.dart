import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/mirror_syncs_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/my_records_dao.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show immutable, kIsWeb;

/// The viewer's own records in an event: their participant record, the
/// people in their groups, and those groups.
@immutable
class OwnRecords {
  const OwnRecords({this.people = const [], this.groups = const []});

  final List<ParticipantModel> people;
  final List<GroupModel> groups;

  /// Each group's invited session IDs, for attendance.
  Map<String, List<String>> get groupInvitations => {
    for (final g in groups) g.id: g.invitedTo,
  };
}

/// Reads and mirrors the viewer's own records (Req 51, 74). Only their own
/// record (`uid ==`) and their groups' people (`groupId in`, up to 30
/// groups) are read, as rules allow; rosters are never mirrored.
class MyRecordsRepository {
  MyRecordsRepository({
    required MyRecordsDao dao,
    required FirebaseFirestore firestore,
    MirrorSyncsDao? syncs,
  }) : _dao = dao,
       _firestore = firestore,
       _syncs = syncs;

  final MyRecordsDao _dao;
  final FirebaseFirestore _firestore;
  final MirrorSyncsDao? _syncs;
  final Map<String, List<StreamSubscription<Object?>>> _subs = {};
  final Map<String, String> _scopes = {};

  static String mirrorKey(String eventId) => 'agenda/$eventId';

  DocumentReference<Map<String, dynamic>> _event(String id) =>
      _firestore.collection('events').doc(id);

  /// The queries for each kind of record, keyed by the kind stored.
  Map<String, Query<Map<String, dynamic>>> _queries(
    String eventId,
    String uid,
    List<String> groupIds,
  ) {
    final groups = groupIds.take(30).toList();
    return {
      'self': _event(
        eventId,
      ).collection('participants').where('uid', isEqualTo: uid),
      if (groups.isNotEmpty) ...{
        'groupPeople': _event(
          eventId,
        ).collection('participants').where('groupId', whereIn: groups),
        'group': _event(
          eventId,
        ).collection('groups').where(FieldPath.documentId, whereIn: groups),
      },
    };
  }

  Stream<OwnRecords> watchMine(
    String eventId, {
    required String uid,
    required List<String> groupIds,
  }) {
    final queries = _queries(eventId, uid, groupIds);
    if (kIsWeb) return _combine(queries);
    _ensureMirror(eventId, '$uid|${groupIds.join(',')}', queries);
    return _dao.watchByEvent(eventId).map(_fromRows);
  }

  void _ensureMirror(
    String eventId,
    String scope,
    Map<String, Query<Map<String, dynamic>>> queries,
  ) {
    if (_subs.containsKey(eventId) && _scopes[eventId] == scope) return;
    disposeMirror(eventId);
    _scopes[eventId] = scope;
    // Kinds this scope no longer reads, such as a group left, are cleared.
    for (final kind in const ['self', 'groupPeople', 'group']) {
      if (!queries.containsKey(kind)) {
        unawaited(_dao.replace(eventId, kind, const []));
      }
    }
    _subs[eventId] = [
      for (final MapEntry(key: kind, value: query) in queries.entries)
        query
            .snapshots(includeMetadataChanges: true)
            .listen(
              (snap) async {
                try {
                  await _dao.replace(eventId, kind, [
                    for (final doc in snap.docs)
                      MyRecordsCompanion(
                        eventId: Value(eventId),
                        kind: Value(kind),
                        id: Value(doc.id),
                        data: Value(jsonEncode(_encode(doc.data()))),
                      ),
                  ]);
                  if (kind == 'self') {
                    await _syncs?.record(
                      mirrorKey(eventId),
                      fromCache: snap.metadata.isFromCache,
                    );
                  }
                } catch (e, st) {
                  log(
                    'Mirror failed',
                    error: e,
                    stackTrace: st,
                    name: 'agenda',
                  );
                }
              },
              onError: (Object e, StackTrace st) {
                log(
                  'Firestore stream error',
                  error: e,
                  stackTrace: st,
                  name: 'agenda',
                );
              },
            ),
    ];
  }

  void disposeMirror(String eventId) {
    for (final sub
        in _subs.remove(eventId) ?? const <StreamSubscription<Object?>>[]) {
      unawaited(sub.cancel());
    }
    _scopes.remove(eventId);
  }

  Future<void> dispose() async {
    for (final subs in _subs.values) {
      for (final sub in subs) {
        await sub.cancel();
      }
    }
    _subs.clear();
    _scopes.clear();
  }

  OwnRecords _fromRows(List<MyRecord> rows) {
    final people = <String, ParticipantModel>{};
    final groups = <GroupModel>[];
    for (final r in rows) {
      final data = _decode(jsonDecode(r.data)) as Map<String, dynamic>;
      if (r.kind == 'group') {
        groups.add(GroupModel.fromFirestore(r.id, data));
      } else {
        people[r.id] = ParticipantModel.fromFirestore(r.eventId, r.id, data);
      }
    }
    return OwnRecords(people: people.values.toList(), groups: groups);
  }

  /// Raw Firestore streams merged, for web, which has no mirror.
  Stream<OwnRecords> _combine(Map<String, Query<Map<String, dynamic>>> queries) {
    late final StreamController<OwnRecords> controller;
    final latest =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    final subs = <StreamSubscription<Object?>>[];
    void emit() {
      if (latest.length < queries.length) return;
      final people = <String, ParticipantModel>{};
      for (final kind in const ['self', 'groupPeople']) {
        for (final doc
            in latest[kind] ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
          people[doc.id] = ParticipantModel.fromFirestore(
            doc.reference.parent.parent!.id,
            doc.id,
            doc.data(),
          );
        }
      }
      controller.add(
        OwnRecords(
          people: people.values.toList(),
          groups: [
            for (final doc
                in latest['group'] ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
              GroupModel.fromFirestore(doc.id, doc.data()),
          ],
        ),
      );
    }

    controller = StreamController<OwnRecords>(
      onListen: () {
        for (final MapEntry(key: kind, value: query) in queries.entries) {
          subs.add(
            query.snapshots().listen((snap) {
              latest[kind] = snap.docs;
              emit();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return controller.stream;
  }
}

/// Timestamps become `{"__ts": millis}` so a document survives JSON.
Object? _encode(Object? value) => switch (value) {
  final Timestamp t => {'__ts': t.millisecondsSinceEpoch},
  final Map<String, dynamic> m => {
    for (final e in m.entries) e.key: _encode(e.value),
  },
  final List<dynamic> l => [for (final v in l) _encode(v)],
  _ => value,
};

Object? _decode(Object? value) => switch (value) {
  {'__ts': final int ms} => Timestamp.fromMillisecondsSinceEpoch(ms),
  final Map<String, dynamic> m => {
    for (final e in m.entries) e.key: _decode(e.value),
  },
  final List<dynamic> l => [for (final v in l) _decode(v)],
  _ => value,
};
