/// Pins the chat-detail AppBar title fix from the 2026-06-08 iPhone
/// 12 mini UI QA pass (Chat_detail_screen.PNG): the screen rendered
/// the generic "Chat" string in the AppBar, leaving users in multiple
/// events with no signal about which thread they were inside.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_screen.dart';

void main() {
  testWidgets(
    'AppBar surfaces the supplied event title rather than the generic '
    '"Chat" label so multi-event users can identify the thread',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(
            messages: [],
            currentUserId: 'u1',
            appBarTitle: 'Weekend getaway',
          ),
        ),
      );

      final inAppBar = find.descendant(
        of: find.byType(CpTopBar),
        matching: find.text('Weekend getaway'),
      );
      expect(inAppBar, findsOneWidget);
      expect(
        find.descendant(of: find.byType(CpTopBar), matching: find.text('Chat')),
        findsNothing,
      );
    },
  );

  testWidgets('AppBar falls back to the i18n default ("Chat") when no '
      'appBarTitle is supplied', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(messages: [], currentUserId: 'u1'),
      ),
    );

    expect(
      find.descendant(of: find.byType(CpTopBar), matching: find.text('Chat')),
      findsOneWidget,
    );
  });

  testWidgets('a long title fits the top bar on a 320 px phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(
          messages: [],
          currentUserId: 'u1',
          appBarTitle: 'Weekend getaway with the whole crew at the lake house',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(CpTopBar),
        matching: find.textContaining('Weekend getaway'),
      ),
      findsOneWidget,
    );
  });
}
