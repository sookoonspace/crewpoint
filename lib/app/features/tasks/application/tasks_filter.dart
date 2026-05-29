/// `TasksFilter` + supporting types + pure functions that drive the
/// Tasks screen's search, filter, sort, and grouping behaviour.
///
/// Everything in this file is `clock`-aware (via the `now:` parameter on
/// the pure functions) and free of Riverpod / Flutter dependencies so it
/// stays trivially unit-testable.
library;

import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Returns midnight on `d`'s local-time date. Used so the "overdue"
/// predicate and the due-window grouping flip at start-of-day, not at
/// the dueDate's hh:mm:ss component.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Sort direction is fixed per key (V1 — no user toggle):
/// `dueDate` ascending (nulls last), `priority` descending,
/// `created` descending (newest first), `title` ascending.
enum TasksSortKey { dueDate, priority, created, title }

/// Grouping presentation: status (default), assignee, or due-window
/// (Overdue / Today / This week / Later / No due date).
enum TasksGroupBy { status, assignee, dueWindow }

/// User-driven Tasks-screen state. Session-only (not persisted in V1).
class TasksFilter {
  const TasksFilter({
    this.statuses = const {},
    this.onlyMine = false,
    this.onlyOverdue = false,
    this.onlyWithBudget = false,
    this.query = '',
    this.sortKey = TasksSortKey.dueDate,
    this.groupBy = TasksGroupBy.status,
  });

  final Set<TaskStatus> statuses;
  final bool onlyMine;
  final bool onlyOverdue;
  final bool onlyWithBudget;
  final String query;
  final TasksSortKey sortKey;
  final TasksGroupBy groupBy;

  /// True when any *predicate* (not sort/group) is non-default — used to
  /// switch between the "No tasks yet" and "No tasks match this filter"
  /// empty states.
  bool get hasActiveFilters =>
      statuses.isNotEmpty ||
      onlyMine ||
      onlyOverdue ||
      onlyWithBudget ||
      query.isNotEmpty;

  TasksFilter copyWith({
    Set<TaskStatus>? statuses,
    bool? onlyMine,
    bool? onlyOverdue,
    bool? onlyWithBudget,
    String? query,
    TasksSortKey? sortKey,
    TasksGroupBy? groupBy,
  }) {
    return TasksFilter(
      statuses: statuses ?? this.statuses,
      onlyMine: onlyMine ?? this.onlyMine,
      onlyOverdue: onlyOverdue ?? this.onlyOverdue,
      onlyWithBudget: onlyWithBudget ?? this.onlyWithBudget,
      query: query ?? this.query,
      sortKey: sortKey ?? this.sortKey,
      groupBy: groupBy ?? this.groupBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TasksFilter &&
        _setEquals(other.statuses, statuses) &&
        other.onlyMine == onlyMine &&
        other.onlyOverdue == onlyOverdue &&
        other.onlyWithBudget == onlyWithBudget &&
        other.query == query &&
        other.sortKey == sortKey &&
        other.groupBy == groupBy;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(statuses),
    onlyMine,
    onlyOverdue,
    onlyWithBudget,
    query,
    sortKey,
    groupBy,
  );
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  for (final x in a) {
    if (!b.contains(x)) return false;
  }
  return true;
}

/// Pure: filter → sort. Direction per `TasksSortKey` is fixed (V1 — no
/// user toggle). Time-aware predicates use the supplied `now` so tests
/// can drive `withClock(Clock.fixed(...))` deterministically.
List<TaskModel> applyTasksFilter(
  List<TaskModel> tasks,
  TasksFilter filter, {
  required String currentUserId,
  required DateTime now,
}) {
  final today = startOfDay(now);
  final trimmedQuery = filter.query.trim().toLowerCase();

  final filtered = tasks.where((t) {
    if (filter.statuses.isNotEmpty && !filter.statuses.contains(t.status)) {
      return false;
    }
    if (filter.onlyMine && t.assigneeId != currentUserId) return false;
    if (filter.onlyOverdue) {
      final due = t.dueDate;
      if (due == null) return false;
      if (!startOfDay(due).isBefore(today)) return false;
      if (t.status == TaskStatus.done) return false;
    }
    if (filter.onlyWithBudget && t.budgetEstimate == null) return false;
    if (trimmedQuery.isNotEmpty) {
      final inTitle = t.title.toLowerCase().contains(trimmedQuery);
      final inDesc = (t.description ?? '').toLowerCase().contains(trimmedQuery);
      if (!inTitle && !inDesc) return false;
    }
    return true;
  }).toList();

  filtered.sort((a, b) => _compare(a, b, filter.sortKey));
  return filtered;
}

/// A grouped slice of the task list, paired with a display label + stable
/// key for the group header.
class TasksGroup {
  const TasksGroup({
    required this.key,
    required this.label,
    required this.tasks,
  });

  /// Stable machine key (`'todo'`, `'inProgress'`, `'done'`, `'unassigned'`,
  /// `'overdue'`, `'today'`, `'thisweek'`, `'later'`, `'noDueDate'`, or a
  /// raw `assigneeId` for the assignee grouping). Used for widget Keys
  /// like `tasks.list.groupHeader.<key>`.
  final String key;

