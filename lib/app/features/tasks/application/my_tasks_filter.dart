import 'package:clock/clock.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_assigned_tasks_provider.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Filter segments on the global Tasks tab.
///
/// `all` passes every row through; `todo`/`doing`/`done` map 1:1 to
/// [TaskStatus]. Single-select per [SegmentedFilterBar] semantics.
enum MyTasksSegment { all, todo, doing, done }

/// Session-local filter for `MyTasksScreen`. The Overdue toggle is
/// independent and intersects with whichever segment is active.
class MyTasksFilter {
  const MyTasksFilter({
    this.segment = MyTasksSegment.all,
    this.overdue = false,
  });

  final MyTasksSegment segment;
  final bool overdue;

  MyTasksFilter copyWith({MyTasksSegment? segment, bool? overdue}) {
    return MyTasksFilter(
      segment: segment ?? this.segment,
      overdue: overdue ?? this.overdue,
    );
  }

  /// Applies the segment + overdue predicate to [rows].
  ///
  /// Overdue means: task status is not `done` AND `dueDate` is before
  /// start-of-day `clock.now()`. Today's tasks are NOT overdue — the
  /// boundary flips at midnight, matching `TaskTile._isOverdue` at
  /// `task_tile.dart:51`.
  List<MyAssignedTaskRow> apply(List<MyAssignedTaskRow> rows) {
    final todayStart = _startOfDay(clock.now());
    bool matchesSegment(TaskStatus status) => switch (segment) {
      MyTasksSegment.all => true,
      MyTasksSegment.todo => status == TaskStatus.todo,
      MyTasksSegment.doing => status == TaskStatus.inProgress,
      MyTasksSegment.done => status == TaskStatus.done,
    };
    bool matchesOverdue(TaskModel task) {
      if (!overdue) return true;
      final due = task.dueDate;
      if (due == null) return false;
      if (task.status == TaskStatus.done) return false;
      return _startOfDay(due).isBefore(todayStart);
    }

    return [
      for (final row in rows)
        if (matchesSegment(row.task.status) && matchesOverdue(row.task)) row,
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MyTasksFilter &&
          segment == other.segment &&
          overdue == other.overdue);

  @override
  int get hashCode => Object.hash(segment, overdue);
}

DateTime _startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);
