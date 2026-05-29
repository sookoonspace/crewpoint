import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Users table — local cache of authenticated users.
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get paymentHandle => text().nullable()();
  TextColumn get venmoHandle => text().nullable()();
  TextColumn get cashappHandle => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Events table — core event data.
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get eventType => text().withDefault(const Constant('custom'))();
  TextColumn get creatorId => text()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get adminIds => text().withDefault(const Constant('[]'))(); // JSON
  TextColumn get memberIds =>
      text().withDefault(const Constant('[]'))(); // JSON
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tasks table — tasks within events.
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get eventId => text().references(Events, #id)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get assigneeId => text().nullable().references(Users, #id)();
  TextColumn get createdBy => text().nullable().references(Users, #id)();
  TextColumn get status =>
      text().withDefault(const Constant('todo'))(); // todo, inProgress, done
  IntColumn get priority => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get completedBy => text().nullable().references(Users, #id)();
  RealColumn get budgetEstimate => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Task checklist items — child rows of a task.
class TaskChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get content => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Chat messages table — local cache.
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get eventId => text().references(Events, #id)();
  TextColumn get senderId => text().references(Users, #id)();
  TextColumn get content => text()();
  BoolColumn get isHighPriority =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get timestamp => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Expenses table — budget tracking.
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get eventId => text().references(Events, #id)();
  TextColumn get payerId => text().references(Users, #id)();
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  TextColumn get receiptPath => text().nullable()();
  BoolColumn get isDonation => boolean().withDefault(const Constant(false))();
  BoolColumn get isPayment => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Expense splits — per-user share of an expense.
class ExpenseSplits extends Table {
  TextColumn get expenseId => text().references(Expenses, #id)();
  TextColumn get userId => text().references(Users, #id)();
  RealColumn get amount => real()();

  @override
  Set<Column> get primaryKey => {expenseId, userId};
}

/// Per-user, per-event last-read timestamp powering the global chat
/// inbox unread badges. Source of truth is Firestore
/// (`users/{uid}/chatReads/{eventId}`); this table is the local cache.
class ChatReads extends Table {
  TextColumn get eventId => text()();
  TextColumn get uid => text()();
  DateTimeColumn get lastReadAt => dateTime()();

  @override
  Set<Column> get primaryKey => {eventId, uid};
}

@DriftDatabase(
  tables: [
    Users,
    Events,
    Tasks,
    TaskChecklistItems,
    ChatMessages,
    Expenses,
    ExpenseSplits,
    ChatReads,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 4) {
        await m.addColumn(events, events.currency);
        await m.addColumn(users, users.venmoHandle);
        await m.addColumn(users, users.cashappHandle);
        await m.addColumn(tasks, tasks.createdBy);
        await m.addColumn(tasks, tasks.completedAt);
        await m.addColumn(tasks, tasks.completedBy);
        await m.createTable(taskChecklistItems);
        await m.createTable(expenseSplits);
      }
      if (from < 5) {
        // Drop the FK on Events.creatorId. SQLite cannot drop FKs in
        // place, so Drift's TableMigration rebuilds the table: creates a
        // shadow with the new schema (no FK), copies rows, drops the
        // original, renames. Architectural rationale lives in the
        // Firestore-Write / Drift-Read spec — events are mirrored from
        // Firestore and don't depend on a Drift Users row existing.
        await m.alterTable(TableMigration(events));
      }
      if (from < 6) {
        await m.addColumn(tasks, tasks.budgetEstimate);
      }
      if (from < 7) {
        // Idempotent: a prior partial-migration run may have left the
        // table already present. CREATE TABLE IF NOT EXISTS is the safe
        // form for crash-tolerant migrations.
        await customStatement(
          'CREATE TABLE IF NOT EXISTS chat_reads ('
          'event_id TEXT NOT NULL, '
          'uid TEXT NOT NULL, '
          'last_read_at INTEGER NOT NULL, '
          'PRIMARY KEY (event_id, uid)'
          ')',
        );
      }
    },
  );
}
