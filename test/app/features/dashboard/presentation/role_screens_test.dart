import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../../../harness/roles_harness.dart';
import '../../../../robots/roles_robot.dart';

/// #67: loading, empty, error, permission-denied and not-found states, and
/// forms that keep their data on failure and ask before discarding it.
void main() {
  Future<(RolesHarness, RolesRobot)> open(
    WidgetTester tester,
    String location, {
    String signedInAs = 'owner',
    Map<String, List<String>>? roles,
    List<Override> overrides = const [],
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = RolesHarness(
      signedInAs: signedInAs,
      initialLocation: '/dashboard/event/evt/$location',
    );
    addTearDown(() async => harness.database.close());
    if (roles == null) {
      await harness.seed();
    } else {
      await harness.seed(roles: roles);
    }
    await tester.pumpWidget(harness.buildApp(overrides: overrides));
    final robot = RolesRobot(tester);
    await robot.settle();
    return (harness, robot);
  }

  const withAdmin = {
    'owner': ['owner'],
    'ana': ['admin'],
    'sam': ['participant'],
  };

  group('Roles', () {
    testWidgets('a Participant is told they cannot open it', (tester) async {
      final (_, robot) = await open(tester, 'roles', signedInAs: 'sam');
      robot.expectVisible(const Key('roles.noAccess'));
      robot.expectHidden(const Key('roles.new'));
      await robot.finish();
    });

    testWidgets('an Admin sees the roles, read-only', (tester) async {
      final (_, robot) = await open(
        tester,
        'roles',
        signedInAs: 'ana',
        roles: withAdmin,
      );
      robot.expectVisible(const Key('roles.readOnly'));
      robot.expectVisible(const Key('roles.tile.owner'));
      robot.expectHidden(const Key('roles.new'));
      await robot.finish();
    });

    testWidgets('shows a spinner while loading', (tester) async {
      final pending = StreamController<List<RoleDefinition>>();
      addTearDown(pending.close);
      final (_, robot) = await open(
        tester,
        'roles',
        overrides: [
          eventRolesProvider.overrideWith((ref, _) => pending.stream),
        ],
      );
      robot.expectVisible(const Key('roles.loading'));
      await robot.finish();
    });

    testWidgets('a failed load offers a retry', (tester) async {
      var attempts = 0;
      final (_, robot) = await open(
        tester,
        'roles',
        overrides: [
          eventRolesProvider.overrideWith((ref, _) {
            attempts++;
            return Stream.error(StateError('offline'));
          }),
        ],
      );
      robot.expectVisible(const Key('roles.loadFailed'));
      await robot.tap(const Key('roles.retry'));
      expect(attempts, 2);
      await robot.finish();
    });

    testWidgets('with no custom roles, says so', (tester) async {
      final (_, robot) = await open(tester, 'roles');
      await robot.expectFound(const Key('roles.empty'));
      await robot.finish();
    });

    testWidgets('fits at 200% text', (tester) async {
      final (_, robot) = await open(tester, 'roles', textScale: 2);
      robot.expectVisible(const Key('roles.tile.owner'));
      expect(tester.takeException(), isNull);
      await robot.finish();
    });
  });

  group('Role editor', () {
    testWidgets('the Owner role is read-only', (tester) async {
      final (_, robot) = await open(tester, 'roles/owner');
      robot.expectVisible(const Key('roles.editor.ownerFixed'));
      robot.expectHidden(const Key('roles.editor.save'));
      robot.expectHidden(const Key('roles.editor.remove'));
      await robot.finish();
    });

    testWidgets('a role that no longer exists says so', (tester) async {
      final (_, robot) = await open(tester, 'roles/gone');
      robot.expectVisible(const Key('roles.gone'));
      await robot.finish();
    });

    testWidgets('a name is required', (tester) async {
      final (harness, robot) = await open(tester, 'roles/new');
      await robot.saveRole();
      robot.expectText('Give the role a name.');
      expect(harness.calls.calls, isEmpty);
      await robot.finish();
    });

    testWidgets('a failed save keeps what was entered, and retry saves it', (
      tester,
    ) async {
      final (harness, robot) = await open(tester, 'roles/new');
      await robot.enterRoleName('Stage crew');
      await robot.togglePermission('tasks.manage');
      harness.calls.failNext = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'offline',
      );
      await robot.saveRole();
      robot.expectText(
        "Couldn't save the role. Your changes are still here, "
        'so try again.',
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('roles.editor.permission.tasks.manage')),
            )
            .value,
        isTrue,
      );
      robot.expectText('Stage crew');

      await robot.saveRole();
      // Both attempts used the same role ID, so a retry never makes two.
      final ids = harness.calls.calls.map((c) => c.split(':')[1]).toSet();
      expect(ids, hasLength(1));
      await robot.finish();
    });

    testWidgets('leaving with unsaved changes asks first', (tester) async {
      final (_, robot) = await open(tester, 'roles/volunteer');
      await robot.togglePermission('counts.read');
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.maybePop());
      await robot.settle();
      robot.expectVisible(const Key('roles.discard.keep'));
      await robot.tap(const Key('roles.discard.keep'));
      robot.expectVisible(const Key('roles.editor.save'));
      await robot.finish();
    });

    testWidgets('deleting a custom role someone holds explains why not', (
      tester,
    ) async {
      final (harness, robot) = await open(tester, 'roles');
      await harness.firestore.doc('events/evt/roles/stage').set({
        'name': 'Stage crew',
        'permissions': ['chat.send'],
        'preset': false,
      });
      await harness.calls.setMemberRoles(
        eventId: 'evt',
        uid: 'sam',
        roleIds: ['stage'],
      );
      await robot.settle();
      await robot.openRole('stage');
      await robot.tap(const Key('roles.editor.remove'));
      await robot.tap(const Key('roles.editor.removeConfirm'));
      robot.expectText(
        "Couldn't delete the role. Take it off everyone who holds it first.",
      );
      await robot.finish();
    });
  });

  group('Member detail', () {
    testWidgets('a Participant cannot open someone else', (tester) async {
      final (_, robot) = await open(tester, 'members/owner', signedInAs: 'sam');
      robot.expectVisible(const Key('roles.noAccess'));
      await robot.finish();
    });

    testWidgets('anyone can see their own roles, read-only', (tester) async {
      final (_, robot) = await open(tester, 'members/sam', signedInAs: 'sam');
      robot.expectVisible(const Key('members.detail.role.participant'));
      expect(find.byType(FilterChip), findsNothing);
      robot.expectHidden(const Key('members.detail.remove'));
      await robot.finish();
    });

    testWidgets('someone no longer in the event is shown as gone', (
      tester,
    ) async {
      final (_, robot) = await open(tester, 'members/left');
      robot.expectVisible(const Key('roles.gone'));
      await robot.finish();
    });

    testWidgets('roles cannot be saved empty', (tester) async {
      final (_, robot) = await open(tester, 'members/sam');
      await robot.toggleRole('participant');
      robot.expectVisible(const Key('members.detail.pickOne'));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('members.detail.save')))
            .onPressed,
        isNull,
      );
      await robot.finish();
    });

    testWidgets('a failed save keeps the choice', (tester) async {
      final (harness, robot) = await open(tester, 'members/sam');
      await robot.toggleRole('volunteer');
      harness.calls.failNext = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'no',
      );
      await robot.saveRoles();
      robot.expectVisible(const Key('members.detail.save'));
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const Key('members.detail.role.volunteer')),
            )
            .selected,
        isTrue,
      );
      await robot.finish();
    });

    testWidgets('an Admin can remove a Participant but not change roles', (
      tester,
    ) async {
      final (harness, robot) = await open(
        tester,
        'members/sam',
        signedInAs: 'ana',
        roles: withAdmin,
      );
      expect(find.byType(FilterChip), findsNothing);
      await robot.tap(const Key('members.detail.remove'));
      await robot.tap(const Key('members.detail.removeConfirm'));
      expect(harness.calls.calls, ['removeMember:sam']);
      await robot.finish();
    });
  });
}
