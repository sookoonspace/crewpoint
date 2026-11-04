import 'package:crewpoint_app/app/core/theme/app_theme.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_screen.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/critical_alert_modal.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _limited = Key('chat.message.urgentLimited');
const _openUrgent = Key('chat.urgent.open');

ChatMessageModel _message({bool skipped = false}) => ChatMessageModel(
  id: 'm1',
  eventId: 'e1',
  senderId: 'me',
  text: 'Fire',
  timestamp: DateTime(2027),
  isHighPriority: true,
  urgentPushSkipped: skipped,
);

Future<void> _pumpBubble(
  WidgetTester tester, {
  required ChatMessageModel message,
  required bool isCurrentUser,
  ThemeData? theme,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme,
    home: Scaffold(
      body: MessageBubble(message: message, isCurrentUser: isCurrentUser),
    ),
  ),
);

void main() {
  group('over the urgent rate', () {
    testWidgets('the sender is told nobody was alerted', (tester) async {
      await _pumpBubble(
        tester,
        message: _message(skipped: true),
        isCurrentUser: true,
      );
      expect(find.byKey(_limited), findsOneWidget);
      expect(find.textContaining('nobody was alerted'), findsOneWidget);
      expect(find.text('Fire'), findsOneWidget);
    });

    testWidgets('it is readable in dark mode', (tester) async {
      await _pumpBubble(
        tester,
        message: _message(skipped: true),
        isCurrentUser: true,
        theme: AppTheme.dark(),
      );
      expect(find.byKey(_limited), findsOneWidget);
    });

    testWidgets('others do not see that note', (tester) async {
      await _pumpBubble(
        tester,
        message: _message(skipped: true),
        isCurrentUser: false,
      );
      expect(find.byKey(_limited), findsNothing);
    });

    testWidgets('no note on a message that did alert', (tester) async {
      await _pumpBubble(tester, message: _message(), isCurrentUser: true);
      expect(find.byKey(_limited), findsNothing);
    });

    testWidgets('the chat screen keeps the flag on the message', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            messages: [_message(skipped: true)],
            currentUserId: 'me',
            memberNames: const {'me': 'Me'},
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(_limited), findsOneWidget);
    });
  });

  group('urgent permission', () {
    Widget screen({ValueChanged<String>? onUrgent}) => MaterialApp(
      home: ChatScreen(
        messages: const [],
        currentUserId: 'me',
        onSendCriticalAlert: onUrgent,
      ),
    );

    testWidgets('the urgent action is hidden without permission', (
      tester,
    ) async {
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(find.byKey(_openUrgent), findsNothing);
    });

    testWidgets('the urgent action shows with permission', (tester) async {
      await tester.pumpWidget(screen(onUrgent: (_) {}));
      await tester.pump();
      expect(find.byKey(_openUrgent), findsOneWidget);
    });
  });

  group('message size', () {
    testWidgets('the composer stops at 4,000 characters', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(messages: [], currentUserId: 'me'),
        ),
      );
      await tester.pump();
      final input = find.byKey(const Key('chat.composer.input'));
      await tester.enterText(input, 'a' * 4001);
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text.length, 4000);
    });

    testWidgets('a custom urgent alert stops at 4,000 characters', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CriticalAlertModal())),
      );
      final input = find.descendant(
        of: find.byKey(const Key('chat.urgent.custom')),
        matching: find.byType(TextField),
      );
      await tester.enterText(input, 'a' * 4001);
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text.length, 4000);
    });
  });
}
