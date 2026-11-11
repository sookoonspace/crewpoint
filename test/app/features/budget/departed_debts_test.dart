import 'package:crewpoint_app/app/core/database/app_database.dart'
    show AppDatabase;
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/budget_screen.dart';
import 'package:crewpoint_app/app/features/budget/presentation/event_budget_page.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fake_user_repository.dart';

// `gone` left owing `me` 20. Everyone else is square.
const _debt = ExpenseModel(
  id: 'dinner',
  eventId: 'evt',
  payerId: 'me',
  amount: 40,
  splits: [
    ExpenseSplit(userId: 'me', amount: 20),
    ExpenseSplit(userId: 'gone', amount: 20),
  ],
);

EventModel _event({List<String> adminIds = const []}) => EventModel(
  id: 'evt',
  title: 'Trip',
  creatorId: 'owner',
  adminIds: adminIds,
  memberIds: const ['owner', 'me'],
  currency: 'USD',
);

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

typedef _Recorded = ({String payer, String payee, double amount});

Future<void> _pumpPage(
  WidgetTester tester, {
  required EventModel event,
  List<_Recorded>? recorded,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_SignedIn.new),
        databaseProvider.overrideWithValue(db),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        expenseListProvider.overrideWith((ref, _) => Stream.value([_debt])),
        peopleByIdProvider.overrideWith((ref, _) async => {}),
        // Nobody has a profile: the departed person's name falls back.
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        recordSettlementCallProvider.overrideWithValue(({
          required eventId,
          required settlementId,
          required payerId,
          required payeeId,
          required amount,
        }) async {
          recorded?.add((payer: payerId, payee: payeeId, amount: amount));
        }),
      ],
      child: MaterialApp(home: EventBudgetPage(event: event)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSettle(WidgetTester tester) async {
  final settle = find.byKey(const Key('budget.settle.me'));
  await tester.ensureVisible(settle);
  await tester.tap(settle);
  await tester.pumpAndSettle();
}

void main() {
  group('names on the budget screen', () {
    testWidgets('a departed person is labelled, never shown as an ID', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BudgetScreen(
            expenses: [_debt],
            memberIds: ['owner', 'me'],
            memberNames: {'owner': 'Olive', 'me': 'Mina'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('(no longer in event)'), findsWidgets);
      expect(find.textContaining('gone'), findsNothing);
      expect(find.textContaining('Mina'), findsWidgets);
    });

    testWidgets('a current member with no name yet keeps their ID', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BudgetScreen(expenses: [_debt], memberIds: ['me', 'gone']),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('(no longer in event)'), findsNothing);
    });
  });

  group('settling for a departed person', () {
    testWidgets('someone who manages money can record it, after confirming', (
      tester,
    ) async {
      final recorded = <_Recorded>[];
      await _pumpPage(
        tester,
        event: _event(adminIds: const ['me']),
        recorded: recorded,
      );
      await _tapSettle(tester);

      final confirm = find.byKey(const Key('budget.settle.onBehalf.confirm'));
      expect(confirm, findsOneWidget);
      expect(find.textContaining('(no longer in event)'), findsWidgets);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(recorded.single, (payer: 'gone', payee: 'me', amount: 20.0));
    });

    testWidgets('it records nothing if they cancel', (tester) async {
      final recorded = <_Recorded>[];
      await _pumpPage(
        tester,
        event: _event(adminIds: const ['me']),
        recorded: recorded,
      );
      await _tapSettle(tester);
      await tester.tap(find.byKey(const Key('budget.settle.onBehalf.cancel')));
      await tester.pumpAndSettle();
      expect(recorded, isEmpty);
    });

    testWidgets('others are told who can record it', (tester) async {
      final recorded = <_Recorded>[];
      await _pumpPage(tester, event: _event(), recorded: recorded);
      await _tapSettle(tester);

      expect(
        find.byKey(const Key('budget.settle.onBehalf.confirm')),
        findsNothing,
      );
      expect(find.textContaining('organizer'), findsOneWidget);
      expect(recorded, isEmpty);
    });
  });
}
