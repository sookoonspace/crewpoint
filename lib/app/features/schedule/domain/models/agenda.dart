import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';

/// One session on a personal agenda, with who from the viewer's records
/// attends it (Req 51).
typedef AgendaEntry = ({SessionModel session, List<ParticipantModel> people});

/// How long a session with no end counts as on, for now and next.
const sessionWithoutEndLasts = Duration(hours: 1);

/// The sessions anyone in [people] attends, in time order, with who attends
/// each. [people] are the viewer's own records: themselves and their group.
/// [groupInvitations] are each group's invited session IDs. Hidden sessions
/// never appear.
List<AgendaEntry> buildAgenda({
  required AttendancePolicy policy,
  required Iterable<SessionModel> sessions,
  required List<ParticipantModel> people,
  Map<String, List<String>> groupInvitations = const {},
}) {
  final attendees = [
    for (final p in people)
      (p, p.attendee(groupInvitations[p.groupId] ?? const [])),
  ];
  final ordered = sessions.where((s) => !s.hidden).toList()
    ..sort((a, b) {
      final byTime = a.startAt.compareTo(b.startAt);
      return byTime != 0 ? byTime : a.title.compareTo(b.title);
    });
  return [
    for (final s in ordered)
      if ([
            for (final (p, a) in attendees)
              if (attends(policy: policy, session: s, person: a)) p,
          ]
          case final going when going.isNotEmpty)
        (session: s, people: going),
  ];
}

/// What is on at [now], and the next session to start.
({List<AgendaEntry> now, AgendaEntry? next}) nowAndNext(
  List<AgendaEntry> agenda,
  DateTime now,
) {
  final on = <AgendaEntry>[];
  AgendaEntry? next;
  for (final e in agenda) {
    final start = e.session.startAt;
    final end = e.session.endAt ?? start.add(sessionWithoutEndLasts);
    if (!now.isBefore(start) && now.isBefore(end)) {
      on.add(e);
    } else if (start.isAfter(now)) {
      next ??= e;
    }
  }
  return (now: on, next: next);
}
