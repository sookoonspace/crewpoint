import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Drift v7→v8 adds `chat_messages.urgent_push_skipped`, which marks an urgent
/// message that alerted nobody because its sender was over the rate.
void main() {
  Database v7WithMessage({bool columnAlreadyThere = false}) {
    final raw = sqlite3.openInMemory();
    final extraColumn = columnAlreadyThere
        ? 'urgent_push_skipped INTEGER NOT NULL DEFAULT 0,'
        : '';
    raw.execute('''
      CREATE TABLE chat_messages (
        id TEXT NOT NULL PRIMARY KEY,
        event_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT NOT NULL,
        is_high_priority INTEGER NOT NULL DEFAULT 0,
        $extraColumn
        timestamp INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
      );
    ''');
    raw.execute(
      'INSERT INTO chat_messages (id, event_id, sender_id, content, '
      "is_high_priority, timestamp) VALUES ('m1', 'e1', 'u1', 'Fire', 1, 1000);",
    );
    raw.execute('PRAGMA user_version = 7');
    return raw;
  }

  test('adds the column, and existing messages default to false', () async {
    final raw = v7WithMessage();
    final db = AppDatabase(NativeDatabase.opened(raw));

    final rows = await db
        .customSelect(
          'SELECT id, content, is_high_priority, urgent_push_skipped '
          'FROM chat_messages',
        )
        .get();

    expect(rows.single.data['id'], 'm1');
    expect(rows.single.data['content'], 'Fire');
    expect(rows.single.data['is_high_priority'], 1);
    expect(rows.single.data['urgent_push_skipped'], 0);
    expect(raw.select('PRAGMA user_version').first.values.first, 8);
    await db.close();
  });

  test('is safe to re-run after a partial migration', () async {
    final raw = v7WithMessage(columnAlreadyThere: true);
    final db = AppDatabase(NativeDatabase.opened(raw));
    final rows = await db.customSelect('SELECT id FROM chat_messages').get();
    expect(rows, hasLength(1));
    await db.close();
  });

  test('schemaVersion is 8', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 8);
    db.close();
  });
}
