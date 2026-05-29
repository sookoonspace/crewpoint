import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:crewpoint_app/app/core/database/app_database.dart'
    as db
    show ChatMessage;
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show ChatMessagesCompanion;
import 'package:crewpoint_app/app/core/database/daos/chat_messages_dao.dart';
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
    int maxCachedRows = 200,
  }) : _chatService = chatService,
       _chatMessagesDao = chatMessagesDao,
       _firestore = firestore,
       _chatReadsDao = chatReadsDao,
       _maxCachedRows = maxCachedRows;

  final IChatService _chatService;
  final ChatMessagesDao? _chatMessagesDao;
  final FirebaseFirestore? _firestore;
  final ChatReadsDao? _chatReadsDao;
  final int _maxCachedRows;
  final Map<String, StreamSubscription<List<ChatMessage>>> _firestoreSubs = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _readsSubs = {};

  @override
  Stream<List<ChatMessageModel>> watchMessages(String eventId) {
    final dao = _chatMessagesDao;
    if (dao == null) {
      // No Drift cache — fall back to live-only Firestore (legacy path).
      return _chatService
          .messagesForEvent(eventId)
          .map(
            (messages) => messages.map((m) => _toDomain(eventId, m)).toList(),
          );
    }

    _ensureFirestoreMirror(eventId, dao);
    return dao
        .watchByEventId(eventId)
        .map((rows) => rows.map(_rowToDomain).toList());
  }

  void _ensureFirestoreMirror(String eventId, ChatMessagesDao dao) {
    if (_firestoreSubs.containsKey(eventId)) return;
    _firestoreSubs[eventId] = _chatService
        .messagesForEvent(eventId)
        .listen(
          (messages) async {
            try {
              for (final m in messages) {
                await dao.insertOrReplace(
                  ChatMessagesCompanion(
                    id: Value(m.id),
                    eventId: Value(eventId),
                    senderId: Value(m.senderId),
                    content: Value(m.text),
                    isHighPriority: Value(m.isHighPriority),
                    timestamp: Value(m.timestamp),
                  ),
                );
              }
              await dao.evictOldestIfNeeded(eventId, _maxCachedRows);
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

  /// Streams the user's last-read timestamp for an event. Composes
  /// the Drift cache (instant emission on cold start) with the Firestore
  /// snapshot stream (live updates).
  ///
  /// First subscription per (uid, eventId) pair spins up a Firestore
  /// snapshot listener that mirrors values into Drift; subsequent
  /// subscriptions reuse the existing mirror. Cancelled by `dispose`.
  Stream<DateTime?> watchLastRead(String uid, String eventId) {
    final dao = _chatReadsDao;
    final fs = _firestore;
    if (dao == null) {
      // No Drift cache — read straight from Firestore.
      if (fs == null) return Stream.value(null);
      return _readDocRef(uid, eventId).snapshots().map(_extractLastReadAt);
    }

    _ensureChatReadsMirror(uid, eventId, dao);
    return dao.watchLastReadAt(eventId: eventId, uid: uid);
  }

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
            await dao.upsert(eventId: eventId, uid: uid, lastReadAt: ts);
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
  Future<void> markEventRead(String uid, String eventId) async {
    final ts = DateTime.now();
    try {
      await _readDocRef(uid, eventId).set({
        'lastReadAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _chatReadsDao?.upsert(eventId: eventId, uid: uid, lastReadAt: ts);
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

  @override
  Future<bool> postSettlementNotice({
    required String eventId,
    required String messageId,
    required String senderId,
    required String text,
  }) async {
    try {
      await _chatService.postSettlementNotice(
        eventId: eventId,
        messageId: messageId,
        senderId: senderId,
        text: text,
      );
      return true;
    } catch (e, st) {
      log(
        'Failed to post settlement notice',
        error: e,
        stackTrace: st,
        name: 'chat',
      );
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
  );

  ChatMessageModel _rowToDomain(db.ChatMessage row) => ChatMessageModel(
    id: row.id,
    eventId: row.eventId,
    senderId: row.senderId,
    text: row.content,
    timestamp: row.timestamp,
    isHighPriority: row.isHighPriority,
  );
}
