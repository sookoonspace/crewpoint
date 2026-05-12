import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/edit_task_screen.dart';

void main() {
  const event = EventModel(
    id: 'evt-1',
    title: 'Trip',
    creatorId: 'owner-1',
    memberIds: ['owner-1', 'user-2'],
    currency: 'USD',
  );

  final initial = TaskModel(
    id: 'task-1',
    eventId: 'evt-1',
    title: 'Buy snacks',
    description: 'Chips + soda',
    assigneeId: 'user-2',
    createdBy: 'owner-1',
    dueDate: DateTime(2026, 7, 1),
    budgetEstimate: 25,
  );

  testWidgets('pre-fills title, description, assignee, due date, budget', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditTaskScreen(event: event, initial: initial),
      ),
    );

    final title = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('tasks.edit.title')),
        matching: find.byType(TextField),
      ),
    );
    expect(title.controller!.text, 'Buy snacks');

    final desc = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('tasks.edit.description')),
        matching: find.byType(TextField),
      ),
    );
    expect(desc.controller!.text, 'Chips + soda');

    final budget = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('tasks.edit.budget')),
        matching: find.byType(TextField),
      ),
    );
    expect(budget.controller!.text, '25.0');

    // Due date row renders the formatted date.
    expect(find.text('Jul 1, 2026'), findsOneWidget);
  });

  testWidgets('onSubmit emits updated TaskModel preserving id + eventId', (
    tester,
  ) async {
    // Tall viewport so the three AppFormSections + inline calendar +
    // save button all fit without scrolling — keeps the test focused on
    // the submit contract.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TaskModel? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: EditTaskScreen(
          event: event,
          initial: initial,
          onSubmit: (task) => submitted = task,
        ),
      ),
    );

    // Edit title.
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('tasks.edit.title')),
        matching: find.byType(TextField),
      ),
      'Buy snacks and ice',
    );
    await tester.tap(find.byKey(const Key('tasks.edit.save')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.id, 'task-1');
    expect(submitted!.eventId, 'evt-1');
    expect(submitted!.title, 'Buy snacks and ice');
    expect(submitted!.budgetEstimate, 25.0);
  });

  testWidgets('accepts past due-date (modal path) — firstDate=DateTime(2000)', (
    tester,
  ) async {
    // Narrow viewport → AppDateField uses the modal path.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: EditTaskScreen(
          event: event,
          initial: initial.copyWith(dueDate: DateTime(2010, 1, 1)),
        ),
      ),
    );

    // Tap the trigger row → modal picker opens (firstDate=2000 allows
    // the pre-filled past date).
    await tester.ensureVisible(find.byKey(const Key('tasks.edit.dueDate')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('forms.date.trigger')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'renders orphan assignee as disabled item when assigneeId left the event',
    (tester) async {
      const orphanEvent = EventModel(
        id: 'evt-1',
        title: 'Trip',
        creatorId: 'owner-1',
        memberIds: ['owner-1'], // user-2 left
        currency: 'USD',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditTaskScreen(
            event: orphanEvent,
            initial: initial,
            displayNames: const {'user-2': 'Casey'},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('tasks.create.assignee')));
      await tester.pumpAndSettle();

      expect(find.text('Casey (no longer in event)'), findsWidgets);
    },
  );
}
