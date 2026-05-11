import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/task_detail_screen.dart';

void main() {
  const event = EventModel(
    id: 'evt-1',
    title: 'Trip',
    creatorId: 'owner-1',
    memberIds: ['owner-1', 'user-2'],
  );

  const task = TaskModel(
    id: 'task-1',
    eventId: 'evt-1',
    title: 'Buy snacks',
    createdBy: 'owner-1',
    assigneeId: 'user-2',
  );

  testWidgets(
    'non-authorized user sees no delete affordance and no add field',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TaskDetailScreen(
            task: task,
            event: event,
            checklist: [],
            canEditTask: false,
            canChangeStatus: false,
          ),
        ),
      );

      expect(find.byKey(const Key('tasks.detail.delete')), findsNothing);
      expect(find.byKey(const Key('tasks.detail.checklist.add')), findsNothing);
    },
  );

  testWidgets('creator sees delete button + add-checklist field', (
    tester,
  ) async {
    var deletePressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailScreen(
          task: task,
          event: event,
          checklist: const [],
          canEditTask: true,
          canChangeStatus: true,
          onDelete: () => deletePressed = true,
          onChecklistAdd: (_, _) {},
        ),
      ),
    );

    expect(find.byKey(const Key('tasks.detail.delete')), findsOneWidget);
    expect(find.byKey(const Key('tasks.detail.checklist.add')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tasks.detail.delete')));
    await tester.pump();
    expect(deletePressed, isTrue);
  });

  testWidgets('shows "no longer in event" when assignee is removed', (
    tester,
  ) async {
    const evtWithoutAssignee = EventModel(
      id: 'evt-1',
      title: 'Trip',
      creatorId: 'owner-1',
      memberIds: ['owner-1'], // user-2 removed
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: TaskDetailScreen(
          task: task,
          event: evtWithoutAssignee,
          checklist: [],
          canEditTask: true,
          canChangeStatus: true,
        ),
      ),
    );

    expect(find.text('(no longer in event)'), findsOneWidget);
  });

  testWidgets('renders passed assigneeName when present', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TaskDetailScreen(
          task: task,
          event: event,
          checklist: [],
          canEditTask: true,
          canChangeStatus: true,
          assigneeName: 'Bo Lyons',
        ),
      ),
    );
    expect(find.text('Assigned to Bo Lyons'), findsOneWidget);
  });

  testWidgets('falls back to truncated UID when assigneeName is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TaskDetailScreen(
          task: task,
          event: event,
          checklist: [],
          canEditTask: true,
          canChangeStatus: true,
        ),
      ),
    );
    expect(find.text('Assigned to user-2'), findsOneWidget);
  });

  testWidgets('pencil edit action visible only when canEditTask is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TaskDetailScreen(
          task: task,
          event: event,
          checklist: [],
          canEditTask: false,
          canChangeStatus: false,
        ),
      ),
    );
    expect(find.byKey(const Key('tasks.detail.edit')), findsNothing);

    var editPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailScreen(
          task: task,
          event: event,
          checklist: const [],
          canEditTask: true,
          canChangeStatus: true,
          onEdit: () => editPressed = true,
        ),
      ),
    );
    expect(find.byKey(const Key('tasks.detail.edit')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tasks.detail.edit')));
    await tester.pump();
    expect(editPressed, isTrue);
  });

  testWidgets('pending writes indicator renders only when flag is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TaskDetailScreen(
          task: task,
          event: event,
          checklist: [],
          canEditTask: true,
          canChangeStatus: true,
          hasPendingWrites: true,
        ),
      ),
    );
    expect(find.text('Will sync when online'), findsOneWidget);
  });
}
