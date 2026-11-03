// Keeps every scenario ID in the v3 spec traceable. Scenarios with nothing to
// exercise yet are registered as skipped, carrying the reason. Scenarios with
// real tests live in app_capability_test.dart and functions/test_acceptance/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final rows =
      (jsonDecode(
                File(
                  'test_acceptance/fixtures/scenarios.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();

  for (final row in rows.where((r) => r['tested'] != true)) {
    test(
      '${row['id']} ${row['title']}',
      () {},
      skip: '${row['status']}: ${row['gap']}',
    );
  }
}
