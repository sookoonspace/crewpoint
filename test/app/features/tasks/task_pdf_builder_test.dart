import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_pdf_builder.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

const _event = EventModel(
  id: 'evt-1',
  title: 'Trip',
  creatorId: 'u1',
  memberIds: ['u1', 'u2'],
);

void main() {
  test('produces a non-empty PDF byte buffer with the %PDF magic', () async {
    final bytes = await buildTaskReport(
      event: _event,
      tasks: const [],
      memberNames: const {},
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), equals('%PDF'));
  });

  group('groupTasksByStatus', () {
    test('groups tasks by status and preserves order within each bucket', () {
      const tasks = [
        TaskModel(
          id: 't1',
          eventId: 'evt-1',
          title: 'Pack snacks',
          status: TaskStatus.todo,
        ),
        TaskModel(
          id: 't2',
          eventId: 'evt-1',
          title: 'Book bus',
          status: TaskStatus.done,
        ),
        TaskModel(
          id: 't3',
          eventId: 'evt-1',
          title: 'Plan menu',
          status: TaskStatus.inProgress,
        ),
        TaskModel(
          id: 't4',
          eventId: 'evt-1',
          title: 'Send invites',
          status: TaskStatus.todo,
        ),
      ];

      final grouped = groupTasksByStatus(tasks);

      expect(grouped[TaskStatus.todo]!.map((t) => t.id), ['t1', 't4']);
      expect(grouped[TaskStatus.inProgress]!.map((t) => t.id), ['t3']);
      expect(grouped[TaskStatus.done]!.map((t) => t.id), ['t2']);
    });

    test('returns empty buckets when no tasks match a status', () {
      final grouped = groupTasksByStatus(const []);
      expect(grouped[TaskStatus.todo], isEmpty);
      expect(grouped[TaskStatus.inProgress], isEmpty);
      expect(grouped[TaskStatus.done], isEmpty);
    });
  });

  group('checklistProgressLabel', () {
    test('returns null when the task has no checklist', () {
      const task = TaskModel(id: 't1', eventId: 'evt-1', title: 'Solo');
      expect(checklistProgressLabel(task), isNull);
    });

    test('returns "done/total" when the task has checklist items', () {
      const task = TaskModel(
        id: 't1',
        eventId: 'evt-1',
        title: 'Pack',
        checklistItems: [
          ChecklistItem(id: 'c1', text: 'a', isCompleted: true),
          ChecklistItem(id: 'c2', text: 'b', isCompleted: false),
          ChecklistItem(id: 'c3', text: 'c', isCompleted: true),
        ],
      );
      expect(checklistProgressLabel(task), equals('2/3'));
    });
  });
}
