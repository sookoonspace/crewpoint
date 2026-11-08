import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/participants/data/participant_repository.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';

import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// Fails page reads while [failing] is true.
class _FlakyRepository extends ParticipantRepository {
  _FlakyRepository({required super.firestore});

  bool failing = false;
  bool failSave = false;

  @override
  Future<void> save(
    ParticipantModel person, {
    ParticipantPrivate? privateDetails,
  }) {
    if (failSave) throw Exception('offline');
    return super.save(person, privateDetails: privateDetails);
  }

  @override
  Future<RosterPage> fetchPage(
    String eventId,
    RosterQuery q, {
    RosterPage? after,
  }) {
    if (failing) throw Exception('offline');
    return super.fetchPage(eventId, q, after: after);
  }
}

/// #75 (Req 40, 43; PA-05, Z-01): the roster and participant screens. An
/// organizer pages, searches and filters everyone; a linked adult sees and
/// adds to only their own group, children included; others see nothing.
void main() {
  late RolesHarness harness;
  late _FlakyRepository repo;
  const e = 'events/${RolesHarness.eventId}';
  const people = '/dashboard/event/${RolesHarness.eventId}/people';

  Future<void> person(
    String id,
    String name, {
    String? groupId,
    bool child = false,
  }) => harness.firestore.doc('$e/participants/$id').set({
    'name': name,
    'sortName': name.toLowerCase(),
    'groupId': groupId,
    'isChild': child,
    'status': 'active',
    'createdBy': 'owner',
  });

  Future<void> group(
    String id,
    String name, [
    List<String> adults = const [],
  ]) => harness.firestore.doc('$e/groups/$id').set({
    'name': name,
    'sortName': name.toLowerCase(),
    'adultUids': adults,
  });

  Future<RolesRobot> open(
    WidgetTester tester, {
    String as = 'owner',
    String location = people,
    int extra = 0,
    Size size = const Size(375, 1600),
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
        'parent': const ['participant'],
        'plain': const ['participant'],
      },
      groupIds: {
        'parent': const ['f1'],
      },
    );
    await group('f1', 'Shahs', const ['parent']);
    await group('f2', 'Patels');
    await person('ana', 'Ana Shah', groupId: 'f1', child: true);
    await harness.firestore.doc('$e/participants/ana/private/details').set({
      'birthDate': '2020-05-01',
    });
    await person('raj', 'Raj Patel', groupId: 'f2');
    await person('gil', 'Gil Guest');
    for (var i = 0; i < extra; i++) {
      await person('x$i', 'Zed ${i.toString().padLeft(4, '0')}');
    }
    repo = _FlakyRepository(firestore: harness.firestore);
    await tester.pumpWidget(
      harness.buildApp(
        overrides: [participantRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  Future<Map<String, dynamic>?> stored(String id) async =>
      (await harness.firestore.doc('$e/participants/$id').get()).data();

  testWidgets('an organizer pages through everyone, a page at a time', (
    tester,
  ) async {
    final robot = await open(tester, extra: 60);
    expect(find.byKey(const Key('people.roster.online')), findsOneWidget);
    expect(find.byKey(const Key('people.tile.ana')), findsOneWidget);
    expect(find.byKey(const Key('people.tile.ana.child')), findsOneWidget);
    // 63 people: the first page holds 50.
    expect(find.byKey(const Key('people.tile.x46')), findsOneWidget);
    expect(find.byKey(const Key('people.tile.x47')), findsNothing);
    await robot.tap(const Key('people.roster.more'));
    expect(find.byKey(const Key('people.tile.x59')), findsOneWidget);
    expect(find.byKey(const Key('people.roster.more')), findsNothing);
    await robot.finish();
  });

  testWidgets('searches by name and filters by group', (tester) async {
    final robot = await open(tester);
    await tester.enterText(find.byKey(const Key('people.roster.search')), 'ra');
    await tester.pump(const Duration(milliseconds: 400));
    await robot.settle();
    expect(find.byKey(const Key('people.tile.raj')), findsOneWidget);
    expect(find.byKey(const Key('people.tile.ana')), findsNothing);

    await tester.enterText(find.byKey(const Key('people.roster.search')), '');
    await tester.pump(const Duration(milliseconds: 400));
    await robot.tap(const Key('people.roster.groupFilter'));
    await tester.enterText(
      find.byKey(const Key('people.groupPicker.search')),
      'sha',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await robot.settle();
    await robot.tap(const Key('people.groupPicker.f1'));
    expect(find.byKey(const Key('people.roster.groupChip')), findsOneWidget);
    expect(find.byKey(const Key('people.tile.ana')), findsOneWidget);
    expect(find.byKey(const Key('people.tile.gil')), findsNothing);
    await robot.finish();
  });

  testWidgets('Z-01 an organizer adds a child to a group, with a private birth '
      'date', (tester) async {
    final robot = await open(tester, location: '$people/new?group=f2');
    await tester.enterText(
      find.byKey(const Key('people.edit.name')),
      'Mira Patel',
    );
    await robot.tap(const Key('people.edit.child'));
    await robot.tap(const Key('people.edit.birthDate'));
    await tester.tap(find.text('OK'));
    await robot.settle();
    await robot.tap(const Key('people.edit.save'));
    final added = await harness.firestore
        .collection('$e/participants')
        .where('name', isEqualTo: 'Mira Patel')
        .get();
    final saved = added.docs.single.data();
    expect(saved['groupId'], 'f2');
    expect(saved['isChild'], isTrue);
    expect(saved, isNot(contains('birthDate')));
    final private = await added.docs.single.reference
        .collection('private')
        .doc('details')
        .get();
    expect(private.data()?['birthDate'], isNotNull);
    await robot.finish();
  });

  testWidgets('PA-05 someone with no account is added, with no group', (
    tester,
  ) async {
    final robot = await open(tester, location: '$people/new');
    await tester.enterText(
      find.byKey(const Key('people.edit.name')),
      'Walk In',
    );
    await robot.tap(const Key('people.edit.save'));
    final added = await harness.firestore
        .collection('$e/participants')
        .where('name', isEqualTo: 'Walk In')
        .get();
    expect(added.docs.single.data()['groupId'], isNull);
    expect(added.docs.single.data(), isNot(contains('uid')));
    await robot.finish();
  });

  testWidgets('Z-01 a linked adult sees only their own group, and adds a child '
      'to it', (tester) async {
    final robot = await open(tester, as: 'parent');
    expect(find.byKey(const Key('people.tile.ana')), findsOneWidget);
    expect(find.byKey(const Key('people.tile.raj')), findsNothing);
    expect(find.byKey(const Key('people.tile.gil')), findsNothing);
    expect(find.byKey(const Key('people.roster.groupFilter')), findsNothing);

    await robot.tap(const Key('people.roster.add'));
    await robot.finishTransition();
    await tester.enterText(
      find.byKey(const Key('people.edit.name')),
      'Dev Shah',
    );
    await robot.tap(const Key('people.edit.child'));
    // Only their own group can be picked, and no group is not offered.
    expect(find.byKey(const Key('people.edit.groupClear')), findsNothing);
    await robot.tap(const Key('people.edit.group'));
    expect(find.byKey(const Key('people.groupPicker.f1')), findsOneWidget);
    expect(find.byKey(const Key('people.groupPicker.f2')), findsNothing);
    expect(find.byKey(const Key('people.groupPicker.new')), findsNothing);
    await robot.tap(const Key('people.groupPicker.f1'));
    await robot.tap(const Key('people.edit.save'));
    final added = await harness.firestore
        .collection('$e/participants')
        .where('name', isEqualTo: 'Dev Shah')
        .get();
    expect(added.docs.single.data()['groupId'], 'f1');
    expect(added.docs.single.data()['isChild'], isTrue);
    await robot.finish();
  });

  testWidgets('Z-01 a linked adult sees their child’s birth date', (
    tester,
  ) async {
    final robot = await open(tester, as: 'parent', location: '$people/ana');
    expect(find.textContaining('2020-05-01'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('Z-01 a crew lead edits a child without seeing, or wiping, the '
      'birth date', (tester) async {
    final robot = await open(tester, as: 'lead', location: '$people/ana');
    expect(find.textContaining('2020-05-01'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('people.edit.name')),
      'Anaya Shah',
    );
    await robot.tap(const Key('people.edit.save'));
    expect((await stored('ana'))?['name'], 'Anaya Shah');
    final private = await harness.firestore
        .doc('$e/participants/ana/private/details')
        .get();
    expect(private.data()?['birthDate'], '2020-05-01');
    await robot.finish();
  });

  testWidgets('other members cannot browse the roster', (tester) async {
    final robot = await open(tester, as: 'plain');
    expect(find.byKey(const Key('roles.noAccess')), findsOneWidget);
    expect(find.byKey(const Key('people.tile.ana')), findsNothing);
    await robot.finish();
  });

  testWidgets('the hub shows People only to those who may see it', (
    tester,
  ) async {
    final robot = await open(
      tester,
      as: 'plain',
      location: '/dashboard/event/${RolesHarness.eventId}/hub',
    );
    expect(find.byKey(const Key('events.hub.people')), findsNothing);
    await robot.finish();
    final again = await open(
      tester,
      as: 'parent',
      location: '/dashboard/event/${RolesHarness.eventId}/hub',
    );
    expect(find.byKey(const Key('events.hub.people')), findsOneWidget);
    await again.finish();
  });

  testWidgets('without a connection, it says so and tries again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 1600);
    final robot = await open(tester);
    repo.failing = true;
    await robot.tap(const Key('people.roster.groupFilter'));
    await robot.tap(const Key('people.groupPicker.f2'));
    expect(find.byKey(const Key('people.roster.error')), findsOneWidget);
    repo.failing = false;
    await robot.tap(const Key('people.roster.retry'));
    expect(find.byKey(const Key('people.tile.raj')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('a failed save keeps what was typed, and saves on retry', (
    tester,
  ) async {
    final robot = await open(tester, location: '$people/new');
    await tester.enterText(find.byKey(const Key('people.edit.name')), 'Kept');
    repo.failSave = true;
    await robot.tap(const Key('people.edit.save'));
    expect(find.byKey(const Key('people.edit.error')), findsOneWidget);
    expect(find.text('Kept'), findsOneWidget);
    repo.failSave = false;
    await robot.tap(const Key('people.edit.save'));
    final added = await harness.firestore
        .collection('$e/participants')
        .where('name', isEqualTo: 'Kept')
        .get();
    expect(added.docs, hasLength(1));
    await robot.finish();
  });

  testWidgets('stays usable at 5,000 people: one page, and search finds anyone', (
    tester,
  ) async {
    final robot = await open(tester, extra: 5000);
    expect(find.byKey(const Key('people.roster.more')), findsOneWidget);
    expect(find.byKey(const Key('people.tile.x4999')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('people.roster.search')),
      'zed 4999',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await robot.settle();
    expect(find.byKey(const Key('people.tile.x4999')), findsOneWidget);
    await robot.finish();
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('an organizer links an adult to a group, who can then see it', (
    tester,
  ) async {
    final robot = await open(tester);
    await robot.tap(const Key('people.roster.groupFilter'));
    await robot.tap(const Key('people.groupPicker.f2'));
    await robot.tap(const Key('people.roster.groupManage'));
    await robot.tap(const Key('people.group.adult.plain'));
    await robot.tap(const Key('people.group.saveAdults'));
    expect(harness.calls.calls, contains('setGroupAdults:f2:plain'));
    final plain = await harness.firestore
        .doc('$e/members/plain')
        .get();
    expect(plain.data()!['groupIds'], ['f2']);
    expect(plain.data()!['permissions'], contains('group.editOwn'));
    await robot.finish();
  });

  testWidgets('leaving with unsaved changes asks first', (tester) async {
    final robot = await open(tester);
    await robot.tap(const Key('people.roster.add'));
    await robot.finishTransition();
    await tester.enterText(
      find.byKey(const Key('people.edit.name')),
      'Half done',
    );
    await robot.settle();
    await tester.binding.handlePopRoute();
    await robot.settle();
    expect(find.byKey(const Key('roles.discard.confirm')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('fits a 375 px phone at 200% text, in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final robot = await open(tester);
    expect(tester.takeException(), isNull);
    harness.router.go('$people/ana');
    await robot.finishTransition();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('people.edit.child'))).height,
      greaterThan(47),
    );
    await robot.finish();
  });
}
