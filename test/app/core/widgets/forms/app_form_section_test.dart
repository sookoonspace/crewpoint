import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_form_section.dart';

void main() {
  Widget pump(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders title + child and shows helper only when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      pump(
        const AppFormSection(
          title: 'Details',
          helperText: 'Required fields',
          child: Text('child-content'),
        ),
      ),
    );

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Required fields'), findsOneWidget);
    expect(find.text('child-content'), findsOneWidget);

    await tester.pumpWidget(
      pump(const AppFormSection(title: 'No Helper', child: Text('child-only'))),
    );

    expect(find.text('No Helper'), findsOneWidget);
    expect(find.text('Required fields'), findsNothing);
    expect(find.text('child-only'), findsOneWidget);
  });
}
