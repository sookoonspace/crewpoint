/// Pins the multi-line description prefix-icon fix from the
/// 2026-06-08 iPhone 12 mini UI QA pass (Create_task_screen_01.PNG).
/// Material's `InputDecorator` vertically centers `prefixIcon` in the
/// full multi-line height, so on a `maxLines: 3` field the icon ends
/// up below the placeholder — visibly disconnected.
///
/// The fix: don't pass a `prefixIcon` to the description AppTextField
/// (the single-line title field above keeps its icon). The shared
/// `AppTextField` is left untouched so other single-line callers stay
/// consistent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_text_field.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/create_task_screen.dart';

void main() {
  const event = EventModel(
    id: 'evt-1',
    title: 'Trip',
    creatorId: 'owner-1',
    memberIds: ['owner-1'],
    currency: 'USD',
  );

  testWidgets('multi-line description field has no prefixIcon — '
      'avoids the InputDecorator centring the icon below the placeholder', (
    tester,
  ) async {
    // Tall viewport so the full form lays out without scrolling and
    // the description field stays mounted for inspection.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CreateTaskScreen(event: event, currentUserId: 'owner-1'),
      ),
    );

    final descField = tester.widget<AppTextField>(
      find.byKey(const Key('tasks.create.description')),
    );
    expect(
      descField.prefixIcon,
      isNull,
      reason:
          'Description AppTextField (maxLines=3) must not pass a '
          'prefixIcon — Material centres it vertically across all 3 '
          'lines and the result looks orphaned next to the hint.',
    );
  });
}
