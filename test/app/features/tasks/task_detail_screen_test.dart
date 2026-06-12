import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/theme/app_theme.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/task_detail_screen.dart';

import '../../core/_helpers/wcag_contrast.dart';

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

      expect(find.byKey(const Key('tasks.detail.overflow')), findsNothing);
      expect(find.byKey(const Key('tasks.detail.checklist.add')), findsNothing);
    },
  );

  testWidgets(
    'creator: overflow menu shows Edit + Delete; tapping Delete fires callback',
    (tester) async {
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

      expect(find.byKey(const Key('tasks.detail.overflow')), findsOneWidget);
      expect(
        find.byKey(const Key('tasks.detail.checklist.add')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('tasks.detail.overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tasks.detail.overflow.delete')));
      await tester.pumpAndSettle();
      expect(deletePressed, isTrue);
    },
  );

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

  testWidgets('renders passed completedByName instead of truncated UID', (
    tester,
  ) async {
    final completedTask = TaskModel(
      id: 'task-1',
      eventId: 'evt-1',
      title: 'Buy snacks',
      createdBy: 'owner-1',
      assigneeId: 'user-2',
      status: TaskStatus.done,
      completedAt: DateTime(2026, 7, 4),
      completedBy: 'user-2',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailScreen(
          task: completedTask,
          event: event,
          checklist: const [],
          canEditTask: false,
          canChangeStatus: false,
          completedByName: 'Bo Lyons',
        ),
      ),
    );

    expect(find.textContaining('by Bo Lyons'), findsOneWidget);
    expect(find.textContaining('by user-2'), findsNothing);
  });

  testWidgets('falls back to "Unknown member" when assigneeName is null', (
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
    // When the assignee's displayName isn't resolved, the screen now
    // shows a friendly "Unknown member" label instead of leaking the UID.
    expect(find.text('Assigned to Unknown member'), findsOneWidget);
  });

  testWidgets(
    'overflow menu Edit visible only when canEditTask; tapping fires onEdit',
    (tester) async {
      // No edit, no duplicate → no overflow menu at all.
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
      expect(find.byKey(const Key('tasks.detail.overflow')), findsNothing);

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
      expect(find.byKey(const Key('tasks.detail.overflow')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tasks.detail.overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tasks.detail.overflow.edit')));
      await tester.pumpAndSettle();
      expect(editPressed, isTrue);
    },
  );

  testWidgets(
    'Duplicate menu item visible for any viewer (non-creator) when onDuplicate set',
    (tester) async {
      var duplicatePressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: TaskDetailScreen(
            task: task,
            event: event,
            checklist: const [],
            canEditTask: false, // non-creator non-admin
            canChangeStatus: false,
            onDuplicate: () => duplicatePressed = true,
          ),
        ),
      );

      // Overflow menu still renders because onDuplicate is non-null.
      expect(find.byKey(const Key('tasks.detail.overflow')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tasks.detail.overflow')));
      await tester.pumpAndSettle();

      // Edit + Delete absent (canEditTask=false); only Duplicate appears.
      expect(find.byKey(const Key('tasks.detail.overflow.edit')), findsNothing);
      expect(
        find.byKey(const Key('tasks.detail.overflow.delete')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('tasks.detail.overflow.duplicate')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('tasks.detail.overflow.duplicate')),
      );
      await tester.pumpAndSettle();
      expect(duplicatePressed, isTrue);
    },
  );

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

  group('_StatusBadge — theme-aware colours (2026-06-11 follow-up)', () {
    Future<({Color fg, Color bg})> badgeColours(
      WidgetTester tester, {
      required ThemeData theme,
      required TaskStatus status,
    }) async {
      final taskWithStatus = task.copyWith(status: status);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: TaskDetailScreen(
            task: taskWithStatus,
            event: event,
            checklist: const [],
            canEditTask: false,
            canChangeStatus: false,
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.byKey(const Key('tasks.detail.statusBadge')),
      );
      final bg = (container.decoration as BoxDecoration).color!;
      final textWidget = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('tasks.detail.statusBadge')),
          matching: find.byType(Text),
        ),
      );
      return (fg: textWidget.style!.color!, bg: bg);
    }

    testWidgets(
      'dark mode todo → onSurfaceVariant on surfaceContainerHighest',
      (tester) async {
        final theme = AppTheme.dark();
        final colours = await badgeColours(
          tester,
          theme: theme,
          status: TaskStatus.todo,
        );
        expect(colours.fg, theme.colorScheme.onSurfaceVariant);
        expect(colours.bg, theme.colorScheme.surfaceContainerHighest);
      },
    );

    testWidgets('dark mode todo pill ≥ AA contrast (4.5:1)', (tester) async {
      final theme = AppTheme.dark();
      final colours = await badgeColours(
        tester,
        theme: theme,
        status: TaskStatus.todo,
      );
      expectAaContrast(
        colours.fg,
        colours.bg,
        reason: 'dark mode "To Do" pill needs AA-readable contrast',
      );
    });

    testWidgets('light mode todo → charcoal on lightGrey (unchanged)', (
      tester,
    ) async {
      final colours = await badgeColours(
        tester,
        theme: AppTheme.light(),
        status: TaskStatus.todo,
      );
      expect(colours.fg, AppColors.charcoal);
      expect(colours.bg, AppColors.lightGrey);
    });

    testWidgets('inProgress unchanged across themes — sage bg + white text', (
      tester,
    ) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final colours = await badgeColours(
          tester,
          theme: theme,
          status: TaskStatus.inProgress,
        );
        expect(colours.fg, AppColors.white);
        expect(colours.bg, AppColors.sage);
      }
    });

    testWidgets('done unchanged across themes — sageDark bg + white text', (
      tester,
    ) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final colours = await badgeColours(
          tester,
          theme: theme,
          status: TaskStatus.done,
        );
        expect(colours.fg, AppColors.white);
        expect(colours.bg, AppColors.sageDark);
      }
    });
  });
}
