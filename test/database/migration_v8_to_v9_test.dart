import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Drift v8→v9 adds the event configuration columns (Req 18). Existing events
/// keep `event_type`, which is display text only from now on (Req 21).
void main() {
  Database v8WithEvent({bool partial = false}) {
    final raw = sqlite3.openInMemory();
    final extra = partial ? "template_id TEXT NOT NULL DEFAULT 'blank'," : '';
    raw.execute('''
      CREATE TABLE events (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NULL,
        event_type TEXT NOT NULL DEFAULT 'custom',
        creator_id TEXT NOT NULL,
        start_date INTEGER NULL,
        end_date INTEGER NULL,
        admin_ids TEXT NOT NULL DEFAULT '[]',
        member_ids TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'active',
        currency TEXT NOT NULL DEFAULT 'USD',
        $extra
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute(
      'INSERT INTO events (id, title, event_type, creator_id, currency) '
      "VALUES ('e1', 'Tahoe', 'trip', 'u1', 'EUR');",
    );
    raw.execute('PRAGMA user_version = 8');
    return raw;
  }

  test('adds the columns, keeps existing data, and fills defaults', () async {
    final raw = v8WithEvent();
    final db = AppDatabase(NativeDatabase.opened(raw));

    final row =
        (await db.customSelect('SELECT * FROM events').get()).single.data;

    expect(row['title'], 'Tahoe');
    expect(row['event_type'], 'trip');
    expect(row['currency'], 'EUR');
    expect(row['template_id'], 'blank');
    expect(row['organizer_id'], isNull);
    expect(row['time_zone'], 'UTC');
    expect(row['venues'], '[]');
    expect(row['languages'], '["en"]');
    expect(row['modules'], '{"tasks":true,"budget":true,"chat":true}');
    expect(row['labels'], '{}');
    expect(row['settings'], '{}');
    expect(row['capacity'], isNull);
    expect(row['member_limit'], isNull);
    expect(raw.select('PRAGMA user_version').first.values.first, 9);
    await db.close();
  });

  test('is safe to re-run after a partial migration', () async {
    final raw = v8WithEvent(partial: true);
    final db = AppDatabase(NativeDatabase.opened(raw));
    final rows = await db.customSelect('SELECT time_zone FROM events').get();
    expect(rows.single.data['time_zone'], 'UTC');
    await db.close();
  });

  test('schemaVersion is 9', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 9);
    db.close();
  });
}
