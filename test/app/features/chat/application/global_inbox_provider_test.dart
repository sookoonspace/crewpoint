import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Drain cascading stream emissions through the composed provider.
Future<AsyncValue<List<InboxRow>>> _readAfterPump(
  ProviderContainer container,
  String uid,
) async {
  container.listen<AsyncValue<List<InboxRow>>>(
    globalInboxProvider(uid),
    (_, _) {},
    fireImmediately: true,
  );
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await Future<void>.delayed(const Duration(milliseconds: 10));
  return container.read(globalInboxProvider(uid));
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

      final result = await _readAfterPump(container, 'me');
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

      final result = await _readAfterPump(container, 'me');
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
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    final rows = result.requireValue;
    expect(rows, hasLength(1));
    expect(rows.single.event.id, 'evt-a');
  });
}
