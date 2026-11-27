import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/event_card.dart';
import 'package:crewpoint_app/app/features/tasks/application/event_task_counts_provider.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/features/registration/application/my_waiting_provider.dart';
import 'package:crewpoint_app/app/features/registration/domain/my_registration.dart';

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

    expect(find.byIcon(CpIcons.joinEvent), findsWidgets);
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
          // Drift stream would never settle in widget tests; stub a finite
          // emission so each EventCard's ring resolves to zeros.
          eventTaskCountsProvider.overrideWith(
            (ref, eventId) => Stream.value((todo: 0, doing: 0, done: 0)),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await pumpFrames(tester);

    expect(find.byKey(const Key('dashboard.events.list')), findsOneWidget);
    expect(find.byType(EventCard), findsNWidgets(2));
    expect(find.text('Tahoe Trip'), findsOneWidget);
    expect(find.text('Project Sync'), findsOneWidget);
    expect(find.text('No events yet'), findsNothing);
  });

  testWidgets('shows a loading state while events are loading', (tester) async {
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

    expect(find.byType(CpLoadingState), findsOneWidget);

    // Resolve so the test exits cleanly. Empty list → EmptyStatePlaceholder
    // with looping lottie, so use bounded pumps instead of pumpAndSettle.
    controller.add(const []);
    await pumpFrames(tester);
  });

  group('#292 registrations not confirmed yet', () {
    final soon = DateTime.utc(DateTime.now().year + 1, 7, 16);
    WaitingRegistration waiting(
      String eventId, {
      String status = 'waitlisted',
      DateTime? offer,
    }) => WaitingRegistration(
      eventId: eventId,
      slug: 'conv-$eventId',
      title: 'Convention $eventId',
      status: status,
      startDate: soon,
      dateOnly: true,
      waitlistPosition: 1,
      offerExpiresAt: offer,
    );

    Future<void> pump(
      WidgetTester tester, {
      List<EventModel> events = const [],
      required List<WaitingRegistration> waiting,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardEventsProvider.overrideWith((ref) => Stream.value(events)),
            myWaitingRegistrationsProvider.overrideWith((ref) async => waiting),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await pumpFrames(tester);
    }

    testWidgets('a waitlisted or pending registration shows on home, with '
        'where it stands, instead of the empty state', (tester) async {
      await pump(
        tester,
        waiting: [
          waiting('a'),
          waiting('b', status: 'pending'),
          waiting('c', offer: DateTime.now().add(const Duration(days: 2))),
        ],
      );
      expect(find.text('No events yet'), findsNothing);
      expect(find.text('Not confirmed yet'), findsOneWidget);
      expect(find.text('Convention a'), findsOneWidget);
      expect(find.text('On the waitlist, number 1'), findsOneWidget);
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('A place is available'), findsOneWidget);
    });

    testWidgets('an event I am already in, and the Past filter, leave it out', (
      tester,
    ) async {
      await pump(
        tester,
        events: const [
          EventModel(id: 'a', title: 'Mine', creatorId: 'u', memberIds: ['u']),
        ],
        waiting: [waiting('a')],
      );
      expect(find.byKey(const Key('dashboard.waiting')), findsNothing);
      await tester.tap(find.byKey(const Key('dashboard.filter.past')));
      await pumpFrames(tester);
      expect(find.text('Convention a'), findsNothing);
    });

    testWidgets('Req 71: fits a 320 px phone at 200% text', (tester) async {
      tester.view.physicalSize = const Size(320, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, waiting: [waiting('a'), waiting('b', status: 'pending')]);
      expect(tester.takeException(), isNull);
    });
  });
}
