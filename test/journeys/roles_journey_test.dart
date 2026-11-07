import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #67: role screens, custom roles, and role assignment changing access live.
void main() {
  Future<RolesRobot> start(
    WidgetTester tester,
    RolesHarness harness, {
    Size size = const Size(375, 812),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => harness.database.close());
    await harness.seed();
    await tester.pumpWidget(harness.buildApp());
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  testWidgets('an owner makes someone Crew lead, and the list shows it', (
    tester,
  ) async {
    final harness = RolesHarness(signedInAs: 'owner');
    final robot = await start(tester, harness);

    robot.expectMemberRole('sam', 'Member');
    await robot.openMember('sam');
    await robot.toggleRole('crewLead');
    await robot.toggleRole('participant');
    // The preview shows what the new roles allow before saving.
    robot.expectVisible(const Key('members.detail.grant.tasks.manage'));
    await robot.saveRoles();

    expect(harness.calls.calls, contains('setMemberRoles:sam:crewLead'));
    final saved = await harness.firestore.doc('events/evt/members/sam').get();
    expect(saved.data()!['permissions'], contains('tasks.manage'));
    robot.expectHidden(const Key('members.detail.save'));

    await robot.back();
    robot.expectMemberRole('sam', 'Crew lead');
    await robot.finish();
  });

  testWidgets(
    'a role given while a screen is open changes what that person sees, live',
    (tester) async {
      final harness = RolesHarness(signedInAs: 'sam');
      final robot = await start(tester, harness);

      // A Participant cannot invite or open roles.
      robot.expectHidden(const Key('members.invite'));
      robot.expectHidden(const Key('members.roles'));

      // The owner makes Sam an Admin from another device.
      await harness.calls.setMemberRoles(
        eventId: RolesHarness.eventId,
        uid: 'sam',
        roleIds: ['admin'],
      );
      await robot.settle();

      robot.expectVisible(const Key('members.invite'));
      robot.expectVisible(const Key('members.roles'));

      // And taking it away hides them again.
      await harness.calls.setMemberRoles(
        eventId: RolesHarness.eventId,
        uid: 'sam',
        roleIds: ['participant'],
      );
      await robot.settle();
      robot.expectHidden(const Key('members.invite'));
      await robot.finish();
    },
  );

  testWidgets('GE-03 an owner creates a custom role and gives it to someone', (
    tester,
  ) async {
    final harness = RolesHarness(signedInAs: 'owner');
    final robot = await start(tester, harness);

    await robot.openRoles();
    await robot.expectFound(const Key('roles.empty'));
    await robot.startNewRole();
    await robot.enterRoleName('Hospitality');
    await robot.togglePermission('participants.read');
    await robot.togglePermission('chat.send');
    await robot.saveRole();

    final saved = harness.calls.calls.single;
    expect(saved, startsWith('saveEventRole:hospitality-'));
    expect(saved, endsWith(':Hospitality:participants.read,chat.send'));
    await robot.expectTextFound('Hospitality');
    robot.expectHidden(const Key('roles.empty'));

    await robot.back();
    await robot.openMember('sam');
    await robot.toggleRole(saved.split(':')[1]);
    await robot.saveRoles();
    final sam = await harness.firestore.doc('events/evt/members/sam').get();
    expect(sam.data()!['permissions'], contains('participants.read'));
    await robot.finish();
  });

  testWidgets('an owner edits a preset for this event and can reset it', (
    tester,
  ) async {
    final harness = RolesHarness(signedInAs: 'owner');
    final robot = await start(tester, harness);

    await robot.openRoles();
    await robot.openRole('volunteer');
    await robot.togglePermission('counts.read');
    await robot.saveRole();
    expect(
      harness.calls.calls.last,
      startsWith('saveEventRole:volunteer:Volunteer:'),
    );
    await robot.expectTextFound('7 permissions · Edited');

    await robot.openRole('volunteer');
    await robot.tap(const Key('roles.editor.remove'));
    await robot.tap(const Key('roles.editor.removeConfirm'));
    expect(harness.calls.calls.last, 'deleteEventRole:volunteer');
    await robot.finish();
  });

  testWidgets('works at desktop width', (tester) async {
    final harness = RolesHarness(signedInAs: 'owner');
    final robot = await start(tester, harness, size: const Size(1400, 900));
    await robot.openRoles();
    robot.expectVisible(const Key('roles.tile.owner'));
    expect(tester.takeException(), isNull);
    await robot.finish();
  });
}
