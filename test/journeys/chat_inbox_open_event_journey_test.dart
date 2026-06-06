import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/chat_messages_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/chat_reads_dao.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/data/firestore_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_inbox_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

import '../robots/chat_inbox_robot.dart';

void main() {
  testWidgets(
    'inbox journey: urgent unread row is highlighted with bell + badge; tap fires onOpenChat',
    (tester) async {
      const eventUrgent = EventModel(
        id: 'evt-urgent',
        title: 'Need answer',
        creatorId: 'me',
        memberIds: ['me', 'alex'],
      );
      const eventCalm = EventModel(
        id: 'evt-calm',
        title: 'Casual sync',
        creatorId: 'me',
        memberIds: ['me', 'bob'],
      );
      final urgentMsg = ChatMessageModel(
        id: 'm-urgent',
        eventId: 'evt-urgent',
        senderId: 'alex',
        text: 'Need a call',
        timestamp: DateTime(2026, 5, 15, 10),
        senderName: 'Alex',
        isHighPriority: true,
      );
      final calmMsg = ChatMessageModel(
        id: 'm-calm',
        eventId: 'evt-calm',
        senderId: 'bob',
        text: 'fyi',
        timestamp: DateTime(2026, 5, 14, 9),
        senderName: 'Bob',
      );

      final firestore = FakeFirebaseFirestore();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ChatRepository(
        chatService: FirestoreChatService(firestore: firestore),
        chatMessagesDao: ChatMessagesDao(db),
        firestore: firestore,
        chatReadsDao: ChatReadsDao(db),
      );
      addTearDown(repo.dispose);

      final robot = ChatInboxRobot(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(firestore),
            databaseProvider.overrideWithValue(db),
            chatRepositoryProvider.overrideWithValue(repo),
            currentUserIdProvider.overrideWith((ref) => 'me'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [eventUrgent, eventCalm]),
            ),
            chatMessagesProvider.overrideWith((ref, eventId) {
              return switch (eventId) {
                'evt-urgent' => Stream.value([urgentMsg]),
                'evt-calm' => Stream.value([calmMsg]),
                _ => Stream.value(const <ChatMessageModel>[]),
              };
            }),
            usersByIdProvider.overrideWith(
              (ref, key) async => const <String, AppUser>{},
            ),
            // No backfill (lastReadAt absent), so every other-sender
            // message counts as unread.
            eventChatReadStateProvider.overrideWith(
              (ref, arg) => Stream.value(null),
            ),
          ],
          child: MaterialApp(home: ChatInboxScreen(onOpenChat: robot.onOpen)),
        ),
      );
      await robot.pumpFrames();

      robot.expectRowVisible('evt-urgent');
      robot.expectRowVisible('evt-calm');
      robot.expectUrgent('evt-urgent');
      robot.expectNotUrgent('evt-calm');
      robot.expectUnreadBadge('evt-urgent');
      robot.expectUnreadBadge('evt-calm');

      await robot.tapRowFor('evt-urgent');
      expect(robot.capturedOpen, isNotNull);
      expect(robot.capturedOpen!.event.id, 'evt-urgent');
    },
  );
}
