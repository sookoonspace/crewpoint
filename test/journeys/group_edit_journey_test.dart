import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/connectivity.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';

import '../harness/roles_harness.dart';
import '../robots/group_entry_robot.dart';

class _Online implements IConnectivity {
  @override
  Future<bool> isOnline() async => true;
}

/// Spec #186 Req 26, 37, 39 (#196): a group's linked adult adds people to
/// their own group and changes its answers; organizers change a whole
/// group's answers from the group sheet.
void main() {
  late RolesHarness harness;
  const e = 'events/${RolesHarness.eventId}';
  const people = '/dashboard/event/${RolesHarness.eventId}/people';

  const diet = CustomField(
    id: 'diet',
    label: 'Diet',
    type: FieldType.singleChoice,
    options: ['Veg', 'Jain'],
    required: true,
  );
  const allergies = CustomField(
    id: 'allergies',
    label: 'Allergies',
    type: FieldType.text,
    visibility: FieldVisibility.private,
    order: 1,
  );
  const arriving = CustomField(
    id: 'arriving',
    label: 'Arriving on',
    type: FieldType.singleChoice,
    options: ['Fri', 'Sat'],
    scope: FieldScope.group,
    order: 2,
  );

  Future<GroupEntryRobot> open(
    WidgetTester tester, {
    required String as,
    ThemeMode? themeMode,
  }) async {
    tester.view.physicalSize = const Size(375, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    harness = RolesHarness(signedInAs: as, initialLocation: people);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: {
        'owner': const ['owner'],
        'parent': const ['participant'],
      },
      groupIds: {
        'parent': const ['f1'],
      },
    );
    for (final f in const [diet, allergies, arriving]) {
      await harness.firestore.doc('$e/fields/${f.id}').set(f.toMap());
    }
    await harness.firestore.doc('$e/groups/f1').set({
      'name': 'Shahs',
      'sortName': 'shahs',
      'adultUids': ['parent'],
      'fields': {'arriving': 'Fri'},
    });
    await harness.firestore.doc('$e/participants/ana').set({
      'name': 'Ana Shah',
      'sortName': 'ana shah',
      'groupId': 'f1',
      'isChild': true,
      'status': 'active',
      'createdBy': 'owner',
      'fields': {'diet': 'Veg'},
      'optOuts': ['s1'],
    });
    await harness.firestore.doc('$e/participants/ana/private/details').set({
      'birthDate': '2018-05-01',
      'fields': {'allergies': 'None'},
    });
    await tester.pumpWidget(
      harness.buildApp(
        themeMode: themeMode,
        overrides: [connectivityProvider.overrideWithValue(_Online())],
      ),
    );
    final robot = GroupEntryRobot(tester);
    await robot.settle();
    return robot;
  }

  Future<Map<String, dynamic>?> doc(String path) async =>
      (await harness.firestore.doc(path).get()).data();

  testWidgets('a linked adult adds people to their own group and is never '
      'offered a new group', (tester) async {
    final robot = await open(tester, as: 'parent');
    expect(find.text('Your group'), findsOneWidget);
    expect(find.byKey(const Key('people.roster.groupManage')), findsNothing);
    // "+" adds one person straight away: no "Add {group}".
    await robot.tap(const Key('people.roster.add'));
    await robot.finishTransition();
    expect(find.byKey(const Key('people.roster.addGroup')), findsNothing);
    await robot.back();

    await robot.tap(const Key('people.roster.ownGroup.f1.addPeople'));
    await robot.finishTransition();
    expect(find.text('Add people to Shahs'), findsOneWidget);
    expect(find.byKey(const Key('people.groupEntry.groupName')), findsNothing);
    await robot.namePerson(0, 'Dev Shah');
    await robot.markChild(0);
    await robot.answer(0, 'diet', 'Jain');
    await robot.save();
    await robot.finishTransition();

    expect(find.text('1 person added to Shahs'), findsOneWidget);
    expect(harness.calls.calls, isEmpty);
    final added = await harness.firestore
        .collection('$e/participants')
        .where('name', isEqualTo: 'Dev Shah')
        .get();
    expect(added.docs.single.data()['groupId'], 'f1');
    expect(added.docs.single.data()['createdBy'], 'parent');
    await robot.finish();
  });

  testWidgets("a linked adult changes their group's answers, private ones "
      'included', (tester) async {
    final robot = await open(tester, as: 'parent');
    await robot.tap(const Key('people.roster.ownGroup.f1.editAnswers'));
    await robot.finishTransition();
    expect(find.text('Answers for Shahs'), findsOneWidget);
    // One filled-in card per person, private answers shown.
    expect(find.text('Ana Shah'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    // People already saved are not removed here.
    expect(
      find.byKey(const Key('people.groupEntry.person.0.remove')),
      findsNothing,
    );

    await robot.answerGroup('arriving', 'Sat');
    await robot.answer(0, 'diet', 'Jain');
    await robot.typeAnswer(0, 'allergies', 'Peanuts');
    await robot.save();
    await robot.finishTransition();

    expect(find.text('Answers saved for Shahs'), findsOneWidget);
    final group = await doc('$e/groups/f1');
    expect(group!['fields'], {'arriving': 'Sat'});
    expect(group['adultUids'], ['parent']);
    final ana = await doc('$e/participants/ana');
    expect(ana!['fields'], {'diet': 'Jain'});
    expect(ana['optOuts'], ['s1']);
    expect(ana['createdBy'], 'owner');
    final private = await doc('$e/participants/ana/private/details');
    expect(private!['fields'], {'allergies': 'Peanuts'});
    expect(private['birthDate'], '2018-05-01');
    await robot.finish();
  });

  testWidgets("an organizer changes a group's answers from its sheet", (
    tester,
  ) async {
    final robot = await open(tester, as: 'owner');
    await robot.tap(const Key('people.roster.groupFilter'));
    await robot.tap(const Key('people.groupPicker.f1'));
    await robot.tap(const Key('people.roster.groupManage'));
    await robot.tap(const Key('people.group.editAnswers'));
    await robot.finishTransition();

    expect(find.text('Answers for Shahs'), findsOneWidget);
    await robot.answer(0, 'diet', 'Jain');
    // Someone new can join while answering.
    await robot.addPerson();
    await robot.namePerson(1, 'Mira Shah');
    await robot.answer(1, 'diet', 'Veg');
    await robot.save();
    await robot.finishTransition();

    expect(find.text('Answers saved for Shahs'), findsOneWidget);
    expect((await doc('$e/participants/ana'))!['fields'], {'diet': 'Jain'});
    final mira = await harness.firestore
        .collection('$e/participants')
        .where('name', isEqualTo: 'Mira Shah')
        .get();
    expect(mira.docs.single.data()['groupId'], 'f1');
    // The group itself is unchanged: no rename and no new adults.
    expect(harness.calls.calls, isEmpty);
    await robot.finish();
  });

  testWidgets("a linked adult's People and answers work at 375 px, 200% "
      'text, in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final robot = await open(tester, as: 'parent', themeMode: ThemeMode.dark);
    expect(tester.takeException(), isNull);
    for (final key in const [
      'people.roster.ownGroup.f1.addPeople',
      'people.roster.ownGroup.f1.editAnswers',
    ]) {
      await robot.reveal(find.byKey(Key(key)));
      expect(
        tester.getSize(find.byKey(Key(key))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
    await robot.tap(const Key('people.roster.ownGroup.f1.editAnswers'));
    await robot.finishTransition();
    await robot.reveal(find.byKey(const Key('people.groupEntry.save')));
    expect(tester.takeException(), isNull);
    await robot.finish();
  });
}
