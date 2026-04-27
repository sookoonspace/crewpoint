import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  Stream<List<ChatMessage>> messagesForEvent(String eventId) {
    return _messagesRef(eventId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromFirestore(doc.id, doc.data()))
              .toList(),
        );
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

  @override
  Future<void> postSettlementNotice({
    required String eventId,
    required String messageId,
    required String senderId,
    required String text,
  }) async {
    try {
      // Idempotent: same messageId == same expenseId; .set() upserts.
      await _messagesRef(eventId).doc(messageId).set({
        'senderId': senderId,
        'text': text,
        'isHighPriority': false,
        'kind': 'settlement',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      log(
        'Failed to post settlement notice',
        error: e,
        stackTrace: st,
        name: 'chat',
      );
      rethrow;
    }
  }

  ChatMessage _fromFirestore(String id, Map<String, dynamic> data) =>
      ChatMessage(
        id: id,
        eventId: '',
        senderId: data['senderId'] as String? ?? '',
        text: data['text'] as String? ?? '',
        timestamp:
            (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isHighPriority: data['isHighPriority'] as bool? ?? false,
      );
}
