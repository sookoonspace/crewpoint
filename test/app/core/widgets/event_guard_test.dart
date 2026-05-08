import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/event_guard.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

void main() {
  testWidgets('shows progress while dashboardEventsProvider is loading', (
    tester,
  ) async {
    final controller = StreamController<List<EventModel>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardEventsProvider.overrideWith((ref) => controller.stream),
        ],
        child: MaterialApp(
          home: EventGuard(
            eventId: 'evt-1',
            child: (event) => Text(event.title),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Pattern B: unmount before exit so dispose runs and any timers are
    // canceled cleanly.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'renders the resolved screen when the event is in the data emission',
    (tester) async {
      const target = EventModel(
        id: 'evt-1',
        title: 'Tahoe Trip',
        creatorId: 'uid-1',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardEventsProvider.overrideWith(
              (ref) => Stream.value(const [target]),
            ),
          ],
          child: MaterialApp(
            home: EventGuard(
              eventId: 'evt-1',
              child: (event) =>
                  Scaffold(body: Center(child: Text(event.title))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tahoe Trip'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('empty eventId renders the not-found screen immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const <EventModel>[]),
          ),
        ],
        child: MaterialApp(
          home: EventGuard(eventId: '', child: (event) => Text(event.title)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('event.notFound.back')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'shows progress (NOT fallback) for the first 750ms after a data:[] emission',
    (tester) async {
      final controller = StreamController<List<EventModel>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardEventsProvider.overrideWith((ref) => controller.stream),
          ],
          child: MaterialApp(
            home: EventGuard(
              eventId: 'evt-1',
              child: (event) => Text(event.title),
            ),
          ),
        ),
      );
      controller.add(const []);
      // Drain microtasks (post-frame callback + listener) so _evaluate runs
      // and the grace timer is scheduled.
      await tester.pump();
      await tester.pump();

      // Advance the fake clock just shy of the grace window — fallback must
      // NOT render yet.
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('event.notFound.back')), findsNothing);

      // Pattern B: unmount before grace fires so dispose cancels the timer.
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'resolves the screen if a re-emission with the event lands during grace',
    (tester) async {
      const target = EventModel(
        id: 'evt-1',
        title: 'Late arrival',
        creatorId: 'uid-1',
      );
      final controller = StreamController<List<EventModel>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardEventsProvider.overrideWith((ref) => controller.stream),
          ],
          child: MaterialApp(
            home: EventGuard(
              eventId: 'evt-1',
              child: (event) =>
                  Scaffold(body: Center(child: Text(event.title))),
            ),
          ),
        ),
      );
      controller.add(const []);
      await tester.pump();
      await tester.pump();

      // Mid-grace, second emission with the event lands.
      controller.add(const [target]);
      await tester.pumpAndSettle();

      expect(find.text('Late arrival'), findsOneWidget);
      expect(find.byKey(const Key('event.notFound.back')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'shows the fallback after the 750ms grace elapses with the event still missing',
    (tester) async {
      final controller = StreamController<List<EventModel>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardEventsProvider.overrideWith((ref) => controller.stream),
          ],
          child: MaterialApp(
            home: EventGuard(
              eventId: 'evt-missing',
              child: (event) => Text(event.title),
            ),
          ),
        ),
      );
      controller.add(const []);
      await tester.pump();
      await tester.pump();

      // Pattern A: advance the fake clock past 750ms, then flush setState.
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump();

      expect(find.byKey(const Key('event.notFound.back')), findsOneWidget);
    },
  );

  testWidgets('renders the fallback when the provider is in error state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardEventsProvider.overrideWith(
            (ref) => Stream<List<EventModel>>.error(StateError('boom')),
          ),
        ],
        child: MaterialApp(
          home: EventGuard(
            eventId: 'evt-1',
            child: (event) => Text(event.title),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('event.notFound.back')), findsOneWidget);
  });

  testWidgets('didUpdateWidget on eventId change resets grace state', (
    tester,
  ) async {
    const target = EventModel(
      id: 'evt-B',
      title: 'Event B',
      creatorId: 'uid-1',
    );
    final controller = StreamController<List<EventModel>>();
    addTearDown(controller.close);

    // Build a tiny harness that lets us swap the eventId on the SAME
    // EventGuard subtree without unmounting (so didUpdateWidget runs,
    // not a fresh initState).
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardEventsProvider.overrideWith((ref) => controller.stream),
        ],
        child: const MaterialApp(home: _IdSwapHost()),
      ),
    );
    // Initial id = evt-A; emit data without it; advance past grace so the
    // fallback renders (and _graceElapsed = true).
    controller.add(const []);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();
    expect(find.byKey(const Key('event.notFound.back')), findsOneWidget);

    // Now swap to evt-B and emit a snapshot containing it. Since
    // didUpdateWidget reset grace state, the resolved screen should
    // render — NOT the stale fallback from evt-A.
    _IdSwapHost.swap('evt-B');
    controller.add(const [target]);
    await tester.pumpAndSettle();

    expect(find.text('Event B'), findsOneWidget);
    expect(find.byKey(const Key('event.notFound.back')), findsNothing);
  });

  testWidgets(
    'dispose cancels an in-flight grace timer (no Timer-still-pending failure)',
    (tester) async {
      final controller = StreamController<List<EventModel>>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardEventsProvider.overrideWith((ref) => controller.stream),
          ],
          child: MaterialApp(
            home: EventGuard(
              eventId: 'evt-1',
              child: (event) => Text(event.title),
            ),
          ),
        ),
      );
      // Trigger grace scheduling.
      controller.add(const []);
      await tester.pump();
      await tester.pump();

      // Unmount BEFORE the timer fires. dispose() must cancel + null the
      // timer; otherwise the test framework reports a pending timer leak.
      await tester.pumpWidget(const SizedBox.shrink());
      // Advance past the original deadline — nothing should fire.
      await tester.pump(const Duration(milliseconds: 800));
      // (The implicit assertion is "no exception thrown"; if dispose forgot
      // to cancel, Flutter logs a pending-timer error here.)
    },
  );
}

/// Test host that hosts an `EventGuard` whose `eventId` can be swapped
/// without rebuilding the subtree, so `didUpdateWidget` fires (instead of
/// a fresh `initState` we'd get from a full rebuild).
class _IdSwapHost extends StatefulWidget {
  const _IdSwapHost();

  static void swap(String id) {
    _state?.._next(id);
  }

  static _IdSwapHostState? _state;

  @override
  State<_IdSwapHost> createState() => _IdSwapHostState();
}

class _IdSwapHostState extends State<_IdSwapHost> {
  String _id = 'evt-A';

  @override
  void initState() {
    super.initState();
    _IdSwapHost._state = this;
  }

  @override
  void dispose() {
    _IdSwapHost._state = null;
    super.dispose();
  }

  void _next(String id) => setState(() => _id = id);

  @override
  Widget build(BuildContext context) {
    return EventGuard(
      eventId: _id,
      child: (event) => Scaffold(body: Center(child: Text(event.title))),
    );
  }
}
