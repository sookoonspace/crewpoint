import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Intent-centric helpers for the Dashboard (Home) tab. Keys must match
/// those declared in `dashboard_screen.dart` and `event_tile.dart`.
class DashboardRobot {
  DashboardRobot(this.tester);

  final WidgetTester tester;

  void expectGreetingContains(String fragment) {
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains(fragment),
      ),
      findsAtLeastNWidgets(1),
    );
  }

  void expectEventTile(String title) {
    expect(find.text(title), findsAtLeastNWidgets(1));
  }

  void expectProgressLabel(String eventId, String label) {
    expect(
      find.descendant(
        of: find.byKey(Key('event.tile.$eventId.ring')),
        matching: find.text(label),
      ),
      findsOneWidget,
    );
  }

  Future<void> tapPastFilter() async {
    await tester.tap(find.byKey(const Key('dashboard.filter.past')));
    await tester.pump();
  }

  Future<void> tapUpcomingFilter() async {
    await tester.tap(find.byKey(const Key('dashboard.filter.upcoming')));
    await tester.pump();
  }
}
