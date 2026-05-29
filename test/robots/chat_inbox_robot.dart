import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';

/// Intent-centric helpers for the cross-event Chat inbox.
///
/// Selector contract — declared by the widgets under test:
/// - `Key('chat.inbox.tile.{eventId}')` — the row's tap target
/// - `Key('conversation.tile.unreadPill')` — unread count pill (per-row,
///   found via `find.descendant` of the row key above)
/// - `Key('conversation.tile.urgentBadge')` — urgent flag (same)
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
      find.descendant(
        of: find.byKey(Key('chat.inbox.tile.$eventId')),
        matching: find.byKey(const Key('conversation.tile.urgentBadge')),
      ),
      findsOneWidget,
      reason:
          'Expected event $eventId to render the URGENT badge. '
          'Check the row\'s hasUrgentUnread flag.',
    );
  }

  void expectNotUrgent(String eventId) {
    expect(
      find.descendant(
        of: find.byKey(Key('chat.inbox.tile.$eventId')),
        matching: find.byKey(const Key('conversation.tile.urgentBadge')),
      ),
      findsNothing,
      reason: 'Expected event $eventId NOT to render the URGENT badge.',
    );
  }

  void expectUnreadBadge(String eventId) {
    expect(
      find.descendant(
        of: find.byKey(Key('chat.inbox.tile.$eventId')),
        matching: find.byKey(const Key('conversation.tile.unreadPill')),
      ),
      findsOneWidget,
    );
  }

  void expectNoUnreadBadge(String eventId) {
    expect(
      find.descendant(
        of: find.byKey(Key('chat.inbox.tile.$eventId')),
        matching: find.byKey(const Key('conversation.tile.unreadPill')),
      ),
      findsNothing,
    );
  }

  /// Holder for the screen's `onOpenChat` capture used by journey
  /// assertions. Robot owns the closure so tests stay terse.
  InboxRow? capturedOpen;
  void onOpen(BuildContext _, InboxRow row) {
    capturedOpen = row;
  }
}
