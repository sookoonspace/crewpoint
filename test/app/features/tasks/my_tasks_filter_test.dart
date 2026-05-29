import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_assigned_tasks_provider.dart';
import 'package:crewpoint_app/app/features/tasks/application/my_tasks_filter.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

void main() {
  const event = EventModel(
    id: 'evt',
    title: 'E',
    creatorId: 'me',
    memberIds: ['me'],
  );
  MyAssignedTaskRow row(
    String id, {
    required TaskStatus status,
    DateTime? dueDate,
  }) {
    return MyAssignedTaskRow(
      event: event,
      task: TaskModel(
        id: id,
        eventId: event.id,
        title: 'T-$id',
        status: status,
        dueDate: dueDate,
      ),
    );
  }

  test('All segment without overdue toggle returns every row in order', () {
    final rows = [
      row('1', status: TaskStatus.todo),
      row('2', status: TaskStatus.inProgress),
      row('3', status: TaskStatus.done),
    ];
    const filter = MyTasksFilter(segment: MyTasksSegment.all);
    expect(filter.apply(rows).map((r) => r.task.id), ['1', '2', '3']);
  });

  test('Todo segment keeps only TaskStatus.todo rows', () {
    final rows = [
      row('1', status: TaskStatus.todo),
      row('2', status: TaskStatus.inProgress),
      row('3', status: TaskStatus.done),
    ];
    const filter = MyTasksFilter(segment: MyTasksSegment.todo);
    expect(filter.apply(rows).map((r) => r.task.id), ['1']);
  });

  test('Doing segment keeps only TaskStatus.inProgress rows', () {
    final rows = [
      row('1', status: TaskStatus.todo),
      row('2', status: TaskStatus.inProgress),
      row('3', status: TaskStatus.done),
    ];
    const filter = MyTasksFilter(segment: MyTasksSegment.doing);
    expect(filter.apply(rows).map((r) => r.task.id), ['2']);
  });

  test('Done segment keeps only TaskStatus.done rows', () {
    final rows = [
      row('1', status: TaskStatus.todo),
      row('2', status: TaskStatus.inProgress),
      row('3', status: TaskStatus.done),
    ];
    const filter = MyTasksFilter(segment: MyTasksSegment.done);
    expect(filter.apply(rows).map((r) => r.task.id), ['3']);
  });

  test('Overdue toggle keeps only past-due todos / inProgress rows', () {
    final now = DateTime(2026, 5, 17, 12);
    final rows = [
      row('past-todo', status: TaskStatus.todo, dueDate: DateTime(2026, 5, 10)),
      row(
        'past-doing',
        status: TaskStatus.inProgress,
        dueDate: DateTime(2026, 5, 10),
      ),
      row('past-done', status: TaskStatus.done, dueDate: DateTime(2026, 5, 10)),
      row('today', status: TaskStatus.todo, dueDate: DateTime(2026, 5, 17)),
      row('future', status: TaskStatus.todo, dueDate: DateTime(2026, 6, 1)),
      row('nodue', status: TaskStatus.todo),
    ];
    const filter = MyTasksFilter(segment: MyTasksSegment.all, overdue: true);
    withClock(Clock.fixed(now), () {
      expect(filter.apply(rows).map((r) => r.task.id), [
        'past-todo',
        'past-doing',
      ]);
    });
  });

  test('Overdue toggle intersects with the active segment', () {
    final now = DateTime(2026, 5, 17, 12);
    final rows = [
      row('past-todo', status: TaskStatus.todo, dueDate: DateTime(2026, 5, 10)),
      row(
        'past-doing',
        status: TaskStatus.inProgress,
        dueDate: DateTime(2026, 5, 10),
      ),
    ];
    // Doing + Overdue → only inProgress past-due rows survive.
    const filter = MyTasksFilter(segment: MyTasksSegment.doing, overdue: true);
    withClock(Clock.fixed(now), () {
      expect(filter.apply(rows).map((r) => r.task.id), ['past-doing']);
    });
  });

  test('copyWith preserves untouched fields', () {
    const filter = MyTasksFilter(segment: MyTasksSegment.todo, overdue: true);
    expect(
      filter.copyWith(segment: MyTasksSegment.done),
      const MyTasksFilter(segment: MyTasksSegment.done, overdue: true),
    );
    expect(
      filter.copyWith(overdue: false),
      const MyTasksFilter(segment: MyTasksSegment.todo, overdue: false),
    );
  });
}
