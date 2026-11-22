import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/invite.dart';

import '../harness/fake_qr.dart';
import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #79 and #238 (Req 47, 56; Spec #233 Req 15; GAP-CON-01, GAP-ANY-02,
/// GAP-ANY-03): an event has several invite links, each a link and a QR
/// code that open `/join/:code`, with its own role, expiry and optional
/// single use, each turned off on its own. The server's rules are in
/// `functions/test/events/inviteLinks.test.ts`.
void main() {
  late RolesHarness harness;
  late FakeQrRenderer qr;
  final base = '${AppFlavor.current.legalBaseUrl}/join';
  const first = 'dashboard.invite.ABC234';
  const second = 'dashboard.invite.ABC231';

  Future<RolesRobot> open(
    WidgetTester tester, {
    Size size = const Size(375, 2400),
    Object? failFirst,
    List<InviteLink> links = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: 'owner');
    addTearDown(() async => harness.database.close());
    await harness.seed();
    // A convention a year away.
    await harness.firestore.doc('events/${RolesHarness.eventId}').update({
      'templateId': 'convention',
      'startDate': Timestamp.fromDate(DateTime.utc(2027, 7, 16)),
      'endDate': Timestamp.fromDate(DateTime.utc(2027, 7, 18)),
      'dateOnly': true,
    });
    qr = FakeQrRenderer();
    harness.calls.inviteLinks.addAll(links);
    harness.calls.failNext = failFirst;
    await tester.pumpWidget(
      harness.buildApp(overrides: [qrRendererProvider.overrideWithValue(qr)]),
    );
    final robot = RolesRobot(tester);
    await robot.settle();
    await robot.tap(const Key('members.invite'));
    await robot.finishTransition();
    return robot;
  }

  testWidgets('GAP-CON-01 with no links yet, opening makes a Participant '
      'link, with its QR code opening /join/:code', (tester) async {
    final robot = await open(tester);
    expect(harness.calls.calls, [
      'listInviteLinks',
      'createInviteLink:participant:false',
    ]);
    expect(find.text('$base/ABC234'), findsOneWidget);
    expect(find.byKey(const Key('$first.code')), findsOneWidget);
    expect(find.byKey(const Key('$first.expires')), findsOneWidget);
    expect(find.text('Anyone with it can join'), findsOneWidget);
    await robot.tap(const Key('$first.qr'));
    await robot.finishTransition();
    expect(qr.rendered.last, '$base/ABC234');
    expect(find.byKey(Key('qr:$base/ABC234')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('GAP-ANY-02 GAP-ANY-03 the organizer adds a second, single-use '
      'link into another role, and both are listed', (tester) async {
    final robot = await open(tester);
    await robot.tap(const Key('dashboard.invite.new'));
    await robot.finishTransition();
    await robot.tap(const Key('dashboard.invite.new.role'));
    await robot.finishTransition();
    await robot.tap(const Key('dashboard.invite.role.volunteer'));
    await robot.finishTransition();
    await robot.tap(const Key('dashboard.invite.new.expiry'));
    await robot.finishTransition();
    await robot.tap(const Key('dashboard.invite.new.expiry.eventEnd'));
    await robot.finishTransition();
    await robot.tap(const Key('dashboard.invite.new.singleUse'));
    await robot.tap(const Key('dashboard.invite.new.create'));
    await robot.finishTransition();
    expect(
      harness.calls.calls.last,
      startsWith('createInviteLink:volunteer:true:2027-07-19'),
    );
    expect(find.text('$base/ABC231'), findsOneWidget);
    expect(find.text('$base/ABC234'), findsOneWidget);
    final role = tester.widget<Text>(find.byKey(const Key('$second.role')));
    expect(role.data, 'Volunteer');
    expect(
      tester.widget<Text>(find.byKey(const Key('$second.use'))).data,
      'Single use',
    );
    // The newest is listed first.
    expect(
      tester.getTopLeft(find.byKey(const Key(second))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key(first))).dy),
    );
    await robot.finish();
  });

  testWidgets('GAP-CON-01 the organizer keeps a link open until the event '
      'ends, and the link stays the same', (tester) async {
    final robot = await open(tester);
    await robot.tap(const Key('$first.expiry'));
    await robot.tap(const Key('$first.expiry.eventEnd'));
    expect(
      harness.calls.calls.last,
      startsWith('setInviteLinkExpiry:ABC234:2027-07-19'),
    );
    expect(find.text('$base/ABC234'), findsOneWidget);
    expect(find.textContaining('Jul 19, 2027'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('GAP-ANY-03 turning a link off asks first, then shows it '
      'turned off with no way to share it', (tester) async {
    final robot = await open(tester);
    await robot.tap(const Key('$first.turnOff'));
    await robot.tap(const Key('dashboard.invite.turnOff.cancel'));
    expect(harness.calls.calls, isNot(contains('turnOffInviteLink:ABC234')));
    await robot.tap(const Key('$first.turnOff'));
    await robot.tap(const Key('dashboard.invite.turnOff.confirm'));
    expect(harness.calls.calls.last, 'turnOffInviteLink:ABC234');
    expect(find.text('Turned off'), findsOneWidget);
    expect(find.byKey(const Key('$first.copy')), findsNothing);
    expect(find.text('$base/ABC234'), findsNothing);
    await robot.finish();
  });

  testWidgets('GAP-ANY-03 used and expired links show why, after the '
      'active ones', (tester) async {
    final now = DateTime.now();
    final robot = await open(
      tester,
      links: [
        InviteLink(
          code: 'USED22',
          roleId: 'participant',
          expiresAt: now.add(const Duration(days: 3)),
          singleUse: true,
          uses: 1,
          usedAt: now,
        ),
        InviteLink(
          code: 'OLD222',
          roleId: 'volunteer',
          expiresAt: now.subtract(const Duration(days: 1)),
          uses: 4,
        ),
        InviteLink(
          code: 'LIVE22',
          roleId: 'participant',
          expiresAt: now.add(const Duration(days: 3)),
        ),
      ],
    );
    expect(harness.calls.calls, ['listInviteLinks']);
    expect(find.text('Used'), findsOneWidget);
    expect(find.text('Used once'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Used 4 times'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.byKey(const Key('dashboard.invite.USED22.copy')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('dashboard.invite.LIVE22'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('dashboard.invite.USED22'))).dy,
      ),
    );
    await robot.finish();
  });

  testWidgets('offline, it says invites need a connection, and retries', (
    tester,
  ) async {
    final robot = await open(
      tester,
      failFirst: FirebaseFunctionsException(
        code: 'unavailable',
        message: 'offline',
      ),
    );
    expect(
      find.text('Invites need a connection. Check it and try again.'),
      findsOneWidget,
    );
    await robot.tap(const Key('dashboard.invite.retry'));
    expect(find.text('$base/ABC234'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('fits a 320 px phone at 200% text, in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final robot = await open(tester, size: const Size(320, 3200));
    expect(tester.takeException(), isNull);
    for (final key in [
      '$first.copy',
      '$first.share',
      '$first.qr',
      '$first.expiry',
      '$first.turnOff',
      'dashboard.invite.new',
    ]) {
      expect(
        tester.getSize(find.byKey(Key(key))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
    await robot.finish();
  });
}
