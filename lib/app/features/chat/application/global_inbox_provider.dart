import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// One row of the cross-event inbox — an event plus its chronologically
/// latest chat message, with read-state derived counts.
class InboxRow {
  const InboxRow({
    required this.event,
    this.lastMessage,
    this.unreadCount = 0,
    this.hasUrgentUnread = false,
  });

  final EventModel event;
  final ChatMessageModel? lastMessage;
  final int unreadCount;
  final bool hasUrgentUnread;
}

/// Per-(uid, eventId) last-read timestamp stream. Wraps
/// `ChatRepository.watchLastRead` so the inbox composer can fold it.
final eventChatReadStateProvider =
    StreamProvider.family<DateTime?, ({String uid, String eventId})>((
      ref,
      arg,
    ) {
      final repo = ref.watch(chatRepositoryProvider);
      return repo.watchLastRead(arg.uid, arg.eventId);
    });

/// Cross-event chat inbox. Composes the user's active events with each
/// event's message stream + per-event read state into a flat list of
/// rows sorted by latest-message timestamp desc.
///
/// Archived events are excluded (no point messaging on a closed trip).
/// Events whose message list is empty are excluded from the data list —
/// the empty-state widget covers them.
final globalInboxProvider = Provider.family<AsyncValue<List<InboxRow>>, String>(
  (ref, uid) {
    final eventsAsync = ref.watch(dashboardEventsProvider);
    final events = eventsAsync.value;
    if (events == null) {
      return switch (eventsAsync) {
        AsyncError(:final error, :final stackTrace) => AsyncError(
          error,
          stackTrace,
        ),
        _ => const AsyncLoading(),
      };
    }

    final activeEvents = events.where((e) => e.status == EventStatus.active);
    final rows = <InboxRow>[];
    for (final event in activeEvents) {
      final messagesAsync = ref.watch(chatMessagesProvider(event.id));
      final messages = messagesAsync.value;
      if (messages == null) {
        return switch (messagesAsync) {
          AsyncError(:final error, :final stackTrace) => AsyncError(
            error,
            stackTrace,
          ),
          _ => const AsyncLoading(),
        };
      }
      if (messages.isEmpty) continue;
      final latest = messages.reduce(
        (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
      );

      final readAsync = ref.watch(
        eventChatReadStateProvider((uid: uid, eventId: event.id)),
      );
      final lastReadAt = readAsync.value;
      // Note: we tolerate the reads stream still being in `loading`
      // (lastReadAt stays null) — that just means we treat everything
      // as unread until the first emission arrives. The Drift cache
      // resolves this within microseconds on cold start.

      final unread = messages.where(
        (m) =>
            m.senderId != uid &&
            (lastReadAt == null || m.timestamp.isAfter(lastReadAt)),
      );
      final unreadCount = unread.length;
      final hasUrgentUnread =
          unreadCount > 0 && unread.any((m) => m.isHighPriority);

      rows.add(
        InboxRow(
          event: event,
          lastMessage: latest,
          unreadCount: unreadCount,
          hasUrgentUnread: hasUrgentUnread,
        ),
      );
    }
    rows.sort((a, b) {
      final ta =
          a.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb =
          b.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return AsyncData(rows);
  },
);
