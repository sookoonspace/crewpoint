import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #201 (Spec #186 Req 23): from 840 px Tasks is a list and detail. The
/// route `tasks/:taskId` shows the list with that task beside it;
/// narrower, the task is a page of its own.
void main() {
  late RolesHarness harness;
  const e = 'events/${RolesHarness.eventId}';
  const tasks = '/dashboard/event/${RolesHarness.eventId}/tasks';
  const wide = Size(1280, 1000);
  const phone = Size(375, 1600);

  final list = find.byKey(const Key('listDetail.list'));
  final panel = find.byKey(const Key('listDetail.panel'));
  final placeholder = find.byKey(const Key('listDetail.placeholder'));

  Future<void> task(String id, String title) =>
      harness.firestore.doc('$e/tasks/$id').set({
        'eventId': RolesHarness.eventId,
        'title': title,
        'createdBy': 'owner',
        'status': 'todo',
        'priority': 0,
      });

  Future<RolesRobot> open(
    WidgetTester tester, {
    String location = tasks,
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
    await task('a', 'Book the hall');
    await task('b', 'Print badges');
    await tester.pumpWidget(harness.buildApp());
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  String location() => harness.router.routeInformationProvider.value.uri.path;

  bool isSelected(WidgetTester tester, String id) => tester
      .getSemantics(find.byKey(Key('tasks.tile.$id')))
      .flagsCollection
      .isSelected
      .toBoolOrNull()!;

  /// The task title in the panel's top bar.
  Finder titleInPanel(String title) =>
      find.descendant(of: panel, matching: find.text(title));

  testWidgets('at 1280 px the list shows a quiet prompt until a task is '
      'chosen', (tester) async {
    final robot = await open(tester);
    expect(list, findsOneWidget);
    expect(placeholder, findsOneWidget);
    expect(find.text('Select a task to see details'), findsOneWidget);
    expect(find.byKey(const Key('tasks.tile.a')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('a shared link opens the list with that task beside it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final robot = await open(tester, location: '$tasks/b');
    expect(list, findsOneWidget);
    expect(titleInPanel('Print badges'), findsOneWidget);
    expect(isSelected(tester, 'b'), isTrue);
    expect(isSelected(tester, 'a'), isFalse);
    handle.dispose();
    await robot.finish();
  });

  testWidgets('choosing a row changes the panel and keeps the list', (
    tester,
  ) async {
    final robot = await open(tester);
    await robot.tap(const Key('tasks.tile.a'));
    expect(location(), '$tasks/a');
    expect(list, findsOneWidget);
    expect(titleInPanel('Book the hall'), findsOneWidget);

    await robot.tap(const Key('tasks.tile.b'));
    expect(location(), '$tasks/b');
    expect(titleInPanel('Print badges'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('editing beside the list: switching with unsaved edits asks '
      'first', (tester) async {
    final robot = await open(tester, location: '$tasks/b');
    await robot.tap(const Key('tasks.detail.overflow'));
    await robot.tap(const Key('tasks.detail.overflow.edit'));
    final title = find.descendant(
      of: find.byKey(const Key('tasks.edit.title')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(title, 'Print name badges');
    await robot.settle();

    await robot.tap(const Key('tasks.tile.a'));
    expect(find.byKey(const Key('listDetail.unsaved.keep')), findsOneWidget);
    await robot.tap(const Key('listDetail.unsaved.keep'));
    expect(location(), '$tasks/b');
    expect(
      tester.widget<EditableText>(title).controller.text,
      'Print name badges',
    );

    await robot.tap(const Key('tasks.tile.a'));
    await robot.tap(const Key('listDetail.unsaved.discard'));
    expect(location(), '$tasks/a');
    expect(titleInPanel('Book the hall'), findsOneWidget);
    expect(find.byKey(const Key('tasks.edit.title')), findsNothing);
    await robot.finish();
  });

  testWidgets('the filters stay when a task is chosen', (tester) async {
    final robot = await open(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('tasks.list.search')),
        matching: find.byType(EditableText),
      ),
      'hall',
    );
    await robot.settle();
    expect(find.byKey(const Key('tasks.tile.b')), findsNothing);

    await robot.tap(const Key('tasks.tile.a'));
    expect(location(), '$tasks/a');
    expect(find.byKey(const Key('tasks.tile.b')), findsNothing);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('tasks.list.search')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'hall',
    );
    await robot.finish();
  });

  testWidgets('on a phone the task is a page of its own', (tester) async {
    final robot = await open(tester, location: '$tasks/b', size: phone);
    expect(list, findsNothing);
    expect(find.byKey(const Key('tasks.tile.a')), findsNothing);
    expect(find.text('Print badges'), findsWidgets);
    await robot.finish();
  });

  testWidgets('narrowing the window turns the panel into a full page', (
    tester,
  ) async {
    final robot = await open(tester, location: '$tasks/b');
    expect(list, findsOneWidget);
    tester.view.physicalSize = phone;
    await robot.finishTransition();
    expect(list, findsNothing);
    expect(find.byKey(const Key('tasks.detail.back')), findsOneWidget);
    await robot.finish();
  });
}
