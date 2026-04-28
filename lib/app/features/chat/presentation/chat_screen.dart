import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/critical_alert_modal.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.messages,
    required this.currentUserId,
    this.onSendMessage,
    this.onSendCriticalAlert,
    this.onTapSettlement,
  });

  final List<ChatMessageModel> messages;
  final String currentUserId;
  final ValueChanged<String>? onSendMessage;
  final ValueChanged<String>? onSendCriticalAlert;

  /// Tapped a settlement-kind bubble — caller opens the DisputeSheet.
  final ValueChanged<ChatMessageModel>? onTapSettlement;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage?.call(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber, color: AppColors.terracotta),
            onPressed: () => CriticalAlertModal.show(
              context: context,
              onSend: widget.onSendCriticalAlert,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: AppColors.mediumGrey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    reverse: true,
                    itemCount: widget.messages.length,
                    itemBuilder: (_, index) {
                      final reversedIndex = widget.messages.length - 1 - index;
                      final message = widget.messages[reversedIndex];
                      return MessageBubble(
                        message: message,
                        isCurrentUser: message.senderId == widget.currentUserId,
                        onTapSettlement:
                            message.kind == ChatMessageKind.settlement
                            ? () => widget.onTapSettlement?.call(message)
                            : null,
                      );
                    },
                  ),
          ),
          _MessageInput(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  const _MessageInput({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.send, color: AppColors.sage),
          ),
        ],
      ),
    );
  }
}
