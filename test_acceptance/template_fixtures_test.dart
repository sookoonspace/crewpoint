// SPEC CHECKS. These recompute each template fixture's expected values from its
// own data. They prove the fixtures are self-consistent, and say nothing about
// the app, so they never count toward a scenario PASS.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'seed.dart';

const _templates = {
  'blank',
  'party',
  'wedding',
  'cricket_tournament',
  'golf_outing',
  'convention',
};

// Req 38a. The convention fixture predates these settings and stays unchanged.
const _expenseAccess = {
  'blank': 'everyone',
  'party': 'everyone',
  'wedding': 'everyone',
  'cricket_tournament': 'onlyInvolved',
  'golf_outing': 'onlyInvolved',
};

// Req 50 sets defaults for Party and Wedding. The others are starting points
// for the template work, which may change them.
const _attendancePolicy = {'party': 'everyone', 'wedding': 'invitedOnly'};

void main() {
  final manifest = TemplateFixture.manifest();

  test('there is one fixture per template', () {
    expect(manifest.keys.toSet(), _templates);
    expect(manifest.values.toSet().length, _templates.length);
    for (final file in manifest.values) {
      expect(
        File('test_acceptance/fixtures/$file').existsSync(),
        isTrue,
        reason: file,
      );
    }
  });

  test('the convention fixture is the existing one', () {
    expect(manifest['convention'], 'derod_convention_2027_v3.json');
  });

  for (final entry in manifest.entries.where((e) => e.key != 'convention')) {
    group(entry.key, () {
      final fixture = TemplateFixture.load(entry.value);
      final expected = fixture.expected;
      final everyone = [
        for (final g in fixture.groups) ...TemplateFixture.people(g),
      ];

      test('names its template', () {
        expect(fixture.raw['templateId'], entry.key);
      });

      test('event sets a time zone and currency', () {
        final event = fixture.raw['event'] as Map<String, dynamic>;
        expect(event['title'], isNotEmpty);
        expect(event['timeZone'], isNotEmpty);
        expect(event['currency'], hasLength(3));
      });

      test('settings match the Spec', () {
        expect(fixture.settings['expenseAccess'], _expenseAccess[entry.key]);
        if (_attendancePolicy.containsKey(entry.key)) {
          expect(
            fixture.settings['attendancePolicy'],
            _attendancePolicy[entry.key],
          );
        }
      });

      test('groups and people', () {
        expect(fixture.groups.length, expected['groups']);
        expect(everyone.length, expected['people']);
      });

      test('people without an account', () {
        expect(
          everyone.where((p) => p['hasAccount'] != true).length,
          expected['withoutAccount'],
        );
      });

      test('categories, with adult from age 18', () {
        expect({
          'adult': everyone.where((p) => (p['age'] as int) >= 18).length,
          'child': everyone.where((p) => (p['age'] as int) < 18).length,
        }, expected['byCategory']);
      });

      test('custom fields', () {
        final counts = <String, Map<String, int>>{};
        for (final person in everyone) {
          final fields = (person['fields'] as Map?) ?? const {};
          fields.forEach((field, value) {
            final values = counts.putIfAbsent(field as String, () => {});
            values['$value'] = (values['$value'] ?? 0) + 1;
          });
        }
        expect(counts, expected['byField']);
      });

      test('attendance per session', () {
        expect({
          for (final session in fixture.sessions)
            session['id']: [
              for (final g in fixture.groups)
                for (final p in TemplateFixture.people(g))
                  if (fixture.attends(g, p, session['id'] as String)) p,
            ].length,
        }, expected['perSession']);
      });
    });
  }
}
