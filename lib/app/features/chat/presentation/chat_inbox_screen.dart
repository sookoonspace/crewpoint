import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_assets.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/conversation_tile.dart';
import 'package:crewpoint_app/app/core/widgets/empty_state_placeholder.dart';
import 'package:crewpoint_app/app/core/widgets/screen_header.dart';
import 'package:crewpoint_app/app/core/widgets/skeletons.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/event_type_emoji.dart';

/// Test seam for opening an event chat from an inbox row. Tests inject a
/// capturing callback; production falls through to `context.push`.
typedef OpenChatCallback = void Function(BuildContext context, InboxRow row);

/// Cross-event Chat tab — the Global Inbox. Renders a row per active
/// event that has at least one message; tapping a row pushes into the
/// event-scoped chat page.
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
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: s.chat.inboxAppBarTitle),
            Expanded(
              child: uid == null
                  ? EmptyStatePlaceholder(
                      title: s.tasks.signInRequiredTitle,
                      iconFallback: AppIcons.lock,
                    )
                  : ref
                        .watch(globalInboxProvider(uid))
                        .when(
                          loading: () => ListView.builder(
                            key: const Key('chat.inbox.loading'),
                            itemCount: 4,
                            itemBuilder: (_, _) =>
                                const ConversationTileSkeleton(),
                          ),
                          error: (error, stackTrace) {
                            developer.log(
                              'Failed to load chat inbox',
                              name: 'chat.inbox',
                              error: error,
                              stackTrace: stackTrace,
                            );
                            return EmptyStatePlaceholder(
                              title: s.chat.inboxErrorTitle,
                              subtitle: error.toString(),
                              lottieAsset: AppAssets.lottieError,
                              iconFallback: AppIcons.statusError,
                            );
                          },
                          data: (rows) {
                            if (rows.isEmpty) {
                              return _ChatInboxEmptyState(strings: s);
                            }
                            return _ChatInboxList(
                              rows: rows,
                              currentUserId: uid,
                              onOpenChat: widget.onOpenChat,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
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

  String _formatTimestamp(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return DateFormat.MMMd().format(when);
  }

  String _previewLine(InboxRow row) {
    final last = row.lastMessage;
    if (last == null) return '';
    final senderName = last.senderId == currentUserId
        ? 'You'
        : (last.senderName ?? last.senderId);
    return '$senderName: ${_truncate(last.text, 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('chat.inbox.list'),
      itemCount: rows.length,
      itemBuilder: (_, index) {
        final row = rows[index];
        final last = row.lastMessage;
        return KeyedSubtree(
          key: Key('chat.inbox.tile.${row.event.id}'),
          child: ConversationTile(
            icon: iconForEventType(row.event.eventType),
            title: row.event.title,
            preview: _previewLine(row),
            timestamp: last == null ? '' : _formatTimestamp(last.timestamp),
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
        );
      },
    );
  }
}

/// Adaptive empty-state copy + CTA: with events → "Open Dashboard";
/// zero events → "Create an event".
class _ChatInboxEmptyState extends ConsumerWidget {
  const _ChatInboxEmptyState({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasEvents = ref
        .watch(dashboardEventsProvider)
        .maybeWhen(data: (events) => events.isNotEmpty, orElse: () => false);

    return EmptyStatePlaceholder(
      title: strings.chat.inboxEmptyTitle,
      subtitle: hasEvents
          ? strings.chat.inboxEmptySubtitle
          : strings.chat.inboxEmptyNoEventsSubtitle,
      ctaLabel: hasEvents
          ? strings.tasks.openDashboardCta
          : strings.tasks.createFromDashboardCta,
      iconFallback: AppIcons.navChat,
      onCta: () {
        // No onOpenDashboard seam here because the empty state owns its
        // navigation; the parent's seam is for the tile tap.
        context.go(AppRoutes.dashboard);
      },
    );
  }
}
