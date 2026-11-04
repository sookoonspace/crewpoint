import 'package:crewpoint_app/app/features/budget/presentation/budget_screen.dart';
import 'package:crewpoint_app/app/features/chat/presentation/chat_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/task_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 19: the UI offers only what the server will accept in each status.
void main() {
  EventModel event(EventStatus status) => EventModel(
    id: 'e',
    title: 'T',
    creatorId: 'owner',
    adminIds: const ['admin'],
    memberIds: const ['owner', 'admin', 'member'],
    status: status,
  );

  group('task creation', () {
    Future<void> pumpTasks(
      WidgetTester tester,
      EventStatus status,
      String uid,
    ) => tester.pumpWidget(
      MaterialApp(
        home: TaskListScreen(
          event: event(status),
          currentUserId: uid,
          groups: const [],
          filter: const TasksFilter(),
          onFilterChanged: (_) {},
        ),
      ),
    );
    final create = find.byKey(const Key('tasks.list.create'));

    testWidgets('is offered while the event is live', (tester) async {
      await pumpTasks(tester, EventStatus.live, 'member');
      expect(create, findsOneWidget);
    });

    testWidgets('is gone for a plain member once ended', (tester) async {
      await pumpTasks(tester, EventStatus.ended, 'member');
      expect(create, findsNothing);
    });

    testWidgets('stays for an organizer once ended', (tester) async {
      await pumpTasks(tester, EventStatus.ended, 'admin');
      expect(create, findsOneWidget);
    });

    testWidgets('is gone for everyone once archived', (tester) async {
      await pumpTasks(tester, EventStatus.archived, 'owner');
      expect(create, findsNothing);
    });
  });

  group('adding an expense', () {
    final create = find.byKey(const Key('budget.expense.create'));

    testWidgets('stays open once ended, shown by the page flag', (
      tester,
    ) async {
      expect(event(EventStatus.ended).allowsChatAndMoney, isTrue);
      await tester.pumpWidget(
        const MaterialApp(
          home: BudgetScreen(expenses: [], memberIds: ['u']),
        ),
      );
      expect(create, findsOneWidget);
    });

    testWidgets('is gone once archived', (tester) async {
      expect(event(EventStatus.archived).allowsChatAndMoney, isFalse);
      await tester.pumpWidget(
        const MaterialApp(
          home: BudgetScreen(
            expenses: [],
            memberIds: ['u'],
            canAddExpense: false,
          ),
        ),
      );
      expect(create, findsNothing);
    });
  });

  group('chat', () {
    Future<void> pumpChat(WidgetTester tester, {required bool readOnly}) =>
        tester.pumpWidget(
          MaterialApp(
            home: ChatScreen(
              messages: const [],
              currentUserId: 'u',
              readOnly: readOnly,
            ),
          ),
        );

    testWidgets('has a composer while open', (tester) async {
      await pumpChat(tester, readOnly: false);
      expect(find.byKey(const Key('chat.composer.input')), findsOneWidget);
    });

    testWidgets('explains instead once archived', (tester) async {
      await pumpChat(tester, readOnly: true);
      expect(find.byKey(const Key('chat.composer.input')), findsNothing);
      expect(find.byKey(const Key('chat.composer.readOnly')), findsOneWidget);
    });
  });
}
