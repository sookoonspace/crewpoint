/// The Create Task form in the Person form's pattern (Spec #186): no icon
/// floating beside the multi-line description, the save button in a bar
/// of its own at the bottom, and the budget figure only for `budget.edit`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/create_task_screen.dart';

void main() {
  const event = EventModel(
    id: 'evt-1',
    title: 'Trip',
    creatorId: 'owner-1',
    memberIds: ['owner-1'],
    currency: 'USD',
  );

  testWidgets('the multi-line description has no prefix icon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CreateTaskScreen(event: event, currentUserId: 'owner-1'),
      ),
    );

    final descField = tester.widget<CpTextField>(
      find.byKey(const Key('tasks.create.description')),
    );
    expect(descField.prefixIcon, isNull);
    expect(descField.maxLines, 3);
  });

  testWidgets('the save button sits in the bottom bar, clear of the form', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CreateTaskScreen(event: event, currentUserId: 'owner-1'),
      ),
    );

    final bar = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(bar.bottomNavigationBar, isNotNull);
    expect(
      find.descendant(
        of: find.byWidget(bar.bottomNavigationBar!),
        matching: find.byKey(const Key('tasks.create.save')),
      ),
      findsOneWidget,
    );    // Only as tall as its button, never covering the form.
    expect(
      tester.getSize(find.byWidget(bar.bottomNavigationBar!)).height,
      lessThan(120),
    );
  });

  group('budget figure (Req 36)', () {
    const shared = EventModel(
      id: 'evt-1',
      title: 'Trip',
      creatorId: 'owner-1',
      memberIds: ['owner-1', 'user-2'],
      currency: 'USD',
    );

    /// Opens the form as [as] and saves it, returning what was submitted.
    Future<TaskModel?> save(
      WidgetTester tester, {
      required String as,
      TaskModel? initial,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TaskModel? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: CreateTaskScreen(
            event: shared,
            currentUserId: as,
            initial: initial,
            onSubmit: (task) => submitted = task,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('tasks.create.save')));
      await tester.pumpAndSettle();
      return submitted;
    }

    const copy = TaskModel(
      id: 'copy',
      eventId: 'evt-1',
      title: 'Caterer',
      createdBy: 'owner-1',
      budgetEstimate: 40,
    );

    testWidgets('with budget.edit, the field shows and the figure is kept', (
      tester,
    ) async {
      final submitted = await save(tester, as: 'owner-1', initial: copy);
      expect(find.byKey(const Key('tasks.create.budget')), findsOneWidget);
      expect(submitted?.budgetEstimate, 40);
    });

    testWidgets('without it, the field is hidden and a copied figure dropped', (
      tester,
    ) async {
      final submitted = await save(tester, as: 'user-2', initial: copy);
      expect(find.byKey(const Key('tasks.create.budget')), findsNothing);
      expect(submitted, isNotNull);
      expect(submitted!.budgetEstimate, isNull);
    });
  });
}
