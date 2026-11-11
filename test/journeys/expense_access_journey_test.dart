import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/expense_access.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #72 (Req 38, 38b, 38d; H-05): the Expense access screen. An Admin picks
/// who reads every expense, sees roles and people by name, and is warned,
/// with a count, before fewer people can see them.
void main() {
  late RolesHarness harness;
  const route = '/dashboard/event/${RolesHarness.eventId}/settings/expenses';

  Future<RolesRobot> open(
    WidgetTester tester, {
    String as = 'owner',
    ExpenseAccess? access,
  }) async {
    tester.view.physicalSize = const Size(375, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: as, initialLocation: route);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: {
        'owner': const ['owner'],
        'books': const ['finance'],
        'lead': const ['crewLead'],
        'sam': const ['participant'],
        'pat': const ['participant'],
        'obs': const ['observer'],
      },
      expenseAccess: access,
    );
    await tester.pumpWidget(harness.buildApp());
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  Future<ExpenseAccess> saved() async {
    final event = await harness.firestore
        .doc('events/${RolesHarness.eventId}')
        .get();
    return ExpenseAccess.fromMap(
      (event.data()?['settings'] as Map?)?['expenseAccess'],
    );
  }

  Future<List<String>> permissionsOf(String uid) async {
    final doc = await harness.firestore
        .doc('events/${RolesHarness.eventId}/members/$uid')
        .get();
    return (doc.data()!['permissions'] as List).cast<String>();
  }

  testWidgets('starts on Everyone, with Observers and Vendors left out', (
    tester,
  ) async {
    final robot = await open(tester);
    expect(
      tester
          .widget<RadioGroup<ExpenseAccessMode>>(
            find.byKey(const Key('expenses.access.options')),
          )
          .groupValue,
      ExpenseAccessMode.everyone,
    );
    final include = tester.widget<SwitchListTile>(
      find.byKey(const Key('expenses.access.includeNonContributors')),
    );
    expect(include.value, isFalse);
    await robot.finish();
  });

  testWidgets(
    'H-05 narrowing to selected roles warns with a count, then saves',
    (tester) async {
      final robot = await open(tester);
      await robot.tap(const Key('expenses.access.option.selected'));
      // Roles and people show by name. Finance already sees everything, so
      // it is not offered.
      expect(find.byKey(const Key('expenses.access.role.crewLead')), findsOne);
      expect(
        find.byKey(const Key('expenses.access.role.finance')),
        findsNothing,
      );
      // People are chosen by name search (Req 43a).
      expect(find.byKey(const Key('expenses.access.person.choose')), findsOne);
      expect(find.byKey(const Key('expenses.access.nobody')), findsOne);
      await robot.tap(const Key('expenses.access.role.crewLead'));
      await robot.pickMembers(const Key('expenses.access.person.choose'), [
        'pat',
      ]);
      robot.expectVisible(const Key('expenses.access.person.pat'));
      await robot.tap(const Key('expenses.access.save'));

      // Only Sam loses access: the lead and Pat were picked.
      expect(find.byKey(const Key('expenses.access.narrowWarning')), findsOne);
      expect(find.textContaining('1 person'), findsOneWidget);
      await robot.tap(const Key('expenses.access.narrowConfirm'));

      expect(
        await saved(),
        const ExpenseAccess(
          mode: ExpenseAccessMode.selected,
          roleIds: ['crewLead'],
          uids: ['pat'],
        ),
      );
      expect(await permissionsOf('sam'), isNot(contains('expenses.readAll')));
      expect(await permissionsOf('pat'), contains('expenses.readAll'));
      expect(find.text('Saved'), findsOneWidget);
      await robot.finish();
    },
  );

  testWidgets('choosing nobody is allowed', (tester) async {
    final robot = await open(tester);
    await robot.tap(const Key('expenses.access.option.selected'));
    await robot.tap(const Key('expenses.access.save'));
    expect(find.textContaining('3 people'), findsOneWidget);
    await robot.tap(const Key('expenses.access.narrowConfirm'));
    expect((await saved()).mode, ExpenseAccessMode.selected);
    // Permission holders keep it.
    expect(await permissionsOf('books'), contains('expenses.readAll'));
    await robot.finish();
  });

  testWidgets('widening saves without a warning', (tester) async {
    final robot = await open(
      tester,
      access: const ExpenseAccess(mode: ExpenseAccessMode.involved),
    );
    await robot.tap(const Key('expenses.access.option.everyone'));
    await robot.tap(const Key('expenses.access.includeNonContributors'));
    await robot.tap(const Key('expenses.access.save'));
    expect(
      find.byKey(const Key('expenses.access.narrowWarning')),
      findsNothing,
    );
    expect(
      await saved(),
      const ExpenseAccess.everyone(includeNonContributors: true),
    );
    expect(await permissionsOf('obs'), contains('expenses.readAll'));
    await robot.finish();
  });

  testWidgets('a failed save explains, keeps the choice, and retries', (
    tester,
  ) async {
    final robot = await open(tester);
    await robot.tap(const Key('expenses.access.option.involved'));
    harness.calls.failNext = Exception('offline');
    await robot.tap(const Key('expenses.access.save'));
    await robot.tap(const Key('expenses.access.narrowConfirm'));
    expect(find.byKey(const Key('expenses.access.error')), findsOneWidget);
    expect((await saved()).mode, ExpenseAccessMode.everyone);
    expect(
      tester
          .widget<RadioGroup<ExpenseAccessMode>>(
            find.byKey(const Key('expenses.access.options')),
          )
          .groupValue,
      ExpenseAccessMode.involved,
    );
    await robot.tap(const Key('expenses.access.save'));
    await robot.tap(const Key('expenses.access.narrowConfirm'));
    expect((await saved()).mode, ExpenseAccessMode.involved);
    await robot.finish();
  });

  testWidgets('leaving with an unsaved choice asks first', (tester) async {
    final robot = await open(tester);
    await robot.tap(const Key('expenses.access.option.involved'));
    await tester.binding.handlePopRoute();
    await robot.settle();
    expect(find.byKey(const Key('roles.discard.confirm')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('needs event.manage', (tester) async {
    final robot = await open(tester, as: 'lead');
    expect(find.byKey(const Key('roles.noAccess')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('fits a 375 px phone at 200% text, in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final robot = await open(tester);
    await robot.tap(const Key('expenses.access.option.selected'));
    // Overflow would have thrown. Every choice is a full-width tile of at
    // least 48 px.
    for (final key in const [
      'expenses.access.option.everyone',
      'expenses.access.role.crewLead',
      'expenses.access.person.choose',
    ]) {
      expect(tester.getSize(find.byKey(Key(key))).height, greaterThan(47));
    }
    expect(tester.takeException(), isNull);
    await robot.finish();
  });
}
