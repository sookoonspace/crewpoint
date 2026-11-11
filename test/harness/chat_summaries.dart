import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_summary.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// The chat summary the server keeps for [messages] (Req 57a).
ChatSummary summaryOf(List<ChatMessageModel> messages) {
  if (messages.isEmpty) return const ChatSummary();
  final sorted = [...messages]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final urgent = sorted.where((m) => m.isHighPriority).lastOrNull;
  return ChatSummary(
    count: sorted.length,
    latest: sorted.last,
    lastUrgentAt: urgent?.timestamp,
    lastUrgentSenderId: urgent?.senderId,
  );
}

/// Feeds the inbox each event's summary, worked out from the messages
/// [messages] gives, as the server would.
Override summariesFromMessages(
  Stream<List<ChatMessageModel>> Function(Ref ref, String eventId) messages,
) => chatSummaryProvider.overrideWith(
  (ref, eventId) => messages(ref, eventId).map(summaryOf),
);
