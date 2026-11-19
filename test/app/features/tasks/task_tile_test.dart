import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/widgets/task_tile.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, child: child)),
  );

  TaskModel buildTask(TaskStatus status) => TaskModel(
    id: 'task-1',
    eventId: 'evt-1',
    title: 'Buy snacks',
    status: status,
  );

  Finder inStatus(Finder f) => find.descendant(
    of: find.byKey(const Key('tasks.tile.task-1.status')),
    matching: f,
  );

  testWidgets('status button: an empty circle to do', (tester) async {
    await tester.pumpWidget(
      harness(
        TaskTile(task: buildTask(TaskStatus.todo), canChangeStatus: false),
      ),
    );
    expect(inStatus(find.byIcon(CpIcons.statusTodo)), findsOneWidget);
  });

  testWidgets('status button: a play sign in progress', (tester) async {
    await tester.pumpWidget(
      harness(
        TaskTile(
          task: buildTask(TaskStatus.inProgress),
          canChangeStatus: false,
        ),
      ),
    );
    expect(inStatus(find.byIcon(CpIcons.statusDoing)), findsOneWidget);
  });

  testWidgets('done: a tick, and the green Done chip with its icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        TaskTile(task: buildTask(TaskStatus.done), canChangeStatus: false),
      ),
    );
    expect(inStatus(find.byIcon(CpIcons.check)), findsOneWidget);
    final chip = find.byKey(const Key('tasks.tile.task-1.done'));
    expect(tester.widget<CpStatusChip>(chip).status, CpStatus.done);
    expect(
      find.descendant(of: chip, matching: find.byIcon(CpIcons.statusDone)),
      findsOneWidget,
    );
  });

  testWidgets('tapping the status moves it on; without permission it says '
      'why instead', (tester) async {
    TaskStatus? next;
    var refused = false;
    await tester.pumpWidget(
      harness(
        TaskTile(
          task: buildTask(TaskStatus.todo),
          canChangeStatus: true,
          onStatusChanged: (s) => next = s,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('tasks.tile.task-1.status')));
    expect(next, TaskStatus.inProgress);

    await tester.pumpWidget(
      harness(
        TaskTile(
          task: buildTask(TaskStatus.todo),
          canChangeStatus: false,
          onUnauthorizedTap: () => refused = true,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('tasks.tile.task-1.status')));
    expect(refused, isTrue);
  });

  testWidgets('the status button is at least 48 px', (tester) async {
    await tester.pumpWidget(
      harness(
        TaskTile(task: buildTask(TaskStatus.todo), canChangeStatus: true),
      ),
    );
    final size = tester.getSize(
      find.byKey(const Key('tasks.tile.task-1.status')),
    );
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('renders budget text only when budgetEstimate is non-null', (
    tester,
  ) async {
    const taskWithBudget = TaskModel(
      id: 'task-1',
      eventId: 'evt-1',
      title: 'Buy snacks',
      budgetEstimate: 25.5,
    );
    await tester.pumpWidget(
      harness(const TaskTile(task: taskWithBudget, canChangeStatus: false)),
    );
    expect(find.byKey(const Key('tasks.tile.task-1.budget')), findsOneWidget);

    const taskNoBudget = TaskModel(
      id: 'task-2',
      eventId: 'evt-1',
      title: 'No estimate',
    );
    await tester.pumpWidget(
      harness(const TaskTile(task: taskNoBudget, canChangeStatus: false)),
    );
    expect(find.byKey(const Key('tasks.tile.task-2.budget')), findsNothing);
  });

  group('progress bar', () {
    TaskModel withChecklist({
      required TaskStatus status,
      required int total,
      required int completed,
    }) {
      assert(completed <= total);
      final items = <ChecklistItem>[
        for (var i = 0; i < total; i++)
          ChecklistItem(
            id: 'i$i',
            text: 'item-$i',
            isCompleted: i < completed,
            sortOrder: i,
          ),
      ];
      return TaskModel(
        id: 'task-1',
        eventId: 'evt-1',
        title: 't',
        status: status,
        checklistItems: items,
      );
    }

    testWidgets('hidden when checklist is empty', (tester) async {
      await tester.pumpWidget(
        harness(
          TaskTile(task: buildTask(TaskStatus.todo), canChangeStatus: false),
        ),
      );
      expect(
        find.byKey(const Key('tasks.tile.task-1.progressBar')),
        findsNothing,
      );
    });

    testWidgets('visible when checklist non-empty and status != done', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          TaskTile(
            task: withChecklist(
              status: TaskStatus.inProgress,
              total: 4,
              completed: 1,
            ),
            canChangeStatus: false,
          ),
        ),
      );
      expect(
        find.byKey(const Key('tasks.tile.task-1.progressBar')),
        findsOneWidget,
      );
    });

    testWidgets('hidden when status == done even with partial checklist', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          TaskTile(
            task: withChecklist(
              status: TaskStatus.done,
              total: 4,
              completed: 1,
            ),
            canChangeStatus: false,
          ),
        ),
      );
      expect(
        find.byKey(const Key('tasks.tile.task-1.progressBar')),
        findsNothing,
      );
    });

    testWidgets('width factor matches completed / total fraction', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          TaskTile(
            task: withChecklist(
              status: TaskStatus.inProgress,
              total: 4,
              completed: 1,
            ),
            canChangeStatus: false,
          ),
        ),
      );
      final sized = tester.widget<FractionallySizedBox>(
        find.descendant(
          of: find.byKey(const Key('tasks.tile.task-1.progressBar')),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(sized.widthFactor, closeTo(0.25, 1e-9));
    });

    testWidgets('renders X/Y count next to the bar (visible only with bar)', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          TaskTile(
            task: withChecklist(
              status: TaskStatus.inProgress,
              total: 5,
              completed: 3,
            ),
            canChangeStatus: false,
          ),
        ),
      );
      expect(find.text('3/5'), findsOneWidget);

      // Hidden when bar is hidden.
      await tester.pumpWidget(
        harness(
          TaskTile(
            task: withChecklist(
              status: TaskStatus.done,
              total: 5,
              completed: 3,
            ),
            canChangeStatus: false,
          ),
        ),
      );
      expect(find.text('3/5'), findsNothing);
    });
  });

  group('overdue badge', () {
    TaskModel withDue({
      required DateTime? dueDate,
      required TaskStatus status,
    }) => TaskModel(
      id: 'task-1',
      eventId: 'evt-1',
      title: 't',
      status: status,
      dueDate: dueDate,
    );

    Future<void> pumpAtFrozenNow(
      WidgetTester tester,
      Widget child,
      DateTime now,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(harness(child));
      });
    }

    testWidgets('hidden when dueDate is null', (tester) async {
      await pumpAtFrozenNow(
        tester,
        TaskTile(
          task: withDue(dueDate: null, status: TaskStatus.todo),
          canChangeStatus: false,
        ),
        DateTime(2026, 6, 15, 12, 0),
      );
      expect(
        find.byKey(const Key('tasks.tile.task-1.overdueBadge')),
        findsNothing,
      );
    });

    testWidgets('hidden when dueDate is today (same start-of-day)', (
      tester,
    ) async {
      // Frozen now late in the day; due date earlier the same day → NOT overdue.
      await pumpAtFrozenNow(
        tester,
        TaskTile(
          task: withDue(
            dueDate: DateTime(2026, 6, 15, 8, 0),
            status: TaskStatus.todo,
          ),
          canChangeStatus: false,
        ),
        DateTime(2026, 6, 15, 23, 30),
      );
      expect(
        find.byKey(const Key('tasks.tile.task-1.overdueBadge')),
        findsNothing,
      );
    });

    testWidgets('visible when dueDate is before today AND status != done', (
      tester,
    ) async {
      await pumpAtFrozenNow(
        tester,
        TaskTile(
          task: withDue(
            dueDate: DateTime(2026, 6, 14),
            status: TaskStatus.todo,
          ),
          canChangeStatus: false,
        ),
        DateTime(2026, 6, 15, 12, 0),
      );
      final chip = find.byKey(const Key('tasks.tile.task-1.overdueBadge'));
      expect(tester.widget<CpStatusChip>(chip).status, CpStatus.overdue);
      expect(
        find.descendant(of: chip, matching: find.byIcon(CpIcons.statusOverdue)),
        findsOneWidget,
      );
    });

    testWidgets('amber Due chip with a clock when due within the week', (
      tester,
    ) async {
      await pumpAtFrozenNow(
        tester,
        TaskTile(
          task: withDue(
            dueDate: DateTime(2026, 6, 18),
            status: TaskStatus.todo,
          ),
          canChangeStatus: false,
        ),
        DateTime(2026, 6, 15, 12, 0),
      );
      final chip = find.byKey(const Key('tasks.tile.task-1.due'));
      expect(tester.widget<CpStatusChip>(chip).status, CpStatus.due);
      expect(
        find.descendant(of: chip, matching: find.byIcon(CpIcons.statusDue)),
        findsOneWidget,
      );
      expect(find.text('Due Thu'), findsOneWidget);
    });

    testWidgets('hidden when status == done even if past due', (tester) async {
      await pumpAtFrozenNow(
        tester,
        TaskTile(
          task: withDue(
            dueDate: DateTime(2026, 6, 14),
            status: TaskStatus.done,
          ),
          canChangeStatus: false,
        ),
        DateTime(2026, 6, 15, 12, 0),
      );
      expect(
        find.byKey(const Key('tasks.tile.task-1.overdueBadge')),
        findsNothing,
      );
    });
  });

  group('priority pill', () {
    TaskModel withPriority(int priority) => TaskModel(
      id: 'task-1',
      eventId: 'evt-1',
      title: 't',
      priority: priority,
    );

    testWidgets('hidden when priority == 0', (tester) async {
      await tester.pumpWidget(
        harness(TaskTile(task: withPriority(0), canChangeStatus: false)),
      );
      expect(
        find.byKey(const Key('tasks.tile.task-1.priorityBadge')),
        findsNothing,
      );
    });

    testWidgets('visible with label for priority 1/2/3', (tester) async {
      for (final (level, label) in [(1, 'Low'), (2, 'Medium'), (3, 'High')]) {
        await tester.pumpWidget(
          harness(TaskTile(task: withPriority(level), canChangeStatus: false)),
        );
        expect(
          find.byKey(const Key('tasks.tile.task-1.priorityBadge')),
          findsOneWidget,
          reason: 'priority $level should show badge',
        );
        expect(find.text(label), findsOneWidget);
      }
    });
  });
}
