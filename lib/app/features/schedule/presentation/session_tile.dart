import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/agenda.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/schedule.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';

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

/// Who a session is for, as names: categories, then field answers. Empty
/// for everyone.
List<String> eligibilityNames(
  BuildContext context,
  EventModel event,
  SessionEligibility e,
  List<CustomField> fields,
) {
  if (e.isEveryone) return const [];
  final categories = {
    for (final c in categoriesOf(event.settings)) c.id: c.name,
  };
  final labels = {for (final f in fields) f.id: f};
  String answer(String tag) {
    final i = tag.indexOf('=');
    if (i < 0) return tag;
    final field = labels[tag.substring(0, i)];
    final value = tag.substring(i + 1);
    if (field == null) return value;
    final shown = field.type == FieldType.yesNo
        ? (value == 'yes'
              ? context.strings.fields.yes
              : context.strings.fields.no)
        : value;
    return '${field.label}: $shown';
  }

  return [
    for (final id in e.categoryIds) categories[id] ?? id,
    for (final tag in e.filterTags) answer(tag),
  ];
}

/// Who a session is for, in words: "For everyone" or "For Adult, Child".
String eligibilityLabel(
  BuildContext context,
  EventModel event,
  SessionEligibility e,
  List<CustomField> fields,
) {
  final strings = context.strings.schedule;
  if (e.isEveryone) return strings.forEveryone;
  return strings.forOnly(
    eligibilityNames(context, event, e, fields).join(', '),
  );
}

/// Whether [session] is on at [now]; one with no end lasts an hour.
bool sessionIsOn(SessionModel session, DateTime now) {
  final end = session.endAt ?? session.startAt.add(sessionWithoutEndLasts);
  return !now.isBefore(session.startAt) && now.isBefore(end);
}

/// Whether [session] is over at [now].
bool sessionIsOver(SessionModel session, DateTime now) {
  final end = session.endAt ?? session.startAt.add(sessionWithoutEndLasts);
  return !now.isBefore(end);
}

/// One session in a schedule list (Spec #186): its start time beside the
/// title, where it is, and tags for now, who it is for, capacity, a
/// placeholder time and a hidden draft. A session that is over is muted.
/// Opens `schedule/:sessionId`. Put it in a [CpRowGroup].
class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.event,
    required this.session,
    this.withDay = false,
    this.showVenue = true,
    this.note,
    this.now,
    this.fields = const [],
    this.keyPrefix = 'schedule.tile',
  });

  final EventModel event;
  final SessionModel session;

  /// Shows the date too, where sessions of several days are mixed.
  final bool withDay;
  final bool showVenue;

  /// An extra line, such as who from the viewer's group attends.
  final String? note;

  /// The time now, for the Now tag and dimming what is over; none without.
  final DateTime? now;

  /// The event's fields, to name answers in who a session is for.
  final List<CustomField> fields;

  /// Keys are `{keyPrefix}.{sessionId}`, so the same session can show twice.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.schedule;
    final id = session.id;
    final venue = venueOf(event, session);
    final where =
        venue?.name ?? (session.locationTba ? strings.locationTba : null);
    final start = event.inZone(session.startAt);
    final end = session.endAt == null ? null : event.inZone(session.endAt!);
    final at = now;
    final on = at != null && sessionIsOn(session, at);
    final over = at != null && !on && sessionIsOver(session, at);
    final who = eligibilityNames(context, event, session.eligibility, fields);

    // "7:00" over "PM", as in the approved mockup.
    final hm = DateFormat.jm().format(start);
    final split = hm.lastIndexOf(RegExp(r'\s'));
    final clock = split < 0 ? hm : hm.substring(0, split);
    final period = split < 0 ? '' : hm.substring(split + 1);
    final details = [
      if (withDay) DateFormat.MMMEd().format(start),
      if (end != null) '$hm – ${DateFormat.jm().format(end)}',
      ?session.type,
    ].join(' · ');

    final tags = <Widget>[
      if (on)
        CpTag(
          key: Key('$keyPrefix.$id.now'),
          label: context.strings.agenda.now,
          dot: true,
        ),
      if (session.timeTbc)
        CpTag(
          key: Key('$keyPrefix.$id.tbc'),
          label: strings.timeTbc,
          tone: CpTagTone.quiet,
          icon: CpIcons.statusInfo,
        ),
      if (session.hidden)
        CpTag(
          key: Key('$keyPrefix.$id.hidden'),
          label: strings.hiddenDraft,
          tone: CpTagTone.quiet,
          icon: CpIcons.lock,
        ),
      if (who.isNotEmpty) CpTag(label: who.join(', '), tone: CpTagTone.quiet),
      if (session.capacity != null)
        CpTag(
          label: strings.capacity(session.capacity!),
          tone: CpTagTone.quiet,
        ),
      for (final tag in session.tags) CpTag(label: tag, tone: CpTagTone.quiet),
    ];

    final muted = cp.type.bodySmall.copyWith(color: cp.colors.textMuted);
    // Over: title and time in the muted colour, still readable (Req 45).
    final ink = over ? cp.colors.textMuted : cp.colors.text;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: cp.space.xs,
      children: [
        Text(session.title, style: cp.type.titleSmall.copyWith(color: ink)),
        if (showVenue && where != null)
          Row(
            spacing: cp.space.xs,
            children: [
              Icon(
                CpIcons.place,
                size: cp.sizes.iconSm,
                color: cp.colors.textMuted,
              ),
              Flexible(child: Text(where, style: muted)),
            ],
          ),
        if (details.isNotEmpty) Text(details, style: muted),
        if (note != null)
          Text(note!, key: Key('$keyPrefix.$id.note'), style: muted),
        if (tags.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: cp.space.xs),
            child: Wrap(
              spacing: cp.space.xs,
              runSpacing: cp.space.xs,
              children: tags,
            ),
          ),
      ],
    );

    final timeStyle = cp.type.titleSmall.copyWith(
      color: ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final periodStyle = cp.type.labelSmall.copyWith(color: cp.colors.textMuted);
    final chevron = Icon(
      CpIcons.chevronRight,
      size: cp.sizes.iconMd,
      color: cp.colors.textMuted,
    );

    final row = LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        // Large text: the time goes above the title, so neither breaks.
        final stacked = box.maxWidth / scale < 300;
        final time = stacked
            ? Text(hm, style: timeStyle)
            : SizedBox(
                width: cp.sizes.timeColumn,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clock, style: timeStyle),
                    if (period.isNotEmpty) Text(period, style: periodStyle),
                  ],
                ),
              );
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: cp.space.lg,
            vertical: cp.space.md,
          ),
          child: Row(
            spacing: cp.space.md,
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (!stacked) time,
              Expanded(
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: cp.space.xs,
                        children: [time, body],
                      )
                    : body,
              ),
              chevron,
            ],
          ),
        );
      },
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: Key('$keyPrefix.$id'),
            onTap: () =>
                context.push('/dashboard/event/${event.id}/schedule/$id'),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: cp.sizes.rowMinHeight),
              child: row,
            ),
          ),
        ),
      ),
    );
  }
}
