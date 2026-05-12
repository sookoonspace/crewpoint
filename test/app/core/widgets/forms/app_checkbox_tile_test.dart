import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_checkbox_tile.dart';

void main() {
  testWidgets('renders title + subtitle and toggles via onChanged', (
    tester,
  ) async {
    bool? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCheckboxTile(
            key: const Key('tile.donate'),
            title: 'Donate cost',
            subtitle: 'Payer not split',
            value: false,
            onChanged: (v) => captured = v,
          ),
        ),
      ),
    );

    expect(find.text('Donate cost'), findsOneWidget);
    expect(find.text('Payer not split'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(captured, isTrue);
  });
}
