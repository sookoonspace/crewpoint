import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #78 (Req 46, 14a; X-05): a verified email that matches more than one
/// adult, or only children, waits for an organizer, who picks who the person
/// is or says it is not a match. A linked person with no group sees their own
/// record and nobody else's. A record left by a deleted account shows as
/// unnamed. The server's linking rules are tested in
/// `functions/test/participants/`.
void main() {
  late RolesHarness harness;
  const e = 'events/${RolesHarness.eventId}';
  const base = '/dashboard/event/${RolesHarness.eventId}';

  Future<void> person(
    String id,
    String name, {
    String? groupId,
    bool isChild = false,
    Map<String, Object?> extra = const {},
  }) => harness.firestore.doc('$e/participants/$id').set({
    'name': name,
    'sortName': name.isEmpty ? '' : name.toLowerCase(),
    'groupId': groupId,
    'isChild': isChild,
    'status': 'active',
    'createdBy': 'owner',
    ...extra,
  });

  Future<RolesRobot> open(
    WidgetTester tester, {
    String as = 'owner',
    required String location,
    Size size = const Size(375, 1800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: as, initialLocation: location);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: {
        'owner': const ['owner'],
        'lead': const ['crewLead'],
        'solo': const ['participant'],
      },
    );
    final db = harness.firestore;
    await db.doc('$e/members/solo').update({'participantId': 'pSolo'});
    await db.doc('$e/groups/f1').set({
      'name': 'Patel',
      'sortName': 'patel',
      'adultUids': <String>[],
    });
    await db.doc('$e/groups/f2').set({
      'name': 'Shah',
      'sortName': 'shah',
      'adultUids': <String>[],
    });
    await person('ravi', 'Ravi Patel', groupId: 'f1');
    await person('mira', 'Mira Patel', groupId: 'f1');
    await person('kid', 'Dev Shah', groupId: 'f2', isChild: true);
    await person('pSolo', 'Sol Guest', extra: {'uid': 'solo'});
    await person('anon', '', groupId: 'f1', extra: {'anonymised': true});
    // Two adults share the Patels' email; only a child carries the Shahs'.
    await db.doc('$e/linkRequests/u1').set({
      'uid': 'u1',
      'name': 'R Patel',
      'email': 'home@x.test',
      'participantIds': ['mira', 'ravi'],
      'groupIds': ['f1'],
      'status': 'open',
    });
    await db.doc('$e/linkRequests/u2').set({
      'uid': 'u2',
      'name': null,
      'email': 'shah@x.test',
      'participantIds': ['kid'],
      'groupIds': ['f2'],
      'status': 'open',
    });
    await tester.pumpWidget(harness.buildApp());
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  testWidgets('X-05 the roster tells an organizer who is waiting, and they '
      'link the person to the record they pick', (tester) async {
    final robot = await open(tester, location: '$base/people');
    expect(
      find.text('2 people are waiting to be linked to their records.'),
      findsOneWidget,
    );
    await robot.tap(const Key('people.roster.linkRequests.open'));
    await robot.finishTransition();
    expect(find.text('R Patel · home@x.test'), findsOneWidget);
    // Nothing is linked until someone is picked.
    final link = find.byKey(const Key('links.u1.link'));
    expect(tester.widget<FilledButton>(link).onPressed, isNull);
    await robot.tap(const Key('links.u1.pick.mira'));
    await robot.tap(const Key('links.u1.link'));
    expect(harness.calls.calls, contains('resolveLinkRequest:u1:mira'));
    expect(
      (await harness.firestore.doc('$e/participants/mira').get())
          .data()!['uid'],
      'u1',
    );
    expect(find.byKey(const Key('links.request.u1')), findsNothing);
    await robot.finish();
  });

  testWidgets('with only children matching, the person becomes an adult of '
      'the group; a child is never offered', (tester) async {
    final robot = await open(tester, location: '$base/people/links');
    expect(find.byKey(const Key('links.u2.pick.kid')), findsNothing);
    expect(find.byKey(const Key('links.u2.child.kid')), findsOneWidget);
    await robot.tap(const Key('links.u2.group.f2'));
    await robot.tap(const Key('links.u2.link'));
    expect(harness.calls.calls, contains('resolveLinkRequest:u2:f2'));
    await robot.finish();
  });

  testWidgets('not a match', (tester) async {
    final robot = await open(tester, location: '$base/people/links');
    await robot.tap(const Key('links.u2.dismiss'));
    expect(harness.calls.calls, contains('resolveLinkRequest:u2:dismiss'));
    expect(find.byKey(const Key('links.request.u2')), findsNothing);
    await robot.finish();
  });

  testWidgets('a failed link says so and keeps the choice to try again', (
    tester,
  ) async {
    final robot = await open(tester, location: '$base/people/links');
    await robot.tap(const Key('links.u1.pick.ravi'));
    harness.calls.failNext = Exception('offline');
    await robot.tap(const Key('links.u1.link'));
    expect(find.byKey(const Key('links.u1.error')), findsOneWidget);
    await robot.tap(const Key('links.u1.link'));
    expect(harness.calls.calls, contains('resolveLinkRequest:u1:ravi'));
    await robot.finish();
  });

  testWidgets('a crew lead edits people but cannot see emails, so sees no '
      'requests', (tester) async {
    var robot = await open(tester, as: 'lead', location: '$base/people');
    expect(find.byKey(const Key('people.roster.linkRequests')), findsNothing);
    await robot.finish();
    robot = await open(tester, as: 'lead', location: '$base/people/links');
    expect(find.byKey(const Key('roles.noAccess')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('X-05 a linked person with no group sees their own record, and '
      'nobody else', (tester) async {
    final robot = await open(tester, as: 'solo', location: '$base/people');
    expect(find.byKey(const Key('people.roster.own')), findsOneWidget);
    expect(find.text('Sol Guest'), findsOneWidget);
    expect(find.text('Ravi Patel'), findsNothing);
    await robot.tap(const Key('people.tile.pSolo'));
    await robot.finishTransition();
    expect(find.byKey(const Key('roles.noAccess')), findsNothing);
    expect(find.byKey(const Key('people.edit.readOnly')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('a record left by a deleted account shows as unnamed', (
    tester,
  ) async {
    var robot = await open(tester, location: '$base/people');
    expect(
      find.descendant(
        of: find.byKey(const Key('people.tile.anon')),
        matching: find.text('Unnamed person'),
      ),
      findsOneWidget,
    );
    await robot.finish();
    robot = await open(tester, location: '$base/people/anon');
    expect(find.byKey(const Key('people.edit.unnamed')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('nobody waiting says so', (tester) async {
    final robot = await open(tester, location: '$base/people/links');
    await harness.firestore.doc('$e/linkRequests/u1').delete();
    await harness.firestore.doc('$e/linkRequests/u2').delete();
    await robot.settle();
    expect(find.byKey(const Key('links.empty')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('fits a 375 px phone at 200% text, in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final robot = await open(
      tester,
      location: '$base/people/links',
      size: const Size(375, 3000),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('links.u1.pick.mira'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('links.u1.dismiss'))).height,
      greaterThanOrEqualTo(48),
    );
    await robot.finish();
  });
}
