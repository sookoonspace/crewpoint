import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #70 (Req 32, 35; WE-08, H-05): the UI half of the role matrix. Every
/// preset in the Req 26a table, signed in as `me`, against the event hub,
/// tasks, budget and chat. Vendors and Observers see only tasks assigned to
/// them and expenses they share in, and add neither, and chat needs
/// `chat.send`. The rules half is `functions/test/roleMatrix.test.ts`.
void main() {
  final presets = resolveRoles(RoleCatalogue.current, const {});
  final roleIds = [for (final role in presets) role.id];

  late RolesHarness harness;

  Future<RolesRobot> open(WidgetTester tester, String role) async {
    tester.view.physicalSize = const Size(375, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(
      signedInAs: 'me',
      initialLocation: '/dashboard/event/${RolesHarness.eventId}/hub',
    );
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: {
        'owner': const ['owner'],
        'me': [role],
      },
    );
    final db = harness.firestore;
    const e = 'events/${RolesHarness.eventId}';
    Future<void> task(String id, String title, String assignee) =>
        db.doc('$e/tasks/$id').set({
          'eventId': RolesHarness.eventId,
          'title': title,
          'createdBy': 'owner',
          'assigneeId': assignee,
          'status': 'todo',
        });
    await task('mine', 'Hang banners', 'me');
    await task('theirs', 'Book caterer', 'owner');
    Future<void> expense(String id, String what, List<String> people) =>
        db.doc('$e/expenses/$id').set({
          'eventId': RolesHarness.eventId,
          'payerId': 'owner',
          'amount': 40,
          'description': what,
          'isPayment': false,
          'splits': [
            for (final uid in people)
              {'userId': uid, 'amount': 40 / people.length},
          ],
          'involvedUids': people,
        });
    await expense('mine', 'Banner deposit', ['owner', 'me']);
    await expense('theirs', 'Venue hire', ['owner']);
    await tester.pumpWidget(harness.buildApp());
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  for (final role in roleIds) {
    final permissions = presets.firstWhere((r) => r.id == role).permissions;
    final contributes = role != 'observer' && role != 'vendor';
    final allTasks = contributes || permissions.contains('tasks.manage');
    final allExpenses =
        contributes ||
        permissions.contains('money.read') ||
        permissions.contains('expenses.readAll');
    final chat = permissions.contains('chat.send');

    testWidgets('$role sees what the role allows', (tester) async {
      final robot = await open(tester, role);
      final hasChat = find.byKey(const Key('events.hub.chat'));
      expect(hasChat, chat ? findsOneWidget : findsNothing);

      harness.router.go('/dashboard/event/${RolesHarness.eventId}/tasks');
      await robot.finishTransition();
      expect(find.text('Hang banners'), findsOneWidget);
      expect(
        find.text('Book caterer'),
        allTasks ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('tasks.list.create')),
        contributes ? findsOneWidget : findsNothing,
      );

      harness.router.go('/dashboard/event/${RolesHarness.eventId}/budget');
      await robot.finishTransition();
      expect(find.text('Banner deposit'), findsOneWidget);
      expect(
        find.text('Venue hire'),
        allExpenses ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('budget.expense.create')),
        contributes ? findsOneWidget : findsNothing,
      );

      harness.router.go('/dashboard/event/${RolesHarness.eventId}/chat');
      await robot.finishTransition();
      expect(
        find.byKey(const Key('roles.noAccess')),
        chat ? findsNothing : findsOneWidget,
      );
      await robot.finish();
    });
  }

  testWidgets('WE-08 a vendor given chat by the Owner sees it straight away', (
    tester,
  ) async {
    final robot = await open(tester, 'vendor');
    expect(find.byKey(const Key('events.hub.chat')), findsNothing);
    await harness.calls.saveEventRole(
      eventId: RolesHarness.eventId,
      roleId: 'vendor',
      name: 'Vendor',
      permissions: const ['group.readOwn', 'chat.send'],
    );
    await robot.settle();
    expect(find.byKey(const Key('events.hub.chat')), findsOneWidget);
    await robot.finish();
  });
}
