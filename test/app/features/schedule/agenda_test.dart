import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/agenda.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 51 (J-05, J-06): a personal agenda from the viewer's own records, and
/// what is on now and next.
void main() {
  SessionModel session(
    String id,
    DateTime start, {
    DateTime? end,
    bool hidden = false,
    AttendancePolicy? attendance,
  }) => SessionModel(
    id: id,
    title: id,
    startAt: start,
    endAt: end,
    hidden: hidden,
    attendance: attendance,
  );

  ParticipantModel person(
    String id, {
    String? groupId,
    List<String> optOuts = const [],
    List<String> signUps = const [],
    DateTime? arrivalAt,
  }) => ParticipantModel(
    id: id,
    eventId: 'e',
    name: id,
    groupId: groupId,
    optOuts: optOuts,
    signUps: signUps,
    arrivalAt: arrivalAt,
  );

  final m1 = session('m1', DateTime.utc(2027, 7, 17, 0));
  final m2 = session('m2', DateTime.utc(2027, 7, 17, 13));
  final m3 = session('m3', DateTime.utc(2027, 7, 17, 17, 30));
  final k1 = session(
    'k1',
    DateTime.utc(2027, 7, 17, 18, 30),
    attendance: AttendancePolicy.bySession,
  );

  group('buildAgenda', () {
    test(
      'lists sessions anyone in the viewer\'s records attends, with who',
      () {
        final agenda = buildAgenda(
          policy: AttendancePolicy.arrivalToDeparture,
          sessions: [k1, m3, m1, m2],
          people: [
            person('kunal'),
            person('ramesh', optOuts: const ['m3']),
            person('asha', signUps: const ['k1']),
          ],
        );
        expect(
          [for (final e in agenda) e.session.id],
          ['m1', 'm2', 'm3', 'k1'],
        );
        expect([for (final p in agenda[2].people) p.id], ['kunal', 'asha']);
        expect([for (final p in agenda[3].people) p.id], ['asha']);
      },
    );

    test('someone arriving later sees nothing earlier', () {
      final agenda = buildAgenda(
        policy: AttendancePolicy.arrivalToDeparture,
        sessions: [m1, m2, m3],
        people: [person('savita', arrivalAt: DateTime.utc(2027, 7, 17, 16))],
      );
      expect([for (final e in agenda) e.session.id], ['m3']);
    });

    test('uses the group\'s invitations', () {
      final agenda = buildAgenda(
        policy: AttendancePolicy.invitedOnly,
        sessions: [m1, m2],
        people: [person('rina', groupId: 'g1')],
        groupInvitations: const {
          'g1': ['m2'],
        },
      );
      expect([for (final e in agenda) e.session.id], ['m2']);
    });

    test('leaves out hidden sessions', () {
      final agenda = buildAgenda(
        policy: AttendancePolicy.everyone,
        sessions: [
          m1,
          session('gala', DateTime.utc(2027, 7, 19), hidden: true),
        ],
        people: [person('a')],
      );
      expect([for (final e in agenda) e.session.id], ['m1']);
    });

    test('is empty without records', () {
      expect(
        buildAgenda(
          policy: AttendancePolicy.everyone,
          sessions: [m1],
          people: const [],
        ),
        isEmpty,
      );
    });
  });

  group('nowAndNext', () {
    final agenda = buildAgenda(
      policy: AttendancePolicy.everyone,
      sessions: [
        session(
          'dinner',
          DateTime.utc(2027, 7, 17, 0),
          end: DateTime.utc(2027, 7, 17, 2),
        ),
        session('garba', DateTime.utc(2027, 7, 17, 2)),
        session('breakfast', DateTime.utc(2027, 7, 17, 13)),
      ],
      people: [person('a')],
    );
    List<String> ids(Iterable<AgendaEntry> e) => [
      for (final x in e) x.session.id,
    ];

    test('before anything starts, nothing is on and the first is next', () {
      final r = nowAndNext(agenda, DateTime.utc(2027, 7, 16, 20));
      expect(r.now, isEmpty);
      expect(r.next?.session.id, 'dinner');
    });

    test('during a session, it is on and the following one is next', () {
      final r = nowAndNext(agenda, DateTime.utc(2027, 7, 17, 1));
      expect(ids(r.now), ['dinner']);
      expect(r.next?.session.id, 'garba');
    });

    test('a session with no end counts as on for an hour', () {
      final r = nowAndNext(agenda, DateTime.utc(2027, 7, 17, 2, 30));
      expect(ids(r.now), ['garba']);
      expect(r.next?.session.id, 'breakfast');
      expect(nowAndNext(agenda, DateTime.utc(2027, 7, 17, 3, 30)).now, isEmpty);
    });

    test('after the last session, nothing is on or next', () {
      final r = nowAndNext(agenda, DateTime.utc(2027, 7, 18));
      expect(r.now, isEmpty);
      expect(r.next, isNull);
    });
  });
}
