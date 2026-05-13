import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/tasks/presentation/my_tasks_screen.dart';

/// Screen-level robot for `MyTasksScreen`. Full `StatefulShellRoute`
/// (real bottom-nav tab switching) scope is deferred per spec — this is
/// the "TabsJourneyHarness" stand-in.
class MyTasksTabRobot {
  MyTasksTabRobot(this.tester);

  final WidgetTester tester;

  /// Records every CTA tap so tests can assert one-and-only-one fire.
  int dashboardCtaTaps = 0;

  Future<void> pumpEmptyNoEvents() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => 'uid-1'),
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const <EventModel>[]),
          ),
        ],
        child: MaterialApp(
          home: MyTasksScreen(onOpenDashboard: () => dashboardCtaTaps++),
        ),
      ),
    );
    // Lottie loops forever — bounded pumps, never pumpAndSettle.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void expectEmptyState() {
    expect(find.byKey(const Key('emptyState.title')), findsOneWidget);
    expect(find.byKey(const Key('emptyState.cta')), findsOneWidget);
  }

  void expectNoEventsCtaLabel() {
    expect(find.text('Create an event'), findsOneWidget);
  }

  Future<void> tapCta() async {
    await tester.tap(find.byKey(const Key('emptyState.cta')));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

void main() {
  testWidgets(
    'Tasks tab — zero events: empty-state CTA fires the dashboard navigation seam exactly once',
    (tester) async {
      final robot = MyTasksTabRobot(tester);

      await robot.pumpEmptyNoEvents();
      robot.expectEmptyState();
      robot.expectNoEventsCtaLabel();

      await robot.tapCta();

      expect(robot.dashboardCtaTaps, 1);
    },
  );
}
