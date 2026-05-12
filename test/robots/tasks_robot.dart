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
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('tasks.create.title')),
        matching: find.byType(TextField),
      ),
      title,
    );
    await tester.pump();
  }

  Future<void> tapSave() async {
    // CreateTaskScreen now renders three AppFormSections + inline
    // AppDateField; the Save button can sit below the default 800x600
    // viewport. Scroll it into view first.
    await tester.ensureVisible(find.byKey(const Key('tasks.create.save')));
    // Bounded pumps: callers from detail-page harnesses keep emitting via
    // their Drift/Firestore mirrors, so pumpAndSettle can deadlock.
    await _bounded(frames: 4);
    await tester.tap(find.byKey(const Key('tasks.create.save')));
    await _bounded();
  }

  Future<void> tapStatus(String taskId) async {
    await tester.tap(find.byKey(Key('tasks.tile.$taskId.status')));
    await tester.pumpAndSettle();
  }

  void expectEmptyState() {
    expect(find.byKey(const Key('tasks.list.emptyState')), findsOneWidget);
  }

  void expectTaskTitle(String title) {
    expect(find.text(title), findsOneWidget);
  }

  void expectStatusIcon({required IconData icon}) {
    expect(find.byIcon(icon), findsAtLeastNWidgets(1));
  }

  // ===== Edit-task journey helpers =====
  //
  // Explicit pumps (vs pumpAndSettle) throughout because EventTaskDetailPage
  // wires a Drift watch + Firestore mirror that keep emitting, making
  // pumpAndSettle deadlock indefinitely.

  Future<void> _bounded({int frames = 6}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapEditOnDetail() async {
    await tester.tap(find.byKey(const Key('tasks.detail.overflow')));
    await _bounded();
    await tester.tap(find.byKey(const Key('tasks.detail.overflow.edit')));
    await _bounded();
  }

  Future<void> tapDuplicateOnDetail() async {
    await tester.tap(find.byKey(const Key('tasks.detail.overflow')));
    await _bounded();
    await tester.tap(find.byKey(const Key('tasks.detail.overflow.duplicate')));
    await _bounded();
  }

  Future<void> enterEditBudget(String value) async {
    await tester.ensureVisible(find.byKey(const Key('tasks.edit.budget')));
    await _bounded();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('tasks.edit.budget')),
        matching: find.byType(TextField),
      ),
      value,
    );
    await tester.pump();
  }

  Future<void> tapEditSave() async {
    await tester.ensureVisible(find.byKey(const Key('tasks.edit.save')));
    await _bounded();
    await tester.tap(find.byKey(const Key('tasks.edit.save')));
    await _bounded();
  }
}
