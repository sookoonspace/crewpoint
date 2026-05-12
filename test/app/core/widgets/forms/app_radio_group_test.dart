import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_radio_group.dart';

void main() {
  testWidgets(
    'renders label + helper + all options; selecting fires onChanged',
    (tester) async {
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppRadioGroup<int>(
              labelText: 'Priority',
              helperText: 'Higher = more urgent',
              value: 0,
              options: const [
                AppRadioOption(value: 0, label: 'None'),
                AppRadioOption(value: 1, label: 'Low'),
                AppRadioOption(value: 2, label: 'Medium'),
                AppRadioOption(value: 3, label: 'High'),
              ],
              onChanged: (v) => captured = v,
            ),
          ),
        ),
      );

      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Higher = more urgent'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);

      await tester.tap(find.text('Medium'));
      await tester.pump();
      expect(captured, 2);
    },
  );
}
