import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// One chat in the inbox (Spec #186): the event's icon or cover, its title,
/// the latest message, when it was sent, and how many are unread. An urgent
/// unread message adds an Urgent chip in red with its icon. Put it in a
/// [CpRowGroup].
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.preview,
    required this.timestamp,
    this.leading,
    this.unreadCount = 0,
    this.isUrgent = false,
    this.onTap,
  });

  /// Shown in an accent tile when there is no [leading].
  final IconData icon;

  /// Replaces the icon tile, such as the event's cover thumbnail.
  final Widget? leading;
  final String title;
  final String preview;
  final String timestamp;
  final int unreadCount;
  final bool isUrgent;
  final VoidCallback? onTap;

  String _unreadLabel() => unreadCount > 99 ? '99+' : '$unreadCount';

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.chat;
    final hasUnread = unreadCount > 0;

    final lead =
        leading ??
        Container(
          width: cp.sizes.iconTile,
          height: cp.sizes.iconTile,
          decoration: BoxDecoration(
            color: cp.colors.accentSoft,
            borderRadius: cp.radii.sm,
          ),
          child: Icon(icon, size: cp.sizes.iconMd, color: cp.colors.accent),
        );

    final pill = hasUnread
        ? Semantics(
            label: strings.unreadCount(unreadCount),
            excludeSemantics: true,
            child: Container(
              key: const Key('conversation.tile.unreadPill'),
              constraints: BoxConstraints(
                minWidth: cp.sizes.iconLg,
                minHeight: cp.sizes.iconLg,
              ),
              padding: EdgeInsets.symmetric(horizontal: cp.space.sm),
              decoration: BoxDecoration(
                color: cp.colors.accent,
                borderRadius: cp.radii.pill,
              ),
              alignment: Alignment.center,
              child: Text(
                _unreadLabel(),
                style: cp.type.labelMedium.copyWith(color: cp.colors.onAccent),
              ),
            ),
          )
        : null;

    final time = Text(
      timestamp,
      style: cp.type.labelMedium.copyWith(
        color: hasUnread ? cp.colors.accent : cp.colors.textMuted,
      ),
    );

    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.xs,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: cp.type.titleSmall.copyWith(
            color: cp.colors.text,
            fontWeight: hasUnread ? FontWeight.w700 : null,
          ),
        ),
        if (preview.isNotEmpty)
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: cp.type.bodyMedium.copyWith(
              color: hasUnread ? cp.colors.text : cp.colors.textMuted,
            ),
          ),
        if (isUrgent)
          Padding(
            padding: EdgeInsets.only(top: cp.space.xs),
            child: KeyedSubtree(
              key: const Key('conversation.tile.urgentBadge'),
              child: CpStatusChip(
                status: CpStatus.overdue,
                label: strings.urgentBadge,
              ),
            ),
          ),
      ],
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: cp.sizes.rowMinHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: cp.space.lg,
                  vertical: cp.space.md,
                ),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    final side = Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: cp.space.xs,
                      children: [time, ?pill],
                    );
                    // Large text: the icon, time and count go above the
                    // words, so the title and message keep the full width.
                    if (box.maxWidth / scale < 260) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: cp.space.sm,
                        children: [
                          Row(
                            spacing: cp.space.sm,
                            children: [lead, const Spacer(), time, ?pill],
                          ),
                          texts,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: cp.space.md,
                      children: [
                        lead,
                        Expanded(child: texts),
                        side,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
