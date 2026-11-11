import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// "7:00 PM – 9:00 PM" where the event is, with the day first when
/// [withDay].
String sessionTimeLabel(
  EventModel event,
  SessionModel session, {
  bool withDay = false,
}) {
  final start = event.inZone(session.startAt);
  final end = session.endAt == null ? null : event.inZone(session.endAt!);
  final time = DateFormat.jm();
  final range = end == null
      ? time.format(start)
      : '${time.format(start)} – ${time.format(end)}';
  return withDay ? '${DateFormat.MMMEd().format(start)}, $range' : range;
}

/// One session in a schedule list. Opens `schedule/:sessionId`.
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.event,
    required this.session,
    this.withDay = false,
    this.showVenue = true,
  });

  final EventModel event;
  final SessionModel session;
  final bool withDay;
  final bool showVenue;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.schedule;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final venue = venueOf(event, session);
    final where =
        venue?.name ?? (session.locationTba ? strings.locationTba : null);
    final details = [?session.type, if (showVenue) ?where].join(' · ');

    return ListTile(
      key: Key('schedule.tile.${session.id}'),
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: AppSpacing.sm,
      onTap: () =>
          context.push('/dashboard/event/${event.id}/schedule/${session.id}'),
      title: Text(session.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          Text(
            sessionTimeLabel(event, session, withDay: withDay),
            style: theme.textTheme.bodyMedium,
          ),
          if (details.isNotEmpty) Text(details, style: muted),
          if (session.timeTbc || session.hidden || session.tags.isNotEmpty)
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (session.timeTbc)
                  _Badge(
                    key: Key('schedule.tile.${session.id}.tbc'),
                    label: strings.timeTbc,
                    color: theme.colorScheme.tertiaryContainer,
                    onColor: theme.colorScheme.onTertiaryContainer,
                  ),
                if (session.hidden)
                  _Badge(
                    key: Key('schedule.tile.${session.id}.hidden'),
                    label: strings.hidden,
                    icon: AppIcons.hidden,
                    color: theme.colorScheme.surfaceContainerHighest,
                    onColor: theme.colorScheme.onSurfaceVariant,
                  ),
                for (final tag in session.tags)
                  _Badge(
                    label: tag,
                    color: theme.colorScheme.secondaryContainer,
                    onColor: theme.colorScheme.onSecondaryContainer,
                  ),
              ],
            ),
        ],
      ),
      trailing: const Icon(AppIcons.chevronRight),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    super.key,
    required this.label,
    required this.color,
    required this.onColor,
    this.icon,
  });

  final String label;
  final Color color;
  final Color onColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xs,
        children: [
          if (icon != null) Icon(icon, size: 14, color: onColor),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: onColor),
            ),
          ),
        ],
      ),
    ),
  );
}
