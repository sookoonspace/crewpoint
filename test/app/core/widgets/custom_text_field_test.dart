import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';

void main() {
  Widget buildSubject({
    String hintText = 'Enter text',
    ValueChanged<String>? onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CustomTextField(hintText: hintText, onChanged: onChanged),
      ),
    );
  }

  testWidgets('displays hint text', (tester) async {
    await tester.pumpWidget(buildSubject(hintText: 'Email'));

    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('handles text input', (tester) async {
    String? captured;
    await tester.pumpWidget(
      buildSubject(onChanged: (value) => captured = value),
    );

    await tester.enterText(find.byType(TextFormField), 'hello');
    expect(captured, equals('hello'));
  });
}
