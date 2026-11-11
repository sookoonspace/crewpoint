import 'dart:convert';
import 'dart:io';

import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 50 (J-06): the app works out attendance exactly as the server does,
/// from the same cases.
void main() {
  final cases =
      (jsonDecode(
                File(
                  'functions/test/fixtures/attendance_cases.json',
                ).readAsStringSync(),
              )
              as List<dynamic>)
          .cast<Map<String, dynamic>>();

  DateTime? time(Object? raw) => raw is String ? DateTime.parse(raw) : null;
  List<String> ids(Object? raw) => [
    if (raw is List)
      for (final v in raw) v as String,
  ];

  for (final c in cases) {
    test(c['name'] as String, () {
      final s = c['session'] as Map<String, dynamic>;
      final p = c['person'] as Map<String, dynamic>;
      final g = c['group'] as Map<String, dynamic>?;
      final session = SessionModel(
        id: s['id'] as String,
        title: '',
        startAt: time(s['startAt'])!,
        attendance: AttendancePolicy.tryParse(s['attendance']),
        eligibility: SessionEligibility.fromMap(s['eligibility']),
      );
      final person = Attendee(
        status: p['status'] as String? ?? 'active',
        categoryId: p['categoryId'] as String?,
        filterTags: ids(p['filterTags']),
        arrivalAt: time(p['arrivalAt']),
        departureAt: time(p['departureAt']),
        optOuts: ids(p['optOuts']),
        signUps: ids(p['signUps']),
        invitedTo: ids(p['invitedTo']),
        groupInvitedTo: ids(g?['invitedTo']),
      );
      expect(
        attends(
          policy: AttendancePolicy.of(c['policy']),
          session: session,
          person: person,
        ),
        c['attends'],
      );
    });
  }

  test('a policy is read from its stored name, defaulting to everyone', () {
    expect(AttendancePolicy.of('bySession'), AttendancePolicy.bySession);
    expect(AttendancePolicy.of(null), AttendancePolicy.everyone);
    expect(AttendancePolicy.of('nonsense'), AttendancePolicy.everyone);
    expect(AttendancePolicy.tryParse(null), isNull);
  });

  group('setAttending stores only the smallest exception', () {
    final m3 = SessionModel(
      id: 'm3',
      title: 'Lunch',
      startAt: DateTime.utc(2027, 7, 17, 17, 30),
    );
    final k1 = SessionModel(
      id: 'k1',
      title: 'Kids',
      startAt: DateTime.utc(2027, 7, 17, 18, 30),
      attendance: AttendancePolicy.bySession,
      eligibility: const SessionEligibility(categoryIds: ['child']),
    );
    const policy = AttendancePolicy.arrivalToDeparture;

    test('turning off a session someone attends adds an opt-out', () {
      final r = setAttending(
        policy: policy,
        session: m3,
        person: const Attendee(),
        attend: false,
        canInvite: false,
      )!;
      expect(r.optOuts, ['m3']);
      expect(r.invitedTo, isEmpty);
    });

    test('turning it back on removes the opt-out', () {
      final r = setAttending(
        policy: policy,
        session: m3,
        person: const Attendee(optOuts: ['m3', 'm2']),
        attend: true,
        canInvite: false,
      )!;
      expect(r.optOuts, ['m2']);
    });

    test('a sign-up session takes a sign-up, and turning off removes it', () {
      final on = setAttending(
        policy: policy,
        session: k1,
        person: const Attendee(categoryId: 'child'),
        attend: true,
        canInvite: false,
      )!;
      expect(on.signUps, ['k1']);
      final off = setAttending(
        policy: policy,
        session: k1,
        person: Attendee(categoryId: 'child', signUps: on.signUps),
        attend: false,
        canInvite: false,
      )!;
      expect(off.signUps, isEmpty);
      expect(off.optOuts, isEmpty);
    });

    test('outside the stay, only an organizer can add it, by invitation', () {
      final late = Attendee(arrivalAt: DateTime.utc(2027, 7, 18));
      expect(
        setAttending(
          policy: policy,
          session: m3,
          person: late,
          attend: true,
          canInvite: false,
        ),
        isNull,
      );
      expect(
        setAttending(
          policy: policy,
          session: m3,
          person: late,
          attend: true,
          canInvite: true,
        )!.invitedTo,
        ['m3'],
      );
    });

    test("an adult opts out of their own invitation, but can't remove it", () {
      final r = setAttending(
        policy: AttendancePolicy.invitedOnly,
        session: m3,
        person: const Attendee(invitedTo: ['m3']),
        attend: false,
        canInvite: false,
      )!;
      expect(r.invitedTo, ['m3']);
      expect(r.optOuts, ['m3']);
    });

    test('an organizer turning off an invitation removes it', () {
      final r = setAttending(
        policy: AttendancePolicy.invitedOnly,
        session: m3,
        person: const Attendee(invitedTo: ['m3']),
        attend: false,
        canInvite: true,
      )!;
      expect(r.invitedTo, isEmpty);
      expect(r.optOuts, isEmpty);
    });

    test("a group's invitation is turned off with an opt-out", () {
      final r = setAttending(
        policy: AttendancePolicy.invitedOnly,
        session: m3,
        person: const Attendee(groupInvitedTo: ['m3']),
        attend: false,
        canInvite: true,
      )!;
      expect(r.optOuts, ['m3']);
    });
  });
}
