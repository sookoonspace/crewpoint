import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
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
          .markEventRead(auth.user.uid, widget.event.id);
    });
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

  Future<void> _onDispute(ChatMessageModel m) async {
    final summary = m.text.isEmpty ? 'Settlement record' : m.text;
    await DisputeSheet.show(
      context: context,
      summary: summary,
      onDispute: () async {
        final dispute = ref.read(disputeSettlementCallableProvider);
        try {
          await dispute(eventId: widget.event.id, settlementId: m.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settlement disputed'),
              backgroundColor: AppColors.sage,
            ),
          );
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not dispute — try again'),
              backgroundColor: AppColors.terracotta,
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
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }

    final asyncMessages = ref.watch(chatMessagesProvider(widget.event.id));
    final asyncUsers = ref.watch(usersByIdProvider(widget.event.memberIds));
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

    return asyncMessages.when(
      data: (messages) => ChatScreen(
        messages: messages,
        currentUserId: uid,
        memberNames: memberNames,
        isSending: _isSending,
        lastSendFailed: _lastSendFailed,
        onSendMessage: (text) => _send(text),
        onSendCriticalAlert: (text) => _send(text, isHighPriority: true),
        onTapSettlement: _onDispute,
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Chat'), elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Chat'), elevation: 0),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
