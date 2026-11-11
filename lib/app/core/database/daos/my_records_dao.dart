import 'package:drift/drift.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

part 'my_records_dao.g.dart';

@DriftAccessor(tables: [MyRecords])
class MyRecordsDao extends DatabaseAccessor<AppDatabase>
    with _$MyRecordsDaoMixin {
  MyRecordsDao(super.db);

  Stream<List<MyRecord>> watchByEvent(String eventId) =>
      (select(myRecords)..where((r) => r.eventId.equals(eventId))).watch();

  /// Replaces the event's records of [kind] in one transaction.
  Future<void> replace(
    String eventId,
    String kind,
    List<MyRecordsCompanion> rows,
  ) => transaction(() async {
    await (delete(
      myRecords,
    )..where((r) => r.eventId.equals(eventId) & r.kind.equals(kind))).go();
    await batch((b) => b.insertAll(myRecords, rows));
  });
}
