import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';

/// By-sign-up sessions as per-person choices on the registration form
/// (Spec #233 Req 17; #242, W-01). A session is by sign-up when its own
/// attendance, or else the event's policy, is `bySession`; sessions at the
/// same time (overlapping, chained) form one either/or choice, so a person
/// picks at most one of them. A session with no end lasts an hour, as on
/// the agenda. Hidden drafts are never offered. The server's
/// `functions/src/registration/sessionChoices.ts` runs the same cases
/// (`functions/test/fixtures/session_choice_cases.json`); change them
/// together.
///
/// Returns the choices in time order; each is one session or an either/or.
List<List<SessionModel>> signUpChoices(
  AttendancePolicy policy,
  Iterable<SessionModel> sessions,
) {
  const hour = Duration(hours: 1);
  final offered =
      sessions
          .where((s) => !s.hidden)
          .where((s) => (s.attendance ?? policy) == AttendancePolicy.bySession)
          .toList()
        ..sort((a, b) {
          final byStart = a.startAt.compareTo(b.startAt);
          return byStart != 0 ? byStart : a.id.compareTo(b.id);
        });
  final choices = <List<SessionModel>>[];
  DateTime? lastEnd;
  for (final s in offered) {
    final end = s.endAt ?? s.startAt.add(hour);
    if (lastEnd != null && s.startAt.isBefore(lastEnd)) {
      choices.last.add(s);
      if (end.isAfter(lastEnd)) lastEnd = end;
    } else {
      choices.add([s]);
      lastEnd = end;
    }
  }
  return choices;
}

/// Whether [signUps] picks only offered sessions, at most one per choice.
/// [choices] are session IDs, as [signUpChoices] groups them.
bool validSignUps(List<List<String>> choices, Set<String> signUps) {
  final choiceOf = {
    for (var i = 0; i < choices.length; i++)
      for (final id in choices[i]) id: i,
  };
  final used = <int>{};
  for (final id in signUps) {
    final i = choiceOf[id];
    if (i == null || !used.add(i)) return false;
  }
  return true;
}
