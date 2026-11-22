import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/connectivity.dart';
import 'package:crewpoint_app/app/features/participants/data/participant_repository.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/group_draft.dart';

import '../harness/roles_harness.dart';
import '../robots/group_entry_robot.dart';

/// Fails the people batch while [failPeople] is set.
class _FlakyRepository extends ParticipantRepository {
  _FlakyRepository({required super.firestore});

  bool failPeople = false;
  int peopleSaves = 0;

  @override
  Future<void> savePeople(
    String eventId,
    List<PersonRecord> records, {
    List<CustomField> definitions = const [],
    bool writesPrivateOfExisting = true,
  }) {
    peopleSaves++;
    if (failPeople) throw Exception('network');
    return super.savePeople(
      eventId,
      records,
      definitions: definitions,
      writesPrivateOfExisting: writesPrivateOfExisting,
    );
  }
}

/// Online unless told otherwise; with [gate], waits for it before saying.
class _FakeConnectivity implements IConnectivity {
  bool online = true;
  Completer<void>? gate;

  @override
  Future<bool> isOnline() async {
    await gate?.future;
    return online;
  }
}

/// Spec #186 Req 25–36 (#195): an organizer adds a whole group, or people
/// to an existing group, with everyone's answers, in one save that is safe
/// to retry.
void main() {
  late RolesHarness harness;
  late _FlakyRepository repo;
  late _FakeConnectivity connectivity;
  const e = 'events/${RolesHarness.eventId}';
  const people = '/dashboard/event/${RolesHarness.eventId}/people';

  const diet = CustomField(
    id: 'diet',
    label: 'Diet',
    type: FieldType.singleChoice,
    options: ['Veg', 'Jain'],
    required: true,
    order: 0,
  );
  const shirt = CustomField(
    id: 'shirt',
    label: 'T-shirt size',
    type: FieldType.singleChoice,
    options: ['S', 'M'],
    order: 1,
  );
  const allergies = CustomField(
    id: 'allergies',
    label: 'Allergies',
    type: FieldType.text,
    visibility: FieldVisibility.private,
    order: 2,
  );
  const arriving = CustomField(
    id: 'arriving',
    label: 'Arriving on',
    type: FieldType.singleChoice,
    options: ['Fri', 'Sat'],
    scope: FieldScope.group,
    order: 3,
  );

  Future<GroupEntryRobot> open(
    WidgetTester tester, {
    Size size = const Size(375, 2400),
    ThemeMode? themeMode,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    harness = RolesHarness(signedInAs: 'owner', initialLocation: people);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: {
        'owner': const ['owner'],
      },
    );
    for (final f in const [diet, shirt, allergies, arriving]) {
      await harness.firestore.doc('$e/fields/${f.id}').set(f.toMap());
    }
    await harness.firestore.doc('$e/groups/f2').set({
      'name': 'Patels',
      'sortName': 'patels',
      'adultUids': <String>[],
      'fields': {'arriving': 'Sat'},
    });
    repo = _FlakyRepository(firestore: harness.firestore);
    connectivity = _FakeConnectivity();
    await tester.pumpWidget(
      harness.buildApp(
        themeMode: themeMode,
        overrides: [
          participantRepositoryProvider.overrideWithValue(repo),
          connectivityProvider.overrideWithValue(connectivity),
        ],
      ),
    );
    final robot = GroupEntryRobot(tester);
    await robot.settle();
    return robot;
  }

  Future<List<Map<String, dynamic>>> peopleIn(String groupId) async {
    final snap = await harness.firestore
        .collection('$e/participants')
        .where('groupId', isEqualTo: groupId)
        .get();
    return [
      for (final d in snap.docs) {...d.data(), 'id': d.id},
    ];
  }

  Future<Map<String, dynamic>?> privateOf(String id) async =>
      (await harness.firestore.doc('$e/participants/$id/private/details').get())
          .data();

  String? newGroupId() {
    final saves = harness.calls.calls.where((c) => c.startsWith('saveGroup:'));
    return saves.isEmpty ? null : saves.first.split(':')[1];
  }

  testWidgets('an organizer adds a new group of several people with their '
      'answers', (tester) async {
    final robot = await open(tester);
    await robot.openNewGroup();
    expect(find.text('New group'), findsOneWidget);
    // It opens with two empty people.
    expect(find.byKey(const Key('people.groupEntry.person.0')), findsOneWidget);
    expect(find.byKey(const Key('people.groupEntry.person.1')), findsOneWidget);

    await robot.nameGroup('Mehta');
    await robot.answerGroup('arriving', 'Fri');
    await robot.namePerson(0, 'Neha Mehta');
    await robot.emailPerson(0, 'neha@example.com');

    // A required answer is missing, so Save points to it and sends nothing.
    await robot.save();
    expect(robot.message(), '1 answer missing');
    expect(find.text('Choose an answer.'), findsOneWidget);
    expect(harness.calls.calls, isEmpty);

    await robot.answer(0, 'diet', 'Veg');
    await robot.answer(0, 'shirt', 'M');
    await robot.typeAnswer(0, 'allergies', 'Peanuts');
    await robot.namePerson(1, 'Kabir Mehta');
    await robot.markChild(1);
    // "Same answers as" copies answers, never name, age or email.
    expect(find.text('Same answers as Neha Mehta'), findsOneWidget);
    await robot.copyPrevious(1);
    await robot.addPerson();
    await robot.namePerson(2, 'Diya Mehta');
    await robot.answer(2, 'diet', 'Jain');
    // A fourth card left empty is ignored.
    await robot.addPerson();
    await robot.save();
    await robot.finishTransition();

    // Back on People, showing the new group.
    expect(find.text('Mehta added with 3 people'), findsOneWidget);
    expect(find.byKey(const Key('people.roster.groupChip')), findsOneWidget);

    final groupId = newGroupId()!;
    expect(harness.calls.calls, ['saveGroup:$groupId:Mehta']);
    final group = await harness.firestore.doc('$e/groups/$groupId').get();
    expect(group.data()!['fields'], {'arriving': 'Fri'});
    expect(group.data()!['adultUids'], isEmpty);

    final saved = {for (final p in await peopleIn(groupId)) p['name']: p};
    expect(
      saved.keys,
      unorderedEquals(['Neha Mehta', 'Kabir Mehta', 'Diya Mehta']),
    );
    final neha = saved['Neha Mehta']!;
    final kabir = saved['Kabir Mehta']!;
    expect(neha['fields'], {'diet': 'Veg', 'shirt': 'M'});
    expect(neha['filterTags'], unorderedEquals(['diet=Veg', 'shirt=M']));
    expect(kabir['fields'], {'diet': 'Veg', 'shirt': 'M'});
    expect(kabir['isChild'], isTrue);
    expect(saved['Diya Mehta']!['fields'], {'diet': 'Jain'});
    expect(
      (await privateOf(neha['id'] as String))!['email'],
      'neha@example.com',
    );
    final kabirPrivate = await privateOf(kabir['id'] as String);
    expect(kabirPrivate!['fields'], {'allergies': 'Peanuts'});
    expect(kabirPrivate.containsKey('email'), isFalse);
    await robot.finish();
  });

  testWidgets('Spec #233 Req 13 a phone is checked on its card, then saved '
      'in E.164', (tester) async {
    final robot = await open(tester);
    await robot.openNewGroup();
    await robot.nameGroup('Mehta');
    await robot.namePerson(0, 'Neha Mehta');
    await robot.answer(0, 'diet', 'Veg');
    await robot.phonePerson(0, '555-0100');
    await robot.save();
    expect(
      find.textContaining('Enter the whole number, with the area code'),
      findsOneWidget,
    );
    expect(harness.calls.calls, isEmpty);

    await robot.phonePerson(0, '214.555.0100');
    // Fixing it clears the error before the next save.
    expect(
      find.textContaining('Enter the whole number, with the area code'),
      findsNothing,
    );
    await robot.save();
    await robot.finishTransition();
    final neha = (await peopleIn(newGroupId()!)).single;
    expect(neha, isNot(contains('phone')));
    expect((await privateOf(neha['id'] as String))!['phone'], '+12145550100');
    await robot.finish();
  });

  testWidgets("adds people to an existing group from the group's sheet", (
    tester,
  ) async {
    final robot = await open(tester);
    await robot.tap(const Key('people.roster.groupFilter'));
    await robot.tap(const Key('people.groupPicker.f2'));
    await robot.tap(const Key('people.roster.groupManage'));
    await robot.tap(const Key('people.group.addPeople'));
    await robot.finishTransition();

    expect(
      find.byKey(const Key('people.groupEntry.groupNameShown')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('people.groupEntry.groupName')), findsNothing);
    await robot.namePerson(0, 'Mina Patel');
    await robot.answer(0, 'diet', 'Veg');
    await robot.save();
    await robot.finishTransition();

    expect(find.text('1 person added to Patels'), findsOneWidget);
    expect(
      harness.calls.calls.where((c) => c.startsWith('saveGroup')),
      isEmpty,
    );
    final added = await peopleIn('f2');
    expect([for (final p in added) p['name']], ['Mina Patel']);
    // The group's own answers were left as they were.
    final group = await harness.firestore.doc('$e/groups/f2').get();
    expect(group.data()!['fields'], {'arriving': 'Sat'});
    await robot.finish();
  });

  testWidgets('a failed batch keeps everything typed, and a retry saves '
      'without duplicates', (tester) async {
    final robot = await open(tester);
    await robot.openNewGroup();
    await robot.nameGroup('Shah');
    await robot.namePerson(0, 'Ravi Shah');
    await robot.answer(0, 'diet', 'Jain');
    repo.failPeople = true;
    await robot.save();

    expect(
      robot.message(),
      "The group is saved, but its people aren't. Everything you typed is "
      'still here, so try again.',
    );
    expect(find.text('Ravi Shah'), findsOneWidget);
    final groupId = newGroupId()!;
    expect(await peopleIn(groupId), isEmpty);

    repo.failPeople = false;
    await robot.save();
    await robot.finishTransition();
    expect(find.text('Shah added with 1 person'), findsOneWidget);
    // The group was created once, and Ravi saved once.
    expect(harness.calls.calls, ['saveGroup:$groupId:Shah']);
    expect(await peopleIn(groupId), hasLength(1));
    await robot.finish();
  });

  testWidgets('offline, Save says so and keeps the draft', (tester) async {
    final robot = await open(tester);
    await robot.openNewGroup();
    await robot.nameGroup('Kapoor');
    await robot.namePerson(0, 'Aarav Kapoor');
    await robot.answer(0, 'diet', 'Veg');
    connectivity.online = false;
    await robot.save();

    expect(robot.message(), "You're offline. Connect to save this group.");
    expect(find.text('Aarav Kapoor'), findsOneWidget);
    expect(harness.calls.calls, isEmpty);
    expect(repo.peopleSaves, 0);
    await robot.finish();
  });

  testWidgets('a second tap on Save does nothing', (tester) async {
    final robot = await open(tester);
    await robot.openNewGroup();
    await robot.nameGroup('Lal');
    await robot.namePerson(0, 'Jai Lal');
    await robot.answer(0, 'diet', 'Veg');
    connectivity.gate = Completer<void>();
    await robot.save();
    // Saving: the button shows progress and ignores taps.
    expect(
      find.descendant(
        of: find.byKey(const Key('people.groupEntry.save')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('people.groupEntry.save')),
      warnIfMissed: false,
    );
    await robot.settle();
    connectivity.gate!.complete();
    await robot.settle();
    await robot.finishTransition();
    expect(
      harness.calls.calls.where((c) => c.startsWith('saveGroup')),
      hasLength(1),
    );
    expect(repo.peopleSaves, 1);
    await robot.finish();
  });

  testWidgets('leaving with something entered asks first', (tester) async {
    final robot = await open(tester);
    await robot.openNewGroup();
    await robot.namePerson(0, 'Half done');
    await tester.binding.handlePopRoute();
    await robot.settle();
    expect(find.byKey(const Key('roles.discard.confirm')), findsOneWidget);
    await robot.tap(const Key('roles.discard.keep'));
    expect(find.text('Half done'), findsOneWidget);

    await robot.tap(const Key('people.groupEntry.close'));
    await robot.tap(const Key('roles.discard.confirm'));
    await robot.finishTransition();
    expect(find.byKey(const Key('people.groupEntry')), findsNothing);
    expect(find.byKey(const Key('people.roster.add')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('closing the dialog and screen with the keyboard up does not '
      'crash (#185)', (tester) async {
    final robot = await open(tester);
    await robot.openNewGroup();
    await robot.nameGroup('Desai');
    // The keyboard is up while typing.
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await robot.settle();
    await robot.tap(const Key('people.groupEntry.close'));
    await robot.tap(const Key('roles.discard.confirm'));
    // The keyboard goes down while the screen closes, rebuilding it.
    for (var i = 0; i < 8; i++) {
      tester.view.viewInsets = FakeViewPadding(bottom: 280.0 - i * 40);
      await tester.pump(const Duration(milliseconds: 40));
    }
    tester.view.resetViewInsets();
    await robot.finishTransition();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('people.groupEntry')), findsNothing);

    // The add menu's sheet closes cleanly too.
    await robot.tap(const Key('people.roster.add'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.binding.handlePopRoute();
    tester.view.resetViewInsets();
    await robot.finishTransition();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('people.roster.addGroup')), findsNothing);
    await robot.finish();
  });

  testWidgets('works at 375 px, 200% text, in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final robot = await open(
      tester,
      size: const Size(375, 1200),
      themeMode: ThemeMode.dark,
    );
    await robot.openNewGroup();
    await robot.nameGroup('Mehta');
    await robot.namePerson(0, 'Neha Mehta');
    await robot.answer(0, 'diet', 'Veg');
    await robot.namePerson(1, 'Kabir Mehta');
    await robot.copyPrevious(1);
    await robot.reveal(find.byKey(const Key('people.groupEntry.addPerson')));
    expect(tester.takeException(), isNull);
    final scaffold = tester.widget<Scaffold>(
      find.ancestor(
        of: find.byKey(const Key('people.groupEntry')),
        matching: find.byType(Scaffold),
      ),
    );
    expect(
      scaffold.backgroundColor ??
          Theme.of(
            tester.element(find.byKey(const Key('people.groupEntry'))),
          ).scaffoldBackgroundColor,
      CpColors.dark.background,
    );
    // Every tap target on the screen is at least 48 px.
    for (final key in const [
      'people.groupEntry.save',
      'people.groupEntry.close',
      'people.groupEntry.person.1.copy',
      'people.groupEntry.person.0.answer.diet.Veg',
    ]) {
      await robot.reveal(find.byKey(Key(key)));
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
    await robot.finish();
  });
}
