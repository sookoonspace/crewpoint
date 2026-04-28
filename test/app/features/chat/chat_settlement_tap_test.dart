import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_screen.dart';

void main() {
  testWidgets(
    'tapping a settlement-kind bubble fires onTapSettlement; tapping a '
    'normal one does not',
    (tester) async {
      final messages = [
        ChatMessageModel(
          id: 'normal-1',
          eventId: 'e1',
          senderId: 'me',
          text: 'Hey there!',
          timestamp: DateTime(2026, 4),
        ),
        ChatMessageModel(
          id: 'settle-1',
          eventId: 'e1',
          senderId: 'me',
          text: 'Settled \$25',
          timestamp: DateTime(2026, 4, 2),
          kind: ChatMessageKind.settlement,
        ),
      ];

      final tapped = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            messages: messages,
            currentUserId: 'me',
            onTapSettlement: (m) => tapped.add(m.id),
          ),
        ),
      );

      // Tap normal — no fire.
      await tester.tap(find.byKey(const Key('chat.message.normal-1')));
      await tester.pumpAndSettle();
      expect(tapped, isEmpty);

      // Tap settlement — fires.
      await tester.tap(find.byKey(const Key('chat.message.settle-1')));
      await tester.pumpAndSettle();
      expect(tapped, equals(['settle-1']));
    },
  );
}
