import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';

/// One chat message (Spec #186). Your own messages sit on the right in the
/// accent colour, other people's on the left with their name. An urgent
/// message is red with its icon, and a settlement green with its icon, in
/// the middle; tapping a settlement opens the dispute sheet.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onTapSettlement,
  });

  final ChatMessageModel message;
  final bool isCurrentUser;

  /// Tapping a settlement-kind bubble fires this (Phase 6 dispute hook).
  final VoidCallback? onTapSettlement;

  bool get _isSettlement => message.kind == ChatMessageKind.settlement;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.chat;

    // Status colour only with its icon and words (Req 45).
    final (Color background, Color? border, Color ink) = _isSettlement
        ? (cp.colors.doneSoft, cp.colors.done, cp.colors.text)
        : message.isHighPriority
        ? (cp.colors.overdueSoft, cp.colors.overdue, cp.colors.text)
        : isCurrentUser
        ? (cp.colors.accent, null, cp.colors.onAccent)
        : (cp.colors.surface, cp.colors.border, cp.colors.text);

    final (IconData, String, Color)? status = _isSettlement
        ? (CpIcons.actionSwap, strings.settlementLabel, cp.colors.done)
        : message.isHighPriority
        ? (CpIcons.statusUrgent, strings.urgentLabel, cp.colors.overdue)
        : null;

    // Your own corner and theirs stay square, pointing at who wrote it.
    final round = cp.radii.lg.topLeft;
    final tail = cp.radii.xs.topLeft;
    final radius = _isSettlement
        ? BorderRadius.all(round)
        : BorderRadius.only(
            topLeft: round,
            topRight: round,
            bottomLeft: isCurrentUser ? round : tail,
            bottomRight: isCurrentUser ? tail : round,
          );

    final bubble = Container(
      key: Key('chat.bubble.${message.id}'),
      constraints: BoxConstraints(maxWidth: cp.sizes.bubbleMax),
      margin: EdgeInsets.symmetric(vertical: cp.space.xs),
      padding: EdgeInsets.symmetric(
        horizontal: cp.space.md,
        vertical: cp.space.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: border == null
            ? null
            : Border.all(
                color: border,
                width: status == null
                    ? cp.sizes.hairline
                    : cp.sizes.hairline * 2,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: cp.space.xs,
        children: [
          if (!_isSettlement && !isCurrentUser && message.senderName != null)
            Text(
              message.senderName!,
              style: cp.type.labelMedium.copyWith(color: cp.colors.textMuted),
            ),
          if (status != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: cp.space.xs,
              children: [
                Icon(status.$1, size: cp.sizes.iconSm, color: status.$3),
                Flexible(
                  child: Text(
                    status.$2,
                    style: cp.type.labelMedium.copyWith(color: status.$3),
                  ),
                ),
              ],
            ),
          Text(message.text, style: cp.type.bodyMedium.copyWith(color: ink)),
          if (isCurrentUser && message.urgentPushSkipped)
            Text(
              strings.urgentLimitReached,
              key: const Key('chat.message.urgentLimited'),
              style: cp.type.bodySmall.copyWith(color: ink),
            ),
        ],
      ),
    );

    return Align(
      key: Key('chat.message.${message.id}'),
      alignment: _isSettlement
          ? Alignment.center
          : isCurrentUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: _isSettlement && onTapSettlement != null
          ? Semantics(
              button: true,
              hint: strings.settlementTapHint,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: radius,
                  onTap: onTapSettlement,
                  child: bubble,
                ),
              ),
            )
          : bubble,
    );
  }
}
