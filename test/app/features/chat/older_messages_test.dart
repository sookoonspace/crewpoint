import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/chat/application/older_messages.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_window.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements ChatRepository {
  _Repo(this.pages);

  /// Pages to answer, in order, or an error to throw.
  final List<Object> pages;
  final befores = <DateTime>[];

  @override
  Future<List<ChatMessageModel>> fetchOlder(
    String eventId, {
    required DateTime before,
  }) async {
    befores.add(before);
    final next = pages.removeAt(0);
    if (next is List<ChatMessageModel>) return next;
    throw next;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

ChatMessageModel _m(int minute) => ChatMessageModel(
  id: 'o$minute',
  eventId: 'e',
  senderId: 'u',
  text: '$minute',
  timestamp: DateTime.utc(2027, 1, 1, 0, minute),
);

/// Req 57: older messages load a page at a time, on demand, from the
/// server.
void main() {
  ProviderContainer container(_Repo repo) {
    final c = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(olderMessagesProvider('e'), (_, _) {});
    return c;
  }

  test('loads the page before the oldest message, oldest first', () async {
    final page = [for (var i = chatPageSize; i > 0; i--) _m(i)];
    final repo = _Repo([page]);
    final c = container(repo);
    await c
        .read(olderMessagesProvider('e').notifier)
        .load(DateTime.utc(2027, 1, 2));
    final state = c.read(olderMessagesProvider('e'));
    expect(repo.befores.single, DateTime.utc(2027, 1, 2));
    expect(state.messages.first.id, 'o1');
    expect(state.messages, hasLength(chatPageSize));
    expect(state.hasMore, isTrue);
    expect(state.loading, isFalse);
  });

  test('a short page means there is nothing older', () async {
    final c = container(
      _Repo([
        [_m(3)],
      ]),
    );
    await c
        .read(olderMessagesProvider('e').notifier)
        .load(DateTime.utc(2027, 1, 2));
    expect(c.read(olderMessagesProvider('e')).hasMore, isFalse);
  });

  test('pages build up, older ones first', () async {
    final first = [for (var i = 50 + chatPageSize; i > 50; i--) _m(i)];
    final c = container(
      _Repo([
        first,
        [_m(2), _m(1)],
      ]),
    );
    final notifier = c.read(olderMessagesProvider('e').notifier);
    await notifier.load(DateTime.utc(2027, 1, 2));
    await notifier.load(
      c.read(olderMessagesProvider('e')).messages.first.timestamp,
    );
    final messages = c.read(olderMessagesProvider('e')).messages;
    expect(messages.first.id, 'o1');
    expect(messages.last.id, 'o${50 + chatPageSize}');
  });

  test('a failure is kept, for a retry, and keeps what was loaded', () async {
    final c = container(
      _Repo([
        StateError('offline'),
        [_m(1)],
      ]),
    );
    final notifier = c.read(olderMessagesProvider('e').notifier);
    await notifier.load(DateTime.utc(2027, 1, 2));
    expect(c.read(olderMessagesProvider('e')).failed, isTrue);
    await notifier.load(DateTime.utc(2027, 1, 2));
    final state = c.read(olderMessagesProvider('e'));
    expect(state.failed, isFalse);
    expect(state.messages.single.id, 'o1');
  });
}
