import 'dart:convert';
import 'dart:io';

import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LabelResolver (Req 20)', () {
    test('returns the default with no label set', () {
      const labels = LabelResolver({});
      expect(labels.one('group'), 'Group');
      expect(labels.other('group'), 'Groups');
    });

    test('returns the event label when set', () {
      const labels = LabelResolver({
        'group': {'one': 'Team', 'other': 'Teams'},
      });
      expect(labels.one('group'), 'Team');
      expect(labels.other('group'), 'Teams');
      expect(labels.one('session'), 'Session');
    });

    test('a label with no plural still reads sensibly', () {
      const labels = LabelResolver({
        'member': {'one': 'Committee'},
      });
      expect(labels.one('member'), 'Committee');
      expect(labels.other('member'), 'Committee');
    });

    test('a label with no singular uses its plural', () {
      const labels = LabelResolver({
        'member': {'other': 'Crew'},
      });
      expect(labels.one('member'), 'Crew');
    });

    test('blank or badly shaped labels fall back to the default', () {
      const labels = LabelResolver({
        'group': {'one': '  ', 'other': ''},
        'session': 'Match',
        'crew': {'one': 5},
      });
      expect(labels.one('group'), 'Group');
      expect(labels.other('group'), 'Groups');
      expect(labels.one('session'), 'Session');
      expect(labels.one('crew'), 'Crew');
    });

    test('count uses the singular only for one, in lower case', () {
      const labels = LabelResolver({
        'group': {'one': 'Guest party', 'other': 'Guest parties'},
      });
      expect(labels.count('group', 1), '1 guest party');
      expect(labels.count('group', 3), '3 guest parties');
      expect(labels.count('group', 0), '0 guest parties');
    });

    test('an unknown concept is a mistake in the code', () {
      expect(() => const LabelResolver({}).one('nope'), throwsArgumentError);
    });
  });

  group('the shared defaults file', () {
    final file =
        jsonDecode(File(LabelDefaults.assetPath).readAsStringSync())
            as Map<String, dynamic>;

    test('holds every term in the glossary', () {
      expect(LabelDefaults.current.concepts, [...file.keys]);
      for (final concept in [
        'event',
        'organizer',
        'member',
        'participant',
        'group',
        'category',
        'session',
        'crew',
        'registration',
        'customField',
        'pass',
        'charge',
        'payment',
        'contribution',
        'goal',
        'update',
        'incident',
        'audience',
      ]) {
        expect(file.keys, contains(concept));
      }
    });

    test('is listed as an app asset', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- ${LabelDefaults.assetPath}'),
      );
    });
  });
}
