import 'dart:developer';

import 'package:crewpoint_app/app/core/services/i_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/chat/domain/repositories/i_chat_repository.dart';

/// Repository wrapping IChatService with local caching.
class ChatRepository implements IChatRepository {
  const ChatRepository({required IChatService chatService})
    : _chatService = chatService;

  final IChatService _chatService;

  @override
  Stream<List<ChatMessageModel>> watchMessages(String eventId) {
    return _chatService
        .messagesForEvent(eventId)
        .map(
          (messages) => messages
              .map(
                (m) => ChatMessageModel(
                  id: m.id,
                  eventId: eventId,
                  senderId: m.senderId,
                  text: m.text,
                  timestamp: m.timestamp,
                  isHighPriority: m.isHighPriority,
                ),
              )
              .toList(),
        );
  }

  @override
  Future<bool> sendMessage({
    required String eventId,
    required String senderId,
    required String text,
    bool isHighPriority = false,
  }) async {
    try {
      await _chatService.sendMessage(
        eventId: eventId,
        senderId: senderId,
        text: text,
        isHighPriority: isHighPriority,
      );
      return true;
    } catch (e, st) {
      log('Failed to send message', error: e, stackTrace: st, name: 'chat');
      return false;
    }
  }
}
