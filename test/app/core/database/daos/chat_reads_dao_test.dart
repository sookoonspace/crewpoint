import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/chat_reads_dao.dart';

void main() {
  late AppDatabase db;
  late ChatReadsDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = ChatReadsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upsert + watchLastReadAt emits the upserted timestamp', () async {
    final ts = DateTime(2026, 5, 14, 10);
    await dao.upsert(eventId: 'e-1', uid: 'u-1', lastReadAt: ts);

    final stream = dao.watchLastReadAt(eventId: 'e-1', uid: 'u-1');
    expect(await stream.first, ts);
  });

  test(
    'watchLastReadAt emits null when no row exists for the (event, uid) pair',
    () async {
      expect(
        await dao.watchLastReadAt(eventId: 'e-x', uid: 'u-x').first,
        isNull,
      );
    },
  );

  test('upsert with the same key replaces the timestamp', () async {
    final older = DateTime(2026, 5, 13, 9);
    final newer = DateTime(2026, 5, 14, 9);
    await dao.upsert(eventId: 'e-1', uid: 'u-1', lastReadAt: older);
    await dao.upsert(eventId: 'e-1', uid: 'u-1', lastReadAt: newer);

    expect(await dao.watchLastReadAt(eventId: 'e-1', uid: 'u-1').first, newer);
  });
}
