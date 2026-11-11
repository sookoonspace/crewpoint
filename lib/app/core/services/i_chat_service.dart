import 'package:crewpoint_app/app/features/chat/domain/chat_window.dart';

/// Abstract chat service interface.
/// Current implementation uses plain Firestore.
// TODO(phase2): Swap implementation to support E2EE without breaking UI layer.
abstract class IChatService {
  /// Changes to the latest [limit] messages (Req 57), from the server's
  /// `docChanges`, so a new message costs one change rather than the whole
  /// history. The first change set, and the first from the server, carry
  /// the whole window.
  Stream<ChatChanges> latestMessages(
    String eventId, {
    int limit = chatPageSize,
  });

  /// Up to [limit] messages sent before [before], newest first. Needs a
  /// connection.
  Future<List<ChatMessage>> olderMessages(
    String eventId, {
    required DateTime before,
    int limit = chatPageSize,
  });

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
    this.kind,
    this.urgentPushSkipped = false,
  });

  final String id;
  final String eventId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isHighPriority;

  /// Raw kind tag — used by the domain layer to map to [ChatMessageKind].
  final String? kind;

  /// Set by the server when the sender was over the urgent rate, so the message
  /// was saved but nobody was alerted.
  final bool urgentPushSkipped;
}
