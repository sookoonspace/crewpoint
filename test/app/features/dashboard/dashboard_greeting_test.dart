import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:crewpoint_app/app/features/profile/application/current_user_doc_provider.dart';
import 'package:crewpoint_app/app/features/tasks/application/event_task_counts_provider.dart';

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

ProviderScope _harness({
  required AppUser? user,
  required List<EventModel> events,
}) {
  return ProviderScope(
    overrides: [
      dashboardEventsProvider.overrideWith((ref) => Stream.value(events)),
      currentUserDocProvider.overrideWith((ref) => Stream.value(user)),
      eventTaskCountsProvider.overrideWith(
        (ref, eventId) => Stream.value((todo: 0, doing: 0, done: 0)),
      ),
    ],
    child: const MaterialApp(home: DashboardScreen()),
  );
}

void main() {
  const user = AppUser(
    uid: 'u-1',
    email: 'alex@example.com',
    displayName: 'Alex Morgan',
    emailVerified: true,
  );

  testWidgets('renders "Good morning, Alex 👋" when the clock is before noon', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 5, 17, 8)), () async {
      await tester.pumpWidget(_harness(user: user, events: const []));
      await _pumpFrames(tester);
      expect(find.text('Good morning, Alex 👋'), findsOneWidget);
    });
  });

  testWidgets('falls back to "Good afternoon, there 👋" with no displayName', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 5, 17, 14)), () async {
      await tester.pumpWidget(_harness(user: null, events: const []));
      await _pumpFrames(tester);
      expect(find.text('Good afternoon, there 👋'), findsOneWidget);
    });
  });

  testWidgets('Create Event button is present; no FAB on the screen', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(user: user, events: const []));
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('dashboard.action.createEvent')),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Upcoming and Past filter pills are rendered', (tester) async {
    await tester.pumpWidget(_harness(user: user, events: const []));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('dashboard.filter.upcoming')), findsOneWidget);
    expect(find.byKey(const Key('dashboard.filter.past')), findsOneWidget);
  });
}
