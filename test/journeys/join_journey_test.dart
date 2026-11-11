import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/data/member_calls.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/join_screen.dart';

import '../harness/fake_member_calls.dart';
import '../robots/roles_robot.dart';

/// #79 (Req 47; GAP-CON-01): an invite link or scanned QR code opens
/// `/join/:code`, which shows the event and the role, explains a draft, an
/// ended or full event, and joins with one tap. Joining needs a connection.
/// The server's checks are in `functions/test/events/inviteLink.test.ts`.
void main() {
  late FakeMemberCalls calls;

  InvitePreview preview({
    bool open = true,
    String? reason,
    bool full = false,
    bool alreadyMember = false,
  }) => (
    eventId: 'conv',
    title: 'Convention 2027',
    roleName: 'Volunteer',
    open: open,
    reason: reason,
    alreadyMember: alreadyMember,
    full: full,
    startDate: DateTime.utc(2027, 7, 16),
    dateOnly: true,
  );

  Future<RolesRobot> open(
    WidgetTester tester, {
    InvitePreview? invite,
    String code = 'abc234',
    Size size = const Size(375, 1200),
    Object? failFirst,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    calls = FakeMemberCalls();
    if (invite != null) calls.previews['ABC234'] = invite;
    calls.failNext = failFirst;
    final router = GoRouter(
      initialLocation: '/join/$code',
      routes: [
        GoRoute(
          path: '/join/:code',
          builder: (_, state) =>
              JoinScreen(code: state.pathParameters['code']!),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('My events')),
          routes: [
            GoRoute(
              path: 'event/:id',
              builder: (_, state) =>
                  Scaffold(body: Text('Event ${state.pathParameters['id']}')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [memberCallsProvider.overrideWithValue(calls)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  testWidgets('GAP-CON-01 the link shows the event and role, and joins with '
      'one tap', (tester) async {
    final robot = await open(tester, invite: preview());
    expect(find.text('Convention 2027'), findsOneWidget);
    expect(find.text("You'll join as Volunteer."), findsOneWidget);
    expect(find.textContaining('Starts Friday, July 16, 2027'), findsOneWidget);
    expect(find.text('Joining needs a connection.'), findsOneWidget);
    await robot.tap(const Key('join.submit'));
    expect(calls.calls, ['previewInvite:ABC234', 'joinEvent:ABC234']);
    expect(find.text('Event conv'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('a draft explains it is not open yet, with no join button', (
    tester,
  ) async {
    final robot = await open(
      tester,
      invite: preview(open: false, reason: 'draft'),
    );
    expect(find.textContaining("isn't open to joining yet"), findsOneWidget);
    expect(find.byKey(const Key('join.submit')), findsNothing);
    await robot.finish();
  });

  testWidgets('an ended or full event is explained', (tester) async {
    var robot = await open(
      tester,
      invite: preview(open: false, reason: 'ended'),
    );
    expect(find.textContaining('has ended'), findsOneWidget);
    await robot.finish();
    robot = await open(tester, invite: preview(full: true));
    expect(find.textContaining('This event is full'), findsOneWidget);
    expect(find.byKey(const Key('join.submit')), findsNothing);
    await robot.finish();
  });

  testWidgets('someone already in it opens the event instead', (tester) async {
    final robot = await open(tester, invite: preview(alreadyMember: true));
    await robot.tap(const Key('join.open'));
    expect(find.text('Event conv'), findsOneWidget);
    expect(calls.calls, isNot(contains('joinEvent:ABC234')));
    await robot.finish();
  });

  testWidgets('an unknown or expired link says to ask for a new one', (
    tester,
  ) async {
    final robot = await open(tester);
    expect(find.byKey(const Key('join.notFound')), findsOneWidget);
    await robot.tap(const Key('join.back'));
    expect(find.text('My events'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('opened offline, it says so and tries again', (tester) async {
    final robot = await open(
      tester,
      invite: preview(),
      failFirst: FirebaseFunctionsException(
        code: 'unavailable',
        message: 'offline',
      ),
    );
    expect(find.byKey(const Key('join.error')), findsOneWidget);
    expect(find.text('Joining needs a connection.'), findsOneWidget);
    await robot.tap(const Key('join.retry'));
    expect(find.text('Convention 2027'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('offline when joining keeps the invite and retries', (
    tester,
  ) async {
    final robot = await open(tester, invite: preview());
    calls.failNext = FirebaseFunctionsException(
      code: 'unavailable',
      message: 'offline',
    );
    await robot.tap(const Key('join.submit'));
    expect(find.byKey(const Key('join.failed')), findsOneWidget);
    expect(find.text('Convention 2027'), findsOneWidget);
    await robot.tap(const Key('join.submit'));
    expect(find.text('Event conv'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('fits a 375 px phone at 200% text, in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final robot = await open(tester, invite: preview());
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('join.submit'))).height,
      greaterThanOrEqualTo(48),
    );
    await robot.finish();
  });
}
