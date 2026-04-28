import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/dispute_sheet.dart';

void main() {
  testWidgets('renders the supplied summary line', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DisputeSheet(summary: 'You settled \$25 with Alex'),
        ),
      ),
    );

    expect(find.text('You settled \$25 with Alex'), findsOneWidget);
  });

  testWidgets('Cancel ("All good") closes the sheet without firing onDispute', (
    tester,
  ) async {
    var disputed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => DisputeSheet.show(
                context: ctx,
                summary: 'You settled \$25 with Alex',
                onDispute: () => disputed = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat.dispute.cancel')));
    await tester.pumpAndSettle();

    expect(disputed, isFalse);
    expect(find.byKey(const Key('chat.dispute.confirm')), findsNothing);
  });

  testWidgets('Dispute confirm fires onDispute and closes the sheet', (
    tester,
  ) async {
    var disputed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => DisputeSheet.show(
                context: ctx,
                summary: 'You settled \$25 with Alex',
                onDispute: () => disputed = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat.dispute.confirm')));
    await tester.pumpAndSettle();

    expect(disputed, isTrue);
    expect(find.byKey(const Key('chat.dispute.confirm')), findsNothing);
  });
}
