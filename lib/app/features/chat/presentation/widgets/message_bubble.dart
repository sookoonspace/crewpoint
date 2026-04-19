import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  final ChatMessageModel message;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: message.isHighPriority
              ? AppColors.terracottaLight.withValues(alpha: 0.2)
              : isCurrentUser
              ? AppColors.sage
              : AppColors.lightGrey,
          borderRadius: BorderRadius.circular(16),
          border: message.isHighPriority
              ? Border.all(color: AppColors.terracotta, width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            if (!isCurrentUser && message.senderName != null)
              Text(
                message.senderName!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isCurrentUser
                      ? AppColors.white.withValues(alpha: 0.7)
                      : AppColors.mediumGrey,
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
                color: isCurrentUser ? AppColors.white : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
