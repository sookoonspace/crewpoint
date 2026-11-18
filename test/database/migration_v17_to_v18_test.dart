import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Drift v17→v18 (Spec #186 Req 43): events keep their cover photo's
/// Storage path and when it last changed, so thumbnails show on an offline
/// cold start. Existing events have none until the next sync.
void main() {
  Database v17({bool partly = false}) {
    final raw = sqlite3.openInMemory();
    raw.execute(
      'CREATE TABLE events (id TEXT NOT NULL PRIMARY KEY, '
      'title TEXT NOT NULL, creator_id TEXT NOT NULL'
      '${partly ? ', cover_path TEXT NULL' : ''});',
    );
    raw.execute(
      "INSERT INTO events (id, title, creator_id) VALUES ('e1', 'Hall', 'u1');",
    );
    raw.execute('PRAGMA user_version = 17');
    return raw;
  }

  test('adds the cover columns, and existing events have no cover', () async {
    final raw = v17();
    final db = AppDatabase(NativeDatabase.opened(raw));
    final row = (await db.customSelect('SELECT * FROM events').get()).single;
    expect(row.data['cover_path'], isNull);
    expect(row.data.containsKey('cover_updated_at'), isTrue);
    expect(row.data['cover_updated_at'], isNull);
    expect(raw.select('PRAGMA user_version').first.values.first, 18);
    await db.close();
  });

  test('is safe to re-run after a partial migration', () async {
    final raw = v17(partly: true);
    final db = AppDatabase(NativeDatabase.opened(raw));
    final row = (await db.customSelect('SELECT * FROM events').get()).single;
    expect(row.data.containsKey('cover_updated_at'), isTrue);
    await db.close();
  });

  test('schemaVersion is 18', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 18);
    db.close();
  });
}
