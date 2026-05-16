import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';

/// Intent-centric helpers for the cross-event Chat inbox.
///
/// Selector contract — declared by the widgets under test:
/// - `Key('chat.inbox.tile.{eventId}')` — the row's tap target
/// - `Key('chat.inbox.tile.{eventId}.badge')` — unread badge container
/// - `Key('chat.inbox.tile.{eventId}.urgent')` — terracotta bell icon
class ChatInboxRobot {
  ChatInboxRobot(this.tester);

  final WidgetTester tester;

  /// Bounded pumps — the inbox screen renders a looping Lottie inside
  /// `EmptyStatePlaceholder`, so `pumpAndSettle` would hang.
  Future<void> pumpFrames({int frames = 3}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapRowFor(String eventId) async {
    await tester.tap(find.byKey(Key('chat.inbox.tile.$eventId')));
    await pumpFrames();
  }

  void expectRowVisible(String eventId) {
    expect(find.byKey(Key('chat.inbox.tile.$eventId')), findsOneWidget);
  }

  void expectUrgent(String eventId) {
    expect(
      find.byKey(Key('chat.inbox.tile.$eventId.urgent')),
      findsOneWidget,
      reason:
          'Expected event $eventId to render the urgent bell icon. '
          'Check the row\'s hasUrgentUnread flag.',
    );
  }

  void expectNotUrgent(String eventId) {
    expect(
      find.byKey(Key('chat.inbox.tile.$eventId.urgent')),
      findsNothing,
      reason: 'Expected event $eventId NOT to render the urgent bell icon.',
    );
  }

  void expectUnreadBadge(String eventId) {
    expect(find.byKey(Key('chat.inbox.tile.$eventId.badge')), findsOneWidget);
  }

  void expectNoUnreadBadge(String eventId) {
    expect(find.byKey(Key('chat.inbox.tile.$eventId.badge')), findsNothing);
  }

  /// Holder for the screen's `onOpenChat` capture used by journey
  /// assertions. Robot owns the closure so tests stay terse.
  InboxRow? capturedOpen;
  void onOpen(BuildContext _, InboxRow row) {
    capturedOpen = row;
  }
}
