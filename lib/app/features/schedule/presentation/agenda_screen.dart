import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/core/widgets/last_updated_note.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart'
    show eventFieldsProvider;
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
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

/// `agenda` (Req 51; Spec #186): the sessions the viewer and their group attend, with
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
    final cp = context.cp;
    final strings = context.strings.agenda;
    final event = widget.event;
    final sessions = ref.watch(sessionListProvider(event.id));
    final records = ref.watch(myRecordsProvider(event.id));
    final now =
        ref.watch(minuteProvider).value ?? ref.watch(clockProvider).now();
    final navigator = Navigator.of(context);

    final Widget body;
    if (sessions.hasValue && records.hasValue) {
      body = _body(event, sessions.requireValue, records.requireValue, now);
    } else if (sessions.hasError || records.hasError) {
      body = CpErrorState(
        key: const Key('agenda.error'),
        title: strings.loadFailed,
        retryLabel: strings.retry,
        retryKey: const Key('agenda.retry'),
        onRetry: _retry,
      );
    } else {
      body = CpLoadingState.rows(
        key: const Key('agenda.loading'),
        semanticLabel: strings.title,
      );
    }

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: strings.title,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: navigator.canPop() ? () => navigator.maybePop() : null,
        actions: [
          CpTopBarAction(
            key: const Key('agenda.schedule'),
            tooltip: strings.wholeSchedule,
            onPressed: () =>
                context.push('/dashboard/event/${event.id}/schedule'),
            icon: CpIcons.calendar,
          ),
        ],
      ),
      body: Column(
        children: [
          LastUpdatedNote(mirrorKey: MyRecordsRepository.mirrorKey(event.id)),
          Expanded(child: body),
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
    final cp = context.cp;
    final strings = context.strings.agenda;
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
    final fields =
        ref.watch(eventFieldsProvider(event.id)).value ?? const <CustomField>[];

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
      now: now,
      fields: fields,
      keyPrefix: keyPrefix,
    );

    Widget heading(String text, {Key? key}) => Semantics(
      header: true,
      child: Text(
        text,
        key: key,
        style: cp.type.titleMedium.copyWith(color: cp.colors.text),
      ),
    );

    Widget quiet(String text, Key key) => CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Text(
        text,
        key: key,
        style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
      ),
    );

    return ListView(
      key: const Key('agenda.list'),
      padding: EdgeInsets.fromLTRB(
        cp.space.lg,
        cp.space.sm,
        cp.space.lg,
        cp.space.xxl,
      ),
      children: [
        ContentMaxWidth(
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.lg,
            children: [
              if (!hasRecord)
                Text(
                  strings.noRecord,
                  key: const Key('agenda.noRecord'),
                  style: cp.type.bodyMedium.copyWith(
                    color: cp.colors.textMuted,
                  ),
                ),
              if (people.length > 1)
                Wrap(
                  spacing: cp.space.sm,
                  runSpacing: cp.space.sm,
                  children: [
                    CpFilterChip(
                      key: const Key('agenda.person.all'),
                      label: strings.everyoneInGroup,
                      selected: chosen.isEmpty,
                      onTap: () => setState(() => _personId = null),
                    ),
                    for (final p in [
                      ...people,
                    ]..sort((a, b) => a.name.compareTo(b.name)))
                      CpFilterChip(
                        key: Key('agenda.person.${p.id}'),
                        label: p.name,
                        selected: p.id == _personId,
                        onTap: () => setState(() => _personId = p.id),
                      ),
                  ],
                ),
              if (agenda.isEmpty)
                CpEmptyState(
                  key: const Key('agenda.empty'),
                  icon: CpIcons.calendar,
                  title: strings.empty,
                )
              else ...[
                Column(
                  key: const Key('agenda.nowAndNext'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: cp.space.sm,
                  children: [
                    heading(strings.now),
                    if (current.now.isEmpty)
                      quiet(strings.nothingNow, const Key('agenda.now.none'))
                    else
                      CpCard(
                        child: CpRowGroup(
                          children: [
                            for (final e in current.now)
                              KeyedSubtree(
                                key: Key('agenda.now.${e.session.id}'),
                                child: entryTile(
                                  e,
                                  keyPrefix: 'agenda.nowTile',
                                ),
                              ),
                          ],
                        ),
                      ),
                    SizedBox(height: cp.space.sm),
                    heading(strings.next),
                    if (current.next case final next?)
                      CpCard(
                        child: KeyedSubtree(
                          key: Key('agenda.next.${next.session.id}'),
                          child: entryTile(
                            next,
                            withDay: true,
                            keyPrefix: 'agenda.nextTile',
                          ),
                        ),
                      )
                    else
                      quiet(strings.nothingNext, const Key('agenda.next.none')),
                  ],
                ),
                for (final day in _days(event, agenda))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: cp.space.sm,
                    children: [
                      heading(
                        DateFormat.yMMMMEEEEd().format(day.day),
                        key: Key(
                          'agenda.day.${DateFormat('yyyy-MM-dd').format(day.day)}',
                        ),
                      ),
                      CpCard(
                        child: CpRowGroup(
                          children: [for (final e in day.entries) entryTile(e)],
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
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
