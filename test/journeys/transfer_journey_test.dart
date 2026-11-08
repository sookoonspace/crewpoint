import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #69 (Req 30, WE-10): the Owner hands ownership to someone, who accepts it,
/// the old owner becomes a Co-owner, and ownership comes back the same way.
void main() {
  testWidgets('WE-10 Olivia transfers ownership to Sam, then gets it back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = RolesHarness(signedInAs: 'owner');
    addTearDown(() async => harness.database.close());
    await harness.seed();
    await tester.pumpWidget(harness.buildApp());
    final robot = RolesRobot(tester);
    await robot.settle();

    // Olivia offers ownership to Sam, a Participant.
    await robot.tap(const Key('members.transfer'));
    await robot.finishTransition();
    robot.expectText('Owner: You');
    await robot.tap(const Key('transfer.pick.sam'));
    await robot.tap(const Key('transfer.offer'));
    await robot.tap(const Key('transfer.offerConfirm'));
    expect(harness.calls.calls, ['offerOwnership:sam']);
    robot.expectText('Waiting for Sam to accept.');
    robot.expectVisible(const Key('transfer.withdraw'));

    // Sam accepts on his phone. Olivia's screen changes live.
    harness.calls.actingAs = 'sam';
    await harness.calls.acceptOwnership(eventId: RolesHarness.eventId);
    await robot.settle();
    robot.expectText('Owner: Sam');
    robot.expectHidden(const Key('transfer.offer'));
    final olivia = await harness.firestore.doc('events/evt/members/owner').get();
    expect(olivia.data()!['roleIds'], ['coOwner']);

    // Sam offers it back, and Olivia accepts here.
    await harness.calls.offerOwnership(
      eventId: RolesHarness.eventId,
      toUid: 'owner',
    );
    await robot.settle();
    robot.expectVisible(const Key('transfer.offerToMe'));
    harness.calls.actingAs = 'owner';
    await robot.tap(const Key('transfer.accept'));
    robot.expectText('Owner: You');
    robot.expectText("You're now the Owner");
    final sam = await harness.firestore.doc('events/evt/members/sam').get();
    expect(sam.data()!['roleIds'], ['coOwner']);
    expect(harness.calls.calls.last, 'acceptOwnership');
    expect(tester.takeException(), isNull);
    await robot.finish();
  });
}
