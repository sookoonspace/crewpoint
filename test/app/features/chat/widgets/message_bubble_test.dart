import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/message_bubble.dart';

ChatMessageModel _msg({String id = 'm1', String text = 'hi'}) =>
    ChatMessageModel(
      id: id,
      eventId: 'e1',
      senderId: 'u1',
      text: text,
      timestamp: DateTime(2025, 1, 1),
      senderName: 'Alice',
    );

Future<void> _pumpInBox(
  WidgetTester tester, {
  required double parentWidth,
  required Widget bubble,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: parentWidth, child: bubble),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('bubble caps at 540 inside a 720-wide parent', (tester) async {
    await _pumpInBox(
      tester,
      parentWidth: 720,
      bubble: MessageBubble(
        message: _msg(text: 'a' * 5000),
        isCurrentUser: false,
      ),
    );

    final width = tester.getSize(find.byKey(const Key('chat.bubble.m1'))).width;
    expect(width, lessThanOrEqualTo(540));
  });

  testWidgets('bubble shrinks below 375 inside a 375-wide parent', (
    tester,
  ) async {
    await _pumpInBox(
      tester,
      parentWidth: 375,
      bubble: MessageBubble(
        message: _msg(text: 'a' * 5000),
        isCurrentUser: false,
      ),
    );

    final width = tester.getSize(find.byKey(const Key('chat.bubble.m1'))).width;
    expect(width, lessThanOrEqualTo(375));
  });

  testWidgets('outer Align flips direction by isCurrentUser', (tester) async {
    await _pumpInBox(
      tester,
      parentWidth: 720,
      bubble: MessageBubble(message: _msg(), isCurrentUser: true),
    );
    final selfAlign = tester.widget<Align>(
      find.byKey(const Key('chat.message.m1')),
    );
    expect(selfAlign.alignment, equals(Alignment.centerRight));

    await _pumpInBox(
      tester,
      parentWidth: 720,
      bubble: MessageBubble(message: _msg(), isCurrentUser: false),
    );
    final peerAlign = tester.widget<Align>(
      find.byKey(const Key('chat.message.m1')),
    );
    expect(peerAlign.alignment, equals(Alignment.centerLeft));
  });
}
