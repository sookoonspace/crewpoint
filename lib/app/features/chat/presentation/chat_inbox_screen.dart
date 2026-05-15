import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/router/app_router.dart';
import 'package:crewpoint_app/app/core/widgets/empty_state_placeholder.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/inbox_tile.dart';

/// Test seam for opening an event chat from an inbox row. Tests inject a
/// capturing callback; production falls through to `context.push`.
typedef OpenChatCallback = void Function(BuildContext context, InboxRow row);

/// Cross-event Chat tab — the Global Inbox. Renders a row per active
/// event that has at least one message; tapping a row pushes into the
/// event-scoped chat page.
class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key, this.onOpenChat, this.onOpenDashboard});

  final OpenChatCallback? onOpenChat;
  final VoidCallback? onOpenDashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(s.chat.inboxAppBarTitle),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: uid == null
          ? EmptyStatePlaceholder(title: s.tasks.signInRequiredTitle)
          : ref
                .watch(globalInboxProvider(uid))
                .when(
                  loading: () => const Center(child: LoadingAnimation()),
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
                      lottieAsset: 'assets/animations/error.json',
                    );
                  },
                  data: (rows) {
                    if (rows.isEmpty) return _ChatInboxEmptyState(strings: s);
                    return _ChatInboxList(
                      rows: rows,
                      currentUserId: uid,
                      onOpenChat: onOpenChat,
                    );
                  },
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

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('chat.inbox.list'),
      itemCount: rows.length,
      itemBuilder: (_, index) {
        final row = rows[index];
        return InboxTile(
          row: row,
          currentUserId: currentUserId,
          onTap: () {
            final cb = onOpenChat;
            if (cb != null) {
              cb(context, row);
            } else {
              context.push('/dashboard/event/${row.event.id}/chat');
            }
          },
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
      onCta: () {
        // No onOpenDashboard seam here because the empty state owns its
        // navigation; the parent's seam is for the tile tap.
        context.go(AppRoutes.dashboard);
      },
    );
  }
}
