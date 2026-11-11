import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/module_guard.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_assigned_tasks_provider.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const on = EventModel(
    id: 'on',
    title: 'On',
    creatorId: 'me',
    memberIds: ['me'],
  );
  const off = EventModel(
    id: 'off',
    title: 'Off',
    creatorId: 'me',
    memberIds: ['me'],
    modules: {'tasks': false, 'budget': false, 'chat': false},
  );

  testWidgets(
    'GE-02 a saved link to a turned-off module explains and returns',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/dashboard/event/off/budget',
        routes: [
          GoRoute(
            path: '/dashboard/event/off',
            builder: (_, _) => const Text('event home'),
          ),
          GoRoute(
            path: '/dashboard/event/off/budget',
            builder: (_, _) => const ModuleGuard(
              event: off,
              module: 'budget',
              child: Text('budget page'),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('budget page'), findsNothing);
      expect(find.byKey(const Key('events.module.off')), findsOneWidget);
      await tester.tap(find.byKey(const Key('events.module.back')));
      await tester.pumpAndSettle();
      expect(find.text('event home'), findsOneWidget);
    },
  );

  testWidgets('GE-02 a module that is on shows its page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ModuleGuard(
          event: on,
          module: 'budget',
          child: Text('budget page'),
        ),
      ),
    );
    expect(find.text('budget page'), findsOneWidget);
  });

  group('GE-02 global tabs leave out a turned-off module', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('me'),
          peopleByIdProvider.overrideWith((_, _) async => const {}),
          dashboardEventsProvider.overrideWith(
            (_) => Stream.value(const [on, off]),
          ),
          taskListProvider.overrideWith(
            (_, eventId) => Stream.value([
              TaskModel(
                id: 't-$eventId',
                eventId: eventId,
                title: 'Task in $eventId',
                assigneeId: 'me',
              ),
            ]),
          ),
          expenseListProvider.overrideWith(
            (_, eventId) => Stream.value([
              ExpenseModel(
                id: 'x-$eventId',
                eventId: eventId,
                payerId: 'me',
                amount: 10,
              ),
            ]),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('GE-02 my tasks', () async {
      final c = container();
      final sub = c.listen(myAssignedTasksProvider('me'), (_, _) {});
      addTearDown(sub.close);
      await settle();
      expect(sub.read().requireValue.map((r) => r.event.id), ['on']);
    });

    test('GE-02 budget', () async {
      final c = container();
      final sub = c.listen(globalBalanceLedgerProvider('me'), (_, _) {});
      addTearDown(sub.close);
      await settle();
      expect(sub.read().requireValue.recentExpenses.map((r) => r.event.id), [
        'on',
      ]);
    });
  });
}
