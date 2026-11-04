/// Kind of message — drives chat bubble styling.
enum ChatMessageKind {
  normal,
  settlement;

  static ChatMessageKind fromString(String? value) => switch (value) {
    'settlement' => ChatMessageKind.settlement,
    _ => ChatMessageKind.normal,
  };
}

/// Domain model for a chat message.
class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isHighPriority = false,
    this.senderName,
    this.kind = ChatMessageKind.normal,
    this.urgentPushSkipped = false,
  });

  /// The most text a message can hold, matching `firestore.rules`.
  static const int maxTextLength = 4000;

  final String id;
  final String eventId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isHighPriority;
  final String? senderName;
  final ChatMessageKind kind;

  /// The sender was over the urgent rate, so nobody was alerted.
  final bool urgentPushSkipped;
}
