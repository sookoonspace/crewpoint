import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase, ChatMessagesCompanion, EventsCompanion, UsersCompanion;
import 'package:crewpoint_app/app/core/database/daos/chat_messages_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/mirror_syncs_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/users_dao.dart';
import 'package:crewpoint_app/app/core/services/i_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_window.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';

/// Emits change sets for the latest messages, as Firestore's `docChanges`
/// would, and answers older pages.
class _ControllableChatService implements IChatService {
  final ctrl = StreamController<ChatChanges>.broadcast();
  List<ChatMessage> older = const [];
  DateTime? olderBefore;

  @override
  Stream<ChatChanges> latestMessages(
    String eventId, {
    int limit = chatPageSize,
  }) => ctrl.stream;

  @override
  Future<List<ChatMessage>> olderMessages(
    String eventId, {
    required DateTime before,
    int limit = chatPageSize,
  }) async {
    olderBefore = before;
    return older;
  }

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
}

ChatMessage _m(String id, int minute, {String? kind, bool urgent = false}) =>
    ChatMessage(
      id: id,
      eventId: 'event-1',
      senderId: 'sender',
      text: id,
      timestamp: DateTime.utc(2026, 4, 1, 12, minute),
      kind: kind,
      isHighPriority: urgent,
      urgentPushSkipped: urgent,
    );

ChatChanges _window(List<ChatMessage> w, {bool fromCache = false}) =>
    (upserts: w, deleted: const <String>[], window: w, fromCache: fromCache);

ChatChanges _change({
  List<ChatMessage> upserts = const [],
  List<String> deleted = const [],
  bool fromCache = false,
}) => (upserts: upserts, deleted: deleted, window: null, fromCache: fromCache);

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
      syncs: MirrorSyncsDao(db),
      maxCachedRows: 3,
    );
  });

  tearDown(() async {
    await repo.dispose();
    await service.ctrl.close();
    await db.close();
  });

  Future<List<String>> ids() async => [
    for (final r in await dao.byEventId('event-1')) r.id,
  ];

  /// Lets the mirror apply what was emitted.
  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 30));

  test('the latest messages are mirrored into Drift and emitted', () async {
    final stream = repo.watchMessages('event-1');
    final first = stream.firstWhere((list) => list.isNotEmpty);
    service.ctrl.add(_window([_m('m1', 1)]));
    final messages = await first;
    expect(messages.single.text, 'm1');
    expect(await ids(), ['m1']);
  });

  test(
    'FND-11 a settlement notice keeps its kind through the mirror',
    () async {
      final stream = repo.watchMessages('event-1');
      final seen = stream.firstWhere((l) => l.isNotEmpty);
      service.ctrl.add(_window([_m('s1', 1, kind: 'settlement')]));
      expect((await seen).single.kind, ChatMessageKind.settlement);
    },
  );

  test('the urgent limit flag survives the mirror', () async {
    final stream = repo.watchMessages('event-1');
    final seen = stream.firstWhere((l) => l.isNotEmpty);
    service.ctrl.add(_window([_m('u1', 1, urgent: true)]));
    expect((await seen).single.urgentPushSkipped, isTrue);
  });

  test('FND-11 a deleted message leaves the mirror', () async {
    repo.watchMessages('event-1');
    await tick();
    service.ctrl.add(_window([_m('m1', 1), _m('m2', 2)]));
    await tick();
    service.ctrl.add(_change(deleted: ['m1']));
    await tick();
    expect(await ids(), ['m2']);
  });

  test('only the changed messages are applied', () async {
    repo.watchMessages('event-1');
    await tick();
    service.ctrl.add(_window([_m('m1', 1), _m('m2', 2)]));
    await tick();
    // A message that left the window is not in the change set, so it stays.
    service.ctrl.add(_change(upserts: [_m('m3', 3)]));
    await tick();
    expect(await ids(), ['m1', 'm2', 'm3']);
  });

  test('messages deleted while away are cleared by the first window', () async {
    await dao.insertOrReplace(
      ChatMessagesCompanion.insert(
        id: 'gone',
        eventId: 'event-1',
        senderId: 'sender',
        content: 'gone',
        timestamp: DateTime.utc(2026, 4, 1, 12, 2),
      ),
    );
    repo.watchMessages('event-1');
    await tick();
    service.ctrl.add(_window([_m('m1', 1), _m('m3', 3)]));
    await tick();
    expect(await ids(), ['m1', 'm3']);
  });

  test('a cached first window keeps rows it cannot confirm', () async {
    await dao.insertOrReplace(
      ChatMessagesCompanion.insert(
        id: 'kept',
        eventId: 'event-1',
        senderId: 'sender',
        content: 'kept',
        timestamp: DateTime.utc(2026, 4, 1, 12, 2),
      ),
    );
    repo.watchMessages('event-1');
    await tick();
    service.ctrl.add(_window([_m('m1', 1)], fromCache: true));
    await tick();
    expect(await ids(), ['m1', 'kept']);
  });

  test('the device keeps at most maxCachedRows, the newest', () async {
    for (var i = 0; i < 5; i++) {
      await dao.insertOrReplace(
        ChatMessagesCompanion.insert(
          id: 'c$i',
          eventId: 'event-1',
          senderId: 'sender',
          content: '$i',
          timestamp: DateTime.utc(2026, 4, 1, 11, i),
        ),
      );
    }
    repo.watchMessages('event-1');
    await tick();
    expect(await ids(), ['c2', 'c3', 'c4']);
  });

  test('records whether chat is read from the cache (Req 74)', () async {
    repo.watchMessages('event-1');
    await tick();
    final syncs = MirrorSyncsDao(db);
    final key = ChatRepository.mirrorKey('event-1');
    service.ctrl.add(_window([_m('m1', 1)]));
    final online = await syncs.watch(key).firstWhere((s) => s != null);
    service.ctrl.add(_change(fromCache: true));
    final offline = await syncs
        .watch(key)
        .firstWhere((s) => s?.fromCache ?? false);
    expect(offline!.syncedAt, online!.syncedAt);
  });

  test('older pages come from the server, before the given time', () async {
    service.older = [_m('o1', 0)];
    final page = await repo.fetchOlder(
      'event-1',
      before: DateTime.utc(2026, 4, 1, 12, 1),
    );
    expect(service.olderBefore, DateTime.utc(2026, 4, 1, 12, 1));
    expect(page.single.id, 'o1');
    // Older pages are not kept on the device.
    expect(await ids(), isEmpty);
  });
}
