import 'dart:convert';
import 'dart:io';

import 'package:crewpoint_app/app/features/dashboard/domain/models/event_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 62, 63: the app reads the same template files the server copies, to
/// show the picker. Party and Blank take the fast path.
void main() {
  Map<String, dynamic> read(String file) =>
      jsonDecode(File('assets/templates/$file').readAsStringSync())
          as Map<String, dynamic>;

  test('the index lists the six templates in order', () {
    expect(EventTemplateInfo.idsFrom(read('index.json')), [
      'blank',
      'party',
      'wedding',
      'cricket_tournament',
      'golf_outing',
      'convention',
    ]);
  });

  test('each file reads, with a name and a description', () {
    for (final id in EventTemplateInfo.idsFrom(read('index.json'))) {
      final t = EventTemplateInfo.fromJson(read('$id.json'));
      expect(t.id, id);
      expect(t.version, greaterThanOrEqualTo(1));
      expect(t.name('en'), isNotEmpty);
      expect(t.description('en'), isNotEmpty);
    }
  });

  test('only Party and Blank take the fast path', () {
    final fast = [
      for (final id in EventTemplateInfo.idsFrom(read('index.json')))
        if (EventTemplateInfo.fromJson(read('$id.json')).fastPath) id,
    ];
    expect(fast, ['blank', 'party']);
  });

  test('a missing language falls back to English', () {
    final t = EventTemplateInfo.fromJson(read('party.json'));
    expect(t.name('gu'), t.name('en'));
  });

  test('a damaged file is refused', () {
    expect(
      () => EventTemplateInfo.fromJson(const {'id': 7}),
      throwsFormatException,
    );
  });
}
