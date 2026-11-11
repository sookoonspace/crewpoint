import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:crewpoint_app/app/features/schedule/presentation/session_tile.dart';
import 'package:crewpoint_app/app/features/schedule/presentation/venue_card.dart';
import 'package:crewpoint_app/app/core/widgets/last_updated_note.dart';
import 'package:crewpoint_app/app/features/schedule/data/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum _View { day, venue }

/// The event's schedule (Req 48, 49), grouped by day or by venue. Every
/// member reads it; `schedule.edit` adds sessions and sees hidden ones.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  _View _view = _View.day;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.schedule;
    final event = widget.event;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final edits = event.canEditSchedule(me);
    final sessions = ref.watch(sessionListProvider(event.id));
    final words = event.words;

    return Scaffold(
      appBar: AppBar(title: Text(strings.title), elevation: 0),
      floatingActionButton: edits
          ? FloatingActionButton.extended(
              key: const Key('schedule.add'),
              onPressed: () =>
                  context.push('/dashboard/event/${event.id}/schedule/new'),
              icon: const Icon(AppIcons.actionAdd),
              label: Text(strings.add(words.one('session'))),
            )
          : null,
      body: Column(
        children: [
          LastUpdatedNote(mirrorKey: SessionRepository.mirrorKey(event.id)),
          Expanded(
            child: ContentMaxWidth(
              maxWidth: 720,
              child: switch (sessions) {
                AsyncValue(:final value?) => _body(event, value, edits),
                AsyncValue(error: != null) => _Failed(
                  onRetry: () => ref.invalidate(sessionListProvider(event.id)),
                ),
                _ => const Center(
                  child: CircularProgressIndicator(
                    key: Key('schedule.loading'),
                  ),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(EventModel event, List<SessionModel> sessions, bool edits) {
    final strings = context.strings.schedule;
    final theme = Theme.of(context);
    final padding = EdgeInsets.fromLTRB(
      Breakpoints.screenHorizontalPadding(context),
      AppSpacing.md,
      Breakpoints.screenHorizontalPadding(context),
      96,
    );
    final picker = SegmentedButton<_View>(
      key: const Key('schedule.view'),
      segments: [
        ButtonSegment(
          value: _View.day,
          label: Text(strings.byDay, key: const Key('schedule.view.day')),
        ),
        ButtonSegment(
          value: _View.venue,
          label: Text(strings.byVenue, key: const Key('schedule.view.venue')),
        ),
      ],
      selected: {_view},
      onSelectionChanged: (v) => setState(() => _view = v.single),
    );

    final empty =
        sessions.isEmpty && (_view == _View.day || event.venues.isEmpty);
    final children = <Widget>[
      picker,
      if (empty)
        Padding(
          key: const Key('schedule.empty'),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            spacing: AppSpacing.sm,
            children: [
              Icon(
                AppIcons.calendar,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Text(
                strings.noneYet(event.words.other('session')),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (edits)
                Text(strings.noneYetEditorHint, textAlign: TextAlign.center),
            ],
          ),
        )
      else if (_view == _View.day)
        for (final day in byDay(event, sessions)) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Semantics(
              header: true,
              child: Text(
                DateFormat.yMMMMEEEEd().format(day.day),
                key: Key(
                  'schedule.day.${DateFormat('yyyy-MM-dd').format(day.day)}',
                ),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          for (final s in day.sessions) SessionTile(event: event, session: s),
        ]
      else
        for (final group in byVenue(event, sessions))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: VenueCard(
              venue: group.venue,
              children: [
                for (final s in group.sessions)
                  SessionTile(
                    event: event,
                    session: s,
                    withDay: true,
                    showVenue: false,
                  ),
              ],
            ),
          ),
    ];

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sessionListProvider(event.id)),
      child: ListView(
        key: const Key('schedule.list'),
        padding: padding,
        children: children,
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.schedule;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.md,
          children: [
            Text(
              strings.loadFailed,
              key: const Key('schedule.error'),
              textAlign: TextAlign.center,
            ),
            FilledButton.icon(
              key: const Key('schedule.retry'),
              onPressed: onRetry,
              icon: const Icon(AppIcons.actionRetry),
              label: Text(strings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
