import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/dashboard_harness.dart';
import '../robots/create_event_robot.dart';

/// #90 (Req 64, 65; GE-06): larger templates offer optional follow-up setup
/// that can be skipped, and a person's saved templates come first in the
/// picker, create events, and can be deleted.
void main() {
  late DashboardJourneyHarness harness;
  late CreateEventRobot robot;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1200, 2400),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = DashboardJourneyHarness(
      currentUser: const AppUser(uid: 'host', email: 'host@example.com'),
    );
    addTearDown(() async => harness.database.close());
    await tester.pumpWidget(harness.buildApp());
    robot = CreateEventRobot(tester);
    await robot.settle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'a larger template offers follow-up setup, which can be skipped',
    (tester) async {
      await open(tester);
      await robot.tapCreateFab();
      await robot.chooseTemplate('convention');
      await robot.enterTitle('Reunion 2027');
      await robot.tapSubmit();
      await robot.settle();
      expect(find.byKey(const Key('setup.list')), findsOneWidget);
      for (final step in ['dates', 'venues', 'schedule', 'fields', 'people']) {
        expect(
          find.byKey(Key('setup.step.$step')),
          findsOneWidget,
          reason: step,
        );
      }
      // The template brought its questions, so that step is already done.
      expect(find.byKey(const Key('setup.step.fields.done')), findsOneWidget);
      expect(find.byKey(const Key('setup.step.dates.todo')), findsOneWidget);
      await tester.tap(find.byKey(const Key('setup.skip')));
      await robot.settle();
      expect(find.byKey(const Key('setup.list')), findsNothing);
      await finish(tester);
    },
  );

  testWidgets('Party goes straight back, with no setup', (tester) async {
    await open(tester);
    await robot.tapCreateFab();
    await robot.chooseTemplate('party');
    await robot.enterTitle('Lily turns 7');
    await robot.tapSubmit();
    await robot.settle();
    expect(find.byKey(const Key('setup.list')), findsNothing);
    await finish(tester);
  });

  testWidgets('GE-06 a saved template comes first and creates an event', (
    tester,
  ) async {
    await open(tester);
    await harness.firestore.doc('users/host/templates/ours').set({
      'id': 'ours',
      'version': 1,
      'name': {'en': 'Our cup'},
      'description': {'en': ''},
      'icon': 'bat',
      'fastPath': false,
      'baseTemplateId': 'cricket_tournament',
      'createdAt': Timestamp.now(),
    });
    await robot.tapCreateFab();
    expect(find.text('Your templates'), findsOneWidget);
    await tester.tap(find.byKey(const Key('events.create.mine.ours')));
    await robot.settle();
    await robot.enterTitle('Winter cup');
    await robot.tapSubmit();
    await robot.settle();
    final event = (await harness.firestore.collection('events').get())
        .docs
        .single
        .data();
    expect(event['savedTemplateId'], 'ours');
    expect(event['templateId'], 'cricket_tournament');
    await finish(tester);
  });

  testWidgets('a saved template can be deleted', (tester) async {
    await open(tester);
    await harness.firestore.doc('users/host/templates/old').set({
      'version': 1,
      'name': {'en': 'Old'},
      'createdAt': Timestamp.now(),
    });
    await robot.tapCreateFab();
    await tester.tap(find.byKey(const Key('events.create.mine.old.delete')));
    await robot.settle();
    await tester.tap(find.byKey(const Key('events.create.mine.deleteConfirm')));
    await robot.settle();
    expect(
      (await harness.firestore.doc('users/host/templates/old').get()).exists,
      isFalse,
    );
    expect(find.byKey(const Key('events.create.mine.old')), findsNothing);
    await finish(tester);
  });

  testWidgets('the setup checklist fits a phone at 200% text', (tester) async {
    await open(tester, size: const Size(375, 2400), textScale: 2);
    await robot.tapCreateFab();
    await robot.chooseTemplate('wedding');
    await tester.enterText(
      find.byKey(const Key('createEvent.title')),
      'Asha and Dev',
    );
    await tester.ensureVisible(find.byKey(const Key('createEvent.submit')));
    await robot.tapSubmit();
    await robot.settle();
    expect(find.byKey(const Key('setup.list')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
