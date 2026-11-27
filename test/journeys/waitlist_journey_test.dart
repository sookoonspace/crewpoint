import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/features/registration/domain/waitlist.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #248 (Spec #233 Req 32, 32a, 34): the organizer's waitlist, for
/// registrations.manage: places used and held, how far over a lowered
/// capacity, then groups in queue order with Offer a place, or an open
/// offer's expiry with Extend and Withdraw. The server side is in
/// `functions/test/registration/offers.test.ts`.
void main() {
  late RolesHarness harness;
  const k = 'registration.waitlist';
  const route = '/dashboard/event/${RolesHarness.eventId}/waitlist';
  final offerUntil = DateTime.utc(2027, 2, 4, 18);

  WaitlistView view({int capacity = 10, int used = 8, int held = 1}) =>
      WaitlistView(
        capacity: capacity,
        placesUsed: used,
        held: held,
        timeZone: 'America/Chicago',
        waiting: [
          WaitingGroup(
            registrationId: 'r1',
            groupName: 'Shah family',
            size: 1,
            position: 1,
            offerExpiresAt: offerUntil,
          ),
          const WaitingGroup(
            registrationId: 'r2',
            groupName: 'Desai family',
            size: 1,
            position: 2,
          ),
          const WaitingGroup(
            registrationId: 'r3',
            groupName: 'Big family',
            size: 6,
            position: 3,
          ),
        ],
      );

  Future<RolesRobot> open(
    WidgetTester tester, {
    String as = 'owner',
    String location = route,
    WaitlistView? waitlist,
    Size size = const Size(375, 2000),
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: as, initialLocation: location);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: const {
        'owner': ['owner'],
        'sam': ['participant'],
      },
    );
    harness.calls.waitlists[RolesHarness.eventId] = waitlist ?? view();
    await tester.pumpWidget(
      harness.buildApp(themeMode: dark ? ThemeMode.dark : null),
    );
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  testWidgets('shows places and the queue in order, with open offers and '
      'their expiry', (tester) async {
    final robot = await open(tester);
    expect(find.text('8 of 10 places used'), findsOneWidget);
    expect(find.text('1 held by open offers'), findsOneWidget);
    expect(find.text('Number 1 · Shah family'), findsOneWidget);
    expect(find.textContaining('Offered until Thu, Feb 4 12:00'), findsOneWidget);
    expect(find.text('6 people'), findsOneWidget);
    // Big family (6) does not fit the one free place: no Offer a place.
    final big = tester.widget<CpButton>(
      find.byKey(const Key('$k.offer.r3')),
    );
    expect(big.onPressed, isNull);
    expect(find.byKey(const Key('$k.over')), findsNothing);
    await robot.finish();
  });

  testWidgets('offers a place by hand, extends and withdraws an offer', (
    tester,
  ) async {
    final robot = await open(tester);
    await robot.tap(const Key('$k.offer.r2'));
    expect(find.text('Offer sent.'), findsOneWidget);
    await robot.tap(const Key('$k.extend.r1'));
    await robot.tap(const Key('$k.extend.48'));
    expect(find.text('Offer extended.'), findsOneWidget);
    await robot.tap(const Key('$k.withdraw.r1'));
    expect(find.text('Withdraw this offer?'), findsOneWidget);
    await robot.tap(const Key('$k.withdraw.confirm'));
    expect(harness.calls.offerActions, [
      'offer:r2',
      'extend:r1:48',
      'withdraw:r1',
    ]);
    await robot.finish();
  });

  testWidgets('no room says so', (tester) async {
    final robot = await open(tester);
    harness.calls.noRoomFor.add('r2');
    await robot.tap(const Key('$k.offer.r2'));
    expect(find.text("There's no room for this group."), findsOneWidget);
    await robot.finish();
  });

  testWidgets('Req 32a: a lowered capacity shows how far over, and removes '
      'nobody', (tester) async {
    final robot = await open(tester, waitlist: view(capacity: 6, held: 0));
    expect(find.byKey(const Key('$k.over')), findsOneWidget);
    expect(
      find.textContaining('Over capacity by 2. Nobody is removed'),
      findsOneWidget,
    );
    await robot.finish();
  });

  testWidgets('needs registrations.manage, on the hub too', (tester) async {
    var robot = await open(tester, as: 'sam');
    expect(find.byKey(const Key('$k.body')), findsNothing);
    await robot.finish();
    const hub = '/dashboard/event/${RolesHarness.eventId}/hub';
    robot = await open(tester, location: hub);
    expect(find.text('Waitlist'), findsOneWidget);
    await robot.finish();
    robot = await open(tester, as: 'sam', location: hub);
    expect(find.text('Waitlist'), findsNothing);
    await robot.finish();
  });

  testWidgets('Req 71: fits a 320 px phone at 200% text in dark mode', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final robot = await open(tester, size: const Size(320, 3200), dark: true);
    expect(tester.takeException(), isNull);
    await robot.finish();
  });
}
