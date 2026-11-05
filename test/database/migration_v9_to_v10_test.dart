import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Drift v9→v10 adds `events.date_only` (Req 23). Existing events keep showing
/// as they did, so it defaults to false.
void main() {
  Database v9WithEvent({bool columnAlreadyThere = false}) {
    final raw = sqlite3.openInMemory();
    final extra = columnAlreadyThere
        ? 'date_only INTEGER NOT NULL DEFAULT 0,'
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
    raw.execute('PRAGMA user_version = 9');
    return raw;
  }

  test('adds the column, and existing events default to false', () async {
    final raw = v9WithEvent();
    final db = AppDatabase(NativeDatabase.opened(raw));
    final rows = await db.customSelect('SELECT * FROM events').get();
    expect(rows.single.data['title'], 'T');
    expect(rows.single.data['date_only'], 0);
    expect(raw.select('PRAGMA user_version').first.values.first, 10);
    await db.close();
  });

  test('is safe to re-run after a partial migration', () async {
    final raw = v9WithEvent(columnAlreadyThere: true);
    final db = AppDatabase(NativeDatabase.opened(raw));
    expect(await db.customSelect('SELECT id FROM events').get(), hasLength(1));
    await db.close();
  });

  test('schemaVersion is 10', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 10);
    db.close();
  });
}
