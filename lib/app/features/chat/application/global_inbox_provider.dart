import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// One row of the cross-event inbox — an event plus its chronologically
/// latest chat message, with read-state derived counts.
class InboxRow {
  const InboxRow({
    required this.event,
    this.lastMessage,
    this.lastSenderName,
    this.unreadCount = 0,
    this.hasUrgentUnread = false,
  });

  final EventModel event;
  final ChatMessageModel? lastMessage;

  /// Resolved display name for `lastMessage.senderId`. Null when there is
  /// no last message; `kRemovedMemberPlaceholder` when the sender is no
  /// longer in the event roster.
  final String? lastSenderName;
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

      // Fetch the user roster for this event so the inbox preview can
      // show the latest sender's display name instead of a raw UID.
      final rosterAsync = ref.watch(
        usersByIdProvider(usersByIds(event.memberIds)),
      );
      final roster = rosterAsync.value;
      if (roster == null) {
        return switch (rosterAsync) {
          AsyncError(:final error, :final stackTrace) => AsyncError(
            error,
            stackTrace,
          ),
          _ => const AsyncLoading(),
        };
      }
      final memberNames = <String, String>{};
      for (final entry in roster.entries) {
        final name = entry.value.displayName;
        if (name != null && name.isNotEmpty) {
          memberNames[entry.key] = name;
        } else if (entry.value.email.isNotEmpty) {
          memberNames[entry.key] = entry.value.email;
        }
      }

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
          lastSenderName: resolveMemberName(
            uid: latest.senderId,
            memberNames: memberNames,
          ),
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
