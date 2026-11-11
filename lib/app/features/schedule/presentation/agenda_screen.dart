import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/last_updated_note.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/schedule/data/my_records_repository.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/agenda.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:crewpoint_app/app/features/schedule/presentation/session_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// `agenda` (Req 51): the sessions the viewer and their group attend, with
/// what is on now and next. Read from the viewer's own records, mirrored for
/// offline use (Req 74). Someone with no attendee record sees the whole
/// schedule.
class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  /// One person to narrow to, or null for everyone in the viewer's records.
  String? _personId;

  void _retry() {
    ref.invalidate(sessionListProvider(widget.event.id));
    ref.invalidate(myRecordsProvider(widget.event.id));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.agenda;
    final event = widget.event;
    final sessions = ref.watch(sessionListProvider(event.id));
    final records = ref.watch(myRecordsProvider(event.id));
    final now =
        ref.watch(minuteProvider).value ?? ref.watch(clockProvider).now();

    final Widget body;
    if (sessions.hasValue && records.hasValue) {
      body = _body(event, sessions.requireValue, records.requireValue, now);
    } else if (sessions.hasError || records.hasError) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.md,
            children: [
              Text(
                strings.loadFailed,
                key: const Key('agenda.error'),
                textAlign: TextAlign.center,
              ),
              FilledButton.icon(
                key: const Key('agenda.retry'),
                onPressed: _retry,
                icon: const Icon(AppIcons.actionRetry),
                label: Text(strings.retry),
              ),
            ],
          ),
        ),
      );
    } else {
      body = const Center(
        child: CircularProgressIndicator(key: Key('agenda.loading')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.title),
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('agenda.schedule'),
            tooltip: strings.wholeSchedule,
            onPressed: () =>
                context.push('/dashboard/event/${event.id}/schedule'),
            icon: const Icon(AppIcons.calendar),
          ),
        ],
      ),
      body: Column(
        children: [
          LastUpdatedNote(mirrorKey: MyRecordsRepository.mirrorKey(event.id)),
          Expanded(child: ContentMaxWidth(maxWidth: 720, child: body)),
        ],
      ),
    );
  }

  Widget _body(
    EventModel event,
    List<SessionModel> sessions,
    OwnRecords records,
    DateTime now,
  ) {
    final strings = context.strings.agenda;
    final theme = Theme.of(context);
    final people = records.people;
    final hasRecord = people.isNotEmpty;
    final chosen = people.where((p) => p.id == _personId).toList();
    final List<AgendaEntry> agenda = hasRecord
        ? buildAgenda(
            policy: event.attendancePolicy,
            sessions: sessions,
            people: chosen.isEmpty ? people : chosen,
            groupInvitations: records.groupInvitations,
          )
        // No attendee record: the whole visible schedule.
        : [
            for (final s
                in sessions.where((s) => !s.hidden).toList()
                  ..sort((a, b) => a.startAt.compareTo(b.startAt)))
              (session: s, people: const <ParticipantModel>[]),
          ];
    final current = nowAndNext(agenda, now);

    String? who(AgendaEntry e) => hasRecord && people.length > 1
        ? e.people.map((p) => p.name).join(', ')
        : null;

    Widget entryTile(
      AgendaEntry e, {
      bool withDay = false,
      String keyPrefix = 'schedule.tile',
    }) => SessionTile(
      event: event,
      session: e.session,
      withDay: withDay,
      note: who(e),
      keyPrefix: keyPrefix,
    );

    final padding = Breakpoints.screenHorizontalPadding(context);
    return ListView(
      key: const Key('agenda.list'),
      padding: EdgeInsets.fromLTRB(padding, AppSpacing.md, padding, 48),
      children: [
        if (!hasRecord)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              strings.noRecord,
              key: const Key('agenda.noRecord'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (people.length > 1)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                key: const Key('agenda.person.all'),
                label: Text(strings.everyoneInGroup),
                selected: chosen.isEmpty,
                onSelected: (_) => setState(() => _personId = null),
              ),
              for (final p in [
                ...people,
              ]..sort((a, b) => a.name.compareTo(b.name)))
                ChoiceChip(
                  key: Key('agenda.person.${p.id}'),
                  label: Text(p.name),
                  selected: p.id == _personId,
                  onSelected: (_) => setState(() => _personId = p.id),
                ),
            ],
          ),
        if (agenda.isEmpty)
          Padding(
            key: const Key('agenda.empty'),
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
                  strings.empty,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          Card(
            key: const Key('agenda.nowAndNext'),
            margin: const EdgeInsets.only(top: AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      strings.now,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (current.now.isEmpty)
                    Text(strings.nothingNow, key: const Key('agenda.now.none'))
                  else
                    for (final e in current.now)
                      KeyedSubtree(
                        key: Key('agenda.now.${e.session.id}'),
                        child: entryTile(e, keyPrefix: 'agenda.nowTile'),
                      ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      strings.next,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (current.next case final next?)
                    KeyedSubtree(
                      key: Key('agenda.next.${next.session.id}'),
                      child: entryTile(
                        next,
                        withDay: true,
                        keyPrefix: 'agenda.nextTile',
                      ),
                    )
                  else
                    Text(
                      strings.nothingNext,
                      key: const Key('agenda.next.none'),
                    ),
                ],
              ),
            ),
          ),
          for (final day in _days(event, agenda)) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Semantics(
                header: true,
                child: Text(
                  DateFormat.yMMMMEEEEd().format(day.day),
                  key: Key(
                    'agenda.day.${DateFormat('yyyy-MM-dd').format(day.day)}',
                  ),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            for (final e in day.entries) entryTile(e),
          ],
        ],
      ],
    );
  }

  /// The agenda by the calendar day each session starts on, where the event is.
  List<({DateTime day, List<AgendaEntry> entries})> _days(
    EventModel event,
    List<AgendaEntry> agenda,
  ) {
    final byId = {for (final e in agenda) e.session.id: e};
    return [
      for (final d in byDay(event, [for (final e in agenda) e.session]))
        (day: d.day, entries: [for (final s in d.sessions) byId[s.id]!]),
    ];
  }
}
