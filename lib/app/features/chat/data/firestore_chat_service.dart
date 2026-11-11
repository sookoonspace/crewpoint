import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_window.dart';
import 'package:crewpoint_app/app/core/services/i_chat_service.dart';

// TODO(phase2): Swap this implementation to support E2EE
// without breaking the UI layer. The IChatService interface
// remains the same; only the implementation changes.

/// Firestore implementation of [IChatService].
class FirestoreChatService implements IChatService {
  FirestoreChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messagesRef(String eventId) =>
      _firestore.collection('events').doc(eventId).collection('messages');

  @override
  Stream<ChatChanges> latestMessages(
    String eventId, {
    int limit = chatPageSize,
  }) {
    var first = true;
    var fromServer = false;
    return _messagesRef(eventId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          final window = [
            for (final doc in snap.docs)
              _fromFirestore(eventId, doc.id, doc.data()),
          ];
          final upserts = <ChatMessage>[];
          final removed = <ChatMessage>[];
          for (final change in snap.docChanges) {
            final m = _fromFirestore(
              eventId,
              change.doc.id,
              change.doc.data() ?? const {},
            );
            if (change.type == DocumentChangeType.removed) {
              removed.add(m);
            } else {
              upserts.add(m);
            }
          }
          final ChatChanges changes = (
            upserts: upserts,
            deleted: deletedFromWindow(
              removed: removed,
              window: window,
              limit: limit,
            ),
            // The whole window comes with the first snapshot, and again
            // with the first from the server.
            window: first || (!fromServer && !snap.metadata.isFromCache)
                ? window
                : null,
            fromCache: snap.metadata.isFromCache,
          );
          first = false;
          fromServer = fromServer || !snap.metadata.isFromCache;
          return changes;
        });
  }

  @override
  Future<List<ChatMessage>> olderMessages(
    String eventId, {
    required DateTime before,
    int limit = chatPageSize,
  }) async {
    final snap = await _messagesRef(eventId)
        .orderBy('timestamp', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();
    return [
      for (final doc in snap.docs) _fromFirestore(eventId, doc.id, doc.data()),
    ];
  }

  @override
  Future<void> sendMessage({
    required String eventId,
    required String senderId,
    required String text,
    bool isHighPriority = false,
  }) async {
    try {
      await _messagesRef(eventId).add({
        'senderId': senderId,
        'text': text,
        'isHighPriority': isHighPriority,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      log('Failed to send message', error: e, stackTrace: st, name: 'chat');
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage({
    required String eventId,
    required String messageId,
  }) async {
    try {
      await _messagesRef(eventId).doc(messageId).delete();
    } catch (e, st) {
      log('Failed to delete message', error: e, stackTrace: st, name: 'chat');
      rethrow;
    }
  }

  ChatMessage _fromFirestore(
    String eventId,
    String id,
    Map<String, dynamic> data,
  ) => ChatMessage(
    id: id,
    eventId: eventId,
    senderId: data['senderId'] as String? ?? '',
    text: data['text'] as String? ?? '',
    timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    isHighPriority: data['isHighPriority'] as bool? ?? false,
    kind: data['kind'] as String?,
    urgentPushSkipped: data['urgentPushSkipped'] as bool? ?? false,
  );
}
