import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/task_list_screen.dart';

void main() {
  // Wide canvas so the filter-bar Wrap doesn't collide with the FAB.
  void resizeWide(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
  }

  const event = EventModel(
    id: 'evt-1',
    title: 'Trip',
    creatorId: 'owner-1',
    memberIds: ['owner-1'],
    currency: 'USD',
  );

  Widget pump({
    required List<TasksGroup> groups,
    required TasksFilter filter,
    ValueChanged<TasksFilter>? onFilterChanged,
  }) {
    return MaterialApp(
      home: TaskListScreen(
        groups: groups,
        event: event,
        currentUserId: 'owner-1',
        filter: filter,
        onFilterChanged: onFilterChanged ?? (_) {},
      ),
    );
  }

  testWidgets('tapping a chip propagates updated TasksFilter via callback', (
    tester,
  ) async {
    resizeWide(tester);
    addTearDown(tester.view.resetPhysicalSize);

    TasksFilter? captured;
    await tester.pumpWidget(
      pump(
        groups: const [],
        filter: const TasksFilter(),
        onFilterChanged: (f) => captured = f,
      ),
    );

    await tester.tap(find.byKey(const Key('tasks.list.filterChip.mine')));
    await tester.pump();
    expect(captured?.onlyMine, isTrue);
  });

  testWidgets(
    'empty state — "No tasks yet" when no filters; no Clear-filters button',
    (tester) async {
      resizeWide(tester);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        pump(groups: const [], filter: const TasksFilter()),
      );

      expect(find.byKey(const Key('tasks.list.emptyState')), findsOneWidget);
      expect(find.text('No tasks yet'), findsOneWidget);
      expect(
        find.byKey(const Key('tasks.list.emptyState.clear')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'empty state — filter-aware copy + Clear-filters button when filters active',
    (tester) async {
      resizeWide(tester);
      addTearDown(tester.view.resetPhysicalSize);

      TasksFilter? captured;
      await tester.pumpWidget(
        pump(
          groups: const [],
          filter: const TasksFilter(onlyMine: true),
          onFilterChanged: (f) => captured = f,
        ),
      );

      expect(find.text('No tasks match this filter'), findsOneWidget);
      expect(
        find.byKey(const Key('tasks.list.emptyState.clear')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('tasks.list.emptyState.clear')));
      await tester.pump();
      expect(captured, isNotNull);
      expect(captured!.hasActiveFilters, isFalse);
    },
  );

  testWidgets('renders a group header per non-empty TasksGroup', (
    tester,
  ) async {
    resizeWide(tester);
    addTearDown(tester.view.resetPhysicalSize);

    const todoTask = TaskModel(
      id: 't-1',
      eventId: 'evt-1',
      title: 'Buy snacks',
    );
    const doneTask = TaskModel(
      id: 't-2',
      eventId: 'evt-1',
      title: 'Pack bags',
      status: TaskStatus.done,
    );

    await tester.pumpWidget(
      pump(
        groups: const [
          TasksGroup(key: 'todo', label: 'To Do', tasks: [todoTask]),
          TasksGroup(key: 'done', label: 'Done', tasks: [doneTask]),
        ],
        filter: const TasksFilter(),
      ),
    );

    expect(
      find.byKey(const Key('tasks.list.groupHeader.todo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('tasks.list.groupHeader.done')),
      findsOneWidget,
    );
    // "To Do" / "Done" also appear as filter chip labels — assert at least
    // one match (the group header text).
    expect(find.text('To Do'), findsWidgets);
    expect(find.text('Done'), findsWidgets);
    expect(find.text('Buy snacks'), findsOneWidget);
    expect(find.text('Pack bags'), findsOneWidget);
  });
}
