import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_sizes.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/status_badge.dart';

/// Chat inbox row — emoji + title + last-message preview + timestamp +
/// optional urgent badge + optional unread pill. Stateless and parameter-
/// driven; the screen (or a Riverpod-watching wrapper) supplies the values.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.emoji,
    required this.title,
    required this.preview,
    required this.timestamp,
    this.unreadCount = 0,
    this.isUrgent = false,
    this.onTap,
  });

  final String emoji;
  final String title;
  final String preview;
  final String timestamp;
  final int unreadCount;
  final bool isUrgent;
  final VoidCallback? onTap;

  String _unreadLabel() => unreadCount > 99 ? '99+' : '$unreadCount';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = unreadCount > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: AppSizes.emojiChat)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isUrgent) ...[
                        const _UrgentBadge(),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: hasUnread || isUrgent
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isUrgent
                          ? AppColors.statusUrgentFg
                          : AppColors.darkGrey,
                      fontWeight: isUrgent ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timestamp,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.darkGrey,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    key: const Key('conversation.tile.unreadPill'),
                    constraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 22,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: isUrgent
                          ? AppColors.statusUrgentFg
                          : AppColors.charcoal,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _unreadLabel(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgentBadge extends StatelessWidget {
  const _UrgentBadge();

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: Key('conversation.tile.urgentBadge'),
      child: StatusBadge.urgent(label: 'URGENT'),
    );
  }
}
