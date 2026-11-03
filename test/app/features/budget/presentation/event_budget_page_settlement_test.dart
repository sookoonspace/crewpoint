import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase;
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/url_launcher_service.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';
import 'package:crewpoint_app/app/features/budget/presentation/event_budget_page.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _event = EventModel(
  id: 'evt',
  title: 'Trip',
  creatorId: 'me',
  memberIds: ['me', 'alex'],
  currency: 'USD',
);

// I owe alex 20.
const _dinner = ExpenseModel(
  id: 'dinner',
  eventId: 'evt',
  payerId: 'alex',
  amount: 40,
  splits: [
    ExpenseSplit(userId: 'me', amount: 20),
    ExpenseSplit(userId: 'alex', amount: 20),
  ],
);

class _Launcher implements IUrlLauncher {
  @override
  Future<bool> launch(Uri uri) async => true;
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedIn extends AuthNotifier {
  _SignedIn() : super(authRepository: _UnusedAuthRepository());

  @override
  AuthState build() =>
      const Authenticated(AppUser(uid: 'me', email: 'me@example.com'));
}

Future<void> _confirmPayment(
  WidgetTester tester, {
  required RecordSettlementCall call,
}) async {
  final firestore = FakeFirebaseFirestore();
  await firestore.doc('users/alex').set({'venmoHandle': 'alex_v'});
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_SignedIn.new),
        databaseProvider.overrideWithValue(db),
        firestoreProvider.overrideWithValue(firestore),
        urlLauncherProvider.overrideWithValue(_Launcher()),
        recordSettlementCallProvider.overrideWithValue(call),
        expenseListProvider.overrideWith((ref, _) => Stream.value([_dinner])),
        usersByIdProvider.overrideWith((ref, _) async => {}),
      ],
      child: const MaterialApp(home: EventBudgetPage(event: _event)),
    ),
  );
  await tester.pumpAndSettle();

  final settle = find.byKey(const Key('budget.settle.alex'));
  await tester.ensureVisible(settle);
  await tester.tap(settle);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('budget.settle.venmo')));
  await tester.pumpAndSettle();

  // Back from the payment app, within the confirm window.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('budget.settle.confirm')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a recorded payment shows no error', (tester) async {
    final sent = <({String payer, String payee, double amount})>[];
    await _confirmPayment(
      tester,
      call:
          ({
            required eventId,
            required settlementId,
            required payerId,
            required payeeId,
            required amount,
          }) async {
            sent.add((payer: payerId, payee: payeeId, amount: amount));
          },
    );
    expect(sent.single, (payer: 'me', payee: 'alex', amount: 20.0));
    expect(find.byKey(const Key('budget.settle.error')), findsNothing);
  });

  testWidgets('with no connection, explains and retries with the same ID', (
    tester,
  ) async {
    final ids = <String>[];
    await _confirmPayment(
      tester,
      call:
          ({
            required eventId,
            required settlementId,
            required payerId,
            required payeeId,
            required amount,
          }) async {
            ids.add(settlementId);
            if (ids.length == 1) {
              throw FirebaseFunctionsException(
                message: 'offline',
                code: 'unavailable',
              );
            }
          },
    );

    expect(find.textContaining('needs a connection'), findsOneWidget);

    await tester.tap(find.byKey(const Key('budget.settle.retry')));
    await tester.pumpAndSettle();

    expect(ids, hasLength(2));
    expect(ids[1], ids[0], reason: 'a retry must not record it twice');
  });

  testWidgets('a refusal explains, with no retry', (tester) async {
    await _confirmPayment(
      tester,
      call:
          ({
            required eventId,
            required settlementId,
            required payerId,
            required payeeId,
            required amount,
          }) async {
            throw FirebaseFunctionsException(
              message: 'no',
              code: 'permission-denied',
            );
          },
    );
    expect(find.textContaining('could not be recorded'), findsOneWidget);
    expect(find.byKey(const Key('budget.settle.retry')), findsNothing);
  });
}
