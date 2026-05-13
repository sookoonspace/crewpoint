import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_tab_placeholder_screen.dart';

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
    'renders ChatStrings.tabEmptyTitle + CTA; tap fires onOpenDashboard seam',
    (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ChatTabPlaceholderScreen(onOpenDashboard: () => taps++),
        ),
      );
      await _pumpFrames(tester);

      expect(find.text('Chat is coming soon'), findsOneWidget);
      expect(find.byKey(const Key('emptyState.cta')), findsOneWidget);
      expect(find.text('Open Dashboard'), findsOneWidget);

      await tester.tap(find.byKey(const Key('emptyState.cta')));
      await _pumpFrames(tester);
      expect(taps, 1);
    },
  );
}
