import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/mirror_syncs_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 74: each mirror shows when it last heard from the server.
void main() {
  late AppDatabase db;
  late MirrorSyncsDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = MirrorSyncsDao(db);
  });
  tearDown(() => db.close());

  test('a server snapshot moves the time, a cached one keeps it', () async {
    final noon = DateTime(2027, 7, 17, 12);
    await dao.record('tasks/e1', fromCache: false, now: noon);
    await dao.record(
      'tasks/e1',
      fromCache: true,
      now: DateTime(2027, 7, 17, 13),
    );
    final sync = await dao.watch('tasks/e1').first;
    expect(sync!.fromCache, isTrue);
    expect(sync.syncedAt, noon);
  });

  test('a mirror that never reached the server has no time', () async {
    await dao.record('chat/e1', fromCache: true);
    final sync = await dao.watch('chat/e1').first;
    expect(sync!.syncedAt, isNull);
    expect(await dao.watch('other').first, isNull);
  });
}
