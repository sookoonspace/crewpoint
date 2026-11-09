import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #76 (Req 41, 42; GE-04, GAP-WED-14, Z-01): custom fields and categories.
/// An organizer asks for a diet and a private allergy, adds Child and Adult,
/// and the roster filters by both. Categories come from the private birth
/// date, so the roster shows an age band, never the date.
void main() {
  late RolesHarness harness;
  const e = 'events/${RolesHarness.eventId}';
  const base = '/dashboard/event/${RolesHarness.eventId}';

  Future<void> person(
    String id,
    String name, {
    String? groupId,
    String? categoryId,
    Map<String, Object?> fields = const {},
  }) => harness.firestore.doc('$e/participants/$id').set({
    'name': name,
    'sortName': name.toLowerCase(),
    'groupId': groupId,
    'isChild': categoryId == 'child',
    'status': 'active',
    'createdBy': 'owner',
    'categoryId': ?categoryId,
    'fields': fields,
    'filterTags': [
      for (final entry in fields.entries) '${entry.key}=${entry.value}',
    ],
  });

  Future<RolesRobot> open(
    WidgetTester tester, {
    String as = 'owner',
    required String location,
    bool seedFields = true,
    String anaBirthDate = '2008-07-04',
    bool categories = true,
  }) async {
    tester.view.physicalSize = const Size(375, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: as, initialLocation: location);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: {
        'owner': const ['owner'],
        'lead': const ['crewLead'],
        'parent': const ['participant'],
        'plain': const ['participant'],
      },
      groupIds: {
        'parent': const ['f1'],
      },
    );
    final db = harness.firestore;
    // The convention starts on 3 July 2026.
    await db.doc(e).update({
      'startDate': Timestamp.fromDate(DateTime.utc(2026, 7, 3)),
      'dateOnly': true,
      'settings': {
        if (categories)
          'categories': [
            {'id': 'child', 'name': 'Child', 'maxAge': 17, 'isChild': true},
            {'id': 'adult', 'name': 'Adult', 'minAge': 18},
          ],
      },
    });
    await db.doc('$e/groups/f1').set({
      'name': 'Shahs',
      'sortName': 'shahs',
      'adultUids': ['parent'],
    });
    if (seedFields) {
      await db.doc('$e/fields/diet').set({
        'label': 'Diet',
        'type': 'singleChoice',
        'options': ['Jain', 'Veg'],
        'required': true,
        'scope': 'participant',
        'visibility': 'standard',
        'order': 0,
      });
      await db.doc('$e/fields/allergy').set({
        'label': 'Allergy',
        'type': 'text',
        'options': <String>[],
        'required': false,
        'scope': 'participant',
        'visibility': 'private',
        'order': 1,
      });
      await db.doc('$e/fields/hotel').set({
        'label': 'Hotel',
        'type': 'text',
        'options': <String>[],
        'required': false,
        'scope': 'group',
        'visibility': 'standard',
        'order': 2,
      });
    }
    await person(
      'ana',
      'Ana Shah',
      groupId: 'f1',
      categoryId: 'child',
      fields: {'diet': 'Jain'},
    );
    await db.doc('$e/participants/ana/private/details').set({
      'birthDate': anaBirthDate,
      'fields': {'allergy': 'Peanuts'},
    });
    await person(
      'raj',
      'Raj Patel',
      categoryId: 'adult',
      fields: {'diet': 'Veg'},
    );
    await person(
      'gil',
      'Gil Guest',
      categoryId: 'adult',
      fields: {'diet': 'Jain'},
    );
    await tester.pumpWidget(harness.buildApp());
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  Future<Map<String, dynamic>?> doc(String path) async =>
      (await harness.firestore.doc(path).get()).data();

  testWidgets('GE-04 an organizer adds a field, with choices, from the Fields '
      'screen', (tester) async {
    final robot = await open(
      tester,
      location: '$base/fields',
      seedFields: false,
    );
    expect(find.byKey(const Key('fields.empty')), findsOneWidget);
    await robot.tap(const Key('fields.add'));
    await tester.enterText(
      find.byKey(const Key('fields.editor.label')),
      'Meal',
    );
    await robot.tap(const Key('fields.editor.type'));
    await tester.tap(find.text('One choice').last);
    await robot.settle();
    await tester.enterText(
      find.byKey(const Key('fields.editor.options')),
      'Fish\nVeg\n\nVeg',
    );
    await robot.tap(const Key('fields.editor.required'));
    await robot.tap(const Key('fields.editor.save'));
    final saved = await harness.firestore.collection('$e/fields').get();
    final meal = saved.docs.single.data();
    expect(meal['label'], 'Meal');
    expect(meal['type'], 'singleChoice');
    expect(meal['options'], ['Fish', 'Veg']);
    expect(meal['required'], isTrue);
    expect(meal['visibility'], 'standard');
    expect(find.text('Meal'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('an organizer adds Child and Adult in one step', (tester) async {
    final robot = await open(
      tester,
      location: '$base/fields',
      categories: false,
    );
    await robot.tap(const Key('fields.category.preset'));
    final settings = (await doc(e))!['settings'] as Map;
    expect((settings['categories'] as List).map((c) => (c as Map)['id']), [
      'child',
      'adult',
    ]);
    await robot.finish();
  });

  testWidgets('only event.manage opens the Fields screen', (tester) async {
    final robot = await open(tester, as: 'lead', location: '$base/fields');
    expect(find.byKey(const Key('roles.noAccess')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('Z-01 the convention boundary: 17 on the first day is a child', (
    tester,
  ) async {
    final robot = await open(tester, location: '$base/people/ana');
    expect(find.text('Child, from the birth date'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('Z-01 the convention boundary: 18 on the first day is an adult, '
      'and saving stores the band', (tester) async {
    final robot = await open(
      tester,
      location: '$base/people/ana',
      anaBirthDate: '2008-07-03',
    );
    expect(find.text('Adult, from the birth date'), findsOneWidget);
    await robot.tap(const Key('people.edit.save'));
    final ana = (await doc('$e/participants/ana'))!;
    expect(ana['categoryId'], 'adult');
    expect(ana['isChild'], isFalse);
    await robot.finish();
  });

  testWidgets('GAP-WED-14 answers are saved, standard on the person with a '
      'filter tag, private apart', (tester) async {
    final robot = await open(tester, location: '$base/people/raj');
    await robot.tap(const Key('people.answer.diet'));
    await tester.tap(find.text('Jain').last);
    await robot.settle();
    await tester.enterText(
      find.byKey(const Key('people.answer.allergy')),
      'Shellfish',
    );
    await robot.tap(const Key('people.edit.save'));
    final raj = (await doc('$e/participants/raj'))!;
    expect(raj['fields'], {'diet': 'Jain'});
    expect(raj['filterTags'], ['diet=Jain']);
    expect(raj.toString(), isNot(contains('Shellfish')));
    expect(
      ((await doc('$e/participants/raj/private/details'))!['fields']
          as Map)['allergy'],
      'Shellfish',
    );
    await robot.finish();
  });

  testWidgets('a required answer is asked for, and the form is kept', (
    tester,
  ) async {
    final robot = await open(tester, location: '$base/people/new');
    await tester.enterText(
      find.byKey(const Key('people.edit.name')),
      'No Diet',
    );
    await robot.tap(const Key('people.edit.save'));
    expect(find.text('This is required.'), findsOneWidget);
    expect(find.text('No Diet'), findsOneWidget);
    final added = await harness.firestore
        .collection('$e/participants')
        .where('name', isEqualTo: 'No Diet')
        .get();
    expect(added.docs, isEmpty);
    await robot.finish();
  });

  testWidgets('Z-01 the roster shows age bands and filters by category and by '
      'an answer', (tester) async {
    final robot = await open(tester, location: '$base/people');
    expect(
      find.descendant(
        of: find.byKey(const Key('people.tile.ana')),
        matching: find.textContaining('Child'),
      ),
      findsWidgets,
    );
    expect(find.textContaining('2008'), findsNothing);
    await robot.tap(const Key('people.roster.categoryFilter'));
    await tester.tap(find.byKey(const Key('people.roster.category.adult')));
    await robot.settle();
    expect(find.byKey(const Key('people.tile.ana')), findsNothing);
    expect(find.byKey(const Key('people.tile.raj')), findsOneWidget);
    await robot.tap(const Key('people.roster.fieldFilter'));
    await robot.tap(const Key('people.roster.answer.diet=Jain'));
    expect(find.byKey(const Key('people.tile.gil')), findsOneWidget);
    expect(find.byKey(const Key('people.tile.raj')), findsNothing);
    // Private fields never offer a filter.
    await robot.finish();
  });

  testWidgets('Z-01 a crew lead sees standard answers but not private ones', (
    tester,
  ) async {
    final robot = await open(tester, as: 'lead', location: '$base/people/ana');
    expect(find.byKey(const Key('people.answer.diet')), findsOneWidget);
    expect(find.byKey(const Key('people.answer.allergy')), findsNothing);
    expect(find.text('Peanuts'), findsNothing);
    await robot.finish();
  });

  testWidgets('a linked adult answers their group’s questions', (tester) async {
    final robot = await open(tester, as: 'parent', location: '$base/people');
    await robot.tap(const Key('people.roster.ownGroup.f1'));
    await tester.enterText(find.byKey(const Key('people.answer.hotel')), 'Inn');
    await robot.tap(const Key('people.group.saveAnswers'));
    expect(((await doc('$e/groups/f1'))!['fields'] as Map)['hotel'], 'Inn');
    // Answers only: no rename, adults or delete.
    expect(find.byKey(const Key('people.group.rename')), findsNothing);
    await robot.finish();
  });

  testWidgets(
    'the Fields screen fits a 375 px phone at 200% text, in dark mode',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final robot = await open(tester, location: '$base/fields');
      expect(tester.takeException(), isNull);
      await robot.tap(const Key('fields.tile.diet'));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('fields.editor.required'))).height,
        greaterThan(47),
      );
      await robot.finish();
    },
  );
}
