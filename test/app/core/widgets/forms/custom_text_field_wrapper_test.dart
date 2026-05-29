import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_text_field.dart';

void main() {
  testWidgets(
    'CustomTextField delegates to AppTextField (single nested instance)',
    (tester) async {
      // ignore: deprecated_member_use_from_same_package
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomTextField(
              hintText: 'Hint',
              prefixIcon: Icon(Icons.email_outlined),
              maxLines: 1,
              enabled: true,
            ),
          ),
        ),
      );

      // The wrapper is a CustomTextField in the tree…
      expect(find.byType(CustomTextField), findsOneWidget);
      // …and inside it lives exactly one AppTextField (the delegate).
      expect(find.byType(AppTextField), findsOneWidget);
      // Visual surface is preserved: hint, prefix icon.
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    },
  );
}
