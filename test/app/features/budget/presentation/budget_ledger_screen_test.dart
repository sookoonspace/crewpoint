import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/skeletons.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/budget_ledger_screen.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Empty roster — keeps the cross-event ledger off the real user repo
/// in tests that don't care about resolved names.
final _emptyRosterOverride = usersByIdProvider.overrideWith(
  (ref, key) async => const <String, AppUser>{},
);

/// Lottie loops forever — bounded pumps, not pumpAndSettle.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('loading branch — renders BalanceTileSkeleton, no empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'uid-1'),
          dashboardEventsProvider.overrideWith(
            (ref) => const Stream<List<EventModel>>.empty(),
          ),
        ],
        child: const MaterialApp(home: BudgetLedgerScreen()),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byType(BalanceTileSkeleton), findsOneWidget);
    expect(find.byKey(const Key('emptyState.title')), findsNothing);
  });

  testWidgets(
    'null-uid short-circuit — signInRequiredTitle; globalBalanceLedgerProvider never subscribed',
    (tester) async {
      var dashboardSubs = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => null),
            dashboardEventsProvider.overrideWith((ref) {
              dashboardSubs++;
              return Stream.value(const <EventModel>[]);
            }),
          ],
          child: const MaterialApp(home: BudgetLedgerScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(find.text('Sign in to view your tasks'), findsOneWidget);
      expect(dashboardSubs, 0);
    },
  );

  testWidgets(
    'empty-no-events branch — ledgerEmptyNoEventsSubtitle + createFromDashboardCta',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'uid-1'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const <EventModel>[]),
            ),
          ],
          child: const MaterialApp(home: BudgetLedgerScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.text(
          'Create an event from the Dashboard to start tracking expenses.',
        ),
        findsOneWidget,
      );
      expect(find.text('Create an event'), findsOneWidget);
    },
  );

  testWidgets(
    'empty-with-events-no-expenses branch — ledgerEmptySubtitle + openDashboardCta',
    (tester) async {
      const event = EventModel(
        id: 'evt-1',
        title: 'Trip',
        creatorId: 'uid-1',
        memberIds: ['uid-1'],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'uid-1'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [event]),
            ),
            expenseListProvider.overrideWith(
              (ref, eventId) => Stream.value(const <ExpenseModel>[]),
            ),
            _emptyRosterOverride,
          ],
          child: const MaterialApp(home: BudgetLedgerScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.text('Open an event from the Dashboard to log an expense.'),
        findsOneWidget,
      );
      expect(find.text('Open Dashboard'), findsOneWidget);
    },
  );

  testWidgets(
    'non-empty branch — hero + debt tile keyed by counterparty+event + recent expense tile',
    (tester) async {
      const event = EventModel(
        id: 'evt-1',
        title: 'Trip',
        creatorId: 'me',
        memberIds: ['me', 'alex'],
        currency: 'USD',
      );
      // I owe alex $50.
      final exp = ExpenseModel(
        id: 'exp-1',
        eventId: 'evt-1',
        payerId: 'alex',
        amount: 100,
        splits: const [
          ExpenseSplit(userId: 'alex', amount: 50),
          ExpenseSplit(userId: 'me', amount: 50),
        ],
        createdAt: DateTime(2026, 5, 14),
        description: 'Lift tickets',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'me'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [event]),
            ),
            expenseListProvider.overrideWith(
              (ref, eventId) => Stream.value([exp]),
            ),
            _emptyRosterOverride,
          ],
          child: const MaterialApp(home: BudgetLedgerScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(const Key('balance.tile.youOwe')), findsOneWidget);
      expect(find.byKey(const Key('balance.tile.owedToYou')), findsOneWidget);
      expect(
        find.byKey(const Key('budget.ledger.debt.alex.evt-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('budget.ledger.recentExpense.exp-1')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'all-settled state — LedgerAllSettledChip renders when debts empty but recent expenses present',
    (tester) async {
      const event = EventModel(
        id: 'evt-1',
        title: 'Trip',
        creatorId: 'me',
        memberIds: ['me'],
        currency: 'USD',
      );
      // Self-only expense: I pay $10, my own split is $10. No debt.
      final exp = ExpenseModel(
        id: 'exp-1',
        eventId: 'evt-1',
        payerId: 'me',
        amount: 10,
        splits: const [ExpenseSplit(userId: 'me', amount: 10)],
        createdAt: DateTime(2026, 5, 14),
        description: 'Coffee',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'me'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [event]),
            ),
            expenseListProvider.overrideWith(
              (ref, eventId) => Stream.value([exp]),
            ),
            _emptyRosterOverride,
          ],
          child: const MaterialApp(home: BudgetLedgerScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(const Key('budget.ledger.allSettled')), findsOneWidget);
      expect(find.text("You're all settled up."), findsOneWidget);
    },
  );

  testWidgets(
    'recent expense tile tap fires onOpenEventBudget seam with the right event',
    (tester) async {
      const event = EventModel(
        id: 'evt-1',
        title: 'Trip',
        creatorId: 'me',
        memberIds: ['me'],
        currency: 'USD',
      );
      final exp = ExpenseModel(
        id: 'exp-1',
        eventId: 'evt-1',
        payerId: 'me',
        amount: 10,
        splits: const [ExpenseSplit(userId: 'me', amount: 10)],
        createdAt: DateTime(2026, 5, 14),
        description: 'Coffee',
      );

      EventModel? captured;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'me'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [event]),
            ),
            expenseListProvider.overrideWith(
              (ref, eventId) => Stream.value([exp]),
            ),
            _emptyRosterOverride,
          ],
          child: MaterialApp(
            home: BudgetLedgerScreen(onOpenEventBudget: (_, e) => captured = e),
          ),
        ),
      );
      await _pumpFrames(tester);

      await tester.tap(
        find.byKey(const Key('budget.ledger.recentExpense.exp-1')),
      );
      await _pumpFrames(tester);
      expect(captured?.id, 'evt-1');
    },
  );

  testWidgets(
    'multi-currency disclaimer renders only when an event currency is non-USD',
    (tester) async {
      const eventEur = EventModel(
        id: 'evt-eur',
        title: 'Paris',
        creatorId: 'me',
        memberIds: ['me', 'bob'],
        currency: 'EUR',
      );
      final exp = ExpenseModel(
        id: 'exp-1',
        eventId: 'evt-eur',
        payerId: 'bob',
        amount: 20,
        splits: const [
          ExpenseSplit(userId: 'bob', amount: 10),
          ExpenseSplit(userId: 'me', amount: 10),
        ],
        createdAt: DateTime(2026, 5, 14),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'me'),
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [eventEur]),
            ),
            expenseListProvider.overrideWith(
              (ref, eventId) => Stream.value([exp]),
            ),
            _emptyRosterOverride,
          ],
          child: const MaterialApp(home: BudgetLedgerScreen()),
        ),
      );
      await _pumpFrames(tester);

      expect(find.byKey(const Key('balance.tile.disclaimer')), findsOneWidget);
    },
  );
}
