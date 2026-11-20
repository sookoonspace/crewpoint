import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import 'package:crewpoint_app/app/features/schedule/data/session_repository.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:crewpoint_app/app/features/schedule/presentation/session_tile.dart';
import 'package:crewpoint_app/app/features/schedule/presentation/venue_card.dart';

enum _View { day, venue }

/// `2027-07-17`, for keys.
String _dayKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

/// The event's schedule (Req 48, 49; Spec #186), by day or by venue. Every
/// member reads it; `schedule.edit` adds sessions and sees hidden drafts.
/// By day, a button for each day jumps to it, and the day under way is
/// chosen first.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  _View _view = _View.day;

  /// The day button last chosen, as [_dayKey]; null means the day under way.
  String? _day;
  final _dayHeaders = <String, GlobalKey>{};

  void _add() =>
      context.push('/dashboard/event/${widget.event.id}/schedule/new');

  void _jumpTo(String day) {
    setState(() => _day = day);
    final target = _dayHeaders[day]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: context.cp.motion.medium,
        curve: context.cp.motion.curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.schedule;
    final event = widget.event;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final edits = event.canEditSchedule(me);
    final sessions = ref.watch(sessionListProvider(event.id));
    final words = event.words;
    final navigator = Navigator.of(context);

    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: strings.title,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: navigator.canPop() ? () => navigator.maybePop() : null,
        actions: [
          if (edits)
            CpTopBarAction(
              key: const Key('schedule.add'),
              icon: CpIcons.actionAdd,
              tooltip: strings.add(words.one('session')),
              primary: true,
              onPressed: _add,
            ),
        ],
      ),
      body: Column(
        children: [
          LastUpdatedNote(mirrorKey: SessionRepository.mirrorKey(event.id)),
          Expanded(
            child: switch (sessions) {
              AsyncValue(:final value?) => _body(event, value, edits),
              AsyncValue(error: != null) => CpErrorState(
                key: const Key('schedule.error'),
                title: strings.loadFailed,
                retryLabel: strings.retry,
                retryKey: const Key('schedule.retry'),
                onRetry: () => ref.invalidate(sessionListProvider(event.id)),
              ),
              _ => CpLoadingState.rows(
                key: const Key('schedule.loading'),
                semanticLabel: strings.title,
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _body(EventModel event, List<SessionModel> sessions, bool edits) {
    final cp = context.cp;
    final strings = context.strings.schedule;
    final words = event.words;
    final now =
        ref.watch(minuteProvider).value ?? ref.watch(clockProvider).now();
    final fields =
        ref.watch(eventFieldsProvider(event.id)).value ?? const <CustomField>[];
    final bigText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final choices = [
      CpChoice(_View.day, strings.byDay, key: const Key('schedule.view.day')),
      CpChoice(
        _View.venue,
        strings.byVenue,
        key: const Key('schedule.view.venue'),
      ),
    ];
    // Large text: chips that wrap, rather than two squeezed halves.
    final picker = KeyedSubtree(
      key: const Key('schedule.view'),
      child: bigText
          ? CpChoiceChips<_View>(
              label: strings.viewLabel,
              choices: choices,
              selected: {_view},
              // Tapping the chosen view again keeps it.
              onChanged: (v) {
                if (v.isNotEmpty) setState(() => _view = v.single);
              },
            )
          : CpSegmented<_View>(
              semanticLabel: strings.title,
              choices: choices,
              selected: _view,
              onChanged: (v) => setState(() => _view = v),
            ),
    );

    final empty =
        sessions.isEmpty && (_view == _View.day || event.venues.isEmpty);
    final days = byDay(event, sessions);
    final today = _dayKey(event.inZone(now));
    final chosen =
        _day ??
        (days.any((d) => _dayKey(d.day) == today)
            ? today
            : (days.isEmpty ? null : _dayKey(days.first.day)));

    Widget tile(SessionModel s, {bool withDay = false, bool venue = true}) =>
        SessionTile(
          event: event,
          session: s,
          withDay: withDay,
          showVenue: venue,
          now: now,
          fields: fields,
        );

    final children = <Widget>[
      picker,
      if (empty)
        CpEmptyState(
          key: const Key('schedule.empty'),
          icon: CpIcons.calendar,
          title: strings.noneYet(words.other('session')),
          message: edits ? strings.noneYetEditorHint : null,
          actionLabel: edits ? strings.add(words.one('session')) : null,
          actionKey: const Key('schedule.empty.add'),
          onAction: edits ? _add : null,
        )
      else if (_view == _View.day) ...[
        if (days.length > 1)
          SingleChildScrollView(
            key: const Key('schedule.days'),
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: cp.space.sm,
              children: [
                for (final d in days)
                  _DayButton(
                    key: Key('schedule.dayPick.${_dayKey(d.day)}'),
                    day: d.day,
                    selected: _dayKey(d.day) == chosen,
                    onTap: () => _jumpTo(_dayKey(d.day)),
                  ),
              ],
            ),
          ),
        for (final day in days)
          Column(
            key: _dayHeaders.putIfAbsent(_dayKey(day.day), GlobalKey.new),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.sm,
            children: [
              Semantics(
                header: true,
                child: Text(
                  DateFormat.yMMMMEEEEd().format(day.day),
                  key: Key('schedule.day.${_dayKey(day.day)}'),
                  style: cp.type.titleMedium.copyWith(color: cp.colors.text),
                ),
              ),
              CpCard(
                child: CpRowGroup(
                  children: [for (final s in day.sessions) tile(s)],
                ),
              ),
            ],
          ),
      ] else
        for (final group in byVenue(event, sessions))
          VenueCard(
            venue: group.venue,
            children: [
              for (final s in group.sessions)
                tile(s, withDay: true, venue: false),
            ],
          ),
    ];

    return RefreshIndicator(
      color: cp.colors.accent,
      onRefresh: () async => ref.invalidate(sessionListProvider(event.id)),
      child: SingleChildScrollView(
        key: const Key('schedule.list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.sm,
          cp.space.lg,
          cp.space.xxl,
        ),
        child: ContentMaxWidth(
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.lg,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A day above the list: "SAT" over "17". Tapping it jumps to that day.
class _DayButton extends StatelessWidget {
  const _DayButton({
    super.key,
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final fg = selected ? cp.colors.accent : cp.colors.text;
    return Semantics(
      button: true,
      selected: selected,
      label: context.strings.schedule.goToDay(
        DateFormat.MMMMEEEEd().format(day),
      ),
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: cp.radii.pill,
          child: Container(
            constraints: BoxConstraints(
              minWidth: cp.sizes.tapMin,
              minHeight: cp.sizes.tapMin,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: cp.space.lg,
              vertical: cp.space.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? cp.colors.accentSoft : cp.colors.surface,
              borderRadius: cp.radii.pill,
              border: Border.all(
                color: selected ? cp.colors.accentSoft : cp.colors.border,
                width: cp.sizes.hairline,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.E().format(day).toUpperCase(),
                  style: cp.type.labelSmall.copyWith(color: fg),
                ),
                Text(
                  DateFormat.d().format(day),
                  style: cp.type.titleSmall.copyWith(
                    color: fg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
