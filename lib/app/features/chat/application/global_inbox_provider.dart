import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_summary.dart';
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

/// Where the user has read up to in an event's chat, with the message count
/// then (Req 57a).
final eventChatReadStateProvider =
    StreamProvider.family<ChatReadState?, ({String uid, String eventId})>((
      ref,
      arg,
    ) {
      final repo = ref.watch(chatRepositoryProvider);
      return repo.watchReadState(arg.uid, arg.eventId);
    });

/// An event's chat summary (Req 57a), kept by the server: the latest
/// message, the count and the last urgent message. Firestore's cache keeps
/// it offline. Watch it only for someone who reads chat.
final chatSummaryProvider = StreamProvider.family<ChatSummary?, String>(
  (ref, eventId) => ref
      .watch(firestoreProvider)
      .doc('events/$eventId/chatSummary/current')
      .snapshots()
      .map((doc) {
        final data = doc.data();
        return data == null ? null : ChatSummary.fromFirestore(eventId, data);
      }),
);

/// Cross-event chat inbox. Composes the user's active events with each
/// event's chat summary and read state into rows sorted by the latest
/// message, newest first, without loading any messages (Req 57a).
///
/// Archived events are excluded, and so are events with no messages; the
/// empty state covers them.
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

    final activeEvents = events.where(
      (e) =>
          e.status != EventStatus.archived &&
          e.isModuleOn('chat') &&
          // Reading chat needs `chat.send` (Req 32).
          e.readsChat(uid),
    );
    final rows = <InboxRow>[];
    for (final event in activeEvents) {
      final summaryAsync = ref.watch(chatSummaryProvider(event.id));
      if (!summaryAsync.hasValue) {
        return switch (summaryAsync) {
          AsyncError(:final error, :final stackTrace) => AsyncError(
            error,
            stackTrace,
          ),
          _ => const AsyncLoading(),
        };
      }
      final summary = summaryAsync.value;
      final latest = summary?.latest;
      if (summary == null || latest == null || summary.count == 0) continue;

      // The latest sender's name, for the preview. Only they are read
      // (Req 43a).
      final rosterAsync = ref.watch(
        peopleByIdProvider(PeopleKey(event.id, [latest.senderId])),
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

      // A read state still loading counts everything as unread until it
      // arrives; the Drift cache answers within microseconds on cold start.
      final read = ref
          .watch(eventChatReadStateProvider((uid: uid, eventId: event.id)))
          .value;
      final unread = inboxUnread(summary: summary, read: read, uid: uid);

      rows.add(
        InboxRow(
          event: event,
          lastMessage: latest,
          lastSenderName: resolveMemberName(
            uid: latest.senderId,
            memberNames: memberNames,
          ),
          unreadCount: unread.count,
          hasUrgentUnread: unread.count > 0 && unread.urgent,
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
