import 'dart:convert';
import 'dart:io';

import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/agenda.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// #82 (Req 50, 51): personal agendas for the convention's families from
/// the v4 seed, from arrival to departure, with Saturday split between the
/// waterpark (by sign-up) and the hotel, Jaya's breakfast opt-out, and the
/// kids activity by sign-up for children only.
void main() {
  const zone = 'America/Chicago';
  final fixture =
      jsonDecode(
            File(
              'test_acceptance/fixtures/derod_convention_2027_v4.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  DateTime at(int day, int hour, [int minute = 0]) =>
      eventLocalToUtc(2027, 7, day, zone, hour: hour, minute: minute);

  // §1's schedule, without the shuttle runs (Stage 4). The pool party and
  // the park meal are by sign-up; waterpark people opt out of the hotel
  // lunch. K1 is by sign-up, for children.
  final sessions = [
    SessionModel(id: 'M1', title: 'Welcome Dinner', startAt: at(16, 19)),
    SessionModel(id: 'P1', title: 'Karaoke & Garba', startAt: at(16, 21)),
    SessionModel(id: 'M2', title: 'Breakfast', startAt: at(17, 8)),
    SessionModel(
      id: 'B1',
      title: 'Bhajan',
      startAt: at(17, 10),
      endAt: at(17, 16),
    ),
    SessionModel(
      id: 'W1',
      title: 'Pool Party',
      startAt: at(17, 10, 30),
      endAt: at(17, 13),
      attendance: AttendancePolicy.bySession,
    ),
    SessionModel(
      id: 'M3P',
      title: 'Lunch at the park',
      startAt: at(17, 12, 30),
      attendance: AttendancePolicy.bySession,
    ),
    SessionModel(
      id: 'M3H',
      title: 'Lunch at the hotel',
      startAt: at(17, 12, 30),
    ),
    SessionModel(id: 'B2', title: 'Bhajan & Prasad', startAt: at(17, 16)),
    SessionModel(
      id: 'K1',
      title: 'Kids activities',
      startAt: at(17, 17),
      endAt: at(17, 18, 30),
      attendance: AttendancePolicy.bySession,
      eligibility: const SessionEligibility(categoryIds: ['child']),
    ),
    SessionModel(id: 'M4', title: 'Dinner', startAt: at(17, 19)),
    SessionModel(id: 'P2', title: 'Garba & Karaoke', startAt: at(17, 21)),
    SessionModel(id: 'M5', title: 'Breakfast', startAt: at(18, 8)),
    SessionModel(id: 'M6', title: 'Lunch', startAt: at(18, 12, 30)),
    SessionModel(
      id: 'M7',
      title: 'Gala Night Dinner + DJ',
      startAt: at(18, 19),
    ),
    SessionModel(id: 'M8', title: 'Farewell Breakfast', startAt: at(19, 8)),
  ];
  final byId = {for (final s in sessions) s.id: s};

  /// The family's people, as records: the arrival from the fixture, a
  /// departure just after their last meal, opt-outs and sign-ups.
  List<ParticipantModel> family(String id) {
    final f = (fixture['families'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((f) => f['id'] == id);
    final local = DateTime.parse(f['arrive'] as String);
    final arrival = eventLocalToUtc(
      local.year,
      local.month,
      local.day,
      zone,
      hour: local.hour,
      minute: local.minute,
    );
    final lastMeal = byId[f['lastMeal'] as String]!;
    final departure = lastMeal.startAt.add(const Duration(minutes: 1));
    return [
      for (final (i, p)
          in (f['people'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .indexed)
        ParticipantModel(
          id: '$id-$i',
          eventId: 'conv',
          name: p['name'] as String,
          groupId: id,
          categoryId: (p['age'] as int) < 18 ? 'child' : 'adult',
          arrivalAt: arrival,
          departureAt: departure,
          optOuts: [
            ...?(p['optOut'] as List<dynamic>?)?.cast<String>(),
            if (p['wp'] == true) 'M3H',
          ],
          signUps: [
            if (p['wp'] == true) ...['W1', 'M3P'],
            if (p['kidsAct'] == true) 'K1',
          ],
        ),
    ];
  }

  List<String> agendaOf(List<ParticipantModel> people) => [
    for (final e in buildAgenda(
      policy: AttendancePolicy.arrivalToDeparture,
      sessions: sessions,
      people: people,
    ))
      e.session.id,
  ];

  test('J-06 F4 arrives Sat 11am and sees nothing before', () {
    final agenda = agendaOf(family('F4'));
    expect(agenda.first, 'M3H');
    for (final id in ['M1', 'P1', 'M2', 'B1']) {
      expect(agenda, isNot(contains(id)), reason: id);
    }
    expect(agenda, contains('M8'));
  });

  test("J-06 F3's elders get the hotel lunch, not the park meal", () {
    final people = family('F3');
    for (final name in ['Ramesh', 'Kamla']) {
      final agenda = agendaOf([people.firstWhere((p) => p.name == name)]);
      expect(agenda, contains('M3H'), reason: name);
      expect(agenda, isNot(contains('M3P')), reason: name);
      expect(agenda, isNot(contains('W1')), reason: name);
    }
    final kunal = agendaOf([people.firstWhere((p) => p.name == 'Kunal')]);
    expect(kunal, containsAll(['W1', 'M3P']));
    expect(kunal, isNot(contains('M3H')));
  });

  test('J-06 the kids activity shows only for families with sign-ups', () {
    for (final id in ['F1', 'F3', 'F5', 'F7', 'F11']) {
      expect(agendaOf(family(id)), contains('K1'), reason: id);
    }
    for (final id in ['F2', 'F4', 'F6']) {
      expect(agendaOf(family(id)), isNot(contains('K1')), reason: id);
    }
    // Within F3, only the children who signed up.
    final f3 = buildAgenda(
      policy: AttendancePolicy.arrivalToDeparture,
      sessions: sessions,
      people: family('F3'),
    ).firstWhere((e) => e.session.id == 'K1');
    expect([for (final p in f3.people) p.name], ['Asha', 'Om']);
  });

  test('J-06 local families who leave after the gala miss the farewell', () {
    expect(agendaOf(family('F1')), isNot(contains('M8')));
    expect(agendaOf(family('F2')), contains('M8'));
  });

  test('J-05 now and next during the hotel lunch', () {
    final r = nowAndNext(
      buildAgenda(
        policy: AttendancePolicy.arrivalToDeparture,
        sessions: sessions,
        people: family('F4'),
      ),
      at(17, 12, 45),
    );
    expect([for (final e in r.now) e.session.id], ['M3H']);
    expect(r.next?.session.id, 'B2');
  });

  test('J-05 for someone without the kids activity, next skips it', () {
    final r = nowAndNext(
      buildAgenda(
        policy: AttendancePolicy.arrivalToDeparture,
        sessions: sessions,
        people: family('F4'),
      ),
      at(17, 16, 30),
    );
    expect(r.next?.session.id, 'M4');
  });
}
