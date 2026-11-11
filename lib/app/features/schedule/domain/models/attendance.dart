import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:flutter/foundation.dart';

/// How an event, or one session, decides who attends (Req 50). Stored by
/// name in `settings.attendancePolicy` and on a session as `attendance`.
enum AttendancePolicy {
  /// Sessions within a person's arrival and departure.
  arrivalToDeparture,

  /// Sessions a person or their group was invited to.
  invitedOnly,

  /// All sessions.
  everyone,

  /// Each person chooses, and nothing is assumed.
  bySession;

  /// A stored name, or everyone when missing or unknown.
  static AttendancePolicy of(Object? name) => tryParse(name) ?? everyone;

  /// A stored name, or null when missing or unknown.
  static AttendancePolicy? tryParse(Object? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// What attendance needs to know about one person: their own record and
/// their group's invitations. Only exceptions are stored (Req 50).
@immutable
class Attendee {
  const Attendee({
    this.status = 'active',
    this.categoryId,
    this.filterTags = const [],
    this.arrivalAt,
    this.departureAt,
    this.optOuts = const [],
    this.signUps = const [],
    this.invitedTo = const [],
    this.groupInvitedTo = const [],
  });

  final String status;
  final String? categoryId;
  final List<String> filterTags;
  final DateTime? arrivalAt;
  final DateTime? departureAt;
  final List<String> optOuts;
  final List<String> signUps;
  final List<String> invitedTo;
  final List<String> groupInvitedTo;
}

/// Whether [person] attends [session] under the event's [policy]. The same
/// cases run against `functions/src/schedule/attendance.ts`.
///
/// Cancelled or opted out: no. Invited, alone or with their group: yes.
/// Otherwise the session's eligibility, then its own rule or the event's.
bool attends({
  required AttendancePolicy policy,
  required SessionModel session,
  required Attendee person,
}) {
  if (person.status == 'cancelled') return false;
  if (person.optOuts.contains(session.id)) return false;
  if (person.invitedTo.contains(session.id) ||
      person.groupInvitedTo.contains(session.id)) {
    return true;
  }
  if (!session.eligibility.admits(
    categoryId: person.categoryId,
    tags: person.filterTags,
  )) {
    return false;
  }
  return switch (session.attendance ?? policy) {
    AttendancePolicy.everyone => true,
    AttendancePolicy.invitedOnly => false,
    AttendancePolicy.bySession => person.signUps.contains(session.id),
    AttendancePolicy.arrivalToDeparture =>
      (person.arrivalAt == null ||
              !session.startAt.isBefore(person.arrivalAt!)) &&
          (person.departureAt == null ||
              session.startAt.isBefore(person.departureAt!)),
  };
}

/// A person's exceptions after a change.
typedef AttendanceExceptions = ({
  List<String> optOuts,
  List<String> signUps,
  List<String> invitedTo,
});

/// Changes whether [person] attends [session], storing the smallest
/// exception (Req 50): removing an opt-out, sign-up or invitation where that
/// is enough, else adding one. Only [canInvite] (`participants.edit`) adds
/// or removes invitations. Null when the change is not allowed, such as a
/// group's adult adding a session outside their stay.
AttendanceExceptions? setAttending({
  required AttendancePolicy policy,
  required SessionModel session,
  required Attendee person,
  required bool attend,
  required bool canInvite,
}) {
  final id = session.id;
  var optOuts = [...person.optOuts];
  var signUps = [...person.signUps];
  var invitedTo = [...person.invitedTo];
  bool goes() => attends(
    policy: policy,
    session: session,
    person: Attendee(
      status: person.status,
      categoryId: person.categoryId,
      filterTags: person.filterTags,
      arrivalAt: person.arrivalAt,
      departureAt: person.departureAt,
      optOuts: optOuts,
      signUps: signUps,
      invitedTo: invitedTo,
      groupInvitedTo: person.groupInvitedTo,
    ),
  );

  if (attend) {
    optOuts = [...optOuts]..remove(id);
    if (goes()) {
      return (optOuts: optOuts, signUps: signUps, invitedTo: invitedTo);
    }
    if ((session.attendance ?? policy) == AttendancePolicy.bySession) {
      signUps = [...signUps, id];
      if (goes()) {
        return (optOuts: optOuts, signUps: signUps, invitedTo: invitedTo);
      }
      signUps = [...signUps]..remove(id);
    }
    if (!canInvite) return null;
    invitedTo = [...invitedTo, id];
    return (optOuts: optOuts, signUps: signUps, invitedTo: invitedTo);
  }

  signUps = [...signUps]..remove(id);
  if (canInvite) invitedTo = [...invitedTo]..remove(id);
  if (goes()) optOuts = [...optOuts, id];
  return (optOuts: optOuts, signUps: signUps, invitedTo: invitedTo);
}
