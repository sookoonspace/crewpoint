// Req 2: event-specific words stay out of code and user-facing strings, and
// live only in template data. A hit means the word belongs in a template, a
// label or a setting, not that it should be added to the exceptions.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'naming_guardrail.dart';

void main() {
  group('GE-05 scanner', () {
    List<String> words(String source, {String path = 'a.dart'}) => [
      for (final hit in findBannedWords(path, source)) hit.word,
    ];

    test('finds each banned word in an identifier', () {
      expect(
        words('''
          var familyFee, meal_count, derodId, weddingDate;
          var cricketTeam, GolfRound, teeTime, MEAL;
        '''),
        [
          'family',
          'meal',
          'derod',
          'wedding',
          'cricket',
          'golf',
          'tee',
          'meal',
        ],
      );
    });

    test('finds a banned word in a string', () {
      expect(words("Text('Choose a meal');"), ['meal']);
    });

    test('reports the line of a hit', () {
      final hit = findBannedWords('a.dart', 'var a;\nvar b;\nvar meal;').single;
      expect(hit.line, 3);
      expect('$hit', contains('a.dart:3'));
    });

    test('only matches whole words', () {
      expect(
        words('var committee, employee, golfer, familyish, oatmeal;'),
        isEmpty,
      );
    });

    test('ignores line, doc and block comments', () {
      expect(
        words('''
          // family
          /// meal
          /* wedding /* nested golf */ cricket */
          var a;
        '''),
        isEmpty,
      );
    });

    test('code after a block comment still counts', () {
      expect(words('/* note */ var meal;'), ['meal']);
    });

    test('a comment marker inside a string is not a comment', () {
      expect(words("var a = 'https://x.test/meal';"), ['meal']);
    });

    test('a quote inside a comment does not open a string', () {
      expect(words("// don't\nvar meal;"), ['meal']);
    });

    test('checks code inside string interpolation', () {
      expect(words(r"""var a = 'x ${b ? 'meal' : "golf"} y';"""), [
        'meal',
        'golf',
      ]);
    });

    test('checks triple-quoted and raw strings', () {
      expect(words("var a = '''\nthe meal\n''';\nvar b = r'golf';"), [
        'meal',
        'golf',
      ]);
    });

    test('an unclosed quote stops at the end of the line', () {
      expect(words("var a = 'oops\nvar meal;"), ['meal']);
    });

    test('ignores Riverpod .family, including across lines', () {
      expect(
        words('Provider.family<A, B>; Provider\n  .family<A, B>;'),
        isEmpty,
      );
    });

    test('still finds family used any other way', () {
      expect(words('var family; foo(family: 1);'), ['family', 'family']);
    });

    test('ignores fontFamily', () {
      expect(
        words("TextStyle(fontFamily: 'Inter', fontFamilyFallback: []);"),
        isEmpty,
      );
    });

    test('reads TypeScript templates and comments', () {
      expect(
        words(r'''
          // family
          const a = `the ${meal} and ${`nested golf`} day`;
          ''', path: 'a.ts'),
        ['meal', 'golf'],
      );
    });

    test('a TypeScript regex with a quote does not open a string', () {
      expect(
        words(
          r'''const a = b.replace(/'/g, ''); const meal = 1;''',
          path: 'a.ts',
        ),
        ['meal'],
      );
    });

    test('dividing in TypeScript is not a regex', () {
      expect(words('const a = b / 2; const meal = c / 3;', path: 'a.ts'), [
        'meal',
      ]);
    });

    test('reads every string in JSON', () {
      expect(words('{"title": "Your meal"}', path: 'a.json'), ['meal']);
    });

    test('allows a listed exception, for that file and word only', () {
      const allowed = {
        'lib/a.dart': {'meal'},
      };
      expect(
        findBannedWords('lib/a.dart', 'var meal;', allowed: allowed),
        isEmpty,
      );
      expect(
        findBannedWords('lib/b.dart', 'var meal;', allowed: allowed),
        hasLength(1),
      );
      expect(
        findBannedWords('lib/a.dart', 'var golf;', allowed: allowed),
        hasLength(1),
      );
    });
  });

  test('GE-05 lib and functions/src contain no banned words', () {
    final hits = [
      for (final file in guardedFiles())
        ...findBannedWords(file.path, file.readAsStringSync()),
    ];
    expect(
      hits.map((h) => '$h').toList(),
      isEmpty,
      reason:
          'Event-specific words belong in template data, labels or settings. '
          'See GLOSSARY.md.',
    );
  });

  test('GE-05 the scan covers app and backend code', () {
    final paths = guardedFiles().map((f) => f.path).toSet();
    expect(paths, contains('lib/main.dart'));
    expect(paths, contains('functions/src/index.ts'));
    expect(paths.where((p) => p.endsWith('.g.dart')), isEmpty);
  });

  test('GE-05 the scanner reads every file through to its last line', () {
    // A lexing mistake could swallow the rest of a file and hide a banned word.
    for (final file in guardedFiles()) {
      final source = file.readAsStringSync();
      final lastLine = '\n'.allMatches(source).length + 2;
      final hits = findBannedWords(file.path, '$source\nvar meal;');
      expect(hits.map((h) => h.line), contains(lastLine), reason: file.path);
    }
  });

  test('every glossary term has a one-line definition', () {
    final glossary = File('GLOSSARY.md').readAsStringSync();
    const terms = [
      'Event',
      'Organizer',
      'Member',
      'Participant',
      'Group',
      'Category',
      'Session',
      'Crew',
      'Registration',
      'Custom field',
      'Pass',
      'Charge',
      'Payment',
      'Contribution',
      'Goal',
      'Update',
      'Incident',
      'Audience',
    ];
    for (final term in terms) {
      expect(
        glossary,
        matches(RegExp('^- \\*\\*$term:\\*\\* \\S.*\$', multiLine: true)),
        reason: term,
      );
    }
  });
}
