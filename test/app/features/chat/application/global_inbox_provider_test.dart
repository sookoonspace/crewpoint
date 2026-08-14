import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Empty roster override — keeps the inbox off the real user repo for
/// tests that don't care about name resolution.
final _emptyRosterOverride = usersByIdProvider.overrideWith(
  (ref, key) async => const <String, AppUser>{},
);

/// Drain cascading stream emissions through the composed provider.
/// Reads [globalInboxProvider] once its dependency graph has settled.
///
/// The provider fans out across a family of per-event message streams, so
/// the number of microtasks before it resolves scales with how many events
/// a test seeds. Waiting a fixed number of milliseconds therefore races:
/// two 10ms delays were enough on a developer machine but not on a loaded
/// CI runner, where the sort test read `AsyncLoading` and failed.
///
/// Polling to a bounded deadline is deterministic on any machine, and a
/// provider that genuinely never resolves still fails the test rather than
/// passing on a lucky delay.
///
/// Pass [expectSettled] as false for the cases that assert the provider is
/// *still* loading — those seed streams that never emit, so polling would
/// only burn the deadline.
Future<AsyncValue<List<InboxRow>>> _readAfterPump(
  ProviderContainer container,
  String uid, {
  bool expectSettled = true,
}) async {
  container.listen<AsyncValue<List<InboxRow>>>(
    globalInboxProvider(uid),
    (_, _) {},
    fireImmediately: true,
  );

  if (!expectSettled) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return container.read(globalInboxProvider(uid));
  }

  const timeout = Duration(seconds: 5);
  final started = DateTime.now();
  var value = container.read(globalInboxProvider(uid));
  while (value is AsyncLoading &&
      DateTime.now().difference(started) < timeout) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    value = container.read(globalInboxProvider(uid));
  }
  return value;
}

