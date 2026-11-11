import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_window.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/event_chat_page.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../auth/fake_auth_service.dart';

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier()
    : super(authRepository: AuthRepository(authService: FakeAuthService()));

  @override
  AuthState build() =>
      const Authenticated(AppUser(uid: 'me', email: 'me@example.com'));
}

/// Answers older pages, or fails.
class _Repo implements ChatRepository {
  _Repo(this.pages);

  final List<Object> pages;
  int fetches = 0;

  @override
  Future<List<ChatMessageModel>> fetchOlder(
    String eventId, {
    required DateTime before,
  }) async {
    fetches++;
    final next = pages.removeAt(0);
    if (next is List<ChatMessageModel>) return next;
    throw next;
  }

  @override
  Future<void> markEventRead(String uid, String eventId, {int? count}) async {}

  @override
  void disposeMirror(String eventId) {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

ChatMessageModel _m(String id, int minute) => ChatMessageModel(
  id: id,
  eventId: 'e1',
  senderId: 'me',
  text: 'Message $id',
  timestamp: DateTime.utc(2027, 1, 1).add(Duration(minutes: minute)),
);

/// Req 57: chat shows the latest 50 messages, with earlier pages on demand,
/// and says earlier ones need a connection when offline.
void main() {
  const event = EventModel(
    id: 'e1',
    title: 'Trip',
    creatorId: 'me',
    memberIds: ['me'],
  );
  final latest = [for (var i = 100; i < 100 + chatPageSize; i++) _m('n$i', i)];

  Future<_Repo> pump(
    WidgetTester tester, {
    List<ChatMessageModel>? messages,
    List<Object> pages = const [],
    bool offline = false,
  }) async {
    final repo = _Repo([...pages]);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          databaseProvider.overrideWithValue(db),
          authProvider.overrideWith(_StubAuthNotifier.new),
          chatRepositoryProvider.overrideWithValue(repo),
          chatMessagesProvider.overrideWith(
            (ref, _) => Stream.value(messages ?? latest),
          ),
          mirrorSyncProvider.overrideWith(
            (ref, key) =>
                Stream.value(MirrorSync(mirrorKey: key, fromCache: offline)),
          ),
        ],
        child: const MaterialApp(home: EventChatPage(event: event)),
      ),
    );
    await tester.pump();
    await tester.pump();
    return repo;
  }

  Future<void> scrollToTop(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('chat.list')),
      const Offset(0, 20000),
    );
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('loads earlier messages on demand', (tester) async {
    final repo = await pump(
      tester,
      pages: [
        [for (var i = 99; i >= 50; i--) _m('o$i', i)],
      ],
    );
    await scrollToTop(tester);
    await tester.tap(find.byKey(const Key('chat.older.load')));
    await tester.pump();
    await tester.pump();
    expect(repo.fetches, 1);
    await scrollToTop(tester);
    expect(find.text('Message o50'), findsOneWidget);
    // A full page means there may be more.
    expect(find.byKey(const Key('chat.older.load')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('says when the start of the chat is reached', (tester) async {
    await pump(
      tester,
      pages: [
        [_m('o1', 1)],
      ],
    );
    await scrollToTop(tester);
    await tester.tap(find.byKey(const Key('chat.older.load')));
    await tester.pump();
    await tester.pump();
    await scrollToTop(tester);
    expect(find.byKey(const Key('chat.older.none')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a failed load explains and retries', (tester) async {
    final repo = await pump(
      tester,
      pages: [
        StateError('offline'),
        [_m('o1', 1)],
      ],
    );
    await scrollToTop(tester);
    await tester.tap(find.byKey(const Key('chat.older.load')));
    await tester.pump();
    await tester.pump();
    await scrollToTop(tester);
    expect(find.byKey(const Key('chat.older.failed')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat.older.retry')));
    await tester.pump();
    await tester.pump();
    expect(repo.fetches, 2);
    await finish(tester);
  });

  testWidgets('offline, says earlier messages need a connection', (
    tester,
  ) async {
    final repo = await pump(tester, offline: true);
    await scrollToTop(tester);
    expect(find.byKey(const Key('chat.older.offline')), findsOneWidget);
    expect(find.byKey(const Key('chat.older.load')), findsNothing);
    expect(repo.fetches, 0);
    await finish(tester);
  });

  testWidgets('fewer than a page means the whole chat is shown', (
    tester,
  ) async {
    await pump(tester, messages: [_m('a', 1), _m('b', 2)]);
    expect(find.byKey(const Key('chat.older.load')), findsNothing);
    expect(find.byKey(const Key('chat.older.none')), findsNothing);
    await finish(tester);
  });
}
