import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

part 'chat_messages_dao.g.dart';

@DriftAccessor(tables: [ChatMessages])
class ChatMessagesDao extends DatabaseAccessor<AppDatabase>
    with _$ChatMessagesDaoMixin {
  ChatMessagesDao(super.db);

  Stream<List<ChatMessage>> watchByEventId(String eventId) =>
      (select(chatMessages)
            ..where((m) => m.eventId.equals(eventId))
            ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
          .watch();

  Future<List<ChatMessage>> byEventId(String eventId) =>
      (select(chatMessages)
            ..where((m) => m.eventId.equals(eventId))
            ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
          .get();

  Future<int> insertOrReplace(ChatMessagesCompanion entry) =>
      into(chatMessages).insertOnConflictUpdate(entry);

  Future<int> deleteById(String id) =>
      (delete(chatMessages)..where((m) => m.id.equals(id))).go();

  /// Caps the local cache to `maxRows` per event, deleting oldest first.
  Future<void> evictOldestIfNeeded(String eventId, int maxRows) async {
    final all = await byEventId(eventId);
    if (all.length <= maxRows) return;
    final toDelete = all.length - maxRows;
    for (final row in all.take(toDelete)) {
      await deleteById(row.id);
    }
  }
}
