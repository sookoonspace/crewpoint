import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crewpoint_app/app/core/database/app_database.dart'
    as db
    show ChatMessage;
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show ChatMessagesCompanion;
import 'package:crewpoint_app/app/core/database/daos/chat_messages_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/mirror_syncs_dao.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_summary.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_window.dart';
import 'package:crewpoint_app/app/core/database/daos/chat_reads_dao.dart';
import 'package:crewpoint_app/app/core/services/i_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/domain/repositories/i_chat_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Repository wrapping IChatService with a Drift cache. Firestore is the
/// source of truth; Drift mirrors the most recent [maxCachedRows] per event
/// so cold starts render instantly and short offline windows still show
/// recent history.
class ChatRepository implements IChatRepository {
  ChatRepository({
    required IChatService chatService,
    ChatMessagesDao? chatMessagesDao,
    FirebaseFirestore? firestore,
    ChatReadsDao? chatReadsDao,
    MirrorSyncsDao? syncs,
    int maxCachedRows = 200,
  }) : _syncs = syncs,
       _chatService = chatService,
       _chatMessagesDao = chatMessagesDao,
       _firestore = firestore,
       _chatReadsDao = chatReadsDao,
       _maxCachedRows = maxCachedRows;

  final IChatService _chatService;
  final MirrorSyncsDao? _syncs;

  /// The key under which this mirror records when it last synced (Req 74).
  static String mirrorKey(String eventId) => 'chat/$eventId';
  final ChatMessagesDao? _chatMessagesDao;
  final FirebaseFirestore? _firestore;
  final ChatReadsDao? _chatReadsDao;
  final int _maxCachedRows;
  final Map<String, StreamSubscription<ChatChanges>> _firestoreSubs = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _readsSubs = {};

  @override
  Stream<List<ChatMessageModel>> watchMessages(String eventId) {
    final dao = _chatMessagesDao;
    // Web has no Drift persistence (Wasm is in-memory), so the latest
    // messages are kept in memory from the same change sets.
    if (kIsWeb || dao == null) {
      final byId = <String, ChatMessage>{};
      return _chatService.latestMessages(eventId).map((changes) {
        if (changes.window != null) byId.clear();
        for (final m in changes.upserts) {
          byId[m.id] = m;
        }
        changes.deleted.forEach(byId.remove);
        return [
          for (final m
              in byId.values.toList()
                ..sort((a, b) => a.timestamp.compareTo(b.timestamp)))
            _toDomain(eventId, m),
        ];
      });
    }

    _ensureFirestoreMirror(eventId, dao);
    return dao
        .watchByEventId(eventId)
        .map((rows) => rows.map(_rowToDomain).toList());
  }

  /// Older messages before [before], newest first, read from the server
  /// each time and not kept on the device (Req 57).
  Future<List<ChatMessageModel>> fetchOlder(
    String eventId, {
    required DateTime before,
  }) async => [
    for (final m in await _chatService.olderMessages(eventId, before: before))
      _toDomain(eventId, m),
  ];

  ChatMessagesCompanion _toRow(String eventId, ChatMessage m) =>
      ChatMessagesCompanion(
        id: Value(m.id),
        eventId: Value(eventId),
        senderId: Value(m.senderId),
        content: Value(m.text),
        isHighPriority: Value(m.isHighPriority),
        urgentPushSkipped: Value(m.urgentPushSkipped),
        timestamp: Value(m.timestamp),
        kind: Value(m.kind),
      );

  /// Applies each change set to Drift in one transaction (Req 57): only
  /// what changed, with deletions removed (Req 58). The first window from
  /// the server also clears messages deleted while the app was closed. The
  /// device keeps at most [_maxCachedRows], trimmed when the mirror starts.
  void _ensureFirestoreMirror(String eventId, ChatMessagesDao dao) {
    if (_firestoreSubs.containsKey(eventId)) return;
    unawaited(
      dao.evictOldestIfNeeded(eventId, _maxCachedRows).catchError((
        Object e,
        StackTrace st,
      ) {
        log('Trim failed', error: e, stackTrace: st, name: 'chat');
      }),
    );
    var confirmed = false;
    _firestoreSubs[eventId] = _chatService
        .latestMessages(eventId)
        .listen(
          (changes) async {
            try {
              final deleted = [...changes.deleted];
              final window = changes.window;
              if (!confirmed && !changes.fromCache && window != null) {
                // The first server window: anything it should hold but
                // does not was deleted while away.
                final cached = [
                  for (final r in await dao.byEventId(eventId))
                    ChatMessage(
                      id: r.id,
                      eventId: eventId,
                      senderId: r.senderId,
                      text: r.content,
                      timestamp: r.timestamp,
                    ),
                ];
                deleted.addAll(
                  staleInCache(
                    cached: cached,
                    window: window,
                    limit: chatPageSize,
                  ),
                );
                confirmed = true;
              }
              await dao.applyChanges([
                for (final m in changes.upserts) _toRow(eventId, m),
              ], deleted);
              await _syncs?.record(
                mirrorKey(eventId),
                fromCache: changes.fromCache,
              );
            } catch (e, st) {
              log('Mirror failed', error: e, stackTrace: st, name: 'chat');
            }
          },
          onError: (Object e, StackTrace st) {
            log(
              'Firestore stream error',
              error: e,
              stackTrace: st,
              name: 'chat',
            );
          },
        );
  }

  void disposeMirror(String eventId) {
    _firestoreSubs.remove(eventId)?.cancel();
  }

  Future<void> dispose() async {
    for (final sub in _firestoreSubs.values) {
      await sub.cancel();
    }
    _firestoreSubs.clear();
    for (final sub in _readsSubs.values) {
      await sub.cancel();
    }
    _readsSubs.clear();
  }

