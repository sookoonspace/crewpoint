import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_text_field.dart';

void main() {
  testWidgets('renders validator error after validate()', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AppTextField(
              hintText: 'Title',
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Required' : null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Required'), findsNothing);

    formKey.currentState!.validate();
    await tester.pump();

    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets(
    'accepts every legacy CustomTextField param (no compile or runtime error)',
    (tester) async {
      // Regression: AppTextField must be a strict superset of CustomTextField.
      // Passing the legacy param shape with all parameters provided should
      // compile and render without throwing.
      final controller = TextEditingController(text: 'seed');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: AppTextField(
                hintText: 'Hint',
                controller: controller,
                obscureText: false,
                keyboardType: TextInputType.text,
                onChanged: (_) {},
                validator: (_) => null,
                prefixIcon: const Icon(Icons.person_outline),
                suffixIcon: const Icon(Icons.clear),
                maxLines: 2,
                enabled: true,
                label: 'Label',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppTextField), findsOneWidget);
      expect(find.text('seed'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
      controller.dispose();
    },
  );

  testWidgets('renders helperText, labelText, and errorText additive params', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppTextField(
            hintText: 'Hint',
            labelText: 'My Label',
            helperText: 'My Helper',
            errorText: 'My Error',
          ),
        ),
      ),
    );

    expect(find.text('My Label'), findsOneWidget);
    expect(find.text('My Error'), findsOneWidget);
    // helperText may be hidden behind errorText when both present — assert
    // helperText alone:
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppTextField(hintText: 'Hint', helperText: 'My Helper'),
        ),
      ),
    );
    expect(find.text('My Helper'), findsOneWidget);
  });
}
