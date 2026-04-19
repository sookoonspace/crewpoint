/// Abstract chat service interface.
/// Current implementation uses plain Firestore.
// TODO(phase2): Swap implementation to support E2EE without breaking UI layer.
abstract class IChatService {
  Stream<List<ChatMessage>> messagesForEvent(String eventId);

  Future<void> sendMessage({
    required String eventId,
    required String senderId,
    required String text,
    bool isHighPriority,
  });

  Future<void> deleteMessage({
    required String eventId,
    required String messageId,
  });
}

/// Chat message model independent of Firestore document structure.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isHighPriority = false,
  });

  final String id;
  final String eventId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isHighPriority;
}
