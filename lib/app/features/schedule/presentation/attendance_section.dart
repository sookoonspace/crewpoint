import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:crewpoint_app/app/features/schedule/presentation/session_tile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A person's stay and the sessions they attend (Req 50), on the
/// participant screen. Each switch stores only the smallest exception, and
/// only [canInvite] adds invitations.
class AttendanceSection extends StatelessWidget {
  const AttendanceSection({
    super.key,
    required this.event,
    required this.sessions,
    required this.person,
    required this.enabled,
    required this.canInvite,
    required this.onStay,
    required this.onExceptions,
  });

  final EventModel event;

  /// The schedule as the viewer reads it.
  final List<SessionModel> sessions;
  final Attendee person;
  final bool enabled;
  final bool canInvite;
  final void Function({DateTime? arrivalAt, DateTime? departureAt}) onStay;
  final void Function(AttendanceExceptions) onExceptions;

  Future<DateTime?> _pick(BuildContext context, DateTime? current) async {
    final there = current == null ? null : event.inZone(current);
    final initial = there ?? event.displayStart ?? DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: there?.hour ?? 12,
        minute: there?.minute ?? 0,
      ),
    );
    if (time == null) return null;
    return eventLocalToUtc(
      day.year,
      day.month,
      day.day,
      event.timeZone,
      hour: time.hour,
      minute: time.minute,
    );
  }

  String _label(DateTime? at) =>
      at == null ? '—' : DateFormat.MMMEd().add_jm().format(event.inZone(at));

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.agenda;
    final theme = Theme.of(context);
    final policy = event.attendancePolicy;
    final visible = [
      for (final s in sessions)
        if (!s.hidden) s,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));

    Widget stay(String key, String label, DateTime? value, bool arrival) =>
        ListTile(
          key: Key('people.edit.$key'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.schedule),
          title: Text(label),
          subtitle: Text(_label(value)),
          onTap: enabled
              ? () async {
                  final picked = await _pick(context, value);
                  if (picked == null) return;
                  if (arrival) {
                    onStay(arrivalAt: picked, departureAt: person.departureAt);
                  } else {
                    onStay(arrivalAt: person.arrivalAt, departureAt: picked);
                  }
                }
              : null,
          trailing: enabled && value != null
              ? IconButton(
                  key: Key('people.edit.$key.clear'),
                  tooltip: strings.clearTime,
                  icon: const Icon(AppIcons.actionClose),
                  onPressed: () => arrival
                      ? onStay(departureAt: person.departureAt)
                      : onStay(arrivalAt: person.arrivalAt),
                )
              : null,
        );

    String reason(SessionModel s, bool going) {
      if (person.optOuts.contains(s.id)) return strings.optedOut;
      if (person.invitedTo.contains(s.id) ||
          person.groupInvitedTo.contains(s.id)) {
        return strings.invited;
      }
      if (person.signUps.contains(s.id)) return strings.signedUp;
      return going ? strings.attends : strings.notAttending;
    }

    final badOrder =
        person.arrivalAt != null &&
        person.departureAt != null &&
        person.departureAt!.isBefore(person.arrivalAt!);

    return Column(
      key: const Key('people.edit.attendance'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xs,
      children: [
        Text(strings.attendanceHeading, style: theme.textTheme.titleSmall),
        Text(strings.policyHelp(policy.name), style: theme.textTheme.bodySmall),
        stay('arrival', strings.arrivalLabel, person.arrivalAt, true),
        stay('departure', strings.departureLabel, person.departureAt, false),
        if (badOrder)
          Text(
            strings.departureBeforeArrival,
            key: const Key('people.edit.stayError'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            strings.sessionsHeading,
            style: theme.textTheme.titleSmall,
          ),
        ),
        if (visible.isEmpty)
          Text(strings.sessionsNone, style: theme.textTheme.bodySmall)
        else
          for (final s in visible)
            Builder(
              builder: (_) {
                final going = attends(
                  policy: policy,
                  session: s,
                  person: person,
                );
                AttendanceExceptions? change(bool on) => setAttending(
                  policy: policy,
                  session: s,
                  person: person,
                  attend: on,
                  canInvite: canInvite,
                );
                final allowed = change(!going) != null;
                return SwitchListTile(
                  key: Key('people.edit.session.${s.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.title),
                  subtitle: Text(
                    [
                      sessionTimeLabel(event, s, withDay: true),
                      reason(s, going),
                      if (!allowed && enabled) strings.onlyOrganizersInvite,
                    ].join(' · '),
                  ),
                  value: going,
                  onChanged: enabled && allowed
                      ? (on) => onExceptions(change(on)!)
                      : null,
                );
              },
            ),
      ],
    );
  }
}
