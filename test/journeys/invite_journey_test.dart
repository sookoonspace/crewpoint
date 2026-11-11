import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/providers.dart';

import '../harness/fake_qr.dart';
import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #79 (Req 47, 56; GAP-CON-01): the event's one invite is a link and a QR
/// code that open `/join/:code`, carrying a role, with an expiry the
/// organizer sets, up to a whole registration period. Replacing the link
/// stops the old one. The server's rules are in
/// `functions/test/events/inviteLink.test.ts`.
void main() {
  late RolesHarness harness;
  late FakeQrRenderer qr;
  final link = '${AppFlavor.current.legalBaseUrl}/join/ABC234';

  Future<RolesRobot> open(
    WidgetTester tester, {
    Size size = const Size(375, 2000),
    Object? failFirst,
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

  testWidgets('GAP-CON-01 one link and QR code open /join/:code', (
    tester,
  ) async {
    final robot = await open(tester);
    expect(find.text(link), findsOneWidget);
    expect(qr.rendered.last, link);
    expect(find.byKey(Key('qr:$link')), findsOneWidget);
    expect(find.text('ABC234'), findsOneWidget);
    expect(find.byKey(const Key('dashboard.invite.expires')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('GAP-CON-01 the organizer keeps it open until the event ends, '
      'and the link stays the same', (tester) async {
    final robot = await open(tester);
    await robot.tap(const Key('dashboard.invite.expiry'));
    await robot.tap(const Key('dashboard.invite.expiry.eventEnd'));
    expect(
      harness.calls.calls.last,
      startsWith('generateInviteCode:participant:false:2027-07-19'),
    );
    expect(find.text(link), findsOneWidget);
    expect(find.textContaining('Jul 19, 2027'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('replacing the link stops the old one', (tester) async {
    final robot = await open(tester);
    await robot.tap(const Key('dashboard.invite.rotate'));
    expect(harness.calls.calls.last, 'generateInviteCode:participant:true');
    expect(find.text(link), findsNothing);
    expect(find.textContaining('/join/ABC231'), findsOneWidget);
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
    expect(find.text(link), findsOneWidget);
    await robot.finish();
  });

  testWidgets('fits a 375 px phone at 200% text, in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final robot = await open(tester, size: const Size(375, 1400));
    expect(tester.takeException(), isNull);
    for (final key in ['copy', 'share', 'rotate', 'expiry']) {
      expect(
        tester.getSize(find.byKey(Key('dashboard.invite.$key'))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
    await robot.finish();
  });
}
