import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/conversation_tile.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/event_type_emoji.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_cover.dart';

/// Test seam for opening an event chat from an inbox row. Tests inject a
/// capturing callback; production falls through to `context.push`.
typedef OpenChatCallback = void Function(BuildContext context, InboxRow row);

/// Cross-event Chat tab — the Global Inbox (Spec #186). A row per active
/// event that has at least one message, in one card; tapping a row pushes
/// into the event-scoped chat page.
class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({super.key, this.onOpenChat, this.onOpenDashboard});

  final OpenChatCallback? onOpenChat;
  final VoidCallback? onOpenDashboard;

  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
  /// One-shot guard so the first-launch backfill only fires once per
  /// inbox session (i.e., once per `dashboardEventsProvider` data
  /// emission for a given uid).
  bool _didBackfill = false;

  void _maybeBackfill(String uid) {
    if (_didBackfill) return;
    final eventsAsync = ref.read(dashboardEventsProvider);
    final events = eventsAsync.value;
    if (events == null) return; // wait for events to settle
    _didBackfill = true;
    // Fire-and-forget; repo swallows + logs failures.
    ref
        .read(chatRepositoryProvider)
        .backfillReadStateForExistingEvents(uid, events);
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings;
    final uid = ref.watch(currentUserIdProvider);

    // Touch dashboardEventsProvider so the listener wakes up when events
    // emit; then queue a post-frame backfill (Riverpod forbids triggering
    // dependency reads mid-build via `ref.read` of a method that updates
    // state synchronously, so we defer to the next microtask).
    if (uid != null && !_didBackfill) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeBackfill(uid);
      });
    }

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(title: s.chat.inboxAppBarTitle),
      body: uid == null
          ? CpEmptyState(icon: CpIcons.lock, title: s.tasks.signInRequiredTitle)
          : switch (ref.watch(globalInboxProvider(uid))) {
              AsyncValue(:final value?) =>
                value.isEmpty
                    ? const _ChatInboxEmptyState()
                    : _ChatInboxList(
                        rows: value,
                        currentUserId: uid,
                        onOpenChat: widget.onOpenChat,
                      ),
              AsyncValue(:final error?, :final stackTrace) => () {
                developer.log(
                  'Failed to load chat inbox',
                  name: 'chat.inbox',
                  error: error,
                  stackTrace: stackTrace,
                );
                return CpErrorState(
                  key: const Key('chat.inbox.error'),
                  title: s.chat.inboxErrorTitle,
                  retryLabel: s.chat.retry,
                  retryKey: const Key('chat.inbox.retry'),
                  onRetry: () => ref.invalidate(globalInboxProvider(uid)),
                );
              }(),
              _ => CpLoadingState.rows(
                key: const Key('chat.inbox.loading'),
                semanticLabel: s.chat.inboxAppBarTitle,
              ),
            },
    );
  }
}

class _ChatInboxList extends StatelessWidget {
  const _ChatInboxList({
    required this.rows,
    required this.currentUserId,
    this.onOpenChat,
  });

  final List<InboxRow> rows;
  final String currentUserId;
  final OpenChatCallback? onOpenChat;

  String _truncate(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max).trimRight()}…';

  String _formatTimestamp(ChatStrings s, DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return s.timeNow;
    if (diff.inHours < 1) return s.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return s.hoursAgo(diff.inHours);
    if (diff.inDays == 1) return s.yesterday;
    if (diff.inDays < 30) return s.daysAgo(diff.inDays);
    return DateFormat.MMMd().format(when);
  }

  String _previewLine(ChatStrings s, InboxRow row) {
    final last = row.lastMessage;
    if (last == null) return '';
    final senderName = last.senderId == currentUserId
        ? s.you
        // Roster-resolved name from globalInboxProvider — never the UID.
        : (row.lastSenderName ?? kRemovedMemberPlaceholder);
    return s.inboxLastMessagePrefix(
      senderName: senderName,
      text: _truncate(last.text, 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final s = context.strings.chat;
    return ListView(
      key: const Key('chat.inbox.list'),
      padding: EdgeInsets.fromLTRB(
        cp.space.lg,
        cp.space.xs,
        cp.space.lg,
        cp.space.xxl,
      ),
      children: [
        ContentMaxWidth(
          maxWidth: cp.sizes.phoneColumn,
          child: CpCard(
            child: CpRowGroup(
              children: [
                for (final row in rows)
                  KeyedSubtree(
                    key: Key('chat.inbox.tile.${row.event.id}'),
                    child: ConversationTile(
                      icon: iconForEventType(row.event.displayType),
                      leading: EventCoverThumb(
                        event: row.event,
                        size: cp.sizes.avatarMd,
                      ),
                      title: row.event.title,
                      preview: _previewLine(s, row),
                      timestamp: row.lastMessage == null
                          ? ''
                          : _formatTimestamp(s, row.lastMessage!.timestamp),
                      unreadCount: row.unreadCount,
                      isUrgent: row.hasUrgentUnread,
                      onTap: () {
                        final cb = onOpenChat;
                        if (cb != null) {
                          cb(context, row);
                        } else {
                          context.push('/dashboard/event/${row.event.id}/chat');
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Adaptive empty-state copy + CTA: with events → "Open Dashboard";
/// zero events → "Create an event".
class _ChatInboxEmptyState extends ConsumerWidget {
  const _ChatInboxEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final hasEvents = ref
        .watch(dashboardEventsProvider)
        .maybeWhen(data: (events) => events.isNotEmpty, orElse: () => false);

    return CpEmptyState(
      key: const Key('chat.inbox.empty'),
      icon: CpIcons.navChat,
      title: strings.chat.inboxEmptyTitle,
      message: hasEvents
          ? strings.chat.inboxEmptySubtitle
          : strings.chat.inboxEmptyNoEventsSubtitle,
      actionLabel: hasEvents
          ? strings.tasks.openDashboardCta
          : strings.tasks.createFromDashboardCta,
      actionKey: const Key('chat.inbox.empty.action'),
      // The empty state owns its navigation; the parent's seam is for the
      // tile tap.
      onAction: () => context.go(AppRoutes.dashboard),
    );
  }
}
