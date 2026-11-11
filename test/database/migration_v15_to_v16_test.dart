import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Drift v15→v16 (#85, Req 58): chat messages keep their `kind`, so
/// settlement and dispute bubbles work on mobile. Cached messages have none
/// until they sync again.
void main() {
  Database v15({bool columnAlreadyThere = false}) {
    final raw = sqlite3.openInMemory();
    raw.execute(
      'CREATE TABLE chat_messages (id TEXT NOT NULL PRIMARY KEY, '
      'event_id TEXT NOT NULL, sender_id TEXT NOT NULL, content TEXT NOT NULL, '
      '${columnAlreadyThere ? 'kind TEXT NULL, ' : ''}'
      'timestamp INTEGER NOT NULL);',
    );
    raw.execute(
      'INSERT INTO chat_messages (id, event_id, sender_id, content, timestamp) '
      "VALUES ('m1', 'e1', 'u1', 'Hi', 0);",
    );
    raw.execute('PRAGMA user_version = 15');
    return raw;
  }

  test('adds kind, and cached messages have none yet', () async {
    final raw = v15();
    final db = AppDatabase(NativeDatabase.opened(raw));
    final row =
        (await db.customSelect('SELECT * FROM chat_messages').get()).single;
    expect(row.data['content'], 'Hi');
    expect(row.data.containsKey('kind'), isTrue);
    expect(row.data['kind'], isNull);
    expect(
      raw.select('PRAGMA user_version').first.values.first,
      db.schemaVersion,
    );
    await db.close();
  });

  test('is safe to re-run after a partial migration', () async {
    final raw = v15(columnAlreadyThere: true);
    final db = AppDatabase(NativeDatabase.opened(raw));
    expect(
      await db.customSelect('SELECT id FROM chat_messages').get(),
      hasLength(1),
    );
    await db.close();
  });
}
