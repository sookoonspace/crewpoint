import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';

/// Cross-event inbox row — event title + last message snippet +
/// relative timestamp + unread badge + urgent (terracotta + bell) highlight.
class InboxTile extends StatelessWidget {
  const InboxTile({
    super.key,
    required this.row,
    required this.currentUserId,
    required this.onTap,
  });

  final InboxRow row;
  final String currentUserId;
  final VoidCallback onTap;

  String _truncate(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max).trimRight()}…';

  String _formatTimestamp(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return DateFormat.MMMd().format(when);
  }

  String _firstLetter(String s) =>
      s.isEmpty ? '?' : s.characters.first.toUpperCase();

  String _badgeLabel(int count) => count > 99 ? '99+' : '$count';

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final last = row.lastMessage;
    final isUnread = row.unreadCount > 0;
    final isUrgent = row.hasUrgentUnread;

    final senderName = last == null
        ? ''
        : (last.senderId == currentUserId
              ? 'You'
              : (last.senderName ?? last.senderId));
    final snippet = last == null
        ? ''
        : s.chat.inboxLastMessagePrefix(
            senderName: senderName,
            text: _truncate(last.text, 60),
          );

    return InkWell(
      key: Key('chat.inbox.tile.${row.event.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.sage,
              child: Text(
                _firstLetter(row.event.title),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isUrgent) ...[
                        Icon(
                          Icons.notification_important_outlined,
                          key: Key('chat.inbox.tile.${row.event.id}.urgent'),
                          size: 16,
                          color: AppColors.terracotta,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          row.event.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.charcoal,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (last != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      snippet,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mediumGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (last != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimestamp(last.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.mediumGrey,
                    ),
                  ),
                  if (isUnread) ...[
                    const SizedBox(height: 4),
                    Semantics(
                      label: s.chat.inboxUrgentBadgeLabel,
                      child: Container(
                        key: Key('chat.inbox.tile.${row.event.id}.badge'),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: isUrgent
                              ? AppColors.terracotta
                              : AppColors.sage,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _badgeLabel(row.unreadCount),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
