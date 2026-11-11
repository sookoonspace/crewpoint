import 'dart:async';

import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase;
import 'package:crewpoint_app/app/core/database/daos/chat_messages_dao.dart';
import 'package:crewpoint_app/app/core/services/i_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_window.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Chat implements IChatService {
  final ctrl = StreamController<ChatChanges>.broadcast();

  @override
  Stream<ChatChanges> latestMessages(
    String eventId, {
    int limit = chatPageSize,
  }) => ctrl.stream;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// #85 (Req 58): on mobile, the chat mirror keeps a message's kind, so
/// settlement and dispute bubbles work, and drops deleted messages.
void main() {
  test('FND-11 mobile chat keeps settlement notices and drops deleted '
      'messages', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final chat = _Chat();
    final repo = ChatRepository(
      chatService: chat,
      chatMessagesDao: ChatMessagesDao(db),
    );
    addTearDown(repo.dispose);
    final seen = <List<ChatMessageModel>>[];
    final sub = repo.watchMessages('derod').listen(seen.add);
    addTearDown(sub.cancel);

    ChatMessage m(String id, {String? kind}) => ChatMessage(
      id: id,
      eventId: 'derod',
      senderId: 'u1',
      text: id,
      timestamp: DateTime.utc(2027, 7, 17, id == 'paid' ? 10 : 9),
      kind: kind,
    );
    final window = [m('oops'), m('paid', kind: 'settlement')];
    chat.ctrl.add((
      upserts: window,
      deleted: const <String>[],
      window: window,
      fromCache: false,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    chat.ctrl.add((
      upserts: const <ChatMessage>[],
      deleted: const ['oops'],
      window: null,
      fromCache: false,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final now = seen.last;
    expect([for (final x in now) x.id], ['paid']);
    expect(now.single.kind, ChatMessageKind.settlement);
  });
}
