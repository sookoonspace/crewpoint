import 'package:clock/clock.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/core/widgets/last_updated_note.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/features/chat/application/older_messages.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_window.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart'
    show chatSummaryProvider;
import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/chat/domain/dispute_window.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_screen.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/dispute_sheet.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Event-scoped chat page. Subscribes to `chatMessagesProvider(eventId)` and
/// routes mutations + dispute through the repo / callable providers.
class EventChatPage extends ConsumerStatefulWidget {
  const EventChatPage({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<EventChatPage> createState() => _EventChatPageState();
}

class _EventChatPageState extends ConsumerState<EventChatPage> {
  bool _isSending = false;
  bool _lastSendFailed = false;

  @override
  void initState() {
    super.initState();
    // Mark the event as read on first frame so the global inbox's unread
    // count clears. Fire-and-forget — failures are swallowed by the repo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = ref.read(authProvider);
      if (auth is! Authenticated) return;
      ref
          .read(chatRepositoryProvider)
          .markEventRead(
            auth.user.uid,
            widget.event.id,
            count: ref.read(chatSummaryProvider(widget.event.id)).value?.count,
          );
    });
  }

  /// While the chat is open, new messages count as read (Req 57a).
  void _markReadAt(int count) {
    final auth = ref.read(authProvider);
    if (auth is! Authenticated) return;
    ref
        .read(chatRepositoryProvider)
        .markEventRead(auth.user.uid, widget.event.id, count: count);
  }

