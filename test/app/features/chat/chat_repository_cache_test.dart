import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase, EventsCompanion, UsersCompanion;
import 'package:crewpoint_app/app/core/database/daos/chat_messages_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/users_dao.dart';
import 'package:crewpoint_app/app/core/services/i_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';

class _ControllableChatService implements IChatService {
  final _byEvent = <String, StreamController<List<ChatMessage>>>{};

  StreamController<List<ChatMessage>> _controller(String eventId) =>
      _byEvent.putIfAbsent(
        eventId,
        () => StreamController<List<ChatMessage>>.broadcast(),
      );

  void emit(String eventId, List<ChatMessage> messages) {
    _controller(eventId).add(messages);
  }

  @override
  Stream<List<ChatMessage>> messagesForEvent(String eventId) =>
      _controller(eventId).stream;

  @override
  Future<void> sendMessage({
    required String eventId,
    required String senderId,
    required String text,
    bool isHighPriority = false,
  }) async {}

  @override
  Future<void> deleteMessage({
    required String eventId,
    required String messageId,
  }) async {}

  @override
  Future<void> postSettlementNotice({
    required String eventId,
    required String messageId,
    required String senderId,
    required String text,
  }) async {}

  Future<void> close() async {
    for (final c in _byEvent.values) {
      await c.close();
    }
  }
}

void main() {
  late AppDatabase db;
  late _ControllableChatService service;
  late ChatMessagesDao dao;
  late ChatRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = _ControllableChatService();
    dao = ChatMessagesDao(db);
    await UsersDao(
      db,
    ).insertUser(UsersCompanion.insert(id: 'sender', email: 's@example.com'));
    await EventsDao(db).insertEvent(
      EventsCompanion.insert(
        id: 'event-1',
        title: 'Trip',
        creatorId: 'sender',
        startDate: const Value.absent(),
      ),
    );
    repo = ChatRepository(
      chatService: service,
      chatMessagesDao: dao,
      maxCachedRows: 3, // tiny cap for eviction test
    );
  });

  tearDown(() async {
    await repo.dispose();
    await service.close();
    await db.close();
  });

  test('incoming Firestore messages are mirrored into Drift and emitted '
      'via watchMessages', () async {
    final stream = repo.watchMessages('event-1');
    final firstNonEmpty = stream.firstWhere((list) => list.isNotEmpty);

    service.emit('event-1', [
      ChatMessage(
        id: 'm1',
        eventId: 'event-1',
        senderId: 'sender',
        text: 'Hello',
        timestamp: DateTime(2026, 4, 1, 12),
      ),
    ]);

    final messages = await firstNonEmpty;
    expect(messages, hasLength(1));
    expect(messages.first.text, 'Hello');

    // Drift now has the row
    final localRows = await dao.byEventId('event-1');
    expect(localRows, hasLength(1));
  });

  test('Drift cache caps at maxCachedRows, evicting oldest first', () async {
    final stream = repo.watchMessages('event-1');
    final sub = stream.listen((_) {});
    addTearDown(() async => sub.cancel());

    service.emit('event-1', [
      ChatMessage(
        id: 'old-1',
        eventId: 'event-1',
        senderId: 'sender',
        text: 'oldest',
        timestamp: DateTime(2026, 4, 1, 12),
      ),
      ChatMessage(
        id: 'mid-1',
        eventId: 'event-1',
        senderId: 'sender',
        text: 'mid',
        timestamp: DateTime(2026, 4, 1, 13),
      ),
      ChatMessage(
        id: 'new-1',
        eventId: 'event-1',
        senderId: 'sender',
        text: 'new',
        timestamp: DateTime(2026, 4, 1, 14),
      ),
      ChatMessage(
        id: 'newest-1',
        eventId: 'event-1',
        senderId: 'sender',
        text: 'newest',
        timestamp: DateTime(2026, 4, 1, 15),
      ),
    ]);

    // give the listener a tick to mirror + evict
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final localRows = await dao.byEventId('event-1');
    expect(localRows, hasLength(3));
    expect(
      localRows.map((r) => r.id).toSet(),
      equals({'mid-1', 'new-1', 'newest-1'}),
    );
  });
}
