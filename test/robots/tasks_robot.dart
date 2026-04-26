import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Intent-centric helpers for the Tasks feature widget journey tests.
///
/// Selectors must match the keys declared in:
/// - `task_list_screen.dart` (list, create FAB, empty state)
/// - `create_task_screen.dart` (title, save)
/// - `task_tile.dart` (per-task tile + status chip)
class TasksRobot {
  TasksRobot(this.tester);

  final WidgetTester tester;

  Future<void> tapCreate() async {
    await tester.tap(find.byKey(const Key('tasks.list.create')));
    await tester.pumpAndSettle();
  }

  Future<void> enterTitle(String title) async {
    await tester.enterText(find.byKey(const Key('tasks.create.title')), title);
    await tester.pump();
  }

  Future<void> tapSave() async {
    await tester.tap(find.byKey(const Key('tasks.create.save')));
    await tester.pumpAndSettle();
  }

  Future<void> tapStatus(String taskId) async {
    await tester.tap(find.byKey(Key('tasks.tile.$taskId.status')));
    await tester.pumpAndSettle();
  }

  void expectEmptyState() {
    expect(find.byKey(const Key('tasks.list.empty')), findsOneWidget);
  }

  void expectTaskTitle(String title) {
    expect(find.text(title), findsOneWidget);
  }

  void expectStatusIcon({required IconData icon}) {
    expect(find.byIcon(icon), findsAtLeastNWidgets(1));
  }
}
