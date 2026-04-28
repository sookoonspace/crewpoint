import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_screen.dart';

void main() {
  testWidgets('empty state copy matches the spec', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(messages: [], currentUserId: 'me'),
      ),
    );

    expect(find.byKey(const Key('chat.list.empty')), findsOneWidget);
    expect(
      find.text('No messages yet — be the first to say something.'),
      findsOneWidget,
    );
  });

  testWidgets('Send button disabled while isSending; spinner shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(messages: [], currentUserId: 'me', isSending: true),
      ),
    );

    final btn = tester.widget<IconButton>(
      find.byKey(const Key('chat.composer.send')),
    );
    expect(btn.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('lastSendFailed surfaces a retry indicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(
          messages: [],
          currentUserId: 'me',
          lastSendFailed: true,
        ),
      ),
    );

    expect(find.text('Send failed — tap Send again to retry'), findsOneWidget);
  });

  testWidgets('Resolved sender name from memberNames replaces UID label', (
    tester,
  ) async {
    final messages = [
      ChatMessageModel(
        id: 'm1',
        eventId: 'e1',
        senderId: 'user-2',
        text: 'hi',
        timestamp: DateTime(2026, 4),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          messages: messages,
          currentUserId: 'me',
          memberNames: const {'user-2': 'Alex'},
        ),
      ),
    );

    expect(find.text('Alex'), findsOneWidget);
  });
}
