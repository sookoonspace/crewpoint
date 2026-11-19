import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #202 (Spec #186 Req 23): from 840 px Budget is a list and detail. The
/// summary and settle-up stay above the expenses, and the route
/// `budget/:expenseId` opens that expense beside them; narrower, the
/// expense is a page of its own.
void main() {
  late RolesHarness harness;
  const e = 'events/${RolesHarness.eventId}';
  const budget = '/dashboard/event/${RolesHarness.eventId}/budget';
  const wide = Size(1280, 1000);
  const phone = Size(375, 1600);

  final list = find.byKey(const Key('listDetail.list'));
  final panel = find.byKey(const Key('listDetail.panel'));
  final placeholder = find.byKey(const Key('listDetail.placeholder'));

  Future<void> expense(String id, String what, double amount) =>
      harness.firestore.doc('$e/expenses/$id').set({
        'eventId': RolesHarness.eventId,
        'payerId': 'owner',
        'amount': amount,
        'description': what,
        'isPayment': false,
        'splits': [
          {'userId': 'owner', 'amount': amount / 2},
          {'userId': 'sam', 'amount': amount / 2},
        ],
        'involvedUids': ['owner', 'sam'],
      });

  Future<RolesRobot> open(
    WidgetTester tester, {
    String location = budget,
    Size size = wide,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: 'owner', initialLocation: location);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: {
        'owner': const ['owner'],
        'sam': const ['participant'],
      },
    );
    await expense('venue', 'Venue deposit', 200);
    await expense('food', 'Catering advance', 150);
    await tester.pumpWidget(harness.buildApp());
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  String location() => harness.router.routeInformationProvider.value.uri.path;

  bool isSelected(WidgetTester tester, String id) => tester
      .getSemantics(find.byKey(Key('budget.expense.tile.$id')))
      .flagsCollection
      .isSelected
      .toBoolOrNull()!;

  Finder inPanel(Finder f) => find.descendant(of: panel, matching: f);
  final amountInPanel = inPanel(
    find.byKey(const Key('budget.expense.detail.amount')),
  );
  String panelAmount(WidgetTester tester) =>
      tester.widget<Text>(amountInPanel).data!;

  testWidgets('at 1280 px the summary and settle-up stay above the list, '
      'with a quiet prompt until an expense is chosen', (tester) async {
    final robot = await open(tester);
    expect(list, findsOneWidget);
    expect(placeholder, findsOneWidget);
    expect(find.text('Select an expense to see details'), findsOneWidget);
    expect(find.byKey(const Key('budget.total')), findsOneWidget);
    expect(find.byKey(const Key('budget.yourBalance')), findsOneWidget);
    expect(find.byKey(const Key('budget.expense.tile.venue')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('a shared link opens the list with that expense beside it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final robot = await open(tester, location: '$budget/food');
    expect(list, findsOneWidget);
    expect(panelAmount(tester), r'$150.00');
    expect(isSelected(tester, 'food'), isTrue);
    expect(isSelected(tester, 'venue'), isFalse);
    handle.dispose();
    await robot.finish();
  });

  testWidgets('choosing a row changes the panel and keeps the list', (
    tester,
  ) async {
    final robot = await open(tester);
    await robot.tap(const Key('budget.expense.tile.venue'));
    expect(location(), '$budget/venue');
    expect(list, findsOneWidget);
    expect(panelAmount(tester), r'$200.00');

    await robot.tap(const Key('budget.expense.tile.food'));
    expect(location(), '$budget/food');
    expect(panelAmount(tester), r'$150.00');
    await robot.finish();
  });

  testWidgets('editing beside the list: switching with unsaved edits asks '
      'first', (tester) async {
    final robot = await open(tester, location: '$budget/food');
    await robot.tap(const Key('budget.expense.food.overflow'));
    await robot.tap(const Key('budget.expense.food.edit'));
    final amount = find.descendant(
      of: find.byKey(const Key('budget.expense.amount')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(amount, '175');
    await robot.settle();

    await robot.tap(const Key('budget.expense.tile.venue'));
    expect(find.byKey(const Key('listDetail.unsaved.keep')), findsOneWidget);
    await robot.tap(const Key('listDetail.unsaved.keep'));
    expect(location(), '$budget/food');
    expect(tester.widget<EditableText>(amount).controller.text, '175');

    await robot.tap(const Key('budget.expense.tile.venue'));
    await robot.tap(const Key('listDetail.unsaved.discard'));
    expect(location(), '$budget/venue');
    expect(panelAmount(tester), r'$200.00');
    expect(find.byKey(const Key('budget.expense.amount')), findsNothing);
    await robot.finish();
  });

  testWidgets('on a phone the expense is a page of its own', (tester) async {
    final robot = await open(tester, location: '$budget/food', size: phone);
    expect(list, findsNothing);
    expect(find.byKey(const Key('budget.total')), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('budget.expense.detail.amount')))
          .data,
      r'$150.00',
    );
    await robot.finish();
  });

  testWidgets('narrowing the window turns the panel into a full page', (
    tester,
  ) async {
    final robot = await open(tester, location: '$budget/food');
    expect(list, findsOneWidget);
    tester.view.physicalSize = phone;
    await robot.finishTransition();
    expect(list, findsNothing);
    expect(find.byKey(const Key('budget.expense.back')), findsOneWidget);
    await robot.finish();
  });
}
