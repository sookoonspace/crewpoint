import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Drift v13→v14 adds the `sessions` mirror for an event's schedule (#81,
/// Req 48). It starts empty and fills on the next sync.
void main() {
  Database v13({bool tableAlreadyThere = false}) {
    final raw = sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE events (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        creator_id TEXT NOT NULL
      );
    ''');
    raw.execute(
      "INSERT INTO events (id, title, creator_id) VALUES ('e1', 'Fest', 'a');",
    );
    if (tableAlreadyThere) {
      raw.execute(
        'CREATE TABLE sessions (id TEXT NOT NULL, event_id TEXT NOT NULL, '
        'PRIMARY KEY (event_id, id));',
      );
    }
    raw.execute('PRAGMA user_version = 13');
    return raw;
  }

  test('adds an empty sessions table and keeps events', () async {
    final raw = v13();
    final db = AppDatabase(NativeDatabase.opened(raw));
    expect(await db.customSelect('SELECT id FROM events').get(), hasLength(1));
    expect(await db.select(db.sessions).get(), isEmpty);
    expect(
      raw.select('PRAGMA user_version').first.values.first,
      db.schemaVersion,
    );
    await db.close();
  });

  test('is safe to re-run after a partial migration', () async {
    final raw = v13(tableAlreadyThere: true);
    final db = AppDatabase(NativeDatabase.opened(raw));
    expect(await db.customSelect('SELECT id FROM sessions').get(), isEmpty);
    await db.close();
  });
}
