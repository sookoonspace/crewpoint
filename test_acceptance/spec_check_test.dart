// SPEC CHECKS. These recompute §4 of CREWPOINT_CONVENTION_TEST_v3.md from the
// fixture. They prove the specification is self-consistent, and say nothing
// about the app, so they never count toward a scenario PASS.
import 'package:flutter_test/flutter_test.dart';

import 'seed.dart';

void main() {
  final seed = ConventionSeed.load();
  final fams = seed.families;
  final everyone = [
    for (final f in fams)
      for (final p in ConventionSeed.people(f)) {...p, 'family': f['id']},
  ];
  int count(bool Function(Map<String, dynamic>) t) => everyone.where(t).length;

  bool attends(Map<String, dynamic> p, String meal) {
    final f = fams.firstWhere((x) => x['id'] == p['family']);
    final i = seed.meals.indexOf(meal);
    final first = seed.meals.indexOf((f['firstMeal'] as String?) ?? 'M1');
    final last = seed.meals.indexOf(f['lastMeal'] as String);
    final out = (p['optOut'] as List?)?.contains(meal) ?? false;
    return i >= first && i <= last && !out;
  }

  group('spec: headcounts', () {
    test('families, adults, kids', () {
      expect(fams.length, 7);
      expect(count((p) => (p['age'] as int) >= 18), 16);
      expect(count((p) => (p['age'] as int) < 18), 10);
    });
    test('diet', () {
      expect(count((p) => p['diet'] == 'V'), 18);
      expect(count((p) => p['diet'] == 'J'), 2);
      expect(count((p) => p['diet'] == 'N'), 6);
    });
    test('kids activities', () {
      expect(count((p) => p['kidsAct'] == true), 7);
    });
    test('before F10 merge', () {
      final dup = ConventionSeed.people(
        seed.others.firstWhere((f) => f['id'] == 'F10'),
      );
      expect(everyone.length + dup.length, 28);
      expect(count((p) => p['diet'] == 'J') + dup.length, 4);
    });
  });

  group('spec: per-meal table', () {
    const expected = {
      'M1': [25, 17, 2, 6],
      'M2': [24, 17, 2, 5],
      'M3': [24, 18, 0, 6],
      'M4': [26, 18, 2, 6],
      'M5': [26, 18, 2, 6],
      'M6': [26, 18, 2, 6],
      'M7': [26, 18, 2, 6],
      'M8': [18, 10, 2, 6],
    };
    expected.forEach((meal, want) {
      test(meal, () {
        final who = everyone.where((p) => attends(p, meal)).toList();
        int d(String c) => who.where((p) => p['diet'] == c).length;
        expect([who.length, d('V'), d('J'), d('N')], want);
      });
    });
  });

  group('spec: money', () {
    test('fees per family', () {
      expect(
        {for (final f in fams) f['id']: familyFee(f)},
        {
          'F1': 300,
          'F2': 300,
          'F3': 600,
          'F4': 300,
          'F5': 450,
          'F6': 300,
          'F7': 300,
        },
      );
    });
    test('billed, paid, outstanding', () {
      final billed = fams.fold<int>(0, (a, f) => a + familyFee(f));
      expect(billed, 2550);
      int sum(String status) => fams
          .where((f) => (f['payment'] as Map)['status'] == status)
          .fold<int>(0, (a, f) => a + familyFee(f));
      expect(sum('paid'), 1350);
      expect(sum('pending'), 300);
      expect(sum('unpaid') + sum('due'), 900);
    });
    test('sponsorship totals and item list', () {
      final s = [
        for (final f in fams)
          if (f['sponsor'] != null) f['sponsor'] as Map<String, dynamic>,
      ];
      expect(s.fold<int>(0, (a, x) => a + (x['amount'] as int)), 6502);
      expect(
        seed.items.fold<int>(0, (a, i) => a + ((i['ask'] as int?) ?? 0)),
        45500,
      );
    });
    test('hotel estimates', () {
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
      });
    });
  });

  group('spec: fixture integrity', () {
    test('age boundary: Neel is a kid, Rohan an adult', () {
      expect(everyone.firstWhere((p) => p['name'] == 'Neel')['age'], 17);
      expect(everyone.firstWhere((p) => p['name'] == 'Rohan')['age'], 18);
    });
    test('scale fixture is 108 families, 400 people', () {
      final s = scaleFamilies();
      expect(s.length, 108);
      expect(s.fold<int>(0, (a, f) => a + f[1]), 400);
    });
  });
}
