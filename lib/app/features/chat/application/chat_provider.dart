import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';

/// Manages chat messages for a given event.
class ChatNotifier extends Notifier<List<ChatMessageModel>> {
  ChatNotifier({
    required ChatRepository chatRepository,
    required String eventId,
  }) : _chatRepository = chatRepository,
       _eventId = eventId;

  final ChatRepository _chatRepository;
  final String _eventId;
  StreamSubscription<List<ChatMessageModel>>? _subscription;

  @override
  List<ChatMessageModel> build() {
    _subscription?.cancel();
    _subscription = _chatRepository
        .watchMessages(_eventId)
        .listen((messages) => state = messages);
    ref.onDispose(() => _subscription?.cancel());
    return [];
  }

  Future<bool> sendMessage({
    required String senderId,
    required String text,
    bool isHighPriority = false,
  }) {
    return _chatRepository.sendMessage(
      eventId: _eventId,
      senderId: senderId,
      text: text,
      isHighPriority: isHighPriority,
    );
  }
}
