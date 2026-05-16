import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/chat_messages_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/chat_reads_dao.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/data/firestore_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_inbox_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Lottie loops forever — bounded pumps, not pumpAndSettle.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Unmount the widget tree + drain pending Drift stream timers before
/// the test framework checks for stragglers. Without this, ChatInboxScreen's
/// per-event read-state Drift watchers leak as pending timers and trip
/// the binding's `!timersPending` invariant.
Future<void> _teardownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Test-safe baseline holding the fake Firebase + in-memory Drift +
/// real ChatRepository. The record's `withScope` builder wraps the
/// per-test child in a `ProviderScope` with the baseline + caller's
/// extra overrides — sidesteps Dart's ambiguity around Riverpod's
/// sealed `Override` type by keeping the override list local.
class _ChatInboxTestBaseline {
  _ChatInboxTestBaseline._({
    required this.firestore,
    required this.db,
    required this.repo,
  });

  factory _ChatInboxTestBaseline.create() {
    final firestore = FakeFirebaseFirestore();
    final db = AppDatabase(NativeDatabase.memory());
    final repo = ChatRepository(
      chatService: FirestoreChatService(firestore: firestore),
      chatMessagesDao: ChatMessagesDao(db),
      firestore: firestore,
      chatReadsDao: ChatReadsDao(db),
    );
    return _ChatInboxTestBaseline._(firestore: firestore, db: db, repo: repo);
  }

  final FakeFirebaseFirestore firestore;
  final AppDatabase db;
  final ChatRepository repo;

  /// Returns the three baseline overrides as a typed list — caller
  /// spreads it inline into a `ProviderScope`'s `overrides` list, so
  /// Dart infers the proper Riverpod `Override` type from the
  /// `ProviderScope` constructor (sidesteps the `dart:core.Override`
  /// shadow).
  List<dynamic> get baseOverrides => <dynamic>[
    firestoreProvider.overrideWithValue(firestore),
    databaseProvider.overrideWithValue(db),
    chatRepositoryProvider.overrideWithValue(repo),
  ];

  Future<void> cleanup() async {
    await repo.dispose();
    await db.close();
  }
}

void main() {
  testWidgets('loading branch — renders LoadingAnimation; no empty state', (
    tester,
  ) async {
    final base = _ChatInboxTestBaseline.create();
    addTearDown(base.cleanup);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base.baseOverrides.cast(),
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

    await _teardownTree(tester);
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
      final base = _ChatInboxTestBaseline.create();
      addTearDown(base.cleanup);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base.baseOverrides.cast(),
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

      await _teardownTree(tester);
    },
  );

  testWidgets(
    'empty-no-events branch — inboxEmptyNoEventsSubtitle + createFromDashboardCta',
    (tester) async {
      final base = _ChatInboxTestBaseline.create();
      addTearDown(base.cleanup);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base.baseOverrides.cast(),
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

      await _teardownTree(tester);
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
      final base = _ChatInboxTestBaseline.create();
      addTearDown(base.cleanup);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base.baseOverrides.cast(),
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

      await _teardownTree(tester);
    },
  );

  testWidgets(
    'first-load backfill — writes lastReadAt for every event without an existing read doc',
    (tester) async {
      const eventA = EventModel(
        id: 'evt-a',
        title: 'A',
        creatorId: 'uid-1',
        memberIds: ['uid-1'],
      );
      const eventB = EventModel(
        id: 'evt-b',
        title: 'B',
        creatorId: 'uid-1',
        memberIds: ['uid-1'],
      );
      final base = _ChatInboxTestBaseline.create();
      addTearDown(base.cleanup);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base.baseOverrides.cast(),
            currentUserIdProvider.overrideWith((ref) => 'uid-1'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [eventA, eventB]),
            ),
            chatMessagesProvider.overrideWith(
              (ref, eventId) => Stream.value(const <ChatMessageModel>[]),
            ),
          ],
          child: const MaterialApp(home: ChatInboxScreen()),
        ),
      );
      await _pumpFrames(tester);

      final docs = await base.firestore
          .collection('users')
          .doc('uid-1')
          .collection('chatReads')
          .get();
      expect(
        docs.docs.map((d) => d.id).toSet(),
        {'evt-a', 'evt-b'},
        reason:
            'ChatInboxScreen should fire backfillReadStateForExistingEvents '
            'once on the first inbox render',
      );

      await _teardownTree(tester);
    },
  );
}