  /// Human-facing label rendered in the group header.
  final String label;

  final List<TaskModel> tasks;
}

/// Pure: bucket the (already-filtered, already-sorted) task list into
/// groups for presentation. Empty buckets are omitted; group order matches
/// the spec.
List<TasksGroup> groupTasks(
  List<TaskModel> tasks,
  TasksGroupBy groupBy, {
  required DateTime now,
  required Map<String, String> assigneeNames,
}) {
  switch (groupBy) {
    case TasksGroupBy.status:
      return _groupByStatus(tasks);
    case TasksGroupBy.assignee:
      return _groupByAssignee(tasks, assigneeNames);
    case TasksGroupBy.dueWindow:
      return _groupByDueWindow(tasks, now);
  }
}

List<TasksGroup> _groupByStatus(List<TaskModel> tasks) {
  const order = [TaskStatus.todo, TaskStatus.inProgress, TaskStatus.done];
  const keys = ['todo', 'inProgress', 'done'];
  const labels = ['To Do', 'In Progress', 'Done'];

  final groups = <TasksGroup>[];
  for (var i = 0; i < order.length; i++) {
    final bucket = tasks.where((t) => t.status == order[i]).toList();
    if (bucket.isEmpty) continue;
    groups.add(TasksGroup(key: keys[i], label: labels[i], tasks: bucket));
  }
  return groups;
}

List<TasksGroup> _groupByAssignee(
  List<TaskModel> tasks,
  Map<String, String> assigneeNames,
) {
  // Preserve incoming sort order within each bucket by walking the list
  // once and appending each task to its bucket.
  final buckets = <String, List<TaskModel>>{};
  final order = <String>[]; // bucket-insertion order
  final unassigned = <TaskModel>[];

  for (final t in tasks) {
    final uid = t.assigneeId;
    if (uid == null) {
      unassigned.add(t);
      continue;
    }
    if (!buckets.containsKey(uid)) {
      buckets[uid] = [];
      order.add(uid);
    }
    buckets[uid]!.add(t);
  }

  final groups = <TasksGroup>[];
  for (final uid in order) {
    final name = assigneeNames[uid];
    final label = (name != null && name.isNotEmpty)
        ? name
        : (uid.length > 8 ? '${uid.substring(0, 8)}…' : uid);
    groups.add(TasksGroup(key: uid, label: label, tasks: buckets[uid]!));
  }
  if (unassigned.isNotEmpty) {
    groups.add(
      TasksGroup(key: 'unassigned', label: 'Unassigned', tasks: unassigned),
    );
  }
  return groups;
}

List<TasksGroup> _groupByDueWindow(List<TaskModel> tasks, DateTime now) {
  final today = startOfDay(now);
  final weekEnd = today.add(const Duration(days: 7));

  final overdue = <TaskModel>[];
  final todayBucket = <TaskModel>[];
  final thisWeek = <TaskModel>[];
  final later = <TaskModel>[];
  final none = <TaskModel>[];

  for (final t in tasks) {
    final due = t.dueDate;
    if (due == null) {
      none.add(t);
      continue;
    }
    final d = startOfDay(due);
    if (d.isBefore(today)) {
      overdue.add(t);
    } else if (d.isAtSameMomentAs(today)) {
      todayBucket.add(t);
    } else if (d.isBefore(weekEnd.add(const Duration(days: 1)))) {
      thisWeek.add(t);
    } else {
      later.add(t);
    }
  }

  final groups = <TasksGroup>[];
  void addIf(String key, String label, List<TaskModel> bucket) {
    if (bucket.isNotEmpty) {
      groups.add(TasksGroup(key: key, label: label, tasks: bucket));
    }
  }

  addIf('overdue', 'Overdue', overdue);
  addIf('today', 'Today', todayBucket);
  addIf('thisweek', 'This week', thisWeek);
  addIf('later', 'Later', later);
  addIf('noDueDate', 'No due date', none);
  return groups;
}

int _compare(TaskModel a, TaskModel b, TasksSortKey key) {
  int byId() => a.id.compareTo(b.id); // stable tie-break

  switch (key) {
    case TasksSortKey.dueDate:
      final aDue = a.dueDate;
      final bDue = b.dueDate;
      if (aDue == null && bDue == null) return byId();
      if (aDue == null) return 1; // nulls last
      if (bDue == null) return -1;
      final cmp = aDue.compareTo(bDue);
      return cmp != 0 ? cmp : byId();
    case TasksSortKey.priority:
      final cmp = b.priority.compareTo(a.priority); // descending
      return cmp != 0 ? cmp : byId();
    case TasksSortKey.created:
      // No createdAt on TaskModel today — use id as a proxy for
      // deterministic ordering. When `created` becomes meaningful
      // (server timestamp wired through), revisit.
      return byId();
    case TasksSortKey.title:
      final cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return cmp != 0 ? cmp : byId();
  }
}
