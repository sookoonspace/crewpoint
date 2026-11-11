import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/counts/domain/count_export.dart';
import 'package:crewpoint_app/app/features/counts/domain/event_stats.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 53, 54 (B-10, B-14): counts export to CSV for the caterer, private
/// fields left out unless asked for, and later changes are listed against a
/// freeze.
void main() {
  const event = EventModel(
    id: 'e',
    title: 'Convention',
    creatorId: 'o',
    timeZone: 'America/Chicago',
    settings: {
      'categories': [
        {'id': 'adult', 'name': 'Adult'},
        {'id': 'child', 'name': 'Child'},
      ],
    },
  );
  const diet = CustomField(
    id: 'diet',
    label: 'Diet',
    type: FieldType.singleChoice,
    options: ['Veg', 'Jain', 'Non-veg'],
  );
  const meal = CustomField(
    id: 'meal',
    label: '=Meal',
    type: FieldType.singleChoice,
    options: ['Fish', 'Veg'],
    visibility: FieldVisibility.private,
  );
  final m1 = SessionModel(
    id: 'm1',
    title: 'Welcome dinner',
    startAt: DateTime.utc(2027, 7, 17),
  );
  final m2 = SessionModel(
    id: 'm2',
    title: 'Breakfast',
    startAt: DateTime.utc(2027, 7, 17, 13),
  );

  EventStats stats({int m2Veg = 17, int m2NonVeg = 5}) => EventStats(
    groups: 7,
    event: const CountTally(
      total: 26,
      byCategory: {'adult': 16, 'child': 10},
      byField: {
        'diet': {'Veg': 18, 'Jain': 2, 'Non-veg': 6},
        'meal': {'Fish': 3, '_none': 23},
      },
    ),
    sessions: {
      'm1': const CountTally(
        total: 25,
        byCategory: {'adult': 15, 'child': 10},
        byField: {
          'diet': {'Veg': 17, 'Jain': 2, 'Non-veg': 6},
        },
      ),
      'm2': CountTally(
        total: m2Veg + 2 + m2NonVeg,
        byCategory: const {'adult': 14, 'child': 10},
        byField: {
          'diet': {'Veg': m2Veg, 'Jain': 2, 'Non-veg': m2NonVeg},
        },
      ),
    },
  );

  List<List<String>> rows(String csv) => [
    for (final line in csv.trim().split('\r\n')) line.split(','),
  ];

  group('countsCsv', () {
    test('one row for the event and one per session, with diet columns', () {
      final table = rows(
        countsCsv(
          event: event,
          stats: stats(),
          sessions: [m2, m1],
          fields: const [diet, meal],
        ),
      );
      expect(table[0], [
        'Session',
        'Starts',
        'Total',
        'Adult',
        'Child',
        'Diet: Veg',
        'Diet: Jain',
        'Diet: Non-veg',
        'Diet: No answer',
      ]);
      expect(table[1], [
        'Whole event',
        '',
        '26',
        '16',
        '10',
        '18',
        '2',
        '6',
        '0',
      ]);
      expect(table[2].first, 'Welcome dinner');
      expect(table[2][1], '2027-07-16 19:00');
      expect(table[3].sublist(2), ['24', '14', '10', '17', '2', '5', '0']);
    });

    test('private fields only when asked for, and neutralised', () {
      final csv = countsCsv(
        event: event,
        stats: stats(),
        sessions: [m1],
        fields: const [diet, meal],
        includePrivate: true,
      );
      expect(rows(csv)[0], contains("'=Meal: Fish"));
      expect(rows(csv)[1], contains('3'));
    });
  });

  group('countChanges', () {
    test('lists what changed since the freeze, with before and after', () {
      final changes = countChanges(
        frozen: stats(),
        current: stats(m2Veg: 18, m2NonVeg: 6),
        sessions: [m1, m2],
        fields: const [diet],
        event: event,
      );
      expect(
        [for (final c in changes) (c.where, c.what, c.before, c.after)],
        [
          ('Breakfast', 'Total', 24, 26),
          ('Breakfast', 'Diet: Veg', 17, 18),
          ('Breakfast', 'Diet: Non-veg', 5, 6),
        ],
      );
      expect(changes.first.difference, 2);
    });

    test('is empty when nothing changed', () {
      expect(
        countChanges(
          frozen: stats(),
          current: stats(),
          sessions: [m1, m2],
          fields: const [diet],
          event: event,
        ),
        isEmpty,
      );
    });

    test('exports the changes for the caterer', () {
      final changes = countChanges(
        frozen: stats(),
        current: stats(m2Veg: 18, m2NonVeg: 5),
        sessions: [m2],
        fields: const [diet],
        event: event,
      );
      expect(rows(changesCsv(changes)), [
        ['Session', 'Count', 'Frozen', 'Now', 'Change'],
        ['Breakfast', 'Total', '24', '25', "'+1"],
        ['Breakfast', 'Diet: Veg', '17', '18', "'+1"],
      ]);
    });
  });

  test('FrozenCounts reads a freeze', () {
    final data = <String, dynamic>{
      'frozenAt': Timestamp.fromDate(DateTime.utc(2027, 7, 9, 15)),
      'frozenBy': 'owner',
      'label': 'Caterer',
      'event': {'total': 26, 'groups': 7},
      'sessions': {
        'm1': {'total': 25},
      },
    };
    final f = FrozenCounts.fromFirestore('f1', data);
    expect(f.frozenAt, DateTime.utc(2027, 7, 9, 15));
    expect(f.label, 'Caterer');
    expect(f.stats.event.total, 26);
    expect(f.stats.groups, 7);
    expect(f.stats.sessions['m1']!.total, 25);
  });
}
