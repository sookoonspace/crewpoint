import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

part 'chat_reads_dao.g.dart';

/// DAO for the per-user, per-event `chat_reads` cache. Source of truth
/// is Firestore (`users/{uid}/chatReads/{eventId}`); this table mirrors
/// the timestamps so the global inbox renders unread counts instantly
/// on cold start.
@DriftAccessor(tables: [ChatReads])
class ChatReadsDao extends DatabaseAccessor<AppDatabase>
    with _$ChatReadsDaoMixin {
  ChatReadsDao(super.db);

  /// Streams the most recent `lastReadAt` for the (eventId, uid) pair.
  /// Emits null when no row exists.
  Stream<DateTime?> watchLastReadAt({
    required String eventId,
    required String uid,
  }) {
    return (select(chatReads)
          ..where((t) => t.eventId.equals(eventId) & t.uid.equals(uid)))
        .watchSingleOrNull()
        .map((row) => row?.lastReadAt);
  }

  /// The read marker with its message count (Req 57a), or null.
  Stream<({DateTime lastReadAt, int? readCount})?> watchReadState({
    required String eventId,
    required String uid,
  }) =>
      (select(chatReads)
            ..where((t) => t.eventId.equals(eventId) & t.uid.equals(uid)))
          .watchSingleOrNull()
          .map(
            (row) => row == null
                ? null
                : (lastReadAt: row.lastReadAt, readCount: row.readCount),
          );

  Future<int> upsert({
    required String eventId,
    required String uid,
    required DateTime lastReadAt,
    int? readCount,
  }) {
    return into(chatReads).insertOnConflictUpdate(
      ChatReadsCompanion(
        eventId: Value(eventId),
        uid: Value(uid),
        lastReadAt: Value(lastReadAt),
        readCount: readCount == null ? const Value.absent() : Value(readCount),
      ),
    );
  }
}
