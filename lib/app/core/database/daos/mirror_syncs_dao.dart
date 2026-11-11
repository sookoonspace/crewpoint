import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

part 'mirror_syncs_dao.g.dart';

@DriftAccessor(tables: [MirrorSyncs])
class MirrorSyncsDao extends DatabaseAccessor<AppDatabase>
    with _$MirrorSyncsDaoMixin {
  MirrorSyncsDao(super.db);

  /// Records a snapshot for [key]: from the server it moves the last-updated
  /// time to [now]; from the cache it keeps the time and marks it offline.
  Future<void> record(String key, {required bool fromCache, DateTime? now}) =>
      transaction(() async {
        final existing = await (select(
          mirrorSyncs,
        )..where((m) => m.mirrorKey.equals(key))).getSingleOrNull();
        await into(mirrorSyncs).insertOnConflictUpdate(
          MirrorSyncsCompanion(
            mirrorKey: Value(key),
            fromCache: Value(fromCache),
            syncedAt: Value(
              fromCache ? existing?.syncedAt : (now ?? DateTime.now()),
            ),
          ),
        );
      });

  Stream<MirrorSync?> watch(String key) => (select(
    mirrorSyncs,
  )..where((m) => m.mirrorKey.equals(key))).watchSingleOrNull();
}
