import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Intent-centric helpers for the create-event journey test.
///
/// Selectors must match the keys declared in:
/// - `dashboard_screen.dart` (FAB, list, empty state copy)
/// - `create_event_screen.dart` (title, submit, error)
class CreateEventRobot {
  CreateEventRobot(this.tester);

  final WidgetTester tester;

  Future<void> tapCreateFab() async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
  }

  Future<void> enterTitle(String title) async {
    await tester.enterText(find.byKey(const Key('createEvent.title')), title);
    await tester.pump();
  }

  Future<void> tapSubmit() async {
    await tester.tap(find.byKey(const Key('createEvent.submit')));
    await tester.pumpAndSettle();
  }

  void expectEmptyDashboard() {
    expect(find.text('No events yet'), findsOneWidget);
  }

  void expectEventTile(String title) {
    expect(find.byKey(const Key('dashboard.events.list')), findsOneWidget);
    expect(find.text(title), findsOneWidget);
  }
}
