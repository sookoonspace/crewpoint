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

  /// Bounded pumps: the dashboard's empty-state animation loops forever, so
  /// `pumpAndSettle` would never return.
  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapCreateFab() async {
    await tester.tap(find.byIcon(Icons.add));
    await settle();
  }

  /// Picks a template, the first step of creating an event (Req 63).
  Future<void> chooseTemplate(String id) async {
    final card = find.byKey(Key('events.create.template.$id'));
    await tester.scrollUntilVisible(card, 200);
    await tester.tap(card);
    await settle();
  }

  Future<void> enterTitle(String title) async {
    await tester.enterText(find.byKey(const Key('createEvent.title')), title);
    await tester.pump();
  }

  Future<void> tapSubmit() async {
    await tester.tap(find.byKey(const Key('createEvent.submit')));
    await settle();
  }

  void expectEmptyDashboard() {
    expect(find.text('No events yet'), findsOneWidget);
  }

  void expectEventTile(String title) {
    expect(find.byKey(const Key('dashboard.events.list')), findsOneWidget);
    expect(find.text(title), findsOneWidget);
  }
}