  // ===== Read-state tracking =====

  DocumentReference<Map<String, dynamic>> _readDocRef(
    String uid,
    String eventId,
  ) {
    final fs = _firestore;
    if (fs == null) {
      throw StateError(
        'ChatRepository: firestore is null; cannot access chat reads',
      );
    }
    return fs.collection('users').doc(uid).collection('chatReads').doc(eventId);
  }

  /// Where the user has read up to in an event's chat: the time and the
  /// message count then (Req 57a). The Drift cache answers first on cold
  /// start, and a Firestore listener keeps it current.
  Stream<ChatReadState?> watchReadState(String uid, String eventId) {
    final dao = _chatReadsDao;
    final fs = _firestore;
    if (dao == null) {
      if (fs == null) return Stream.value(null);
      return _readDocRef(uid, eventId).snapshots().map((snap) {
        final at = _extractLastReadAt(snap);
        return at == null && !snap.exists
            ? null
            : ChatReadState(lastReadAt: at, readCount: _readCount(snap));
      });
    }
    _ensureChatReadsMirror(uid, eventId, dao);
    return dao
        .watchReadState(eventId: eventId, uid: uid)
        .map(
          (r) => r == null
              ? null
              : ChatReadState(lastReadAt: r.lastReadAt, readCount: r.readCount),
        );
  }

  int? _readCount(DocumentSnapshot<Map<String, dynamic>> snap) =>
      (snap.data()?['readCount'] as num?)?.toInt();

  void _ensureChatReadsMirror(String uid, String eventId, ChatReadsDao dao) {
    final fs = _firestore;
    if (fs == null) return;
    final key = '$uid/$eventId';
    if (_readsSubs.containsKey(key)) return;
    _readsSubs[key] = _readDocRef(uid, eventId).snapshots().listen(
      (snap) async {
        try {
          final ts = _extractLastReadAt(snap);
          if (ts != null) {
            await dao.upsert(
              eventId: eventId,
              uid: uid,
              lastReadAt: ts,
              readCount: _readCount(snap),
            );
          }
        } catch (e, st) {
          log(
            'Chat reads mirror failed',
            error: e,
            stackTrace: st,
            name: 'chat.reads',
            level: 900,
          );
        }
      },
      onError: (Object e, StackTrace st) {
        log(
          'Chat reads stream error',
          error: e,
          stackTrace: st,
          name: 'chat.reads',
          level: 900,
        );
      },
    );
  }

  DateTime? _extractLastReadAt(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return null;
    final raw = snap.data()?['lastReadAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  /// Idempotent first-launch backfill: for each event the user belongs
  /// to, writes a `lastReadAt = now()` doc IF (and only if) one does not
  /// already exist. Keeps existing users from drowning in "everything
  /// looks unread" after the read-tracking feature ships.
  Future<void> backfillReadStateForExistingEvents(
    String uid,
    List<EventModel> events,
  ) async {
    final fs = _firestore;
    if (fs == null) return;
    for (final event in events) {
      try {
        final ref = _readDocRef(uid, event.id);
        final snap = await ref.get();
        if (snap.exists) continue;
        final ts = DateTime.now();
        await ref.set({'lastReadAt': ts});
        await _chatReadsDao?.upsert(
          eventId: event.id,
          uid: uid,
          lastReadAt: ts,
        );
      } catch (e, st) {
        log(
          'Backfill failed for event ${event.id}',
          error: e,
          stackTrace: st,
          name: 'chat.reads',
          level: 900,
        );
      }
    }
  }

  /// Writes `users/{uid}/chatReads/{eventId}` with `lastReadAt = serverTimestamp`
  /// and mirrors the value into Drift. Fire-and-forget: a Firestore-write
  /// failure is swallowed + logged so navigation isn't blocked.
  ///
  /// [count] is the chat summary's message count, so the inbox can count
  /// what arrives after (Req 57a).
  Future<void> markEventRead(String uid, String eventId, {int? count}) async {
    final ts = DateTime.now();
    try {
      await _readDocRef(uid, eventId).set({
        'lastReadAt': FieldValue.serverTimestamp(),
        'readCount': ?count,
      }, SetOptions(merge: true));
      await _chatReadsDao?.upsert(
        eventId: eventId,
        uid: uid,
        lastReadAt: ts,
        readCount: count,
      );
    } catch (e, st) {
      log(
        'Failed to mark event read',
        error: e,
        stackTrace: st,
        name: 'chat.reads',
        level: 900,
      );
    }
  }

  @override
  Future<bool> sendMessage({
    required String eventId,
    required String senderId,
    required String text,
    bool isHighPriority = false,
  }) async {
    try {
      await _chatService.sendMessage(
        eventId: eventId,
        senderId: senderId,
        text: text,
        isHighPriority: isHighPriority,
      );
      return true;
    } catch (e, st) {
      log('Failed to send message', error: e, stackTrace: st, name: 'chat');
      return false;
    }
  }

  ChatMessageModel _toDomain(String eventId, ChatMessage m) => ChatMessageModel(
    id: m.id,
    eventId: eventId,
    senderId: m.senderId,
    text: m.text,
    timestamp: m.timestamp,
    isHighPriority: m.isHighPriority,
    kind: ChatMessageKind.fromString(m.kind),
    urgentPushSkipped: m.urgentPushSkipped,
  );

  ChatMessageModel _rowToDomain(db.ChatMessage row) => ChatMessageModel(
    id: row.id,
    eventId: row.eventId,
    senderId: row.senderId,
    text: row.content,
    timestamp: row.timestamp,
    isHighPriority: row.isHighPriority,
    kind: ChatMessageKind.fromString(row.kind),
    urgentPushSkipped: row.urgentPushSkipped,
  );
}
