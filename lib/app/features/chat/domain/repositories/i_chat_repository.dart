import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';

/// Abstract chat repository.
abstract class IChatRepository {
  Stream<List<ChatMessageModel>> watchMessages(String eventId);
  Future<bool> sendMessage({
    required String eventId,
    required String senderId,
    required String text,
    bool isHighPriority,
  });
}
