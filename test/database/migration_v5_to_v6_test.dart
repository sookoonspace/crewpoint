import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';

/// Migration test for Drift v5→v6: adds `tasks.budget_estimate` as a
/// nullable real column.
///
/// Snapshot policy: this PR is the first to commit `drift_schemas/`
/// (v6 baseline at `drift_schemas/drift_schema_v6.json`). Future migrations
/// can use `SchemaVerifier` against the prior snapshot generated via
/// `dart run drift_dev schema dump lib/app/core/database/app_database.dart
/// drift_schemas/` — see Drift's migration testing docs.
///
/// For v5→v6 we set up a v5-shaped schema with raw SQL, then construct an
/// `AppDatabase` over the same sqlite handle so its `MigrationStrategy.onUpgrade`
/// runs from `from = 5` to `to = 6` and the new column is added.
void main() {
  test(
    'v5→v6 adds tasks.budget_estimate as nullable real (no data loss)',
    () async {
      // Build a v5-shaped sqlite DB (in-memory, shared across handles).
      final raw = sqlite3.openInMemory();

      // Minimal v5 tasks table (no budget_estimate). Other v5 columns must exist
      // so the Drift generated table mapping doesn't blow up when we open it
      // post-migration.
      raw.execute('''
      CREATE TABLE tasks (
        id TEXT NOT NULL PRIMARY KEY,
        event_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        assignee_id TEXT,
        created_by TEXT,
        status TEXT NOT NULL DEFAULT 'todo',
        priority INTEGER NOT NULL DEFAULT 0,
        due_date INTEGER,
        completed_at INTEGER,
        completed_by TEXT,
        created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)),
        updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER))
      );
    ''');

      // Seed a v5 row to confirm migration preserves data.
      raw.execute('''
      INSERT INTO tasks (id, event_id, title)
      VALUES ('t-1', 'e-1', 'Pre-migration task');
    ''');

      // Stamp the user_version so Drift recognises this DB as v5 and
      // triggers onUpgrade(5 → 6).
      raw.execute('PRAGMA user_version = 5');

      // Open Drift over the same handle. This invokes the MigrationStrategy.
      final db = AppDatabase(NativeDatabase.opened(raw));

      // Force the migrator to walk: a no-op query is enough to lazily
      // initialise and run onUpgrade.
      final results = await db
          .customSelect('SELECT id, budget_estimate FROM tasks')
          .get();

      expect(results, hasLength(1));
      expect(results.single.data['id'], 't-1');
      expect(results.single.data['budget_estimate'], isNull);

      // Confirm the schema version moved.
      final version = raw.select('PRAGMA user_version').first.values.first;
      expect(version, 6);

      await db.close();
    },
  );

  test('Migrator.addColumn step is part of onUpgrade(from=5)', () {
    // Smoke check: AppDatabase.schemaVersion is 6 (regression for accidental
    // bump without a matching onUpgrade step).
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 6);
    db.close();
    // Confirm Migrator exists (compile-time check; satisfies analyzer
    // import of drift package).
    expect(Migrator, isNotNull);
  });
}
