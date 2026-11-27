import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #247 (Spec #233 Req 30, Z-02): the Photo consent screen, for
/// photoConsent.read only: who said no and who has not answered, with a
/// name search, and the note to treat "not answered" as no. The server
/// keeps the list (`functions/test/participants/photoConsent.test.ts`).
void main() {
  late RolesHarness harness;
  const e = 'events/${RolesHarness.eventId}';
  const k = 'people.photoConsent';
  const route = '/dashboard/event/${RolesHarness.eventId}/photo-consent';

  Future<RolesRobot> open(
    WidgetTester tester, {
    String as = 'owner',
    String location = route,
    bool list = true,
    Size size = const Size(375, 1600),
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: as, initialLocation: location);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: const {
        'owner': ['owner'],
        'photographer': ['observer'],
        'sam': ['participant'],
      },
    );
    // The Convention's Photographer: photo consent and their own group only.
    await harness.firestore.doc('$e/members/photographer').update({
      'roleIds': ['photographer'],
      'permissions': ['photoConsent.read', 'group.readOwn'],
    });
    if (list) {
      await harness.firestore.doc('$e/photoConsent/current').set({
        'people': {
          'rohan': {
            'name': 'Rohan Shah',
            'groupName': 'Shah family',
            'ageBand': 'Child',
            'answer': 'no',
          },
          'jaya': {
            'name': 'Jaya Shah',
            'groupName': 'Shah family',
            'ageBand': 'Adult',
            'answer': 'unanswered',
          },
          'kiran': {
            'name': 'Kiran Desai',
            'groupName': 'Desai family',
            'ageBand': 'Adult',
            'answer': 'unanswered',
          },
        },
      });
    }
    await tester.pumpWidget(
      harness.buildApp(themeMode: dark ? ThemeMode.dark : null),
    );
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  testWidgets('Z-02 the photographer sees who said no and who has not '
      'answered, with only name, group and age band', (tester) async {
    final robot = await open(tester, as: 'photographer');
    expect(
      find.text("Treat anyone who hasn't answered yet as a no."),
      findsOneWidget,
    );
    expect(find.text('Said no (1)'), findsOneWidget);
    expect(find.text('Not answered yet (2)'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('$k.saidNo')),
        matching: find.text('Rohan Shah'),
      ),
      findsOneWidget,
    );
    expect(find.text('Shah family · Child'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('$k.search')), 'desai');
    await robot.settle();
    expect(find.text('Kiran Desai'), findsOneWidget);
    expect(find.text('Jaya Shah'), findsNothing);
    expect(find.text('No one by that name.'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('without photoConsent.read there is no screen and no hub entry', (
    tester,
  ) async {
    final robot = await open(tester, as: 'sam');
    expect(find.byKey(const Key('$k.body')), findsNothing);
    expect(find.text('Rohan Shah'), findsNothing);
    await robot.finish();
  });

  testWidgets('before the server has a list, it says when one appears', (
    tester,
  ) async {
    final robot = await open(tester, list: false);
    expect(find.byKey(const Key('$k.notReady')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('the hub shows Photo consent only to those who may read it', (
    tester,
  ) async {
    const hub = '/dashboard/event/${RolesHarness.eventId}/hub';
    var robot = await open(tester, as: 'photographer', location: hub);
    expect(find.text('Photo consent'), findsOneWidget);
    await robot.finish();
    robot = await open(tester, as: 'sam', location: hub);
    expect(find.text('Photo consent'), findsNothing);
    await robot.finish();
  });

  testWidgets('Req 71: fits a 320 px phone at 200% text in dark mode', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final robot = await open(tester, size: const Size(320, 2400), dark: true);
    expect(tester.takeException(), isNull);
    await robot.finish();
  });
}
