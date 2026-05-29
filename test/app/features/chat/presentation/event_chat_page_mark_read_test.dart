import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/chat_messages_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/chat_reads_dao.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/data/firestore_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/event_chat_page.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

import '../../auth/fake_auth_service.dart';

/// Stub auth notifier that emits a fixed `Authenticated` state on build.
class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier({required this.user})
    : super(authRepository: AuthRepository(authService: FakeAuthService()));

  final AppUser user;

  @override
  AuthState build() => Authenticated(user);
}

void main() {
  testWidgets(
    'EventChatPage marks the event as read on the first frame after mount',
    (tester) async {
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

      const event = EventModel(
        id: 'e-1',
        title: 'Trip',
        creatorId: 'me',
        memberIds: ['me'],
      );
      const me = AppUser(uid: 'me', email: 'me@example.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(firestore),
            databaseProvider.overrideWithValue(db),
            chatRepositoryProvider.overrideWithValue(repo),
            chatMessagesProvider.overrideWith(
              (ref, eventId) => Stream.value(const <ChatMessageModel>[]),
            ),
            authProvider.overrideWith(() => _StubAuthNotifier(user: me)),
          ],
          child: const MaterialApp(home: EventChatPage(event: event)),
        ),
      );
      // Allow post-frame callback to fire + microtask drain.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final doc = await firestore
          .collection('users')
          .doc('me')
          .collection('chatReads')
          .doc('e-1')
          .get();
      expect(
        doc.exists,
        isTrue,
        reason:
            'EventChatPage.initState should fire markEventRead(uid, eventId) after first frame',
      );
    },
  );
}
