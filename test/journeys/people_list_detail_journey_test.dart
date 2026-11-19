import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #200 (Spec #186 Req 23): from 840 px People is a list and detail. The
/// route `people/:participantId` shows the roster with that person beside
/// it; narrower, the person is a page of their own.
void main() {
  late RolesHarness harness;
  const e = 'events/${RolesHarness.eventId}';
  const people = '/dashboard/event/${RolesHarness.eventId}/people';
  const wide = Size(1280, 1000);
  const phone = Size(375, 1600);

  final list = find.byKey(const Key('listDetail.list'));
  final panel = find.byKey(const Key('listDetail.panel'));
  final placeholder = find.byKey(const Key('listDetail.placeholder'));
  final name = find.byKey(const Key('people.edit.name'));

  Future<void> person(String id, String name, {String? groupId}) =>
      harness.firestore.doc('$e/participants/$id').set({
        'name': name,
        'sortName': name.toLowerCase(),
        'groupId': groupId,
        'isChild': false,
        'status': 'active',
        'createdBy': 'owner',
      });

  Future<RolesRobot> open(
    WidgetTester tester, {
    String location = people,
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
      },
    );
    await harness.firestore.doc('$e/groups/f1').set({
      'name': 'Shahs',
      'sortName': 'shahs',
      'adultUids': const <String>[],
    });
    await person('ana', 'Ana Shah', groupId: 'f1');
    await person('raj', 'Raj Patel');
    await tester.pumpWidget(harness.buildApp());
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  String location() => harness.router.routeInformationProvider.value.uri.path;

  bool isSelected(WidgetTester tester, String id) => tester
      .getSemantics(find.byKey(Key('people.tile.$id')))
      .flagsCollection
      .isSelected
      .toBoolOrNull()!;

  String nameShown(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(of: name, matching: find.byType(EditableText)),
      )
      .controller
      .text;

  testWidgets('at 1280 px the list shows a quiet prompt until someone is '
      'chosen', (tester) async {
    final robot = await open(tester);
    expect(list, findsOneWidget);
    expect(placeholder, findsOneWidget);
    expect(find.byKey(const Key('people.tile.ana')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('a shared link opens the roster with that person beside it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final robot = await open(tester, location: '$people/raj');
    expect(list, findsOneWidget);
    expect(find.descendant(of: panel, matching: name), findsOneWidget);
    expect(nameShown(tester), 'Raj Patel');
    expect(isSelected(tester, 'raj'), isTrue);
    expect(isSelected(tester, 'ana'), isFalse);
    handle.dispose();
    await robot.finish();
  });

  testWidgets('choosing a row changes the panel and keeps the list', (
    tester,
  ) async {
    final robot = await open(tester);
    await robot.tap(const Key('people.tile.ana'));
    await robot.settle();
    expect(location(), '$people/ana');
    expect(list, findsOneWidget);
    expect(nameShown(tester), 'Ana Shah');

    await robot.tap(const Key('people.tile.raj'));
    await robot.settle();
    expect(location(), '$people/raj');
    expect(nameShown(tester), 'Raj Patel');
    await robot.finish();
  });

  testWidgets('switching with unsaved edits asks first', (tester) async {
    final robot = await open(tester, location: '$people/raj');
    await tester.enterText(name, 'Raj P.');
    await robot.settle();

    await robot.tap(const Key('people.tile.ana'));
    await robot.settle();
    expect(find.byKey(const Key('listDetail.unsaved.keep')), findsOneWidget);
    await robot.tap(const Key('listDetail.unsaved.keep'));
    await robot.settle();
    expect(location(), '$people/raj');
    expect(nameShown(tester), 'Raj P.');

    await robot.tap(const Key('people.tile.ana'));
    await robot.settle();
    await robot.tap(const Key('listDetail.unsaved.discard'));
    await robot.settle();
    expect(location(), '$people/ana');
    expect(nameShown(tester), 'Ana Shah');
    await robot.finish();
  });

  testWidgets('the search stays when someone is chosen', (tester) async {
    final robot = await open(tester);
    await tester.enterText(
      find.byKey(const Key('people.roster.search')),
      'ana',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await robot.settle();
    expect(find.byKey(const Key('people.tile.raj')), findsNothing);

    await robot.tap(const Key('people.tile.ana'));
    await robot.settle();
    expect(location(), '$people/ana');
    expect(find.byKey(const Key('people.tile.raj')), findsNothing);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('people.roster.search')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'ana',
    );
    await robot.finish();
  });

  testWidgets('on a phone the person is a page of their own', (tester) async {
    final robot = await open(tester, location: '$people/raj', size: phone);
    expect(list, findsNothing);
    expect(find.byKey(const Key('people.tile.ana')), findsNothing);
    expect(nameShown(tester), 'Raj Patel');
    await robot.finish();
  });

  testWidgets('narrowing the window turns the panel into a full page', (
    tester,
  ) async {
    final robot = await open(tester, location: '$people/raj');
    expect(list, findsOneWidget);
    tester.view.physicalSize = phone;
    await robot.finishTransition();
    expect(list, findsNothing);
    expect(nameShown(tester), 'Raj Patel');
    await robot.finish();
  });
}
