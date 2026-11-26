import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/registration/domain/form_conditions.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

/// Spec #233 Req 18 (#242): the form shows and hides questions exactly as
/// the server reads them, from the same cases.
void main() {
  final cases =
      (jsonDecode(
                File(
                  'functions/test/fixtures/condition_cases.json',
                ).readAsStringSync(),
              )
              as List<dynamic>)
          .cast<Map<String, dynamic>>();

  for (final c in cases) {
    test(c['name'] as String, () {
      final person = c['person'] as Map<String, dynamic>;
      expect(
        isShown(
          FieldCondition.tryParse(c['condition']),
          categoryId: person['categoryId'] as String?,
          answers: (person['answers'] as Map).cast<String, Object?>(),
        ),
        c['shown'],
      );
    });
  }
}
