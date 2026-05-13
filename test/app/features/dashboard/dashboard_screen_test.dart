import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_card.dart';

void main() {
  // Empty-state branch renders an `EmptyStatePlaceholder` whose lottie
  // animation loops forever — `pumpAndSettle` would hang. Bounded pumps
  // let the stream emit + the lottie loader resolve (or fall through to
  // its errorBuilder) without waiting for animation to settle.
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'renders the empty state when dashboardEventsProvider emits an empty list',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const <EventModel>[]),
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await pumpFrames(tester);

      expect(find.text('No events yet'), findsOneWidget);
      expect(find.text('Join with Code'), findsOneWidget);
      expect(find.byKey(const Key('dashboard.events.list')), findsNothing);
    },
  );

  testWidgets('shows the join-event action in the app bar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const <EventModel>[]),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await pumpFrames(tester);

    expect(find.byIcon(Icons.login_rounded), findsWidgets);
  });

  testWidgets('renders EventCards when dashboardEventsProvider emits events', (
    tester,
  ) async {
    const events = [
      EventModel(
        id: 'evt-1',
        title: 'Tahoe Trip',
        creatorId: 'uid-1',
        memberIds: ['uid-1'],
      ),
      EventModel(
        id: 'evt-2',
        title: 'Project Sync',
        creatorId: 'uid-1',
        memberIds: ['uid-1'],
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardEventsProvider.overrideWith((ref) => Stream.value(events)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard.events.list')), findsOneWidget);
    expect(find.byType(EventCard), findsNWidgets(2));
    expect(find.text('Tahoe Trip'), findsOneWidget);
    expect(find.text('Project Sync'), findsOneWidget);
    expect(find.text('No events yet'), findsNothing);
  });

  testWidgets('shows a progress indicator while events are loading', (
    tester,
  ) async {
    final controller = StreamController<List<EventModel>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardEventsProvider.overrideWith((ref) => controller.stream),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Resolve so the test exits cleanly. Empty list → EmptyStatePlaceholder
    // with looping lottie, so use bounded pumps instead of pumpAndSettle.
    controller.add(const []);
    await pumpFrames(tester);
  });
}
