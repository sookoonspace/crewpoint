// Spec #233 Req 55: every English ARB key has a Gujarati translation, or is
// listed in lib/l10n/english_only.json with a reason for staying English.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _messages(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  final en = _read('lib/l10n/app_en.arb');
  final gu = _read('lib/l10n/app_gu.arb');
  final englishOnly =
      (_read('lib/l10n/english_only.json')['keys'] as Map<String, dynamic>)
          .cast<String, String>();

  test('every English key is translated or listed as English only', () {
    final missing = _messages(en).difference(_messages(gu))
      ..removeAll(englishOnly.keys);
    expect(
      missing,
      isEmpty,
      reason:
          'Add these keys to app_gu.arb, or list them in english_only.json '
          'with a reason',
    );
  });

  test('Gujarati has no keys English lacks', () {
    expect(_messages(gu).difference(_messages(en)), isEmpty);
  });

  test('every English-only key exists and gives a reason', () {
    for (final entry in englishOnly.entries) {
      expect(_messages(en), contains(entry.key));
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
    }
  });

  test('placeholders match between the languages', () {
    final hole = RegExp(r'\{(\w+)');
    for (final key in _messages(gu)) {
      Set<String> holes(Object? s) =>
          hole.allMatches('$s').map((m) => m.group(1)!).toSet();
      expect(holes(gu[key]), holes(en[key]), reason: key);
    }
  });
}
