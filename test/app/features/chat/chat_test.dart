import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/i_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_screen.dart';

class FakeChatService implements IChatService {
  final _controller = StreamController<List<ChatMessage>>.broadcast();
  final List<ChatMessage> _messages = [];

  @override
  Stream<List<ChatMessage>> messagesForEvent(String eventId) =>
      _controller.stream;

  @override
  Future<void> sendMessage({
    required String eventId,
    required String senderId,
    required String text,
    bool isHighPriority = false,
  }) async {
    _messages.add(
      ChatMessage(
        id: 'msg-${_messages.length + 1}',
        eventId: eventId,
        senderId: senderId,
        text: text,
        timestamp: DateTime.now(),
        isHighPriority: isHighPriority,
      ),
    );
    _controller.add(List.of(_messages));
  }

  @override
  Future<void> deleteMessage({
    required String eventId,
    required String messageId,
  }) async {
    _messages.removeWhere((m) => m.id == messageId);
    _controller.add(List.of(_messages));
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
        const MaterialApp(
          home: ChatScreen(messages: [], currentUserId: 'user-1'),
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
