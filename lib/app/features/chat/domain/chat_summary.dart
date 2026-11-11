import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:flutter/foundation.dart';

/// `events/{id}/chatSummary/current` (Req 57a), kept by the server: the
/// message count, the latest message and the last urgent one.
@immutable
class ChatSummary {
  const ChatSummary({
    this.count = 0,
    this.latest,
    this.lastUrgentAt,
    this.lastUrgentSenderId,
  });

  factory ChatSummary.fromFirestore(String eventId, Map<String, dynamic> data) {
    DateTime? time(Object? raw) =>
        raw is Timestamp ? raw.toDate().toUtc() : null;
    final latest = data['latest'];
    return ChatSummary(
      count: (data['count'] as num?)?.toInt() ?? 0,
      latest: latest is Map
          ? ChatMessageModel(
              id: latest['id'] as String? ?? '',
              eventId: eventId,
              senderId: latest['senderId'] as String? ?? '',
              text: latest['text'] as String? ?? '',
              timestamp: time(latest['timestamp']) ?? DateTime.utc(1970),
              isHighPriority: latest['isHighPriority'] == true,
              kind: ChatMessageKind.fromString(latest['kind'] as String?),
            )
          : null,
      lastUrgentAt: time(data['lastUrgentAt']),
      lastUrgentSenderId: data['lastUrgentSenderId'] as String?,
    );
  }

  final int count;
  final ChatMessageModel? latest;
  final DateTime? lastUrgentAt;
  final String? lastUrgentSenderId;
}

/// Where someone has read up to in an event's chat
/// (`users/{uid}/chatReads/{eventId}`). [readCount] is the message count
/// then; older markers have only a time.
@immutable
class ChatReadState {
  const ChatReadState({this.lastReadAt, this.readCount});

  final DateTime? lastReadAt;
  final int? readCount;
}

/// How many messages [uid] has not read, and whether one is urgent.
/// Without a count on the read marker, at least one is shown when the
/// latest message is newer and someone else's.
({int count, bool urgent}) inboxUnread({
  required ChatSummary? summary,
  required ChatReadState? read,
  required String uid,
}) {
  if (summary == null || summary.count == 0) return (count: 0, urgent: false);
  final readAt = read?.lastReadAt;
  final readCount = read?.readCount;
  final latest = summary.latest;
  final int count;
  if (readCount != null) {
    count = (summary.count - readCount).clamp(0, summary.count);
  } else if (readAt == null) {
    count = summary.count;
  } else {
    count =
        latest != null &&
            latest.senderId != uid &&
            latest.timestamp.isAfter(readAt)
        ? 1
        : 0;
  }
  final urgentAt = summary.lastUrgentAt;
  final urgent =
      urgentAt != null &&
      summary.lastUrgentSenderId != uid &&
      (readAt == null || urgentAt.isAfter(readAt));
  return (count: count, urgent: urgent);
}
