import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_switch_tile.dart';

void main() {
  testWidgets('renders title + subtitle and toggles via onChanged', (
    tester,
  ) async {
    bool? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSwitchTile(
            key: const Key('tile.archive'),
            title: 'Archive Event',
            subtitle: 'Read-only when on',
            value: false,
            onChanged: (v) => captured = v,
          ),
        ),
      ),
    );

    expect(find.text('Archive Event'), findsOneWidget);
    expect(find.text('Read-only when on'), findsOneWidget);
    expect(find.byKey(const Key('tile.archive')), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(captured, isTrue);
  });
}