void main() {
  const eventA = EventModel(
    id: 'evt-a',
    title: 'Tahoe Trip',
    creatorId: 'me',
    memberIds: ['me', 'alex'],
  );
  const eventB = EventModel(
    id: 'evt-b',
    title: 'Project Sync',
    creatorId: 'me',
    memberIds: ['me', 'bob'],
  );

  final msgAOlder = ChatMessageModel(
    id: 'm-a-1',
    eventId: 'evt-a',
    senderId: 'alex',
    text: 'See you Friday',
    timestamp: DateTime(2026, 5, 10, 9),
  );
  final msgANewer = ChatMessageModel(
    id: 'm-a-2',
    eventId: 'evt-a',
    senderId: 'alex',
    text: 'Bring snacks',
    timestamp: DateTime(2026, 5, 12, 14),
  );
  final msgBOlder = ChatMessageModel(
    id: 'm-b-1',
    eventId: 'evt-b',
    senderId: 'bob',
    text: 'Spec is ready',
    timestamp: DateTime(2026, 5, 11, 10),
  );

  test(
    'returns one InboxRow per active event with the chronologically-latest message, sorted by lastMessage.timestamp desc',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA, eventB]),
          ),
          chatMessagesProvider.overrideWith((ref, eventId) {
            return switch (eventId) {
              'evt-a' => Stream.value([msgAOlder, msgANewer]),
              'evt-b' => Stream.value([msgBOlder]),
              _ => Stream.value(const <ChatMessageModel>[]),
            };
          }),
          _emptyRosterOverride,
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      expect(result, isA<AsyncData<List<InboxRow>>>());
      final rows = result.requireValue;
      expect(rows, hasLength(2));
      // evt-a's newest (msgANewer @ May 12) beats evt-b's newest (msgBOlder @ May 11)
      expect(rows[0].event.id, 'evt-a');
      expect(rows[0].lastMessage?.id, 'm-a-2');
      expect(rows[1].event.id, 'evt-b');
      expect(rows[1].lastMessage?.id, 'm-b-1');
    },
  );

  test('excludes archived events', () async {
    const archivedEvent = EventModel(
      id: 'evt-archived',
      title: 'Old Trip',
      creatorId: 'me',
      memberIds: ['me'],
      status: EventStatus.archived,
    );
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [eventA, archivedEvent]),
        ),
        chatMessagesProvider.overrideWith(
          (ref, eventId) => Stream.value([msgANewer]),
        ),
        _emptyRosterOverride,
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    final rows = result.requireValue;
    expect(rows, hasLength(1));
    expect(rows.single.event.id, 'evt-a');
  });

  test(
    'returns AsyncLoading while events stream has not emitted yet',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => const Stream<List<EventModel>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(
        container,
        'me',
        expectSettled: false,
      );
      expect(result, isA<AsyncLoading<List<InboxRow>>>());
    },
  );

  test(
    'returns AsyncLoading while any per-event messages stream is pending',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          chatMessagesProvider.overrideWith(
            (ref, eventId) => const Stream<List<ChatMessageModel>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(
        container,
        'me',
        expectSettled: false,
      );
      expect(result, isA<AsyncLoading<List<InboxRow>>>());
    },
  );

  test('propagates an error from the events stream', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream<List<EventModel>>.error(StateError('events boom')),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    expect(result, isA<AsyncError<List<InboxRow>>>());
    expect((result as AsyncError).error, isA<StateError>());
  });

  test('propagates an error from any per-event messages stream', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [eventA]),
        ),
        chatMessagesProvider.overrideWith(
          (ref, eventId) =>
              Stream<List<ChatMessageModel>>.error(StateError('chat boom')),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    expect(result, isA<AsyncError<List<InboxRow>>>());
    expect((result as AsyncError).error, isA<StateError>());
  });

  test(
    'returns AsyncData([]) when user belongs to zero events; chat family never subscribed',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const <EventModel>[]),
          ),
          chatMessagesProvider.overrideWith((ref, eventId) {
            throw StateError(
              'chatMessagesProvider must not be subscribed when events list is empty',
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      expect(result, isA<AsyncData<List<InboxRow>>>());
      expect(result.requireValue, isEmpty);
    },
  );

  test('skips events with empty message lists', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [eventA, eventB]),
        ),
        chatMessagesProvider.overrideWith((ref, eventId) {
          return switch (eventId) {
            'evt-a' => Stream.value([msgANewer]),
            'evt-b' => Stream.value(const <ChatMessageModel>[]),
            _ => Stream.value(const <ChatMessageModel>[]),
          };
        }),
        _emptyRosterOverride,
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    final rows = result.requireValue;
    expect(rows, hasLength(1));
    expect(rows.single.event.id, 'evt-a');
  });

  test(
    'unreadCount counts only other-sender messages newer than lastReadAt',
    () async {
      // 2 messages from alex (both after lastReadAt) + 1 from me + 1 from
      // alex before lastReadAt = expected unreadCount == 2.
      final lastRead = DateTime(2026, 5, 11, 12);
      final mineNewer = ChatMessageModel(
        id: 'm-mine',
        eventId: 'evt-a',
        senderId: 'me',
        text: 'My reply',
        timestamp: DateTime(2026, 5, 12, 13),
      );
      final alexOldBeforeRead = ChatMessageModel(
        id: 'm-old',
        eventId: 'evt-a',
        senderId: 'alex',
        text: 'Old',
        timestamp: DateTime(2026, 5, 10, 8),
      );
      final alexNew1 = ChatMessageModel(
        id: 'm-new-1',
        eventId: 'evt-a',
        senderId: 'alex',
        text: 'See you',
        timestamp: DateTime(2026, 5, 12, 14),
      );
      final alexNew2 = ChatMessageModel(
        id: 'm-new-2',
        eventId: 'evt-a',
        senderId: 'alex',
        text: 'Bring snacks',
        timestamp: DateTime(2026, 5, 13, 9),
      );

      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          chatMessagesProvider.overrideWith(
            (ref, eventId) => Stream.value([
              alexOldBeforeRead,
              mineNewer,
              alexNew1,
              alexNew2,
            ]),
          ),
          _emptyRosterOverride,
          eventChatReadStateProvider.overrideWith(
            (ref, arg) => Stream.value(lastRead),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      final row = result.requireValue.single;
      expect(row.unreadCount, 2);
    },
  );

  test(
    'unreadCount equals message count from other senders when lastReadAt is null',
    () async {
      final m1 = ChatMessageModel(
        id: 'm-1',
        eventId: 'evt-a',
        senderId: 'alex',
        text: 'a',
        timestamp: DateTime(2026, 5, 12),
      );
      final m2 = ChatMessageModel(
        id: 'm-2',
        eventId: 'evt-a',
        senderId: 'alex',
        text: 'b',
        timestamp: DateTime(2026, 5, 13),
      );
      final m3 = ChatMessageModel(
        id: 'm-3',
        eventId: 'evt-a',
        senderId: 'me',
        text: 'reply',
        timestamp: DateTime(2026, 5, 14),
      );

      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          chatMessagesProvider.overrideWith(
            (ref, eventId) => Stream.value([m1, m2, m3]),
          ),
          _emptyRosterOverride,
          // Provider emits null → user has never opened the chat.
          eventChatReadStateProvider.overrideWith(
            (ref, arg) => Stream.value(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      final row = result.requireValue.single;
      // m1 + m2 are from alex; m3 is from me → expected 2.
      expect(row.unreadCount, 2);
    },
  );

  test(
    'hasUrgentUnread is true iff an unread message has isHighPriority=true',
    () async {
      final urgent = ChatMessageModel(
        id: 'm-urgent',
        eventId: 'evt-a',
        senderId: 'alex',
        text: 'Need help',
        timestamp: DateTime(2026, 5, 13, 9),
        isHighPriority: true,
      );
      final normal = ChatMessageModel(
        id: 'm-normal',
        eventId: 'evt-a',
        senderId: 'alex',
        text: 'fyi',
        timestamp: DateTime(2026, 5, 13, 10),
      );

      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          chatMessagesProvider.overrideWith(
            (ref, eventId) => Stream.value([urgent, normal]),
          ),
          _emptyRosterOverride,
          eventChatReadStateProvider.overrideWith(
            (ref, arg) => Stream.value(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      final row = result.requireValue.single;
      expect(row.hasUrgentUnread, isTrue);
    },
  );

  test(
    'hasUrgentUnread is false when the urgent message is older than lastReadAt',
    () async {
      final readBoundary = DateTime(2026, 5, 14);
      final urgent = ChatMessageModel(
        id: 'm-urgent',
        eventId: 'evt-a',
        senderId: 'alex',
        text: 'Need help',
        timestamp: DateTime(2026, 5, 13, 9), // BEFORE readBoundary
        isHighPriority: true,
      );
      final normalNewer = ChatMessageModel(
        id: 'm-normal',
        eventId: 'evt-a',
        senderId: 'alex',
        text: 'hi',
        timestamp: DateTime(2026, 5, 15, 8),
      );

      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          chatMessagesProvider.overrideWith(
            (ref, eventId) => Stream.value([urgent, normalNewer]),
          ),
          _emptyRosterOverride,
          eventChatReadStateProvider.overrideWith(
            (ref, arg) => Stream.value(readBoundary),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      final row = result.requireValue.single;
      // unread is just `normalNewer`, not urgent.
      expect(row.unreadCount, 1);
      expect(row.hasUrgentUnread, isFalse);
    },
  );

  test(
    'InboxRow.lastSenderName resolves from roster displayName (happy path)',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          chatMessagesProvider.overrideWith(
            (ref, eventId) => Stream.value([msgANewer]),
          ),
          usersByIdProvider.overrideWith(
            (ref, key) async => const <String, AppUser>{
              'alex': AppUser(
                uid: 'alex',
                email: 'a@x.com',
                displayName: 'Alex Chen',
              ),
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final row = (await _readAfterPump(container, 'me')).requireValue.single;
      expect(row.lastSenderName, 'Alex Chen');
    },
  );

  test(
    'InboxRow.lastSenderName falls back to email when displayName missing',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          chatMessagesProvider.overrideWith(
            (ref, eventId) => Stream.value([msgANewer]),
          ),
          usersByIdProvider.overrideWith(
            (ref, key) async => const <String, AppUser>{
              'alex': AppUser(uid: 'alex', email: 'alex@x.com'),
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final row = (await _readAfterPump(container, 'me')).requireValue.single;
      expect(row.lastSenderName, 'alex@x.com');
    },
  );

  test(
    'InboxRow.lastSenderName is the placeholder when sender no longer in roster',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          chatMessagesProvider.overrideWith(
            (ref, eventId) => Stream.value([msgANewer]),
          ),
          _emptyRosterOverride,
        ],
      );
      addTearDown(container.dispose);

      final row = (await _readAfterPump(container, 'me')).requireValue.single;
      expect(row.lastSenderName, kRemovedMemberPlaceholder);
    },
  );

  test(
    'inbox returns AsyncLoading while per-event roster is pending',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          chatMessagesProvider.overrideWith(
            (ref, eventId) => Stream.value([msgANewer]),
          ),
          usersByIdProvider.overrideWith((ref, key) {
            final completer = Completer<Map<String, AppUser>>();
            return completer.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(
        container,
        'me',
        expectSettled: false,
      );
      expect(result, isA<AsyncLoading<List<InboxRow>>>());
    },
  );

  test('inbox propagates error from per-event roster', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [eventA]),
        ),
        chatMessagesProvider.overrideWith(
          (ref, eventId) => Stream.value([msgANewer]),
        ),
        usersByIdProvider.overrideWith(
          (ref, key) async => throw StateError('roster boom'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    expect(result, isA<AsyncError<List<InboxRow>>>());
    expect((result as AsyncError).error, isA<StateError>());
  });
}
