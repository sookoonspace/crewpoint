import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Drift v12→v13 mirrors an event's `memberCount` (#80, Req 43a), so event
/// tiles show it instead of counting the member array. Existing rows have
/// none until the next sync, and fall back to the array.
void main() {
  Database v12WithEvent({bool columnAlreadyThere = false}) {
    final raw = sqlite3.openInMemory();
    final extra = columnAlreadyThere ? 'member_count INTEGER NULL,' : '';
    raw.execute('''
      CREATE TABLE events (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        creator_id TEXT NOT NULL,
        $extra
        member_ids TEXT NOT NULL DEFAULT '[]'
      );
    ''');
    raw.execute(
      "INSERT INTO events (id, title, creator_id) VALUES ('e1', 'Fest', 'a');",
    );
    raw.execute('PRAGMA user_version = 12');
    return raw;
  }

  test('adds member_count, and existing events have none yet', () async {
    final raw = v12WithEvent();
    final db = AppDatabase(NativeDatabase.opened(raw));
    final row = (await db.customSelect('SELECT * FROM events').get()).single;
    expect(row.data['title'], 'Fest');
    expect(row.data.containsKey('member_count'), isTrue);
    expect(row.data['member_count'], isNull);
    expect(
      raw.select('PRAGMA user_version').first.values.first,
      db.schemaVersion,
    );
    await db.close();
  });

  test('is safe to re-run after a partial migration', () async {
    final raw = v12WithEvent(columnAlreadyThere: true);
    final db = AppDatabase(NativeDatabase.opened(raw));
    expect(await db.customSelect('SELECT id FROM events').get(), hasLength(1));
    await db.close();
  });
}
