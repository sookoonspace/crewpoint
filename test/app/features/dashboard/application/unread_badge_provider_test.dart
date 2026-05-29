import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/chat/application/global_inbox_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/application/unread_badge_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_assigned_tasks_provider.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

const _uid = 'me';

const _event = EventModel(
  id: 'evt-1',
  title: 'Trip',
  creatorId: _uid,
  memberIds: [_uid, 'alex'],
  currency: 'USD',
);

MyAssignedTaskRow _task({required TaskStatus status, String id = 't1'}) {
  return MyAssignedTaskRow(
    task: TaskModel(
      id: id,
      eventId: _event.id,
      title: 'Task',
      createdBy: 'alex',
      assigneeId: _uid,
      status: status,
    ),
    event: _event,
  );
}

InboxRow _inbox({required int unread, String eventId = 'evt-1'}) {
  return InboxRow(
    event: EventModel(
      id: eventId,
      title: 'Trip',
      creatorId: _uid,
      memberIds: const [_uid, 'alex'],
      currency: 'USD',
    ),
    lastMessage: null,
    unreadCount: unread,
  );
}

DebtRow _debt({double amount = 10}) {
  return DebtRow(
    counterpartyUid: 'alex',
    event: _event,
    amount: amount,
    currency: 'USD',
  );
}

ProviderContainer _container({
  required AsyncValue<List<MyAssignedTaskRow>> tasks,
  required AsyncValue<List<InboxRow>> inbox,
  required AsyncValue<LedgerSummary> ledger,
}) {
  return ProviderContainer(
    overrides: [
      myAssignedTasksProvider(_uid).overrideWith((ref) => tasks),
      globalInboxProvider(_uid).overrideWith((ref) => inbox),
      globalBalanceLedgerProvider(_uid).overrideWith((ref) => ledger),
    ],
  );
}

void main() {
  group('unreadBadgeProvider', () {
    test('all-zero when every source is empty', () {
      final c = _container(
        tasks: const AsyncData([]),
        inbox: const AsyncData([]),
        ledger: const AsyncData(LedgerSummary.empty()),
      );
      addTearDown(c.dispose);

      final counts = c.read(unreadBadgeProvider(_uid));

      expect(counts.tasks, 0);
      expect(counts.chat, 0);
      expect(counts.budget, 0);
      expect(counts.total, 0);
      expect(counts.hasAny, isFalse);
    });

    test(
      'tasks count = number of incomplete assigned tasks (excludes done)',
      () {
        final c = _container(
          tasks: AsyncData([
            _task(status: TaskStatus.todo, id: 't1'),
            _task(status: TaskStatus.inProgress, id: 't2'),
            _task(status: TaskStatus.done, id: 't3'),
          ]),
          inbox: const AsyncData([]),
          ledger: const AsyncData(LedgerSummary.empty()),
        );
        addTearDown(c.dispose);

        final counts = c.read(unreadBadgeProvider(_uid));

        expect(counts.tasks, 2);
        expect(counts.total, 2);
      },
    );

    test('chat count = number of events with unreadCount > 0', () {
      final c = _container(
        tasks: const AsyncData([]),
        inbox: AsyncData([
          _inbox(unread: 3, eventId: 'evt-a'),
          _inbox(unread: 0, eventId: 'evt-b'), // ignored
          _inbox(unread: 7, eventId: 'evt-c'),
        ]),
        ledger: const AsyncData(LedgerSummary.empty()),
      );
      addTearDown(c.dispose);

      final counts = c.read(unreadBadgeProvider(_uid));

      expect(counts.chat, 2);
    });

    test('budget count = number of open debt rows', () {
      final c = _container(
        tasks: const AsyncData([]),
        inbox: const AsyncData([]),
        ledger: AsyncData(
          LedgerSummary(
            totalOwedToYou: 0,
            totalYouOwe: 30,
            debts: [_debt(amount: 10), _debt(amount: 20)],
            recentExpenses: const [],
          ),
        ),
      );
      addTearDown(c.dispose);

      final counts = c.read(unreadBadgeProvider(_uid));

      expect(counts.budget, 2);
    });

    test(
      'loading sources contribute 0 — badge never blocks on partial state',
      () {
        final c = _container(
          tasks: const AsyncLoading(),
          inbox: const AsyncLoading(),
          ledger: const AsyncLoading(),
        );
        addTearDown(c.dispose);

        final counts = c.read(unreadBadgeProvider(_uid));

        expect(counts.total, 0);
      },
    );

    test(
      'error sources contribute 0 — badge never blocks on partial state',
      () {
        final err = StateError('boom');
        const st = StackTrace.empty;
        final c = _container(
          tasks: AsyncError(err, st),
          inbox: AsyncError(err, st),
          ledger: AsyncError(err, st),
        );
        addTearDown(c.dispose);

        final counts = c.read(unreadBadgeProvider(_uid));

        expect(counts.total, 0);
      },
    );

    test('re-emits when an upstream source updates', () {
      var tasks = const AsyncData<List<MyAssignedTaskRow>>([]);
      final c = ProviderContainer(
        overrides: [
          myAssignedTasksProvider(_uid).overrideWith((ref) => tasks),
          globalInboxProvider(_uid).overrideWith((ref) => const AsyncData([])),
          globalBalanceLedgerProvider(
            _uid,
          ).overrideWith((ref) => const AsyncData(LedgerSummary.empty())),
        ],
      );
      addTearDown(c.dispose);

      expect(c.read(unreadBadgeProvider(_uid)).total, 0);

      tasks = AsyncData([_task(status: TaskStatus.todo)]);
      c.invalidate(myAssignedTasksProvider(_uid));

      expect(c.read(unreadBadgeProvider(_uid)).total, 1);
    });
  });
}
