import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_sizes.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/critical_alert_modal.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.messages,
    required this.currentUserId,
    this.memberNames = const {},
    this.isSending = false,
    this.lastSendFailed = false,
    this.onSendMessage,
    this.onSendCriticalAlert,
    this.onTapSettlement,
  });

  final List<ChatMessageModel> messages;
  final String currentUserId;
  final Map<String, String> memberNames;
  final bool isSending;
  final bool lastSendFailed;
  final ValueChanged<String>? onSendMessage;
  final ValueChanged<String>? onSendCriticalAlert;

  /// Tapped a settlement-kind bubble — caller opens the DisputeSheet.
  final ValueChanged<ChatMessageModel>? onTapSettlement;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void didUpdateWidget(ChatScreen old) {
    super.didUpdateWidget(old);
    final delta = widget.messages.length - _lastMessageCount;
    if (delta > 0 && _isNearBottom()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _lastMessageCount = widget.messages.length;
  }

  /// "At bottom" while `reverse: true` means offset is near zero.
  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.offset < 80;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    if (widget.isSending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage?.call(text);
    _controller.clear();
  }

  String? _resolveSenderName(String senderId) {
    final fromMap = widget.memberNames[senderId];
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.chat;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.chatAppBarTitle),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              AppIcons.statusUrgent,
              color: AppColors.terracotta,
            ),
            onPressed: () => CriticalAlertModal.show(
              context: context,
              onSend: widget.onSendCriticalAlert,
            ),
          ),
        ],
      ),
      body: ContentMaxWidth(
        key: const Key('eventChat.body.clamped'),
        maxWidth: 720,
        child: Column(
          children: [
            Expanded(
              child: widget.messages.isEmpty
                  ? Center(
                      key: const Key('chat.list.empty'),
                      child: Text(
                        s.chatEmptyMessage,
                        style: const TextStyle(color: AppColors.mediumGrey),
                      ),
                    )
                  : ListView.builder(
                      key: const Key('chat.list'),
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: Breakpoints.screenHorizontalPadding(
                          context,
                        ),
                        vertical: AppSpacing.lg,
                      ),
                      reverse: true,
                      itemCount: widget.messages.length,
                      itemBuilder: (_, index) {
                        final reversedIndex =
                            widget.messages.length - 1 - index;
                        final message = widget.messages[reversedIndex];
                        final senderName =
                            message.senderName ??
                            _resolveSenderName(message.senderId);
                        return MessageBubble(
                          message: senderName == null
                              ? message
                              : ChatMessageModel(
                                  id: message.id,
                                  eventId: message.eventId,
                                  senderId: message.senderId,
                                  text: message.text,
                                  timestamp: message.timestamp,
                                  isHighPriority: message.isHighPriority,
                                  senderName: senderName,
                                  kind: message.kind,
                                ),
                          isCurrentUser:
                              message.senderId == widget.currentUserId,
                          onTapSettlement:
                              message.kind == ChatMessageKind.settlement
                              ? () => widget.onTapSettlement?.call(message)
                              : null,
                        );
                      },
                    ),
            ),
            _MessageInput(
              controller: _controller,
              onSend: _send,
              isSending: widget.isSending,
              lastSendFailed: widget.lastSendFailed,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  const _MessageInput({
    required this.controller,
    required this.onSend,
    required this.isSending,
    required this.lastSendFailed,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final bool lastSendFailed;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.chat;
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewPaddingOf(context).bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: AppColors.lightGrey)),
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          if (lastSendFailed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(
                    AppIcons.statusError,
                    size: AppSizes.iconXs,
                    color: AppColors.terracotta,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    s.sendFailedHint,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.terracotta,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('chat.composer.input'),
                  controller: controller,
                  enabled: !isSending,
                  decoration: InputDecoration(
                    hintText: s.messageInputHint,
                    border: InputBorder.none,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                ),
              ),
              IconButton(
                key: const Key('chat.composer.send'),
                onPressed: isSending ? null : onSend,
                icon: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.actionSend, color: AppColors.sage),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
