import 'package:crewpoint_app/app/features/counts/domain/count_export.dart';
import 'package:crewpoint_app/app/features/counts/domain/event_stats.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// #84 (Req 53, 54): the caterer's counts export and the changes since a
/// freeze, and a custom field counted, filtered and exported (GE-04).
void main() {
  const event = EventModel(
    id: 'derod',
    title: 'Convention',
    creatorId: 'admin',
    timeZone: 'America/Chicago',
    settings: {
      'categories': [
        {'id': 'child', 'name': 'Child'},
        {'id': 'adult', 'name': 'Adult'},
      ],
    },
  );
  const diet = CustomField(
    id: 'diet',
    label: 'Diet',
    type: FieldType.singleChoice,
    options: ['Veg', 'Jain', 'Non-veg'],
  );
  final m2 = SessionModel(
    id: 'M2',
    title: 'Sat Breakfast',
    startAt: DateTime.utc(2027, 7, 17, 13),
  );

  EventStats stats(int veg, int nonVeg) => EventStats(
    event: const CountTally(
      total: 26,
      byCategory: {'adult': 16, 'child': 10},
      byField: {
        'diet': {'Veg': 18, 'Jain': 2, 'Non-veg': 6},
      },
    ),
    sessions: {
      'M2': CountTally(
        total: veg + 2 + nonVeg,
        byField: {
          'diet': {'Veg': veg, 'Jain': 2, 'Non-veg': nonVeg},
        },
      ),
    },
  );

  test('B-10 per-meal diet counts export to CSV for the caterer', () {
    final csv = countsCsv(
      event: event,
      stats: stats(17, 5),
      sessions: [m2],
      fields: const [diet],
    );
    expect(csv, contains('Diet: Veg,Diet: Jain,Diet: Non-veg'));
    expect(csv, contains('Sat Breakfast,2027-07-17 08:00,24,0,0,17,2,5,0'));
  });

  test('B-14 changes after a freeze are listed for the caterer', () {
    final changes = countChanges(
      frozen: stats(17, 5),
      current: stats(17, 6),
      sessions: [m2],
      fields: const [diet],
      event: event,
    );
    expect(
      changesCsv(changes),
      contains("Sat Breakfast,Diet: Non-veg,5,6,'+1"),
    );
  });

  test('GE-04 a custom field is counted, filtered and exported', () {
    const shirt = CustomField(
      id: 'shirt',
      label: 'T-shirt',
      type: FieldType.singleChoice,
      options: ['S', 'M', 'L'],
    );
    // Filtering uses the tags saved with answers.
    expect(filterTagsFor(const [shirt], const {'shirt': 'M'}), ['shirt=M']);
    // Counted and exported like any other field.
    final csv = countsCsv(
      event: event,
      stats: const EventStats(
        event: CountTally(
          total: 3,
          byField: {
            'shirt': {'M': 2, 'L': 1},
          },
        ),
      ),
      sessions: const [],
      fields: const [shirt],
    );
    expect(csv, contains('T-shirt: S,T-shirt: M,T-shirt: L'));
    expect(csv, contains('Whole event,,3,0,0,0,2,1,0'));
  });
}
