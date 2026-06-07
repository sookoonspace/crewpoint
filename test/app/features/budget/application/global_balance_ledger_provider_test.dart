import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/data/member_name_resolver.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// Returns an empty roster override — for tests that don't care about
/// name resolution and just need the provider not to hit the real repo.
final _emptyRosterOverride = usersByIdProvider.overrideWith(
  (ref, key) async => const <String, AppUser>{},
);

/// Drain cascading stream emissions through the composed provider.
Future<AsyncValue<LedgerSummary>> _readAfterPump(
  ProviderContainer container,
  String uid,
) async {
  container.listen<AsyncValue<LedgerSummary>>(
    globalBalanceLedgerProvider(uid),
    (_, _) {},
    fireImmediately: true,
  );
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await Future<void>.delayed(const Duration(milliseconds: 10));
  return container.read(globalBalanceLedgerProvider(uid));
}

void main() {
  const eventA = EventModel(
    id: 'evt-a',
    title: 'Tahoe Trip',
    creatorId: 'me',
    memberIds: ['me', 'alex'],
    currency: 'USD',
  );

  test(
    'composition: user paid \$100 in event A 50/50 with alex → alex owes user \$50',
    () async {
      final expA = ExpenseModel(
        id: 'exp-a-1',
        eventId: 'evt-a',
        payerId: 'me',
        amount: 100,
        splits: const [
          ExpenseSplit(userId: 'me', amount: 50),
          ExpenseSplit(userId: 'alex', amount: 50),
        ],
        createdAt: DateTime(2026, 5, 14, 10),
      );

      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          expenseListProvider.overrideWith(
            (ref, eventId) => Stream.value([expA]),
          ),
          _emptyRosterOverride,
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      expect(result, isA<AsyncData<LedgerSummary>>());
      final ledger = result.requireValue;
      expect(ledger.totalOwedToYou, 50);
      expect(ledger.totalYouOwe, 0);
      expect(ledger.debts, isEmpty);
      expect(ledger.recentExpenses, hasLength(1));
      expect(ledger.recentExpenses.single.expense.id, 'exp-a-1');
    },
  );

  test('archived events are INCLUDED (debts survive trip closure)', () async {
    const archived = EventModel(
      id: 'evt-old',
      title: 'Closed Trip',
      creatorId: 'me',
      memberIds: ['me', 'bob'],
      status: EventStatus.archived,
      currency: 'USD',
    );
    // I paid $40 for me + bob; bob owes me $20.
    final expOld = ExpenseModel(
      id: 'exp-old-1',
      eventId: 'evt-old',
      payerId: 'me',
      amount: 40,
      splits: const [
        ExpenseSplit(userId: 'me', amount: 20),
        ExpenseSplit(userId: 'bob', amount: 20),
      ],
      createdAt: DateTime(2025, 12, 1),
    );

    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [archived]),
        ),
        expenseListProvider.overrideWith(
          (ref, eventId) => Stream.value([expOld]),
        ),
        _emptyRosterOverride,
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    final ledger = result.requireValue;
    expect(ledger.totalOwedToYou, 20);
    expect(ledger.recentExpenses, hasLength(1));
  });

  test(
    'debt rows: sorted by amount desc; I-owe scenarios surface counterparty + amount',
    () async {
      const eventX = EventModel(
        id: 'evt-x',
        title: 'X',
        creatorId: 'me',
        memberIds: ['me', 'bob'],
        currency: 'USD',
      );
      const eventY = EventModel(
        id: 'evt-y',
        title: 'Y',
        creatorId: 'me',
        memberIds: ['me', 'carol'],
        currency: 'USD',
      );

      // I owe bob $30 (bob paid $60 split 50/50).
      final expX = ExpenseModel(
        id: 'exp-x',
        eventId: 'evt-x',
        payerId: 'bob',
        amount: 60,
        splits: const [
          ExpenseSplit(userId: 'bob', amount: 30),
          ExpenseSplit(userId: 'me', amount: 30),
        ],
        createdAt: DateTime(2026, 5, 1),
      );
      // I owe carol $100 (carol paid $200 split 50/50).
      final expY = ExpenseModel(
        id: 'exp-y',
        eventId: 'evt-y',
        payerId: 'carol',
        amount: 200,
        splits: const [
          ExpenseSplit(userId: 'carol', amount: 100),
          ExpenseSplit(userId: 'me', amount: 100),
        ],
        createdAt: DateTime(2026, 5, 2),
      );

      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventX, eventY]),
          ),
          expenseListProvider.overrideWith((ref, eventId) {
            return switch (eventId) {
              'evt-x' => Stream.value([expX]),
              'evt-y' => Stream.value([expY]),
              _ => Stream.value(const <ExpenseModel>[]),
            };
          }),
          _emptyRosterOverride,
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      final ledger = result.requireValue;
      expect(ledger.totalYouOwe, 130);
      expect(ledger.totalOwedToYou, 0);
      expect(ledger.debts, hasLength(2));
      expect(ledger.debts[0].counterpartyUid, 'carol');
      expect(ledger.debts[0].amount, 100);
      expect(ledger.debts[0].event.id, 'evt-y');
      expect(ledger.debts[1].counterpartyUid, 'bob');
      expect(ledger.debts[1].amount, 30);
    },
  );

  test('debt rows rounding to \$0.00 are dropped (spec req 36)', () async {
    // I paid $0.001 in a 50/50 split — settlement amount rounds to $0.00
    // and should not surface as a debt row. BalanceLedger.calculate's
    // own 0.01 epsilon makes this hard to repro at the simplification
    // step, so seed a tiny non-zero settlement instead and verify the
    // provider's own filter drops a near-zero entry. Simulate via a
    // direct expense that would create an effectively-zero balance.
    const eventTiny = EventModel(
      id: 'evt-tiny',
      title: 'Tiny',
      creatorId: 'me',
      memberIds: ['me', 'alex'],
    );
    final tiny = ExpenseModel(
      id: 'tiny',
      eventId: 'evt-tiny',
      payerId: 'me',
      amount: 0.004,
      splits: const [
        ExpenseSplit(userId: 'me', amount: 0.002),
        ExpenseSplit(userId: 'alex', amount: 0.002),
      ],
      createdAt: DateTime(2026, 5, 1),
    );

    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [eventTiny]),
        ),
        expenseListProvider.overrideWith(
          (ref, eventId) => Stream.value([tiny]),
        ),
        _emptyRosterOverride,
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    final ledger = result.requireValue;
    expect(ledger.debts, isEmpty);
    expect(ledger.totalOwedToYou, 0);
    expect(ledger.totalYouOwe, 0);
  });

  test('recent expenses capped at 20, sorted by createdAt desc', () async {
    const eventFeed = EventModel(
      id: 'evt-feed',
      title: 'Feed',
      creatorId: 'me',
      memberIds: ['me'],
    );
    final expenses = [
      for (var i = 0; i < 25; i++)
        ExpenseModel(
          id: 'e-$i',
          eventId: 'evt-feed',
          payerId: 'me',
          amount: 10,
          splits: const [ExpenseSplit(userId: 'me', amount: 10)],
          createdAt: DateTime(2026, 5, 1).add(Duration(hours: i)),
        ),
    ];

    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [eventFeed]),
        ),
        expenseListProvider.overrideWith(
          (ref, eventId) => Stream.value(expenses),
        ),
        _emptyRosterOverride,
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    final ledger = result.requireValue;
    expect(ledger.recentExpenses, hasLength(20));
    expect(ledger.recentExpenses.first.expense.id, 'e-24');
    expect(ledger.recentExpenses.last.expense.id, 'e-5');
  });

  test('returns AsyncLoading while events stream is pending', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => const Stream<List<EventModel>>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    expect(result, isA<AsyncLoading<LedgerSummary>>());
  });

  test(
    'returns AsyncLoading while any per-event expenses stream is pending',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [eventA]),
          ),
          expenseListProvider.overrideWith(
            (ref, eventId) => const Stream<List<ExpenseModel>>.empty(),
          ),
          _emptyRosterOverride,
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      expect(result, isA<AsyncLoading<LedgerSummary>>());
    },
  );

  test('propagates error from the events stream', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream<List<EventModel>>.error(StateError('events boom')),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    expect(result, isA<AsyncError<LedgerSummary>>());
    expect((result as AsyncError).error, isA<StateError>());
  });

  test('propagates error from any per-event expenses stream', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [eventA]),
        ),
        expenseListProvider.overrideWith(
          (ref, eventId) =>
              Stream<List<ExpenseModel>>.error(StateError('exp boom')),
        ),
        _emptyRosterOverride,
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    expect(result, isA<AsyncError<LedgerSummary>>());
    expect((result as AsyncError).error, isA<StateError>());
  });

  test(
    'DebtRow.counterpartyName resolves from roster displayName (happy path)',
    () async {
      const event = EventModel(
        id: 'evt-name',
        title: 'Trip',
        creatorId: 'me',
        memberIds: ['me', 'bob'],
        currency: 'USD',
      );
      // I owe bob $30.
      final exp = ExpenseModel(
        id: 'e1',
        eventId: 'evt-name',
        payerId: 'bob',
        amount: 60,
        splits: const [
          ExpenseSplit(userId: 'bob', amount: 30),
          ExpenseSplit(userId: 'me', amount: 30),
        ],
        createdAt: DateTime(2026, 5, 1),
      );

      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [event]),
          ),
          expenseListProvider.overrideWith(
            (ref, eventId) => Stream.value([exp]),
          ),
          usersByIdProvider.overrideWith(
            (ref, key) async => const <String, AppUser>{
              'me': AppUser(
                uid: 'me',
                email: 'me@x.com',
                displayName: 'Me User',
              ),
              'bob': AppUser(
                uid: 'bob',
                email: 'bob@x.com',
                displayName: 'Bob Builder',
              ),
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      final ledger = result.requireValue;
      expect(ledger.debts, hasLength(1));
      expect(ledger.debts.single.counterpartyName, 'Bob Builder');
    },
  );

  test(
    'DebtRow.counterpartyName falls back to email when displayName is empty/null',
    () async {
      const event = EventModel(
        id: 'evt-email',
        title: 'Trip',
        creatorId: 'me',
        memberIds: ['me', 'carol'],
        currency: 'USD',
      );
      final exp = ExpenseModel(
        id: 'e1',
        eventId: 'evt-email',
        payerId: 'carol',
        amount: 40,
        splits: const [
          ExpenseSplit(userId: 'carol', amount: 20),
          ExpenseSplit(userId: 'me', amount: 20),
        ],
        createdAt: DateTime(2026, 5, 1),
      );

      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [event]),
          ),
          expenseListProvider.overrideWith(
            (ref, eventId) => Stream.value([exp]),
          ),
          usersByIdProvider.overrideWith(
            (ref, key) async => const <String, AppUser>{
              'carol': AppUser(uid: 'carol', email: 'carol@x.com'),
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final ledger = (await _readAfterPump(container, 'me')).requireValue;
      expect(ledger.debts.single.counterpartyName, 'carol@x.com');
    },
  );

  test(
    'DebtRow.counterpartyName falls back to placeholder when uid is missing from roster',
    () async {
      const event = EventModel(
        id: 'evt-missing',
        title: 'Trip',
        creatorId: 'me',
        memberIds: ['me', 'ghost'],
        currency: 'USD',
      );
      final exp = ExpenseModel(
        id: 'e1',
        eventId: 'evt-missing',
        payerId: 'ghost',
        amount: 20,
        splits: const [
          ExpenseSplit(userId: 'ghost', amount: 10),
          ExpenseSplit(userId: 'me', amount: 10),
        ],
        createdAt: DateTime(2026, 5, 1),
      );

      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const [event]),
          ),
          expenseListProvider.overrideWith(
            (ref, eventId) => Stream.value([exp]),
          ),
          _emptyRosterOverride,
        ],
      );
      addTearDown(container.dispose);

      final ledger = (await _readAfterPump(container, 'me')).requireValue;
      expect(ledger.debts.single.counterpartyName, kRemovedMemberPlaceholder);
    },
  );

  test('RecentExpenseRow.payerName resolves from roster displayName', () async {
    const event = EventModel(
      id: 'evt-payer',
      title: 'Trip',
      creatorId: 'me',
      memberIds: ['me', 'alex'],
      currency: 'USD',
    );
    final exp = ExpenseModel(
      id: 'e1',
      eventId: 'evt-payer',
      payerId: 'alex',
      amount: 30,
      splits: const [ExpenseSplit(userId: 'alex', amount: 30)],
      createdAt: DateTime(2026, 5, 1),
    );

    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [event]),
        ),
        expenseListProvider.overrideWith((ref, eventId) => Stream.value([exp])),
        usersByIdProvider.overrideWith(
          (ref, key) async => const <String, AppUser>{
            'alex': AppUser(
              uid: 'alex',
              email: 'a@x.com',
              displayName: 'Alex Chen',
            ),
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final ledger = (await _readAfterPump(container, 'me')).requireValue;
    expect(ledger.recentExpenses.single.payerName, 'Alex Chen');
  });

  test('returns AsyncLoading while any per-event roster is pending', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [eventA]),
        ),
        expenseListProvider.overrideWith(
          (ref, eventId) => Stream.value(const <ExpenseModel>[]),
        ),
        usersByIdProvider.overrideWith((ref, key) {
          // Never completes → stays AsyncLoading.
          final completer = Completer<Map<String, AppUser>>();
          return completer.future;
        }),
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    expect(result, isA<AsyncLoading<LedgerSummary>>());
  });

  test('propagates error from any per-event roster', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (ref) => Stream.value(const [eventA]),
        ),
        expenseListProvider.overrideWith(
          (ref, eventId) => Stream.value(const <ExpenseModel>[]),
        ),
        usersByIdProvider.overrideWith(
          (ref, key) async => throw StateError('roster boom'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await _readAfterPump(container, 'me');
    expect(result, isA<AsyncError<LedgerSummary>>());
    expect((result as AsyncError).error, isA<StateError>());
  });

  test(
    'returns LedgerSummary.empty() when user has zero events; expense family NEVER subscribed',
    () async {
      final container = ProviderContainer(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const <EventModel>[]),
          ),
          expenseListProvider.overrideWith((ref, eventId) {
            throw StateError(
              'expenseListProvider must not be subscribed when events is empty',
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await _readAfterPump(container, 'me');
      final ledger = result.requireValue;
      expect(ledger.totalOwedToYou, 0);
      expect(ledger.totalYouOwe, 0);
      expect(ledger.debts, isEmpty);
      expect(ledger.recentExpenses, isEmpty);
    },
  );
}
