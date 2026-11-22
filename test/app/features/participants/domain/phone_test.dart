import 'dart:convert';
import 'dart:io';

import 'package:crewpoint_app/app/features/participants/domain/models/phone.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec #233 Req 13, 17 (#237): the app turns a phone number into E.164
/// exactly as the server does, from the same cases.
void main() {
  final cases =
      jsonDecode(
            File('functions/test/fixtures/phone_cases.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  group('normalisePhone', () {
    for (final c in (cases['normalise'] as List).cast<Map<String, dynamic>>()) {
      test('${c['note']}: "${c['input']}" (${c['country']})', () {
        expect(
          normalisePhone(
            c['input'] as String,
            PhoneCountry.byCode(c['country'] as String),
          ),
          c['expected'],
        );
      });
    }
  });

  group('countryForTimeZone', () {
    for (final c
        in (cases['countryForTimeZone'] as List).cast<Map<String, dynamic>>()) {
      test('${c['timeZone']}', () {
        expect(
          countryForTimeZone(c['timeZone'] as String?).code,
          c['expected'],
        );
      });
    }
  });
}
