// Spec #233 Req 59a (A-03): the approved Gujarati spelling list. A known
// wrong spelling may appear nowhere checked, and a Gujarati string must use
// the approved spelling of a listed term. The list is docs/i18n/
// gujarati_terms.json; docs/i18n/gujarati-terms.md shows it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class Term {
  Term(Map<String, dynamic> json)
    : group = json['group'] as String,
      en = json['en'] as String,
      gu = json['gu'] as String,
      wrong = (json['wrong'] as List).cast<String>(),
      word = json['match'] == 'word';

  final String group;
  final String en;
  final String gu;
  final List<String> wrong;

  /// True when the English need only contain the term; else it must equal it.
  final bool word;

  bool appliesTo(String english) => word
      ? RegExp(
          '\\b${RegExp.escape(en)}\\b',
          caseSensitive: false,
        ).hasMatch(english)
      : english.trim().toLowerCase() == en.toLowerCase();
}

final terms = [
  for (final t
      in (jsonDecode(File('docs/i18n/gujarati_terms.json').readAsStringSync())
              as Map<String, dynamic>)['terms']
          as List)
    Term(t as Map<String, dynamic>),
];

/// Everywhere Gujarati text can live: the ARB file, templates, labels,
/// email templates, seed data and fixtures.
const checkedRoots = [
  'lib',
  'assets/templates',
  'functions/src',
  'test_acceptance',
  'functions/test_acceptance',
  'functions/test/fixtures',
];

/// Tests and the scenario record name wrong spellings as what they check
/// for. Seed data, fixtures and everything the app ships are still checked.
bool _namesWrongSpellingsOnPurpose(String path) =>
    path.endsWith('_test.dart') ||
    path.endsWith('.test.ts') ||
    path.endsWith('test_acceptance/fixtures/scenarios.json');

Iterable<File> checkedFiles() sync* {
  for (final root in checkedRoots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync(recursive: true)) {
      if (e is File &&
          RegExp(r'\.(arb|json|dart|ts|md|yaml|csv)$').hasMatch(e.path) &&
          !e.path.contains('/gen/') &&
          !_namesWrongSpellingsOnPurpose(e.path)) {
        yield e;
      }
    }
  }
}

/// English and Gujarati strings that translate each other.
Iterable<(String where, String en, String gu)> pairs() sync* {
  Map<String, dynamic> read(String p) =>
      jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;
  final en = read('lib/l10n/app_en.arb');
  final gu = read('lib/l10n/app_gu.arb');
  for (final key in gu.keys.where((k) => !k.startsWith('@'))) {
    yield ('app_gu.arb $key', '${en[key]}', '${gu[key]}');
  }
  final mailEn = read('functions/src/mail/templates/en.json');
  final mailGu = read('functions/src/mail/templates/gu.json');
  for (final name in mailGu.keys) {
    final g = mailGu[name] as Map<String, dynamic>;
    final e = mailEn[name] as Map<String, dynamic>;
    for (final part in g.keys) {
      yield ('mail $name.$part', '${e[part]}', '${g[part]}');
    }
  }
}

void main() {
  test('the list starts with the agreed terms', () {
    final byEn = {for (final t in terms) t.en: t};
    expect(byEn['Derod']?.gu, 'દેરોદ');
    expect(byEn['Derod']?.wrong, contains('ડેરોડ'));
    for (final group in [
      'Actions and screens',
      'Statuses',
      'Answers',
      'Days',
      'Months',
      'Glossary terms',
      "Convention's own names",
    ]) {
      expect(terms.where((t) => t.group == group), isNotEmpty, reason: group);
    }
  });

  test('no approved spelling is also listed as wrong', () {
    final approved = {for (final t in terms) t.gu};
    for (final t in terms) {
      expect(t.wrong.where(approved.contains), isEmpty, reason: t.en);
    }
  });

  test('no known wrong spelling appears anywhere checked', () {
    final hits = <String>[];
    for (final file in checkedFiles()) {
      final text = file.readAsStringSync();
      for (final t in terms) {
        for (final bad in t.wrong) {
          if (text.contains(bad)) hits.add('${file.path}: $bad (use ${t.gu})');
        }
      }
    }
    expect(hits, isEmpty);
  });

  test('Gujarati strings use the approved spelling of listed terms', () {
    final hits = <String>[];
    for (final (where, en, gu) in pairs()) {
      for (final t in terms.where((t) => t.appliesTo(en))) {
        final ok = t.word ? gu.contains(t.gu) : gu.trim() == t.gu;
        if (!ok) hits.add('$where: "$gu" should use ${t.gu} for ${t.en}');
      }
    }
    expect(hits, isEmpty);
  });

  test('the check catches a term spelled another way', () {
    final derod = terms.firstWhere((t) => t.en == 'Derod');
    expect(derod.appliesTo('Welcome to Derod Gaam'), isTrue);
    expect('ડેરોડ ગામ'.contains(derod.gu), isFalse);
    final yes = terms.firstWhere((t) => t.en == 'Yes');
    expect(yes.appliesTo('Yes'), isTrue);
    expect(yes.appliesTo('Yes, I am coming'), isFalse);
  });

  test('the page shows every term in the list', () {
    final page = File('docs/i18n/gujarati-terms.md').readAsStringSync();
    for (final t in terms) {
      expect(
        page,
        contains('| ${t.group} | ${t.en} | ${t.gu} |'),
        reason: t.en,
      );
    }
  });
}