  Future<void> _send(String text, {bool isHighPriority = false}) async {
    final auth = ref.read(authProvider);
    if (auth is! Authenticated) return;
    setState(() {
      _isSending = true;
      _lastSendFailed = false;
    });
    final ok = await ref
        .read(chatRepositoryProvider)
        .sendMessage(
          eventId: widget.event.id,
          senderId: auth.user.uid,
          text: text,
          isHighPriority: isHighPriority,
        );
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _lastSendFailed = !ok;
    });
  }

  /// Read when a dispute is opened, so that this costs nothing otherwise. Falls
  /// back to the default offline, and the server still enforces the real value.
  Future<int> _disputeWindowDays() async {
    try {
      final event = await ref
          .read(firestoreProvider)
          .collection('events')
          .doc(widget.event.id)
          .get();
      return disputeWindowDaysFrom(
        event.data()?['settings'] as Map<String, dynamic>?,
      );
    } catch (_) {
      return defaultDisputeWindowDays;
    }
  }

  Future<void> _onDispute(ChatMessageModel m) async {
    final summary = m.text.isEmpty
        ? context.strings.chat.settlementFallback
        : m.text;
    final windowDays = await _disputeWindowDays();
    if (!mounted) return;
    final isOpen = isDisputeWindowOpen(
      settledAt: m.timestamp,
      windowDays: windowDays,
      now: clock.now(),
    );
    await DisputeSheet.show(
      context: context,
      summary: summary,
      closedAfterDays: isOpen ? null : windowDays,
      onDispute: () async {
        final dispute = ref.read(disputeSettlementCallableProvider);
        try {
          await dispute(eventId: widget.event.id, settlementId: m.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.strings.chat.disputed)),
          );
        } catch (e) {
          if (!mounted) return;
          // The server has the final say on the window.
          final windowClosed =
              e is FirebaseFunctionsException &&
              e.code == 'failed-precondition';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                windowClosed
                    ? context.strings.chat.disputeWindowClosed(windowDays)
                    : context.strings.chat.disputeFailed,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final uid = auth is Authenticated ? auth.user.uid : null;
    if (uid == null) {
      return _frame(
        CpEmptyState(
          icon: CpIcons.lock,
          title: context.strings.chat.signInRequired,
        ),
      );
    }
    // Reading chat needs `chat.send`, so a Vendor or Observer opening the
    // link sees why (Req 32).
    if (!widget.event.readsChat(uid)) return _frame(const NoAccessView());

    final asyncMessages = ref.watch(chatMessagesProvider(widget.event.id));
    // Names of the people who wrote the loaded messages, read one by one,
    // never the whole event (Req 43a).
    final asyncUsers = ref.watch(
      peopleByIdProvider(
        PeopleKey(widget.event.id, [
          for (final m in asyncMessages.value ?? const <ChatMessageModel>[])
            m.senderId,
        ]),
      ),
    );
    final memberNames = <String, String>{};
    asyncUsers.whenData((users) {
      for (final entry in users.entries) {
        final name = entry.value.displayName;
        if (name != null && name.isNotEmpty) {
          memberNames[entry.key] = name;
        } else if (entry.value.email.isNotEmpty) {
          memberNames[entry.key] = entry.value.email;
        }
      }
    });

    ref.listen(chatSummaryProvider(widget.event.id), (before, after) {
      final count = after.value?.count;
      if (count != null && count != before?.value?.count) _markReadAt(count);
    });
    final older = ref.watch(olderMessagesProvider(widget.event.id));
    // Read from the device's cache, without a connection (Req 74).
    final offline =
        ref
            .watch(
              mirrorSyncProvider(ChatRepository.mirrorKey(widget.event.id)),
            )
            .value
            ?.fromCache ??
        false;

    return asyncMessages.when(
      data: (latest) {
        final latestIds = {for (final m in latest) m.id};
        final messages = [
          for (final m in older.messages)
            if (!latestIds.contains(m.id)) m,
          ...latest,
        ];
        return _chatScreen(
          messages,
          uid,
          memberNames,
          _olderHeader(messages, latest.length, older, offline),
        );
      },
      loading: () => _frame(
        CpLoadingState.rows(
          key: const Key('chat.loading'),
          semanticLabel: widget.event.title,
        ),
      ),
      error: (e, _) => _frame(
        CpErrorState(
          key: const Key('chat.error'),
          title: userMessageFor(
            e,
            strings: context.strings.errors,
            fallback: context.strings.errors.genericFallback,
          ),
          retryLabel: context.strings.chat.retry,
          retryKey: const Key('chat.retry'),
          onRetry: () => ref.invalidate(chatMessagesProvider(widget.event.id)),
        ),
      ),
    );
  }

  /// The event's title above [body], for the states before the chat shows.
  Widget _frame(Widget body) {
    final cp = context.cp;
    final navigator = Navigator.of(context);
    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: widget.event.title,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: navigator.canPop() ? () => navigator.maybePop() : null,
      ),
      body: body,
    );
  }

  /// Above the oldest message: a way to load earlier ones, while any may
  /// remain (Req 57).
  Widget? _olderHeader(
    List<ChatMessageModel> messages,
    int latestCount,
    OlderMessages older,
    bool offline,
  ) {
    final cp = context.cp;
    final strings = context.strings.chat;
    // Fewer than a page means the whole chat is already here.
    if (messages.isEmpty ||
        (latestCount < chatPageSize && older.messages.isEmpty)) {
      return null;
    }
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);
    final Widget child;
    if (!older.hasMore) {
      child = Text(
        strings.olderNone,
        key: const Key('chat.older.none'),
        textAlign: TextAlign.center,
        style: muted,
      );
    } else if (older.loading) {
      child = SizedBox.square(
        key: const Key('chat.older.loading'),
        dimension: cp.sizes.iconLg,
        child: CircularProgressIndicator(
          strokeWidth: cp.sizes.hairline * 2,
          color: cp.colors.accent,
        ),
      );
    } else if (offline) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: cp.space.sm,
        children: [
          Icon(
            CpIcons.cloudOff,
            size: cp.sizes.iconMd,
            color: cp.colors.textMuted,
          ),
          Flexible(
            child: Text(
              strings.olderNeedsConnection,
              key: const Key('chat.older.offline'),
              style: muted,
            ),
          ),
        ],
      );
    } else if (older.failed) {
      child = Column(
        spacing: cp.space.sm,
        children: [
          Text(
            strings.olderFailed,
            key: const Key('chat.older.failed'),
            textAlign: TextAlign.center,
            style: muted,
          ),
          CpButton.text(
            key: const Key('chat.older.retry'),
            label: strings.olderRetry,
            onPressed: () => _loadOlder(messages),
          ),
        ],
      );
    } else {
      child = CpButton.secondary(
        key: const Key('chat.older.load'),
        label: strings.olderLoad,
        onPressed: () => _loadOlder(messages),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: cp.space.md),
      child: Center(child: child),
    );
  }

  void _loadOlder(List<ChatMessageModel> messages) {
    final oldest = messages
        .map((m) => m.timestamp)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    ref.read(olderMessagesProvider(widget.event.id).notifier).load(oldest);
  }

  Widget _chatScreen(
    List<ChatMessageModel> messages,
    String uid,
    Map<String, String> memberNames,
    Widget? olderHeader,
  ) => ChatScreen(
    olderHeader: olderHeader,
    banner: LastUpdatedNote(
      mirrorKey: ChatRepository.mirrorKey(widget.event.id),
    ),
    messages: messages,
    currentUserId: uid,
    memberNames: memberNames,
    appBarTitle: widget.event.title,
    isSending: _isSending,
    // Observers and Vendors read chat without `chat.send`.
    readOnly:
        !widget.event.allowsChatAndMoney || !widget.event.can(uid, 'chat.send'),
    lastSendFailed: _lastSendFailed,
    onSendMessage: (text) => _send(text),
    onSendCriticalAlert: widget.event.can(uid, 'chat.urgent')
        ? (text) => _send(text, isHighPriority: true)
        : null,
    onTapSettlement: _onDispute,
  );
}
