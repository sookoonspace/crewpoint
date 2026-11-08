import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #68 (Req 33): an organizer creates a crew and puts people in it.
void main() {
  testWidgets('an owner creates a crew, puts Sam in it, and renames it', (
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

    await robot.tap(const Key('members.crews'));
    await robot.finishTransition();
    robot.expectVisible(const Key('crews.empty'));

    await robot.tap(const Key('crews.new'));
    await tester.enterText(find.byKey(const Key('crews.name')), 'Food team');
    await robot.tap(const Key('crews.nameSave'));
    final saved = harness.calls.calls.single;
    expect(saved, startsWith('saveCrew:food-team-'));
    final crewId = saved.split(':')[1];
    robot.expectText('Food team');
    robot.expectText('Nobody yet');

    await robot.tap(Key('crews.tile.$crewId'));
    await robot.tap(const Key('crews.members.sam'));
    await robot.tap(const Key('crews.members.save'));
    expect(harness.calls.calls.last, 'setCrewMembers:$crewId:sam');
    final sam = await harness.firestore.doc('events/evt/members/sam').get();
    expect(sam.data()!['crewIds'], [crewId]);
    robot.expectText('1 member');

    await robot.tap(Key('crews.tile.$crewId.menu'));
    await robot.tap(Key('crews.tile.$crewId.rename'));
    await tester.enterText(find.byKey(const Key('crews.name')), 'Catering');
    await robot.tap(const Key('crews.nameSave'));
    robot.expectText('Catering');

    // Member detail shows Sam's crew.
    await robot.back();
    await robot.openMember('sam');
    robot.expectVisible(const Key('members.detail.crew.Catering'));
    await robot.finish();
  });
}
