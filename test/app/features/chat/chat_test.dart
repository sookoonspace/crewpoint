import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/i_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_window.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_screen.dart';

/// Sends each change as a change set, as Firestore's `docChanges` would.
class FakeChatService implements IChatService {
  final _controller = StreamController<ChatChanges>.broadcast();
  final List<ChatMessage> _messages = [];

  @override
  Stream<ChatChanges> latestMessages(
    String eventId, {
    int limit = chatPageSize,
  }) => _controller.stream;

  @override
  Future<List<ChatMessage>> olderMessages(
    String eventId, {
    required DateTime before,
    int limit = chatPageSize,
  }) async => const [];

  @override
  Future<void> sendMessage({
    required String eventId,
    required String senderId,
    required String text,
    bool isHighPriority = false,
  }) async {
    final m = ChatMessage(
      id: 'msg-${_messages.length + 1}',
      eventId: eventId,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      isHighPriority: isHighPriority,
    );
    _messages.add(m);
    _controller.add((
      upserts: [m],
      deleted: const <String>[],
      window: null,
      fromCache: false,
    ));
  }

  @override
  Future<void> deleteMessage({
    required String eventId,
    required String messageId,
  }) async {
    _messages.removeWhere((m) => m.id == messageId);
    _controller.add((
      upserts: const <ChatMessage>[],
      deleted: [messageId],
      window: null,
      fromCache: false,
    ));
  }

  void dispose() => _controller.close();
}

void main() {
  group('ChatRepository', () {
    late FakeChatService fakeChatService;
    late ChatRepository repository;

    setUp(() {
      fakeChatService = FakeChatService();
      repository = ChatRepository(chatService: fakeChatService);
    });

    tearDown(() => fakeChatService.dispose());

    test('sends message and appears in stream', () async {
      // Subscribe before sending so we don't miss the emission
      final future = repository.watchMessages('event-1').first;

      final sent = await repository.sendMessage(
        eventId: 'event-1',
        senderId: 'user-1',
        text: 'Hello team!',
      );
      expect(sent, isTrue);

      final messages = await future;
      expect(messages, hasLength(1));
      expect(messages.first.text, equals('Hello team!'));
    });

    test('critical alert sends high-priority message', () async {
      final future = repository.watchMessages('event-1').first;

      await repository.sendMessage(
        eventId: 'event-1',
        senderId: 'user-1',
        text: 'Emergency!',
        isHighPriority: true,
      );

      final messages = await future;
      expect(messages.first.isHighPriority, isTrue);
    });
  });

  group('ChatScreen', () {
    testWidgets('shows critical alert button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            messages: const [],
            currentUserId: 'user-1',
            onSendCriticalAlert: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('shows messages', (tester) async {
      final messages = [
        ChatMessageModel(
          id: '1',
          eventId: 'e1',
          senderId: 'user-2',
          text: 'Hey there!',
          timestamp: DateTime(2026, 4, 1),
          senderName: 'Alice',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(messages: messages, currentUserId: 'user-1'),
        ),
      );

      expect(find.text('Hey there!'), findsOneWidget);
    });
  });
}
