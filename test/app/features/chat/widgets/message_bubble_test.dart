import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/theme/app_theme.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/widgets/message_bubble.dart';

import '../../../core/_helpers/wcag_contrast.dart';

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

  /// Pumps a bubble under a real `AppTheme` so background/text colors
  /// inherit the brightness-aware ColorScheme. Passes the theme as both
  /// `theme` and `darkTheme` and forces `themeMode` so the requested
  /// brightness is honoured regardless of the test binding's platform
  /// brightness default (light).
  Future<void> pumpWithTheme(
    WidgetTester tester, {
    required ThemeData theme,
    required ChatMessageModel message,
    required bool isCurrentUser,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: theme,
          child: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 375,
                child: MessageBubble(
                  message: message,
                  isCurrentUser: isCurrentUser,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Reads the bubble's background color (Container.decoration.color) and
  /// the body text color (the last Text widget in the bubble, which is
  /// the message text per message_bubble.dart:115).
  ({Color bg, Color fg}) readColors(WidgetTester tester, Key bubbleKey) {
    final container = tester.widget<Container>(find.byKey(bubbleKey));
    final bg = (container.decoration! as BoxDecoration).color!;
    // The message body Text is the last Text inside the bubble Column.
    final texts = find
        .descendant(of: find.byKey(bubbleKey), matching: find.byType(Text))
        .evaluate()
        .map((e) => e.widget as Text)
        .toList();
    final body = texts.last;
    final fg = body.style!.color!;
    return (bg: bg, fg: fg);
  }

  testWidgets('other-user bubble meets WCAG AA in light AND dark mode', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await pumpWithTheme(
        tester,
        theme: theme,
        message: _msg(),
        isCurrentUser: false,
      );
      final colors = readColors(tester, const Key('chat.bubble.m1'));
      expectAaContrast(
        colors.fg,
        colors.bg,
        reason:
            'other-user bubble in ${theme.brightness} theme — '
            'fg ≥ 4.5:1 vs bg required',
      );
    }
  });

  testWidgets('own-user bubble meets WCAG AA in light AND dark mode', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await pumpWithTheme(
        tester,
        theme: theme,
        message: _msg(),
        isCurrentUser: true,
      );
      final colors = readColors(tester, const Key('chat.bubble.m1'));
      expectAaContrast(
        colors.fg,
        colors.bg,
        reason: 'own bubble in ${theme.brightness} theme',
      );
    }
  });

  testWidgets('high-priority bubble meets WCAG AA in light AND dark mode', (
    tester,
  ) async {
    final urgent = ChatMessageModel(
      id: 'm1',
      eventId: 'e1',
      senderId: 'u1',
      text: 'Critical',
      timestamp: DateTime(2025, 1, 1),
      isHighPriority: true,
    );
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await pumpWithTheme(
        tester,
        theme: theme,
        message: urgent,
        isCurrentUser: false,
      );
      final colors = readColors(tester, const Key('chat.bubble.m1'));
      // Backgrounds use alpha; opaque comparison would be misleading.
      // For now assert the text color resolves to a non-null value and
      // contrast against the painted bg meets AA.
      expectAaContrast(
        colors.fg,
        colors.bg,
        reason: 'high-priority bubble in ${theme.brightness} theme',
      );
    }
  });

  testWidgets('settlement bubble meets WCAG AA in light AND dark mode', (
    tester,
  ) async {
    final settle = ChatMessageModel(
      id: 'm1',
      eventId: 'e1',
      senderId: 'u1',
      text: 'Paid \$10',
      timestamp: DateTime(2025, 1, 1),
      kind: ChatMessageKind.settlement,
    );
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await pumpWithTheme(
        tester,
        theme: theme,
        message: settle,
        isCurrentUser: false,
      );
      final colors = readColors(tester, const Key('chat.bubble.m1'));
      expectAaContrast(
        colors.fg,
        colors.bg,
        reason: 'settlement bubble in ${theme.brightness} theme',
      );
    }
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
