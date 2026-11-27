import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/registration/domain/waivers.dart';

/// Spec #233 Req 26-29 (#246): the form decides who a waiver applies to,
/// and whether an acceptance counts, as the server does.
void main() {
  final cases =
      jsonDecode(
            File('functions/test/fixtures/waiver_cases.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  for (final c in (cases['applies'] as List).cast<Map<String, dynamic>>()) {
    test('applies: ${c['name']}', () {
      final person = c['person'] as Map<String, dynamic>;
      expect(
        waiverApplies(
          WaiverAppliesTo.tryParse(c['appliesTo'])!,
          categoryId: person['categoryId'] as String?,
          signUps: (person['signUps'] as List).cast<String>().toSet(),
        ),
        c['applies'],
      );
    });
  }

  for (final c in (cases['status'] as List).cast<Map<String, dynamic>>()) {
    test('status: ${c['name']}', () {
      final result = acceptanceStatus(
        version: c['version'] as int,
        requireLatest: c['requireLatest'] as bool,
        accepted: c['accepted'] as int?,
      );
      expect(result.status.name, c['status']);
      expect(result.counts, c['counts']);
    });
  }
}
