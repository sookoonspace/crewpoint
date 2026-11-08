import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Drift v10→v11 adds the viewer's access to each event (#66): who it is for,
/// their roles and their permissions, from their member document. Existing
/// rows have none, so they fall back to the arrays until the next sync.
void main() {
  Database v10WithEvent({bool columnsAlreadyThere = false}) {
    final raw = sqlite3.openInMemory();
    final extra = columnsAlreadyThere
        ? 'viewer_id TEXT NULL, my_role_ids TEXT NULL, my_permissions TEXT NULL,'
        : '';
    raw.execute('''
      CREATE TABLE events (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        creator_id TEXT NOT NULL,
        $extra
        created_at INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute(
      "INSERT INTO events (id, title, creator_id) VALUES ('e1', 'T', 'u1');",
    );
    raw.execute('PRAGMA user_version = 10');
    return raw;
  }

  test('adds the columns, and existing events have no access yet', () async {
    final raw = v10WithEvent();
    final db = AppDatabase(NativeDatabase.opened(raw));
    final row = (await db.customSelect('SELECT * FROM events').get()).single;
    expect(row.data['title'], 'T');
    expect(row.data['viewer_id'], isNull);
    expect(row.data['my_role_ids'], isNull);
    expect(row.data['my_permissions'], isNull);
    expect(
      raw.select('PRAGMA user_version').first.values.first,
      greaterThanOrEqualTo(11),
    );
    await db.close();
  });

  test('is safe to re-run after a partial migration', () async {
    final raw = v10WithEvent(columnsAlreadyThere: true);
    final db = AppDatabase(NativeDatabase.opened(raw));
    expect(await db.customSelect('SELECT id FROM events').get(), hasLength(1));
    await db.close();
  });
}
