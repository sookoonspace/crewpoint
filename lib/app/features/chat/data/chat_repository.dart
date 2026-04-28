import 'dart:async';
import 'dart:developer';

import 'package:drift/drift.dart' show Value;
import 'package:crewpoint_app/app/core/database/app_database.dart'
    as db
    show ChatMessage;
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show ChatMessagesCompanion;
import 'package:crewpoint_app/app/core/database/daos/chat_messages_dao.dart';
import 'package:crewpoint_app/app/core/services/i_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/domain/repositories/i_chat_repository.dart';

/// Repository wrapping IChatService with a Drift cache. Firestore is the
/// source of truth; Drift mirrors the most recent [maxCachedRows] per event
/// so cold starts render instantly and short offline windows still show
/// recent history.
class ChatRepository implements IChatRepository {
  ChatRepository({
    required IChatService chatService,
    ChatMessagesDao? chatMessagesDao,
    int maxCachedRows = 200,
  }) : _chatService = chatService,
       _chatMessagesDao = chatMessagesDao,
       _maxCachedRows = maxCachedRows;

  final IChatService _chatService;
  final ChatMessagesDao? _chatMessagesDao;
  final int _maxCachedRows;
  final Map<String, StreamSubscription<List<ChatMessage>>> _firestoreSubs = {};

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
