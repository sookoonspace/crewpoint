import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/tasks/application/tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

void main() {
  group('startOfDay', () {
    test('zeroes the time component', () {
      final input = DateTime.utc(2026, 6, 15, 14, 37, 22, 451);
      final result = startOfDay(input);
      expect(result.year, 2026);
      expect(result.month, 6);
      expect(result.day, 15);
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
    });

    test('same-day midnight is identity', () {
      final mid = DateTime(2026, 6, 15);
      expect(startOfDay(mid), mid);
    });
  });

  group('TasksFilter', () {
    test('defaults: empty/false predicates, sort=dueDate, groupBy=status', () {
      const f = TasksFilter();
      expect(f.statuses, isEmpty);
      expect(f.onlyMine, isFalse);
      expect(f.onlyOverdue, isFalse);
      expect(f.onlyWithBudget, isFalse);
      expect(f.query, '');
      expect(f.sortKey, TasksSortKey.dueDate);
      expect(f.groupBy, TasksGroupBy.status);
      expect(f.hasActiveFilters, isFalse);
    });

    test('hasActiveFilters reports true when any predicate non-default', () {
      const base = TasksFilter();
      expect(base.copyWith(onlyMine: true).hasActiveFilters, isTrue);
      expect(base.copyWith(onlyOverdue: true).hasActiveFilters, isTrue);
      expect(base.copyWith(onlyWithBudget: true).hasActiveFilters, isTrue);
      expect(base.copyWith(query: 'lunch').hasActiveFilters, isTrue);
      expect(
        base.copyWith(statuses: const {TaskStatus.todo}).hasActiveFilters,
        isTrue,
      );

      // Sort + group changes alone don't count.
      expect(
        base.copyWith(sortKey: TasksSortKey.priority).hasActiveFilters,
        isFalse,
      );
      expect(
        base.copyWith(groupBy: TasksGroupBy.assignee).hasActiveFilters,
        isFalse,
      );
    });

    test('copyWith preserves other fields + equality / hashCode', () {
      const a = TasksFilter(onlyMine: true, query: 'lunch');
      final b = a.copyWith();
      expect(b, a);
      expect(b.hashCode, a.hashCode);

      final c = a.copyWith(query: 'dinner');
      expect(c, isNot(a));
      expect(c.onlyMine, isTrue);
      expect(c.query, 'dinner');
    });
  });

  group('applyTasksFilter', () {
    // Anchor "now" for all overdue / due-window predicates.
    final now = DateTime(2026, 6, 15, 12, 0); // mid-day on 2026-06-15.

    TaskModel task({
      required String id,
      String title = 't',
      String? description,
      TaskStatus status = TaskStatus.todo,
      String? assigneeId,
      DateTime? dueDate,
      double? budgetEstimate,
      int priority = 0,
    }) => TaskModel(
      id: id,
      eventId: 'evt-1',
      title: title,
      description: description,
      status: status,
      assigneeId: assigneeId,
      dueDate: dueDate,
      budgetEstimate: budgetEstimate,
      priority: priority,
    );

    test('statuses predicate keeps only matching statuses', () {
      final tasks = [
        task(id: 'a', status: TaskStatus.todo),
        task(id: 'b', status: TaskStatus.inProgress),
        task(id: 'c', status: TaskStatus.done),
      ];
      const f = TasksFilter(statuses: {TaskStatus.inProgress, TaskStatus.done});
      final result = applyTasksFilter(tasks, f, currentUserId: 'me', now: now);
      expect(result.map((t) => t.id), ['b', 'c']);
    });

    test('onlyMine predicate keeps assigneeId == currentUserId', () {
      final tasks = [
        task(id: 'a', assigneeId: 'me'),
        task(id: 'b', assigneeId: 'other'),
        task(id: 'c'), // unassigned
      ];
      const f = TasksFilter(onlyMine: true);
      final result = applyTasksFilter(tasks, f, currentUserId: 'me', now: now);
      expect(result.map((t) => t.id), ['a']);
    });

    test('onlyOverdue uses startOfDay and excludes done', () {
      final tasks = [
        task(
          id: 'overdue-todo',
          dueDate: DateTime(2026, 6, 14),
          status: TaskStatus.todo,
        ),
        task(
          id: 'overdue-done',
          dueDate: DateTime(2026, 6, 14),
          status: TaskStatus.done,
        ),
        task(
          id: 'same-day',
          dueDate: DateTime(2026, 6, 15, 23, 59),
          status: TaskStatus.todo,
        ),
        task(id: 'no-due', status: TaskStatus.todo),
      ];
      const f = TasksFilter(onlyOverdue: true);
      final result = applyTasksFilter(tasks, f, currentUserId: 'me', now: now);
      expect(result.map((t) => t.id), ['overdue-todo']);
    });

    test('onlyWithBudget keeps only non-null budgetEstimate (zero counts)', () {
      final tasks = [
        task(id: 'a', budgetEstimate: 25),
        task(id: 'b', budgetEstimate: 0),
        task(id: 'c'), // null
      ];
      const f = TasksFilter(onlyWithBudget: true);
      final result = applyTasksFilter(tasks, f, currentUserId: 'me', now: now);
      expect(result.map((t) => t.id), ['a', 'b']);
    });

    test(
      'query is case-insensitive + trimmed + matches title OR description',
      () {
        final tasks = [
          task(id: 'a', title: 'Buy LUNCH for everyone'),
          task(id: 'b', title: 'Dinner plans', description: 'Italian lunch?'),
          task(id: 'c', title: 'Breakfast'),
        ];
        const f = TasksFilter(query: '  lunch  ');
        final result = applyTasksFilter(
          tasks,
          f,
          currentUserId: 'me',
          now: now,
        );
        expect(result.map((t) => t.id), ['a', 'b']);
      },
    );

    test('composes multiple predicates (statuses + onlyMine + query)', () {
      final tasks = [
        task(
          id: 'match',
          title: 'Buy snacks',
          status: TaskStatus.todo,
          assigneeId: 'me',
        ),
        task(
          id: 'wrong-status',
          title: 'Buy snacks',
          status: TaskStatus.done,
          assigneeId: 'me',
        ),
        task(
          id: 'wrong-assignee',
          title: 'Buy snacks',
          status: TaskStatus.todo,
          assigneeId: 'other',
        ),
        task(
          id: 'wrong-query',
          title: 'Dinner',
          status: TaskStatus.todo,
          assigneeId: 'me',
        ),
      ];
      const f = TasksFilter(
        statuses: {TaskStatus.todo},
        onlyMine: true,
        query: 'snacks',
      );
      final result = applyTasksFilter(tasks, f, currentUserId: 'me', now: now);
      expect(result.map((t) => t.id), ['match']);
    });

    test('handles null fields without throwing', () {
      final tasks = [
        task(id: 'a'), // all nullable fields null
      ];
      const f = TasksFilter(
        onlyMine: true,
        onlyOverdue: true,
        onlyWithBudget: true,
        query: 'x',
      );
      expect(
        () => applyTasksFilter(tasks, f, currentUserId: 'me', now: now),
        returnsNormally,
      );
    });

    test('sort dueDate ascending; nulls last; ties broken by id asc', () {
      final tasks = [
        task(id: 'z', dueDate: DateTime(2026, 6, 20)),
        task(id: 'a', dueDate: DateTime(2026, 6, 20)), // same due, id asc
        task(id: 'b'), // null due — sorts last
        task(id: 'c', dueDate: DateTime(2026, 6, 10)),
      ];
      const f = TasksFilter(); // sortKey: dueDate
      final result = applyTasksFilter(tasks, f, currentUserId: 'me', now: now);
      expect(result.map((t) => t.id), ['c', 'a', 'z', 'b']);
    });

    test('sort priority descending (High → None); ties by id asc', () {
      final tasks = [
        task(id: 'z', priority: 1),
        task(id: 'a', priority: 3),
        task(id: 'b', priority: 1),
        task(id: 'c', priority: 0),
      ];
      const f = TasksFilter(sortKey: TasksSortKey.priority);
      final result = applyTasksFilter(tasks, f, currentUserId: 'me', now: now);
      expect(result.map((t) => t.id), ['a', 'b', 'z', 'c']);
    });

    test('sort title ascending case-insensitive', () {
      final tasks = [
        task(id: 'a', title: 'banana'),
        task(id: 'b', title: 'Apple'),
        task(id: 'c', title: 'cherry'),
      ];
      const f = TasksFilter(sortKey: TasksSortKey.title);
      final result = applyTasksFilter(tasks, f, currentUserId: 'me', now: now);
      expect(result.map((t) => t.id), ['b', 'a', 'c']);
    });

    test('stable: identical input ⇒ identical output ordering', () {
      final tasks = [
        task(id: 'a', dueDate: DateTime(2026, 6, 20)),
        task(id: 'b', dueDate: DateTime(2026, 6, 10)),
        task(id: 'c', dueDate: DateTime(2026, 6, 15)),
      ];
      const f = TasksFilter();
      final r1 = applyTasksFilter(tasks, f, currentUserId: 'me', now: now);
      final r2 = applyTasksFilter(tasks, f, currentUserId: 'me', now: now);
      expect(r1.map((t) => t.id), r2.map((t) => t.id));
    });

    test(
      'overdue predicate flips at start-of-day, not at the dueDate time',
      () {
        final t = task(
          id: 'sameday',
          dueDate: DateTime(2026, 6, 15, 9, 0),
          status: TaskStatus.todo,
        );
        const f = TasksFilter(onlyOverdue: true);

        // Same day at 02:00 — NOT overdue (start-of-day is identical).
        var result = applyTasksFilter(
          [t],
          f,
          currentUserId: 'me',
          now: DateTime(2026, 6, 15, 2, 0),
        );
        expect(result, isEmpty);

        // Same day at 23:00 — still NOT overdue.
        result = applyTasksFilter(
          [t],
          f,
          currentUserId: 'me',
          now: DateTime(2026, 6, 15, 23, 0),
        );
        expect(result, isEmpty);

        // Next day at any time — IS overdue.
        result = applyTasksFilter(
          [t],
          f,
          currentUserId: 'me',
          now: DateTime(2026, 6, 16, 0, 1),
        );
        expect(result.map((t) => t.id), ['sameday']);
      },
    );
  });

  group('groupTasks', () {
    final now = DateTime(2026, 6, 15, 12, 0);

    TaskModel task({
      required String id,
      TaskStatus status = TaskStatus.todo,
      String? assigneeId,
      DateTime? dueDate,
    }) => TaskModel(
      id: id,
      eventId: 'evt-1',
      title: 't-$id',
      status: status,
      assigneeId: assigneeId,
      dueDate: dueDate,
    );

    test(
      'status: groups in order Todo / In Progress / Done; empty omitted',
      () {
        final tasks = [
          task(id: 'd', status: TaskStatus.done),
          task(id: 'a', status: TaskStatus.todo),
          task(id: 'p', status: TaskStatus.inProgress),
        ];
        final groups = groupTasks(
          tasks,
          TasksGroupBy.status,
          now: now,
          assigneeNames: const {},
        );
        expect(groups.map((g) => g.key), ['todo', 'inProgress', 'done']);
        expect(groups.map((g) => g.tasks.length), [1, 1, 1]);

        // Drop one bucket → empty omitted.
        final without = tasks
            .where((t) => t.status != TaskStatus.done)
            .toList();
        final groups2 = groupTasks(
          without,
          TasksGroupBy.status,
          now: now,
          assigneeNames: const {},
        );
        expect(groups2.map((g) => g.key), ['todo', 'inProgress']);
      },
    );

    test(
      'assignee: groups by assigneeId; Unassigned bucket last; orphan name fallback',
      () {
        final tasks = [
          task(id: 'a', assigneeId: 'alice'),
          task(id: 'b', assigneeId: 'bob'),
          task(id: 'c'), // unassigned
          task(id: 'd', assigneeId: 'orphan-uid'),
        ];
        final groups = groupTasks(
          tasks,
          TasksGroupBy.assignee,
          now: now,
          assigneeNames: const {'alice': 'Alice', 'bob': 'Bob'},
        );

        // Alice + Bob + orphan-uid + Unassigned (last).
        expect(groups.length, 4);
        expect(groups.last.key, 'unassigned');
        expect(groups.last.tasks.single.id, 'c');

        final labels = groups.map((g) => g.label).toList();
        expect(labels.contains('Alice'), isTrue);
        expect(labels.contains('Bob'), isTrue);
        // Orphan UID falls back to a truncated UID label.
        expect(labels.any((l) => l.startsWith('orphan-u')), isTrue);
      },
    );

    test(
      'dueWindow: Overdue / Today / This week / Later / No due date in that order',
      () {
        final tasks = [
          task(id: 'overdue', dueDate: DateTime(2026, 6, 10)),
          task(id: 'today', dueDate: DateTime(2026, 6, 15, 20)),
          task(id: 'thisweek', dueDate: DateTime(2026, 6, 18)),
          task(id: 'later', dueDate: DateTime(2026, 7, 1)),
          task(id: 'none'),
        ];
        final groups = groupTasks(
          tasks,
          TasksGroupBy.dueWindow,
          now: now,
          assigneeNames: const {},
        );
        expect(groups.map((g) => g.key), [
          'overdue',
          'today',
          'thisweek',
          'later',
          'noDueDate',
        ]);
        expect(groups.map((g) => g.tasks.single.id), [
          'overdue',
          'today',
          'thisweek',
          'later',
          'none',
        ]);
      },
    );

    test('dueWindow: empty buckets omitted', () {
      final tasks = [
        task(id: 'a', dueDate: DateTime(2026, 6, 10)), // overdue
        task(id: 'b'), // none
      ];
      final groups = groupTasks(
        tasks,
        TasksGroupBy.dueWindow,
        now: now,
        assigneeNames: const {},
      );
      expect(groups.map((g) => g.key), ['overdue', 'noDueDate']);
    });
  });
}
