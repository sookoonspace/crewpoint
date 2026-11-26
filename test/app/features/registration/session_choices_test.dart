import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/registration/domain/session_choices.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';

/// Spec #233 Req 17 (#242, W-01): the form offers by-sign-up sessions as
/// the server checks them, from the same cases.
void main() {
  final cases =
      (jsonDecode(
                File(
                  'functions/test/fixtures/session_choice_cases.json',
                ).readAsStringSync(),
              )
              as List<dynamic>)
          .cast<Map<String, dynamic>>();

  for (final c in cases) {
    test(c['name'] as String, () {
      final sessions = [
        for (final s in (c['sessions'] as List).cast<Map<String, dynamic>>())
          SessionModel(
            id: s['id'] as String,
            title: s['id'] as String,
            startAt: DateTime.parse(s['startAt'] as String),
            endAt: s['endAt'] == null
                ? null
                : DateTime.parse(s['endAt'] as String),
            hidden: s['hidden'] == true,
            attendance: AttendancePolicy.tryParse(s['attendance']),
          ),
      ];
      expect(
        signUpChoices(AttendancePolicy.of(c['policy']), sessions)
            .map((choice) => choice.map((s) => s.id).toList())
            .toList(),
        c['choices'],
      );
    });
  }

  test('one of each choice, or none, is valid; both sides of an either/or '
      'or a session that is not offered is not', () {
    const choices = [
      ['park-meal', 'hotel-lunch'],
      ['tour'],
    ];
    expect(validSignUps(choices, {'park-meal', 'tour'}), isTrue);
    expect(validSignUps(choices, {}), isTrue);
    expect(validSignUps(choices, {'park-meal', 'hotel-lunch'}), isFalse);
    expect(validSignUps(choices, {'opening'}), isFalse);
  });
}
