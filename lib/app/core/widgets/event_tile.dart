import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/format/event_date_range.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/event_type_emoji.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_status_label.dart';

/// An event on the event list (Spec #186, #199): its cover thumbnail, title,
/// dates and people, and on the right whether it is live or a draft, or
/// else how many of its tasks are done. Stateless; the host (`EventCard`)
/// passes the task counts and the thumbnail.
class EventTile extends StatelessWidget {
  const EventTile({
    super.key,
    required this.event,
    required this.todo,
    required this.doing,
    required this.done,
    this.onTap,
    this.leading,
  });

  final EventModel event;
  final int todo;
  final int doing;
  final int done;
  final VoidCallback? onTap;

  /// The event's cover thumbnail (Spec #186 Req 43); without one, its icon.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final dates = formatEventDateRange(event.displayStart, event.displayEnd);
    final total = todo + doing + done;
    final strings = context.strings.dashboard;
    final Widget? trailing = switch (event.status) {
      EventStatus.live => CpTag(
        label: eventStatusLabel(strings, event.status),
        dot: true,
      ),
      EventStatus.draft || EventStatus.archived => CpTag(
        label: eventStatusLabel(strings, event.status),
        tone: CpTagTone.quiet,
      ),
      _ when total > 0 => KeyedSubtree(
        key: Key('event.tile.${event.id}.ring'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: cp.space.xs + 2,
          children: [
            CpProgressRing(
              value: done / total,
              semanticLabel: context.strings.eventHome.tasksDone(done, total),
              size: cp.sizes.iconXl,
              strokeWidth: cp.sizes.ringStroke - 1,
            ),
            Text(
              '$done/$total',
              style: cp.type.labelMedium.copyWith(color: cp.colors.text),
            ),
          ],
        ),
      ),
      _ => null,
    };
    return CpCard(
      key: Key('event.tile.${event.id}'),
      onTap: onTap,
      semanticLabel: [
        event.title,
        if (dates.isNotEmpty) dates,
        event.words.count('member', event.memberCount),
      ].join(', '),
      padding: EdgeInsets.all(cp.space.md),
      child: Row(
        spacing: cp.space.md,
        children: [
          leading ??
              CpCoverThumb(
                icon: iconForEventType(event.displayType),
                size: cp.sizes.tapMin,
              ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: cp.space.xs / 2,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: cp.type.titleSmall.copyWith(
                    color: cp.colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (dates.isNotEmpty)
                  Row(
                    spacing: cp.space.xs,
                    children: [
                      Icon(
                        CpIcons.calendar,
                        size: cp.sizes.iconXs,
                        color: cp.colors.textMuted,
                      ),
                      Flexible(
                        child: Text(
                          dates,
                          style: cp.type.bodySmall.copyWith(
                            color: cp.colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                Text(
                  event.words.count('member', event.memberCount),
                  style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
