import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

/// Migration test for Drift v6→v7: adds the `chat_reads` table (per-user
/// per-event last-read-at timestamps powering the global inbox unread
/// counts). The migration must be idempotent and lossless.
///
/// Pattern mirrors `migration_v5_to_v6_test.dart`: build a v6-shaped
/// in-memory sqlite handle via raw SQL, stamp `PRAGMA user_version = 6`,
/// open `AppDatabase` over the same handle so `MigrationStrategy.onUpgrade`
/// runs from `from = 6` to `to = 7`.
void main() {
  test(
    'v6→v7 adds chat_reads(event_id, uid, last_read_at) without data loss',
    () async {
      final raw = sqlite3.openInMemory();

      // Minimal v6 schema: just enough that AppDatabase post-migration can
      // open without complaining about missing existing tables. The other
      // v6 tables are recreated by Drift's onCreate path if missing — but we
      // emulate a real v6 install by providing them empty.
      raw.execute('''
      CREATE TABLE users (
        id TEXT NOT NULL PRIMARY KEY,
        email TEXT NOT NULL,
        display_name TEXT,
        photo_url TEXT,
        payment_method TEXT,
        payment_handle TEXT,
        venmo_handle TEXT,
        cashapp_handle TEXT,
        currency TEXT NOT NULL DEFAULT 'USD',
        created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)),
        updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
      );
    ''');
      raw.execute('''
      CREATE TABLE events (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        event_type TEXT NOT NULL DEFAULT 'custom',
        creator_id TEXT NOT NULL,
        start_date INTEGER,
        end_date INTEGER,
        admin_ids TEXT NOT NULL DEFAULT '[]',
        member_ids TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'active',
        currency TEXT NOT NULL DEFAULT 'USD',
        created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)),
        updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
      );
    ''');
      // Seed a pre-migration row so we can confirm v7 didn't blow it away.
      raw.execute(
        "INSERT INTO events (id, title, creator_id) VALUES ('e-1', 'Trip', 'u-1');",
      );

      raw.execute('PRAGMA user_version = 6');

      // Open Drift over the same handle → invokes MigrationStrategy.
      final db = AppDatabase(NativeDatabase.opened(raw));

      // Force lazy init + onUpgrade execution by issuing a query that
      // touches the new chat_reads table.
      final results = await db
          .customSelect('SELECT event_id, uid, last_read_at FROM chat_reads')
          .get();
      expect(results, isEmpty);

      // Seed row to confirm columns work as expected.
      raw.execute(
        "INSERT INTO chat_reads (event_id, uid, last_read_at) VALUES ('e-1', 'u-1', 1700000000);",
      );
      final after = await db
          .customSelect('SELECT event_id, uid FROM chat_reads')
          .get();
      expect(after, hasLength(1));
      expect(after.single.data['event_id'], 'e-1');
      expect(after.single.data['uid'], 'u-1');

      // Pre-migration events row still intact.
      final eventsRows = await db.customSelect('SELECT id FROM events').get();
      expect(eventsRows, hasLength(1));
      expect(eventsRows.single.data['id'], 'e-1');

      // Schema version moved.
      final version = raw.select('PRAGMA user_version').first.values.first;
      expect(version, 7);

      await db.close();
    },
  );

  test('migration is idempotent — repeated opens do not throw', () async {
    final raw = sqlite3.openInMemory();
    // Start at v6 with chat_reads ALREADY present (simulating a partial
    // prior migration). The v6→v7 step must NOT crash with "table already
    // exists".
    raw.execute(
      'CREATE TABLE chat_reads (event_id TEXT NOT NULL, uid TEXT NOT NULL, last_read_at INTEGER NOT NULL, PRIMARY KEY (event_id, uid));',
    );
    raw.execute('PRAGMA user_version = 6');

    final db = AppDatabase(NativeDatabase.opened(raw));
    // No throw expected.
    await db.customSelect('SELECT count(*) FROM chat_reads').get();
    await db.close();
  });

  test('schemaVersion is 7', () {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 7);
    db.close();
  });
}
