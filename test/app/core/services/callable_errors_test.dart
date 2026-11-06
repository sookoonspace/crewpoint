import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final strings = AppStrings.fallbackEnglish.errors;

  group('userMessageFor (#66)', () {
    test('a refused callable explains, rather than showing the raw error', () {
      final error = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Only people who manage members can remove someone.',
      );
      expect(
        userMessageFor(error, strings: strings, fallback: 'Failed'),
        strings.permissionDenied,
      );
    });

    test('a refused Firestore write explains too', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(
        userMessageFor(error, strings: strings, fallback: 'Failed'),
        strings.permissionDenied,
      );
    });

    test('anything else shows the screen\'s own message', () {
      expect(
        userMessageFor(
          StateError('boom'),
          strings: strings,
          fallback: 'Failed',
        ),
        'Failed',
      );
    });
  });
}
