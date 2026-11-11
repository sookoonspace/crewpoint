import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Drift v14→v15 (#82): sessions keep their own attendance rule, a person's
/// own records are mirrored for the agenda, and each mirror records when it
/// last heard from the server (Req 74).
void main() {
  Database v14({bool alreadyThere = false}) {
    final raw = sqlite3.openInMemory();
    raw.execute(
      'CREATE TABLE sessions (id TEXT NOT NULL, event_id TEXT NOT NULL, '
      'title TEXT NOT NULL, start_at INTEGER NOT NULL, '
      '${alreadyThere ? 'attendance TEXT NULL, ' : ''}'
      'PRIMARY KEY (event_id, id));',
    );
    raw.execute(
      'INSERT INTO sessions (id, event_id, title, start_at) '
      "VALUES ('m1', 'e1', 'Dinner', 0);",
    );
    if (alreadyThere) {
      raw.execute(
        'CREATE TABLE my_records (event_id TEXT NOT NULL, kind TEXT NOT NULL, '
        'id TEXT NOT NULL, data TEXT NOT NULL, '
        'PRIMARY KEY (event_id, kind, id));',
      );
      raw.execute(
        'CREATE TABLE mirror_syncs (mirror_key TEXT NOT NULL PRIMARY KEY);',
      );
    }
    raw.execute('PRAGMA user_version = 14');
    return raw;
  }

  test(
    'adds the attendance column and the new tables, keeping sessions',
    () async {
      final raw = v14();
      final db = AppDatabase(NativeDatabase.opened(raw));
      final row =
          (await db.customSelect('SELECT * FROM sessions').get()).single;
      expect(row.data['title'], 'Dinner');
      expect(row.data.containsKey('attendance'), isTrue);
      expect(row.data['attendance'], isNull);
      expect(await db.select(db.myRecords).get(), isEmpty);
      expect(await db.select(db.mirrorSyncs).get(), isEmpty);
      expect(
        raw.select('PRAGMA user_version').first.values.first,
        db.schemaVersion,
      );
      await db.close();
    },
  );

  test('is safe to re-run after a partial migration', () async {
    final raw = v14(alreadyThere: true);
    final db = AppDatabase(NativeDatabase.opened(raw));
    expect(
      await db.customSelect('SELECT id FROM sessions').get(),
      hasLength(1),
    );
    await db.close();
  });
}
