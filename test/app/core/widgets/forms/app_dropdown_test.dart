import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_dropdown.dart';

void main() {
  testWidgets(
    'selecting an enabled item fires onChanged; underlying is DropdownButtonFormField',
    (tester) async {
      String? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDropdown<String>(
              labelText: 'Currency',
              value: 'USD',
              items: const [
                AppDropdownItem(value: 'USD', label: 'US Dollar'),
                AppDropdownItem(value: 'EUR', label: 'Euro'),
                AppDropdownItem(value: 'JPY', label: 'Yen', enabled: false),
              ],
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );

      // The widget MUST build on top of DropdownButtonFormField for keyboard
      // navigation + Form integration.
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Euro').last);
      await tester.pumpAndSettle();

      expect(captured, 'EUR');
    },
  );

  testWidgets('disabled item is non-selectable', (tester) async {
    String? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDropdown<String>(
            value: 'USD',
            items: const [
              AppDropdownItem(value: 'USD', label: 'US Dollar'),
              AppDropdownItem(value: 'JPY', label: 'Yen', enabled: false),
            ],
            onChanged: (v) => captured = v,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    // Yen renders but tapping it has no effect (Material disables it).
    await tester.tap(find.text('Yen').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(captured, isNull);
  });
}
