import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase, EventsCompanion, UsersCompanion;
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/users_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expense_splits_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expenses_dao.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_repository.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 32: a Vendor or Observer lists only expenses they paid or share in,
/// with the `involvedUids` query the rules allow.
void main() {
  late AppDatabase db;
  late FakeFirebaseFirestore firestore;
  late ExpenseRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    firestore = FakeFirebaseFirestore();
    for (final uid in ['owner', 'vendor-1']) {
      await UsersDao(
        db,
      ).insertUser(UsersCompanion.insert(id: uid, email: '$uid@example.com'));
    }
    await EventsDao(db).insertEvent(
      EventsCompanion.insert(id: 'event-1', title: 'Fest', creatorId: 'owner'),
    );
    repo = ExpenseRepository(
      expensesDao: ExpensesDao(db),
      splitsDao: ExpenseSplitsDao(db),
      firestore: firestore,
      saveExpenseCall: (_) async {},
      recordSettlementCall:
          ({
            required eventId,
            required settlementId,
            required payerId,
            required payeeId,
            required amount,
          }) async {},
    );
    for (final (id, people) in [
      ('deposit', ['owner', 'vendor-1']),
      ('venue', ['owner']),
    ]) {
      await firestore.doc('events/event-1/expenses/$id').set({
        'payerId': 'owner',
        'amount': 10,
        'description': id,
        'splits': [
          for (final uid in people)
            {'userId': uid, 'amount': 10 / people.length},
        ],
        'involvedUids': people,
      });
    }
  });
  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  test('the scoped stream returns only expenses they share in', () async {
    final expenses = await repo
        .watchExpensesByEventId('event-1', involving: 'vendor-1')
        .firstWhere((e) => e.isNotEmpty);
    expect(expenses.map((e) => e.id), ['deposit']);
  });

  test(
    'narrowing access hides and then drops the rows already mirrored',
    () async {
      await repo
          .watchExpensesByEventId('event-1')
          .firstWhere((e) => e.length == 2);
      final narrowed = await repo
          .watchExpensesByEventId('event-1', involving: 'vendor-1')
          .first;
      expect(narrowed.map((e) => e.id), ['deposit']);
      await pumpEventQueue();
      final rows = await ExpensesDao(db).expensesByEventId('event-1');
      expect(rows.map((r) => r.id), ['deposit']);
    },
  );
}
