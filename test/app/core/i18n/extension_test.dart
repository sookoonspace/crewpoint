import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

void main() {
  testWidgets('context.strings.auth.signIn equals the English fallback', (
    tester,
  ) async {
    String? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context.strings.auth.signIn;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(captured, equals(AppStrings.fallbackEnglish.auth.signIn));
  });
}
