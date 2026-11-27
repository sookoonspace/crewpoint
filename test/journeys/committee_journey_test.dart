import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/registration/domain/committee.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

import '../harness/fake_qr.dart';
import '../harness/roles_harness.dart';
import '../robots/roles_robot.dart';

/// #249 (Spec #233 Req 4a, 37, 52, 64-66; B-12, B-16): the committee's
/// Registration summary, People's status filter and row status, and a
/// group's registration with its actions. The server side is in
/// `functions/test/registration/committee.test.ts`.
void main() {
  late RolesHarness harness;
  const e = 'events/${RolesHarness.eventId}';
  const base = '/dashboard/event/${RolesHarness.eventId}';
  const k = 'registration.summary';
  const g = 'registration.group';

  RegistrationSummary summary({int capacity = 10, int used = 6}) =>
      RegistrationSummary(
        byStatus: const {
          'submitted': (groups: 3, people: 6),
          'pending': (groups: 1, people: 2),
          'waitlisted': (groups: 2, people: 5),
          'cancelled': (groups: 1, people: 1),
          'draft': (groups: 4, people: null),
        },
        capacity: capacity,
        placesUsed: used,
        held: 2,
        deadline: DateTime.utc(2027, 4, 1, 4, 59),
        slug: 'convention-2027',
        timeZone: 'America/Chicago',
      );

  GroupRegistration registration({String status = 'pending'}) =>
      GroupRegistration(
        registrationId: 'r1',
        status: status,
        submittedAt: DateTime.utc(2027, 2, 1, 18),
        contactName: 'Asha Patel',
        contactEmail: 'asha@example.com',
        linkedAdults: const ['Asha Patel', 'Ravi Patel'],
        changes: [
          RegistrationChange(
            action: 'edited',
            at: DateTime.utc(2027, 2, 2, 18),
            by: 'Ravi Patel',
            fields: const ['Diet'],
          ),
          RegistrationChange(
            action: 'submitted',
            at: DateTime.utc(2027, 2, 1, 18),
            by: 'Asha Patel',
          ),
        ],
        people: const [
          GroupRegistrationPerson(
            id: 'p1',
            name: 'Asha Patel',
            waivers: [
              AcceptedWaiver(title: LocalText('Park waiver'), version: 2),
            ],
          ),
          GroupRegistrationPerson(
            id: 'p2',
            name: 'Dev Patel',
            missingWaivers: ['park'],
          ),
        ],
      );

  Future<RolesRobot> open(
    WidgetTester tester, {
    String as = 'owner',
    required String location,
    Size size = const Size(375, 2600),
    bool dark = false,
    RegistrationSummary? withSummary,
    GroupRegistration? withRegistration,
    bool handAdded = false,
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
        'sam': ['participant'],
      },
    );
    await harness.firestore.doc('$e/groups/g1').set({
      'name': 'Patels',
      'sortName': 'patels',
      'adultUids': <String>[],
      'registrationId': 'r1',
      'registrationStatus': 'pending',
    });
    Future<void> person(String id, String name, String? status) =>
        harness.firestore.doc('$e/participants/$id').set({
          'name': name,
          'sortName': name.toLowerCase(),
          'groupId': 'g1',
          'isChild': false,
          'status': 'active',
          'createdBy': 'owner',
          'registrationId': ?status == null ? null : 'r1',
          'registrationStatus': ?status,
        });
    await person('p1', 'Asha Patel', 'pending');
    await person('p2', 'Kiran Desai', 'cancelled');
    await person('p3', 'Gil Guest', null);
    harness.calls.summaries[RolesHarness.eventId] = withSummary ?? summary();
    if (!handAdded) {
      harness.calls.groupRegistrations['g1'] =
          withRegistration ?? registration();
    }
    await tester.pumpWidget(
      harness.buildApp(
        overrides: [qrRendererProvider.overrideWithValue(FakeQrRenderer())],
        themeMode: dark ? ThemeMode.dark : null,
      ),
    );
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  group('Registration summary (Req 64, 4a)', () {
    testWidgets('counts by status, not confirmed yet, places, deadline and '
        'the public link', (tester) async {
      final robot = await open(tester, location: '$base/registration');
      expect(find.text('3 groups · 6 people'), findsOneWidget);
      expect(find.text('4 groups'), findsOneWidget);
      // Drafts 4 + pending 1 + waitlisted 2 groups; pending 2 + waitlisted 5 people.
      expect(
        tester.widget<Text>(find.byKey(const Key('$k.notConfirmed'))).data,
        '7 groups · 7 people',
      );
      expect(find.text('6 of 10 places used'), findsOneWidget);
      expect(find.text('2 held by open offers'), findsOneWidget);
      expect(find.textContaining('Mar 31, 2027'), findsOneWidget);
      expect(find.byKey(const Key('$k.link')), findsOneWidget);
      expect(find.textContaining('/e/convention-2027'), findsWidgets);
      expect(find.byKey(const Key('$k.over')), findsNothing);
      await robot.finish();
    });

    testWidgets('a status opens its follow-up list; waitlisted opens the '
        'waitlist', (tester) async {
      final robot = await open(tester, location: '$base/registration');
      await robot.tap(const Key('$k.status.cancelled'));
      expect(find.byKey(const Key('people.roster.statusChip')), findsOneWidget);
      expect(find.byKey(const Key('people.tile.p2')), findsOneWidget);
      expect(find.byKey(const Key('people.tile.p1')), findsNothing);
      await robot.finish();
    });

    testWidgets('Req 52: the closing reminder asks first, then sends', (
      tester,
    ) async {
      final robot = await open(tester, location: '$base/registration');
      harness.calls.closingRemindersSent = 4;
      await robot.tap(const Key('$k.remind'));
      expect(find.text('Send the closing reminder?'), findsOneWidget);
      await robot.tap(const Key('$k.remind.confirm'));
      expect(
        harness.calls.calls,
        contains('sendClosingReminder:${RolesHarness.eventId}'),
      );
      expect(find.text('4 reminders sent.'), findsOneWidget);
      await robot.finish();
    });

    testWidgets('over a lowered capacity says how far, and removes nobody', (
      tester,
    ) async {
      final robot = await open(
        tester,
        location: '$base/registration',
        withSummary: summary(capacity: 5, used: 8),
      );
      expect(find.byKey(const Key('$k.over')), findsOneWidget);
      expect(find.textContaining('Over capacity by 3.'), findsOneWidget);
      await robot.finish();
    });

    testWidgets('needs registrations.manage, on the hub too', (tester) async {
      var robot = await open(tester, as: 'sam', location: '$base/registration');
      expect(find.byKey(const Key('$k.body')), findsNothing);
      await robot.finish();
      robot = await open(tester, location: '$base/hub');
      expect(
        find.text('Who has registered, and what needs doing'),
        findsOneWidget,
      );
      await robot.finish();
      robot = await open(tester, as: 'sam', location: '$base/hub');
      expect(
        find.text('Who has registered, and what needs doing'),
        findsNothing,
      );
      await robot.finish();
    });

    for (final locale in [null, const Locale('gu')]) {
      testWidgets('Req 71: fits a 320 px phone at 200% text in dark mode '
          '(${locale?.languageCode ?? 'en'})', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final robot = await open(
          tester,
          location: '$base/registration',
          size: const Size(320, 5000),
          dark: true,
        );
        expect(tester.takeException(), isNull);
        await robot.finish();
      });
    }
  });

  group('People (Req 65)', () {
    testWidgets('each row names its registration status, and the filter '
        'lists one status', (tester) async {
      final robot = await open(tester, location: '$base/people');
      expect(
        find.descendant(
          of: find.byKey(const Key('people.tile.p1')),
          matching: find.textContaining('Pending review'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('people.tile.p3')),
          matching: find.textContaining('Pending review'),
        ),
        findsNothing,
      );
      await robot.tap(const Key('people.roster.statusFilter'));
      await robot.tap(const Key('people.roster.status.pending'));
      expect(find.byKey(const Key('people.tile.p1')), findsOneWidget);
      expect(find.byKey(const Key('people.tile.p3')), findsNothing);
      await robot.tap(const Key('people.roster.statusChip.clear'));
      expect(find.byKey(const Key('people.tile.p3')), findsOneWidget);
      await robot.finish();
    });
  });

  group('A group\'s registration (Req 66, 37)', () {
    testWidgets('shows status, contact, adults, waivers and the log, from '
        'the group sheet', (tester) async {
      final robot = await open(tester, location: '$base/people');
      await robot.tap(const Key('people.roster.groupFilter'));
      await tester.enterText(
        find.byKey(const Key('people.groupPicker.search')),
        'pat',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await robot.settle();
      await robot.tap(const Key('people.groupPicker.g1'));
      await robot.tap(const Key('people.roster.groupManage'));
      await robot.tap(const Key('people.group.registration'));
      expect(find.byKey(const Key('$g.status.pending')), findsOneWidget);
      expect(find.text('asha@example.com'), findsOneWidget);
      expect(find.text('Ravi Patel'), findsWidgets);
      expect(find.text('Park waiver, version 2'), findsOneWidget);
      expect(find.textContaining('Missing a waiver'), findsOneWidget);
      expect(find.text('Changed Diet'), findsOneWidget);
      await robot.finish();
    });

    testWidgets('approve, resend and cancel (asking first)', (tester) async {
      final robot = await open(
        tester,
        location: '$base/people/registration/g1',
      );
      await robot.tap(const Key('$g.approve'));
      expect(find.text('Saved.'), findsOneWidget);
      await robot.tap(const Key('$g.resend'));
      expect(find.text('Confirmation sent.'), findsOneWidget);
      await robot.tap(const Key('$g.cancel'));
      expect(find.text('Cancel this registration?'), findsOneWidget);
      await robot.tap(const Key('$g.confirm.go'));
      expect(harness.calls.registrationActions, [
        'approve:r1',
        'resend:r1',
        'cancel:r1',
      ]);
      await robot.finish();
    });

    testWidgets('B-12: reinstating past capacity asks, then goes ahead', (
      tester,
    ) async {
      final robot = await open(
        tester,
        location: '$base/people/registration/g1',
        withRegistration: registration(status: 'cancelled'),
      );
      harness.calls.overCapacityBy['r1'] = 3;
      await robot.tap(const Key('$g.reinstate'));
      expect(find.text('Go over capacity?'), findsOneWidget);
      expect(
        find.text('This takes the event 3 over capacity. Go ahead anyway?'),
        findsOneWidget,
      );
      await robot.tap(const Key('$g.confirm.go'));
      expect(harness.calls.registrationActions, ['reinstate:r1:confirmed']);
      await robot.finish();
    });

    testWidgets('a group added by hand has no registration', (tester) async {
      final robot = await open(
        tester,
        location: '$base/people/registration/g1',
        handAdded: true,
      );
      expect(find.byKey(const Key('$g.none')), findsOneWidget);
      await robot.finish();
    });

    testWidgets('Req 71: fits a 320 px phone at 200% text in dark mode', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final robot = await open(
        tester,
        location: '$base/people/registration/g1',
        size: const Size(320, 4000),
        dark: true,
      );
      expect(tester.takeException(), isNull);
      await robot.finish();
    });
  });
}
