import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Drift v16→v17 (#86, Req 57a): chat read markers keep the message count
/// they were read at, so the inbox counts unread messages from the chat
/// summary. Existing markers have none until the next read.
void main() {
  Database v16({bool columnAlreadyThere = false}) {
    final raw = sqlite3.openInMemory();
    raw.execute(
      'CREATE TABLE chat_reads (event_id TEXT NOT NULL, uid TEXT NOT NULL, '
      'last_read_at INTEGER NOT NULL, '
      '${columnAlreadyThere ? 'read_count INTEGER NULL, ' : ''}'
      'PRIMARY KEY (event_id, uid));',
    );
    raw.execute(
      "INSERT INTO chat_reads (event_id, uid, last_read_at) VALUES ('e1', 'u1', 0);",
    );
    raw.execute('PRAGMA user_version = 16');
    return raw;
  }

  test('adds read_count, and existing markers have none yet', () async {
    final raw = v16();
    final db = AppDatabase(NativeDatabase.opened(raw));
    final row =
        (await db.customSelect('SELECT * FROM chat_reads').get()).single;
    expect(row.data.containsKey('read_count'), isTrue);
    expect(row.data['read_count'], isNull);
    expect(raw.select('PRAGMA user_version').first.values.first, 17);
    await db.close();
  });

  test('is safe to re-run after a partial migration', () async {
    final raw = v16(columnAlreadyThere: true);
    final db = AppDatabase(NativeDatabase.opened(raw));
    expect(
      await db.customSelect('SELECT uid FROM chat_reads').get(),
      hasLength(1),
    );
    await db.close();
  });

  test('schemaVersion is 17', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 17);
    db.close();
  });
}
