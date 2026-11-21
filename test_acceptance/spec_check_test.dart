// SPEC CHECKS. These recompute §4 of CREWPOINT_CONVENTION_TEST_v4.md from the
// fixture. They prove the specification is self-consistent, and say nothing
// about the app, so they never count toward a scenario PASS.
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:flutter_test/flutter_test.dart';

import 'seed.dart';

void main() {
  final seed = ConventionSeed.load();
  final raw = seed.raw;
  final fams = seed.families;
  Map<String, dynamic> other(String id) =>
      seed.others.firstWhere((f) => f['id'] == id);

  List<Map<String, dynamic>> peopleOf(Iterable<Map<String, dynamic>> fs) => [
    for (final f in fs)
      for (final p in ConventionSeed.people(f)) {...p, 'family': f},
  ];
  final everyone = peopleOf(fams);
  final walkIn = other('F9');
  final withWalkIn = peopleOf([...fams, walkIn]);
  int count(
    Iterable<Map<String, dynamic>> who,
    bool Function(Map<String, dynamic>) t,
  ) => who.where(t).length;
  bool adult(Map<String, dynamic> p) => (p['age'] as int) >= 18;

  /// Meals between the family's first and last, minus opt-outs, with the
  /// Saturday lunch at the park for waterpark people and at the hotel for
  /// everyone else.
  bool attends(Map<String, dynamic> p, String meal) {
    final f = p['family'] as Map<String, dynamic>;
    final i = seed.meals.indexOf(meal);
    final first = seed.meals.indexOf((f['firstMeal'] as String?) ?? 'M1');
    final last = seed.meals.indexOf(f['lastMeal'] as String);
    final out = (p['optOut'] as List?)?.contains(meal) ?? false;
    final wp = p['wp'] == true;
    if (meal == 'M3P' && !wp) return false;
    if (meal == 'M3H' && wp) return false;
    return i >= first && i <= last && !out;
  }

  group('spec: headcounts', () {
    test('families, adults, kids, 21+', () {
      expect(fams.length, 8);
      expect(count(everyone, adult), 17);
      expect(count(everyone, (p) => !adult(p)), 12);
      expect(everyone.length, 29);
      expect(count(everyone, (p) => (p['age'] as int) >= 21), 16);
    });
    test('diet', () {
      expect(count(everyone, (p) => p['diet'] == 'V'), 21);
      expect(count(everyone, (p) => p['diet'] == 'J'), 2);
      expect(count(everyone, (p) => p['diet'] == 'N'), 6);
    });
    test('kids activities and T-shirts', () {
      expect(count(everyone, (p) => p['kidsAct'] == true), 8);
      expect(count(everyone, (p) => p['shirt'] != null), 29);
    });
    test('after the walk-in', () {
      expect(withWalkIn.length, 32);
      expect(count(withWalkIn, adult), 19);
      expect(count(withWalkIn, (p) => !adult(p)), 13);
      expect(count(withWalkIn, (p) => (p['age'] as int) >= 21), 18);
    });
    test('before the F10 merge', () {
      final dup = ConventionSeed.people(other('F10'));
      expect(fams.length + 1, 9);
      expect(everyone.length + dup.length, 31);
      expect(count(everyone, (p) => p['diet'] == 'J') + dup.length, 4);
      final billed = fams.fold<int>(0, (a, f) => a + familyFee(f));
      expect(billed + familyFee(other('F10')), 2850);
    });
  });

  group('spec: per-meal table', () {
    const expected = {
      'M1': [28, 20, 2, 6],
      'M2': [27, 20, 2, 5],
      'M3P': [24, 18, 0, 6],
      'M3H': [5, 3, 2, 0],
      'M4': [29, 21, 2, 6],
      'M5': [29, 21, 2, 6],
      'M6': [29, 21, 2, 6],
      'M7': [29, 21, 2, 6],
      'M8': [21, 13, 2, 6],
    };
    expected.forEach((meal, want) {
      test(meal, () {
        final who = everyone.where((p) => attends(p, meal)).toList();
        int d(String c) => who.where((p) => p['diet'] == c).length;
        expect([who.length, d('V'), d('J'), d('N')], want);
      });
    });
    test('after the walk-in', () {
      int at(String meal) => withWalkIn.where((p) => attends(p, meal)).length;
      expect(
        [at('M4'), at('M5'), at('M6'), at('M7'), at('M8')],
        [32, 32, 32, 32, 21],
      );
      expect(
        withWalkIn.where((p) => attends(p, 'M4') && p['diet'] == 'V').length,
        24,
      );
    });
  });

  group('spec: fees', () {
    test('per family, with the age boundary', () {
      expect(
        {for (final f in fams) f['id']: familyFee(f)},
        {
          'F1': 300,
          'F2': 300,
          'F3': 600,
          'F4': 150,
          'F5': 450,
          'F6': 300,
          'F7': 300,
          'F11': 150,
        },
      );
      expect(everyone.firstWhere((p) => p['name'] == 'Neel')['age'], 17);
      expect(everyone.firstWhere((p) => p['name'] == 'Rohan')['age'], 18);
    });
    test('billed, paid, pending, outstanding', () {
      int sum(Set<String> status) => fams
          .where((f) => status.contains((f['payment'] as Map)['status']))
          .fold<int>(0, (a, f) => a + familyFee(f));
      expect(sum({'paid', 'pending', 'unpaid', 'due'}), 2550);
      expect(sum({'paid'}), 1350);
      expect(sum({'pending'}), 300);
      expect(sum({'unpaid', 'due'}), 900);
      // Zelle confirmed, then F6 pays at the desk and F9 walks in.
      expect(sum({'paid', 'pending'}), 1650);
      expect(sum({'paid', 'pending'}) + 300 + familyFee(walkIn), 2250);
      expect(2550 + familyFee(walkIn), 2850);
    });
  });

  group('spec: waterpark day', () {
    final wp = raw['waterpark'] as Map<String, dynamic>;
    double cost(int guests) {
      final extra = guests > 250 ? (guests - 250) * 30.99 : 0;
      return ((8500 + extra) * (1 + (wp['taxPct'] as num) / 100) * 100)
              .round() /
          100;
    }

    test('sign-ups and package cost', () {
      expect(count(everyone, (p) => p['wp'] == true), 24);
      expect(count(everyone, (p) => p['wp'] != true), 5);
      expect(cost(24), 9201.25);
      expect(cost(250), 9201.25);
      expect(cost(260), 9536.72);
      expect((wp['included'] as int) * 0.9, wp['alertAt']);
    });
    test('shuttle riders fit two runs of 15, families together', () {
      final riders = {
        for (final f in fams)
          if (f['drives'] != true)
            f['id']: ConventionSeed.people(
              f,
            ).where((p) => p['wp'] == true).length,
      }..removeWhere((_, n) => n == 0);
      expect(riders.values.fold<int>(0, (a, n) => a + n), 17);
      // Largest family first into the emptiest run.
      final runs = [0, 0];
      for (final n in riders.values.toList()..sort((a, b) => b - a)) {
        final i = runs[0] <= runs[1] ? 0 : 1;
        runs[i] += n;
      }
      expect(runs.every((r) => r <= 15), isTrue);
    });
    test('missing waivers: F5 only, 5 people', () {
      final missing = [
        for (final f in fams)
          if (f['waiver'] != true &&
              ConventionSeed.people(f).any((p) => p['wp'] == true))
            f['id'],
      ];
      expect(missing, ['F5']);
    });
  });

  group('spec: hotel', () {
    test('estimates incl. tax', () {
      final cost = {
        for (final f in fams)
          if (f['hotel'] != null)
            f['id']:
                (((f['hotel'] as Map)['rooms'] as int) *
                        ((f['hotel'] as Map)['nights'] as int) *
                        99 *
                        114.98)
                    .round() /
                100,
      };
      expect(cost, {
        'F2': 341.49,
        'F3': 682.98,
        'F4': 227.66,
        'F5': 569.15,
        'F6': 341.49,
        'F11': 341.49,
      });
    });
  });

  group('spec: sponsorship', () {
    final pledges = (raw['pledges'] as List).cast<Map<String, dynamic>>();
    int total(Iterable<Map<String, dynamic>> ps) =>
        ps.fold<int>(0, (a, p) => a + (p['amount'] as int));

    test(r'list: 23 items, $101,900 asked', () {
      expect(seed.items.length, 23);
      expect(seed.items.fold<int>(0, (a, i) => a + (i['ask'] as int)), 101900);
    });
    test('pledged, received, outstanding', () {
      expect(total(pledges), 19502);
      expect(total(pledges.where((p) => p['received'] == true)), 17503);
      expect(total(pledges.where((p) => p['received'] != true)), 1999);
      expect(
        total(
          pledges.where(
            (p) => p['received'] == true && p['receivedOn'] == null,
          ),
        ),
        16502,
      );
    });
    test(r'Lunch – Sun fully pledged, 71% received; water $399 left', () {
      final lunch = pledges.where((p) => p['item'] == 'Lunch – Sun');
      expect(total(lunch), 7000);
      final received = total(lunch.where((p) => p['received'] == true));
      expect(received, 5001);
      expect((received * 100 / 7000).floor(), 71);
      expect(
        900 - total(pledges.where((p) => p['item'] == 'Bottled water')),
        399,
      );
    });
    test('a pledge cancelled, then part paid (D-09, D-10)', () {
      // F2 cancels its pledge.
      expect(total(pledges.where((p) => p['sponsor'] != 'F2')), 17503);
      // F2 pays $1,000 of $1,999.
      expect(5001 + 1000, 6001);
      expect(17503 + 1000, 18503);
    });
    test('in-kind and the thank-you list', () {
      expect(
        (raw['inKind'] as List).fold<int>(0, (a, i) => a + (i['value'] as int)),
        950,
      );
      expect(
        {
          for (final p in pledges)
            if (p['recognition'] != 'no') p['name'],
        },
        {
          'Patel (Dallas)',
          'Bhakta (Dallas)',
          'Bhakta (Chicago)',
          'Patel Travels',
          'An anonymous family',
        },
      );
    });
  });

  group('spec: raffle', () {
    final raffle = raw['raffle'] as Map<String, dynamic>;
    final sales = (raffle['sales'] as List).cast<Map<String, dynamic>>();
    int sum(String key, bool Function(Map<String, dynamic>) t) =>
        sales.where(t).fold<int>(0, (a, s) => a + (s[key] as int));

    test('sales by method and tickets per drawing', () {
      expect(sum('paid', (s) => s['method'] == 'card'), 170);
      expect(sum('paid', (s) => s['method'] == 'zelle'), 50);
      expect(sum('paid', (s) => s['method'] == 'cash'), 600);
      expect(sum('tickets', (_) => true), 97);
      expect(
        [
          for (final d in ['fri', 'sat', 'sun'])
            sum('tickets', (s) => s['drawing'] == d),
        ],
        [71, 8, 18],
      );
    });
    test('Saturday has as many prizes as tickets', () {
      expect((raffle['prizes'] as Map)['sat'], 8);
    });
    test('kids drawing: one entry per registered child', () {
      expect(count(everyone, (p) => !adult(p)), 12);
      expect(count(withWalkIn, (p) => !adult(p)), 13);
    });
  });

  group('spec: helpers', () {
    final h = raw['helpers'] as Map<String, dynamic>;
    test('planned shifts and budget; M1 pay', () {
      final shifts = (h['perMeal'] as int) * (h['meals'] as int);
      expect(shifts, 80);
      expect(shifts * (h['hours'] as int) * (h['rate'] as int), 6400);
      final logged = ((h['logged'] as Map)['M1'] as Map).cast<String, num>();
      expect(logged.map((k, v) => MapEntry(k, v * 20)), {
        'H1': 80,
        'H2': 80,
        'H3': 70,
      });
    });
  });

  group('spec: notification times', () {
    setUpAll(initEventTimeZones);

    test('hotel reminders 60, 30, 14 and 7 days before the cutoff', () {
      final cutoff = DateTime.utc(2027, 7, 3);
      expect(
        [
          for (final d in [60, 30, 14, 7])
            cutoff
                .subtract(Duration(days: d))
                .toIso8601String()
                .substring(0, 10),
        ],
        ['2027-05-04', '2027-06-03', '2027-06-19', '2027-06-26'],
      );
    });
    test(
      'pledge reminders every 30 days, stopping on receipt or at the event',
      () {
        List<String> reminders(DateTime pledged, DateTime? received) => [
          for (
            var d = pledged.add(const Duration(days: 30));
            d.isBefore(received ?? DateTime.utc(2027, 7, 16));
            d = d.add(const Duration(days: 30))
          )
            d.toIso8601String().substring(0, 10),
        ];
        expect(
          reminders(DateTime.utc(2027, 1, 15), DateTime.utc(2027, 3, 20)),
          ['2027-02-14', '2027-03-16'],
        );
        expect(reminders(DateTime.utc(2027, 3, 1), null), [
          '2027-03-31',
          '2027-04-30',
          '2027-05-30',
          '2027-06-29',
        ]);
      },
    );
    test('10:00am Central reaches London, Toronto and Phoenix', () {
      final sent = eventLocalToUtc(2027, 6, 3, 'America/Chicago', hour: 10);
      expect(
        [
          for (final zone in [
            'Europe/London',
            'America/Toronto',
            'America/Phoenix',
          ])
            inEventZone(sent, zone).hour,
        ],
        [16, 11, 8],
      );
    });
  });

  group('spec: fixture integrity', () {
    test('scale fixture is 108 families, 400 people', () {
      final s = scaleFamilies();
      expect(s.length, 108);
      expect(s.fold<int>(0, (a, f) => a + f[1]), 400);
    });
  });
}
