import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';

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
    final Color background;
    final Border? border;
    if (_isSettlement) {
      background = AppColors.cream;
      border = Border.all(color: AppColors.sage, width: 1.5);
    } else if (message.isHighPriority) {
      background = AppColors.terracottaLight.withValues(alpha: 0.2);
      border = Border.all(color: AppColors.terracotta, width: 1.5);
    } else if (isCurrentUser) {
      background = AppColors.sage;
      border = null;
    } else {
      background = AppColors.lightGrey;
      border = null;
    }

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (!_isSettlement && !isCurrentUser && message.senderName != null)
            Text(
              message.senderName!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.mediumGrey),
            ),
          if (_isSettlement)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                mainAxisSize: .min,
                spacing: AppSpacing.xs,
                children: [
                  const Icon(
                    Icons.swap_horiz_rounded,
                    size: 14,
                    color: AppColors.sage,
                  ),
                  Text(
                    'Settlement',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.sage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (message.isHighPriority)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                mainAxisSize: .min,
                spacing: AppSpacing.xs,
                children: [
                  const Icon(
                    Icons.priority_high,
                    size: 14,
                    color: AppColors.terracotta,
                  ),
                  Text(
                    'Critical Alert',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.terracotta,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            message.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: !_isSettlement && isCurrentUser ? AppColors.white : null,
            ),
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
      child: _isSettlement
          ? GestureDetector(onTap: onTapSettlement, child: bubble)
          : bubble,
    );
  }
}
