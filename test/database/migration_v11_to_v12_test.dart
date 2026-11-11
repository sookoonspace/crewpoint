import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Drift v11→v12 adds a task's optional crew (#68, Req 72). Existing tasks
/// have none.
void main() {
  Database v11WithTask({bool columnAlreadyThere = false}) {
    final raw = sqlite3.openInMemory();
    final extra = columnAlreadyThere ? 'crew_id TEXT NULL,' : '';
    raw.execute('''
      CREATE TABLE tasks (
        id TEXT NOT NULL PRIMARY KEY,
        event_id TEXT NOT NULL,
        title TEXT NOT NULL,
        $extra
        status TEXT NOT NULL DEFAULT 'todo'
      );
    ''');
    raw.execute(
      "INSERT INTO tasks (id, event_id, title) VALUES ('t1', 'e1', 'Caterer');",
    );
    raw.execute('PRAGMA user_version = 11');
    return raw;
  }

  test('adds crew_id, and existing tasks have no crew', () async {
    final raw = v11WithTask();
    final db = AppDatabase(NativeDatabase.opened(raw));
    final row = (await db.customSelect('SELECT * FROM tasks').get()).single;
    expect(row.data['title'], 'Caterer');
    expect(row.data.containsKey('crew_id'), isTrue);
    expect(row.data['crew_id'], isNull);
    expect(
      raw.select('PRAGMA user_version').first.values.first,
      greaterThanOrEqualTo(12),
    );
    await db.close();
  });

  test('is safe to re-run after a partial migration', () async {
    final raw = v11WithTask(columnAlreadyThere: true);
    final db = AppDatabase(NativeDatabase.opened(raw));
    expect(await db.customSelect('SELECT id FROM tasks').get(), hasLength(1));
    await db.close();
  });
}
