import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// One row of the cross-event inbox — an event plus its chronologically
/// latest chat message. Read-state (unread + urgent flags) lands in Phase 2.
class InboxRow {
  const InboxRow({required this.event, this.lastMessage});

  final EventModel event;
  final ChatMessageModel? lastMessage;
}

/// Cross-event chat inbox. Composes the user's active events with each
/// event's message stream and emits a flat row list sorted by the latest
/// message timestamp desc.
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
      rows.add(InboxRow(event: event, lastMessage: latest));
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
