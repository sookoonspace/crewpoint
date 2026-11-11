import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/counts/domain/event_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 52: the counts the server stores in `stats/current`.
void main() {
  test('reads event and session counts with the update time', () {
    final data = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.utc(2027, 7, 10, 12)),
      'event': {
        'total': 26,
        'groups': 7,
        'byCategory': {'adult': 16, 'child': 10},
        'byField': {
          'diet': {'Veg': 18, 'Jain': 2, 'Non-veg': 6},
        },
      },
      'sessions': {
        'M3': {
          'total': 24,
          'byCategory': {'adult': 15, 'child': 9},
          'byField': {
            'diet': {'Veg': 18, 'Non-veg': 6},
          },
        },
      },
    };
    final stats = EventStats.fromFirestore(data);
    expect(stats.updatedAt, DateTime.utc(2027, 7, 10, 12));
    expect(stats.event.total, 26);
    expect(stats.groups, 7);
    expect(stats.event.byCategory, {'adult': 16, 'child': 10});
    expect(stats.event.byField['diet']!['Jain'], 2);
    expect(stats.sessions['M3']!.total, 24);
    expect(stats.sessions['M3']!.byField['diet']!['Jain'], isNull);
  });

  test('reads a damaged or empty document as zero', () {
    final stats = EventStats.fromFirestore(const {'event': 'x', 'sessions': 7});
    expect(stats.event.total, 0);
    expect(stats.groups, 0);
    expect(stats.sessions, isEmpty);
    expect(stats.updatedAt, isNull);
  });

  test('unanswered counts sort last, the rest by count', () {
    const tally = CountTally(
      total: 5,
      byField: {
        'diet': {'_none': 3, 'Veg': 1, 'Jain': 4},
      },
    );
    expect(
      [for (final e in tally.sorted('diet')) e.key],
      ['Jain', 'Veg', '_none'],
    );
  });
}
