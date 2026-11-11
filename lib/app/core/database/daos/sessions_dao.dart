import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

part 'sessions_dao.g.dart';

@DriftAccessor(tables: [Sessions])
class SessionsDao extends DatabaseAccessor<AppDatabase>
    with _$SessionsDaoMixin {
  SessionsDao(super.db);

  /// An event's sessions, leaving out hidden ones unless [withHidden].
  Stream<List<Session>> watchByEvent(
    String eventId, {
    required bool withHidden,
  }) =>
      (select(sessions)..where(
            (s) => withHidden
                ? s.eventId.equals(eventId)
                : s.eventId.equals(eventId) & s.hidden.equals(false),
          ))
          .watch();

  /// Replaces the event's rows with [rows] in one transaction, so a snapshot
  /// updates the screen once rather than once per row.
  Future<void> replaceForEvent(String eventId, List<SessionsCompanion> rows) =>
      transaction(() async {
        await (delete(sessions)..where((s) => s.eventId.equals(eventId))).go();
        await batch((b) => b.insertAll(sessions, rows));
      });
}
