import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/critical_alert_modal.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/message_bubble.dart';

/// An event's chat (Spec #186): the messages, newest at the bottom, and a
/// composer below them, or why nobody can send.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.messages,
    required this.currentUserId,
    this.memberNames = const {},
    this.appBarTitle,
    this.isSending = false,
    this.readOnly = false,
    this.lastSendFailed = false,
    this.onSendMessage,
    this.onSendCriticalAlert,
    this.onTapSettlement,
    this.banner,
    this.olderHeader,
  });

  final List<ChatMessageModel> messages;
  final String currentUserId;
  final Map<String, String> memberNames;

  /// The top bar's title — the parent (`EventChatPage`) passes the event's
  /// name so people in several events know which chat they are in. Falls
  /// back to "Chat".
  final String? appBarTitle;
  final bool isSending;

  /// True once the event is archived, when nobody can send.
  final bool readOnly;
  final bool lastSendFailed;
  final ValueChanged<String>? onSendMessage;
  final ValueChanged<String>? onSendCriticalAlert;

  /// Tapped a settlement-kind bubble — caller opens the DisputeSheet.
  final ValueChanged<ChatMessageModel>? onTapSettlement;

  /// Shown above the messages, such as the offline note (Req 74).
  final Widget? banner;

  /// Shown above the oldest message: loading earlier ones (Req 57).
  final Widget? olderHeader;

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
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            0,
            duration: context.cp.motion.fast,
            curve: context.cp.motion.curve,
          );
        }
      });
    }
    _lastMessageCount = widget.messages.length;
  }

  /// "At bottom" while `reverse: true` means offset is near zero.
  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.offset < context.cp.space.xxxl * 2;
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
    final cp = context.cp;
    final s = context.strings.chat;
    final navigator = Navigator.of(context);
    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: widget.appBarTitle ?? s.chatAppBarTitle,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: navigator.canPop() ? () => navigator.maybePop() : null,
        actions: [
          if (widget.onSendCriticalAlert != null)
            CpTopBarAction(
              key: const Key('chat.urgent.open'),
              icon: CpIcons.statusUrgent,
              tooltip: s.urgentTitle,
              onPressed: () => CriticalAlertModal.show(
                context: context,
                onSend: widget.onSendCriticalAlert,
              ),
            ),
        ],
      ),
      body: ContentMaxWidth(
        key: const Key('eventChat.body.clamped'),
        maxWidth: cp.sizes.phoneColumn,
        child: Column(
          children: [
            ?widget.banner,
            Expanded(
              child: widget.messages.isEmpty
                  ? CpEmptyState(
                      key: const Key('chat.list.empty'),
                      icon: CpIcons.chat,
                      title: s.chatEmptyMessage,
                    )
                  : ListView.builder(
                      key: const Key('chat.list'),
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: cp.space.lg,
                        vertical: cp.space.lg,
                      ),
                      reverse: true,
                      itemCount:
                          widget.messages.length +
                          (widget.olderHeader == null ? 0 : 1),
                      itemBuilder: (_, index) {
                        // Reversed, so the last item sits above the oldest.
                        if (index == widget.messages.length) {
                          return widget.olderHeader!;
                        }
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
                                  urgentPushSkipped: message.urgentPushSkipped,
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
            if (widget.readOnly)
              _ReadOnlyNotice(text: s.readOnlyNotice)
            else
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

/// In place of the composer when nobody can send.
class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cp.space.lg),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cp.colors.border, width: cp.sizes.hairline),
          ),
        ),
        child: Row(
          spacing: cp.space.sm,
          children: [
            Icon(
              CpIcons.lock,
              size: cp.sizes.iconMd,
              color: cp.colors.textMuted,
            ),
            Expanded(
              child: Text(
                text,
                key: const Key('chat.composer.readOnly'),
                style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
              ),
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
    final cp = context.cp;
    final s = context.strings.chat;
    final pill = OutlineInputBorder(
      borderRadius: cp.radii.xl,
      borderSide: BorderSide(color: cp.colors.border, width: cp.sizes.hairline),
    );
    return Container(
      padding: EdgeInsets.only(
        left: cp.space.lg,
        right: cp.space.sm,
        top: cp.space.sm,
        bottom: MediaQuery.viewPaddingOf(context).bottom + cp.space.sm,
      ),
      decoration: BoxDecoration(
        color: cp.colors.surface,
        border: Border(
          top: BorderSide(color: cp.colors.border, width: cp.sizes.hairline),
        ),
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: cp.space.xs,
        children: [
          if (lastSendFailed)
            Row(
              spacing: cp.space.xs,
              children: [
                Icon(
                  CpIcons.statusError,
                  size: cp.sizes.iconSm,
                  color: cp.colors.overdue,
                ),
                Expanded(
                  child: Text(
                    s.sendFailedHint,
                    style: cp.type.labelMedium.copyWith(
                      color: cp.colors.overdue,
                    ),
                  ),
                ),
              ],
            ),
          Row(
            spacing: cp.space.xs,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('chat.composer.input'),
                  controller: controller,
                  enabled: !isSending,
                  minLines: 1,
                  maxLines: 5,
                  style: cp.type.bodyLarge.copyWith(color: cp.colors.text),
                  decoration: InputDecoration(
                    hintText: s.messageInputHint,
                    hintStyle: cp.type.bodyLarge.copyWith(
                      color: cp.colors.textMuted,
                    ),
                    filled: true,
                    fillColor: cp.colors.background,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: cp.space.lg,
                      vertical: cp.space.md,
                    ),
                    border: pill,
                    enabledBorder: pill,
                    disabledBorder: pill,
                    focusedBorder: pill.copyWith(
                      borderSide: BorderSide(
                        color: cp.colors.accent,
                        width: cp.sizes.hairline * 2,
                      ),
                    ),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      ChatMessageModel.maxTextLength,
                    ),
                  ],
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                ),
              ),
              IconButton(
                key: const Key('chat.composer.send'),
                tooltip: s.send,
                onPressed: isSending ? null : onSend,
                constraints: BoxConstraints.tightFor(
                  width: cp.sizes.tapMin,
                  height: cp.sizes.tapMin,
                ),
                icon: isSending
                    ? SizedBox.square(
                        dimension: cp.sizes.iconMd,
                        child: CircularProgressIndicator(
                          strokeWidth: cp.sizes.hairline * 2,
                          color: cp.colors.accent,
                        ),
                      )
                    : Icon(
                        CpIcons.actionSend,
                        size: cp.sizes.iconLg,
                        color: cp.colors.accent,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
