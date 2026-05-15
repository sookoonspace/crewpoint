import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_inbox_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Lottie loops forever — bounded pumps, not pumpAndSettle.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('loading branch — renders LoadingAnimation; no empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'uid-1'),
          dashboardEventsProvider.overrideWith(
            (ref) => const Stream<List<EventModel>>.empty(),
          ),
        ],
        child: const MaterialApp(home: ChatInboxScreen()),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byType(LoadingAnimation), findsOneWidget);
    expect(find.byKey(const Key('emptyState.title')), findsNothing);
  });

  testWidgets(
    'empty-with-events branch — inboxEmptySubtitle + openDashboardCta',
    (tester) async {
      const event = EventModel(
        id: 'evt-1',
        title: 'Tahoe Trip',
        creatorId: 'uid-1',
        memberIds: ['uid-1'],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'uid-1'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [event]),
            ),
            chatMessagesProvider.overrideWith(
              (ref, eventId) => Stream.value(const <ChatMessageModel>[]),
            ),
          ],
          child: const MaterialApp(home: ChatInboxScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.text('Open an event from the Dashboard to start chatting.'),
        findsOneWidget,
      );
      expect(find.text('Open Dashboard'), findsOneWidget);
    },
  );

  testWidgets(
    'empty-no-events branch — inboxEmptyNoEventsSubtitle + createFromDashboardCta',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'uid-1'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const <EventModel>[]),
            ),
          ],
          child: const MaterialApp(home: ChatInboxScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.text('Create or join an event to chat with your crew.'),
        findsOneWidget,
      );
      expect(find.text('Create an event'), findsOneWidget);
      expect(find.text('Open Dashboard'), findsNothing);
    },
  );

  testWidgets(
    'null-uid short-circuit — signInRequiredTitle; globalInboxProvider never subscribed',
    (tester) async {
      var dashboardSubscriptions = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => null),
            // Counter-override: subscribing means globalInboxProvider was
            // invoked. Should stay at 0.
            dashboardEventsProvider.overrideWith((ref) {
              dashboardSubscriptions++;
              return Stream.value(const <EventModel>[]);
            }),
          ],
          child: const MaterialApp(home: ChatInboxScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(find.text('Sign in to view your tasks'), findsOneWidget);
      expect(
        dashboardSubscriptions,
        0,
        reason: 'globalInboxProvider must NOT be invoked when uid is null',
      );
    },
  );

  testWidgets(
    'non-empty branch — one InboxTile per row; tap fires onOpenChat seam with right event',
    (tester) async {
      const eventA = EventModel(
        id: 'evt-a',
        title: 'Tahoe Trip',
        creatorId: 'uid-1',
        memberIds: ['uid-1', 'alex'],
      );
      const eventB = EventModel(
        id: 'evt-b',
        title: 'Project Sync',
        creatorId: 'uid-1',
        memberIds: ['uid-1'],
      );
      final msgA = ChatMessageModel(
        id: 'm-a',
        eventId: 'evt-a',
        senderId: 'alex',
        text: 'Bring snacks',
        timestamp: DateTime(2026, 5, 13, 12),
        senderName: 'Alex',
      );
      final msgB = ChatMessageModel(
        id: 'm-b',
        eventId: 'evt-b',
        senderId: 'uid-1',
        text: 'Done',
        timestamp: DateTime(2026, 5, 12, 8),
      );

      InboxRow? captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'uid-1'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [eventA, eventB]),
            ),
            chatMessagesProvider.overrideWith((ref, eventId) {
              return switch (eventId) {
                'evt-a' => Stream.value([msgA]),
                'evt-b' => Stream.value([msgB]),
                _ => Stream.value(const <ChatMessageModel>[]),
              };
            }),
          ],
          child: MaterialApp(
            home: ChatInboxScreen(onOpenChat: (_, row) => captured = row),
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(const Key('chat.inbox.tile.evt-a')), findsOneWidget);
      expect(find.byKey(const Key('chat.inbox.tile.evt-b')), findsOneWidget);
      // Alex's message in event A renders "Alex: Bring snacks".
      expect(find.text('Alex: Bring snacks'), findsOneWidget);
      // Own message in event B renders "You: Done".
      expect(find.text('You: Done'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat.inbox.tile.evt-a')));
      await _pumpFrames(tester);
      expect(captured?.event.id, 'evt-a');
    },
  );
}
