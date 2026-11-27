import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/app_lifecycle_source.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:crewpoint_app/app/features/registration/application/my_waiting_provider.dart';
import 'package:crewpoint_app/app/features/registration/domain/my_registration.dart';

import '../../../harness/fake_member_calls.dart';

/// #292: home reads registrations not confirmed yet again when the app
/// comes back to the foreground, and on pull to refresh, so an offer made
/// meanwhile shows without restarting the app.
void main() {
  final offered = WaitingRegistration(
    eventId: 'e1',
    slug: 'conv',
    title: 'Convention',
    status: 'waitlisted',
    waitlistPosition: 1,
    offerExpiresAt: DateTime.now().add(const Duration(days: 2)),
  );
  int reads(FakeMemberCalls calls) =>
      calls.calls.where((c) => c == 'getMyWaitingRegistrations').length;

  test('coming back to the foreground reads the list again', () async {
    final calls = FakeMemberCalls();
    final lifecycle = FakeAppLifecycleSource();
    final container = ProviderContainer(
      overrides: [
        memberCallsProvider.overrideWithValue(calls),
        currentUserIdProvider.overrideWithValue('u1'),
        appLifecycleSourceProvider.overrideWithValue(lifecycle),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(myWaitingRegistrationsProvider, (_, _) {});
    addTearDown(sub.close);
    expect(
      await container.read(myWaitingRegistrationsProvider.future),
      isEmpty,
    );
    calls.waitingRegistrations = [offered];
    lifecycle.emit(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(reads(calls), 1);
    lifecycle.emit(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(myWaitingRegistrationsProvider.future), [
      offered,
    ]);
    expect(reads(calls), 2);
  });

  testWidgets('pulling home down reads the list again', (tester) async {
    final calls = FakeMemberCalls();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memberCallsProvider.overrideWithValue(calls),
          currentUserIdProvider.overrideWithValue('u1'),
          appLifecycleSourceProvider.overrideWithValue(
            FakeAppLifecycleSource(),
          ),
          dashboardEventsProvider.overrideWith(
            (ref) => Stream.value(const <EventModel>[
              EventModel(
                id: 'x',
                title: 'Picnic',
                creatorId: 'u1',
                memberIds: ['u1'],
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Not confirmed yet'), findsNothing);
    calls.waitingRegistrations = [offered];
    await tester.fling(
      find.byKey(const Key('dashboard.events.list')),
      const Offset(0, 400),
      1000,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('A place is available'), findsOneWidget);
    expect(reads(calls), 2);
    // Let the pull indicator's timers finish before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
