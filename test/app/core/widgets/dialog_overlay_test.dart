import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/dialog_overlay.dart';

void main() {
  testWidgets('shows dialog with title and content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => DialogOverlay.show(
                context: context,
                title: 'Confirm',
                content: const Text('Are you sure?'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Are you sure?'), findsOneWidget);
  });

  testWidgets('hides when dismissed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => DialogOverlay.show(
                context: context,
                title: 'Test',
                content: const Text('Content'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Test'), findsOneWidget);

    // Tap outside to dismiss
    await tester.tapAt(.zero);
    await tester.pumpAndSettle();
    expect(find.text('Test'), findsNothing);
  });
}
