import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/tasks_filter_bar.dart';

void main() {
  Widget pump(Widget child) => MaterialApp(
    home: Scaffold(body: SafeArea(child: child)),
  );

  testWidgets('typing in search row emits onFilterChanged with new query', (
    tester,
  ) async {
    TasksFilter? captured;
    await tester.pumpWidget(
      pump(
        TasksFilterBar(
          filter: const TasksFilter(),
          onFilterChanged: (f) => captured = f,
        ),
      ),
    );

    final field = find.descendant(
      of: find.byKey(const Key('tasks.list.search')),
      matching: find.byType(TextField),
    );
    expect(field, findsOneWidget);
    await tester.enterText(field, 'lunch');
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.query, 'lunch');
  });

  testWidgets('tapping "Mine" chip toggles onlyMine in the filter', (
    tester,
  ) async {
    TasksFilter? captured;
    await tester.pumpWidget(
      pump(
        TasksFilterBar(
          filter: const TasksFilter(),
          onFilterChanged: (f) => captured = f,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tasks.list.filterChip.mine')));
    await tester.pump();
    expect(captured?.onlyMine, isTrue);
  });

  testWidgets('tapping a status chip toggles that status in the set', (
    tester,
  ) async {
    TasksFilter? captured;
    await tester.pumpWidget(
      pump(
        TasksFilterBar(
          filter: const TasksFilter(),
          onFilterChanged: (f) => captured = f,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tasks.list.filterChip.todo')));
    await tester.pump();
    expect(captured?.statuses, contains(TaskStatus.todo));

    // Tap again to clear.
    await tester.pumpWidget(
      pump(
        TasksFilterBar(filter: captured!, onFilterChanged: (f) => captured = f),
      ),
    );
    await tester.tap(find.byKey(const Key('tasks.list.filterChip.todo')));
    await tester.pump();
    expect(captured?.statuses, isEmpty);
  });

  testWidgets('sort menu selecting "Priority" updates sortKey', (tester) async {
    TasksFilter? captured;
    await tester.pumpWidget(
      pump(
        TasksFilterBar(
          filter: const TasksFilter(),
          onFilterChanged: (f) => captured = f,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tasks.list.sortMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tasks.list.sortMenu.priority')));
    await tester.pumpAndSettle();

    expect(captured?.sortKey, TasksSortKey.priority);
  });

  testWidgets('group toggle changes groupBy', (tester) async {
    TasksFilter? captured;
    await tester.pumpWidget(
      pump(
        TasksFilterBar(
          filter: const TasksFilter(),
          onFilterChanged: (f) => captured = f,
        ),
      ),
    );

    // Tap the assignee segment in the SegmentedButton.
    await tester.tap(find.byKey(const Key('tasks.list.groupToggle.assignee')));
    await tester.pump();
    expect(captured?.groupBy, TasksGroupBy.assignee);
  });
}
