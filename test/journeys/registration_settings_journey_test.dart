import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/i18n/script_fonts.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

import '../harness/roles_harness.dart';
import '../harness/system_templates.dart';
import '../robots/roles_robot.dart';

/// #239 (Spec #233 Req 8, 11, 16-19, 60, 67): Event settings → Registration.
/// An organizer chooses who can register, capacity, the deadline, review,
/// the link name, the role for people who register, the form's built-in
/// parts, sections and conditions, and the after-registration note. The
/// server's checks are in `functions/test/registration/`.
void main() {
  late RolesHarness harness;
  const route =
      '/dashboard/event/${RolesHarness.eventId}/settings/registration';
  const k = 'registration.settings';

  Future<RolesRobot> open(
    WidgetTester tester, {
    String as = 'owner',
    Size size = const Size(375, 2400),
    Map<String, Object?>? registration,
    Locale? locale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness = RolesHarness(signedInAs: as, initialLocation: route);
    addTearDown(() async => harness.database.close());
    await harness.seed(
      roles: const {
        'owner': ['owner'],
        'sam': ['participant'],
      },
    );
    final event = harness.firestore.doc('events/${RolesHarness.eventId}');
    await event.update({
      'templateId': 'convention',
      'timeZone': 'America/Chicago',
      'settings': {
        'categories': [
          {'id': 'child', 'name': 'Child', 'maxAge': 17, 'isChild': true},
          {'id': 'adult', 'name': 'Adult', 'minAge': 18},
        ],
        'registration': ?registration,
      },
    });
    Future<void> field(String id, String label, String type, int order) =>
        event.collection('fields').doc(id).set({
          'label': label,
          'type': type,
          'options': type == 'singleChoice' ? ['Veg', 'Jain'] : <String>[],
          'scope': 'participant',
          'visibility': 'standard',
          'order': order,
        });
    await field('diet', 'Diet', 'singleChoice', 0);
    await field('kids', 'Kids activities', 'yesNo', 1);
    await field('shirt', 'T-shirt size', 'text', 2);
    await field('booked', 'Booked a room?', 'yesNo', 3);
    await field('confirmation', 'Confirmation number', 'text', 4);
    await event.collection('roles').doc('player').set({
      'name': 'Player',
      'permissions': ['chat.send', 'group.readOwn'],
    });
    await tester.pumpWidget(
      harness.buildApp(overrides: [systemTemplatesOverride()], locale: locale),
    );
    final robot = RolesRobot(tester);
    await robot.settle();
    return robot;
  }

  Future<RegistrationSettings> saved() async {
    final doc = await harness.firestore
        .doc('events/${RolesHarness.eventId}')
        .get();
    return RegistrationSettings.fromMaps(
      (doc.data()!['settings'] as Map)['registration'],
      null,
    );
  }

  testWidgets("an event with no settings shows its template's: open, with "
      'its sections and conditions', (tester) async {
    final robot = await open(tester);
    final mode = tester.widget<RadioGroup<RegistrationMode>>(
      find.byKey(const Key('$k.mode')),
    );
    expect(mode.groupValue, RegistrationMode.open);
    expect(find.byKey(const Key('$k.section.food')), findsOneWidget);
    expect(find.text('Only Child'), findsOneWidget);
    expect(
      find.text(
        'Not in a section yet: Booked a room?, '
        'Confirmation number',
      ),
      findsOneWidget,
    );
    // Nothing changed, so nothing to save.
    final save = tester.widget<CpButton>(find.byKey(const Key('$k.save')));
    expect(save.onPressed, isNull);
    await robot.finish();
  });

  testWidgets('the organizer sets up registration and saves it all', (
    tester,
  ) async {
    final robot = await open(tester);
    await robot.tap(const Key('$k.mode.invited'));
    await robot.typeInto(const Key('$k.capacity'), '400');
    await robot.typeInto(const Key('$k.included'), 'Lunch and dinner');
    await robot.tap(const Key('$k.review'));
    await robot.typeInto(const Key('$k.extraGuests'), '2');
    await robot.typeInto(const Key('$k.offerHours'), '48');
    // The role for people who register lists only roles that manage
    // nothing.
    await robot.tap(const Key('$k.role'));
    await robot.finishTransition();
    expect(find.byKey(const Key('$k.role.admin')), findsNothing);
    expect(find.byKey(const Key('$k.role.owner')), findsNothing);
    await robot.tap(const Key('$k.role.player'));
    await robot.finishTransition();
    await robot.tap(const Key('$k.block.ageOnly'));
    // A new section holding the hotel questions.
    await robot.tap(const Key('$k.addSection'));
    await robot.typeInto(const Key('$k.section.section1.name'), 'Hotel');
    await robot.tap(const Key('$k.section.section1.addQuestion'));
    await robot.finishTransition();
    await robot.tap(const Key('$k.addQuestion.booked'));
    await robot.finishTransition();
    await robot.tap(const Key('$k.section.section1.addQuestion'));
    await robot.finishTransition();
    await robot.tap(const Key('$k.addQuestion.confirmation'));
    await robot.finishTransition();
    // Confirmation number only when Booked a room? is Yes.
    await robot.tap(const Key('$k.section.section1.question.confirmation'));
    await robot.finishTransition();
    await robot.tap(const Key('$k.condition.booked.yes'));
    await robot.finishTransition();
    expect(find.text('When Booked a room? is Yes'), findsOneWidget);
    await robot.typeInto(
      const Key('$k.afterNote'),
      'Book at hotel.example with code CONV27',
    );
    await robot.tap(const Key('$k.save'));
    await robot.finishTransition();

    expect(harness.calls.calls.last, 'saveRegistrationSettings:invited:400');
    final s = await saved();
    expect(s.mode, RegistrationMode.invited);
    expect(s.review, isTrue);
    expect(s.included?.en, 'Lunch and dinner');
    expect(s.extraGuests, 2);
    expect(s.offerHours, 48);
    expect(s.registrationRoleId, 'player');
    expect(s.has(RegistrationBlock.ageOnly), isTrue);
    expect(s.has(RegistrationBlock.stay), isTrue);
    expect(s.sections.last.name.en, 'Hotel');
    expect(s.sections.last.fieldIds, ['booked', 'confirmation']);
    expect(
      s.conditions['confirmation'],
      const AnswerCondition('booked', 'yes'),
    );
    expect(s.afterNote?.en, 'Book at hotel.example with code CONV27');
    expect(find.text('Registration settings saved.'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('a question others depend on is always shown, and nothing '
      'depends on a question with a condition', (tester) async {
    final robot = await open(
      tester,
      registration: {
        'sections': [
          {
            'id': 'hotel',
            'name': {'en': 'Hotel'},
            'fieldIds': ['booked', 'confirmation', 'kids'],
          },
        ],
        'conditions': {
          'confirmation': {'fieldId': 'booked', 'value': 'yes'},
          'kids': {'categoryId': 'child'},
        },
      },
    );
    await robot.tap(const Key('$k.section.hotel.question.booked'));
    await robot.finishTransition();
    expect(find.byKey(const Key('$k.condition.fixed')), findsOneWidget);
    expect(find.byKey(const Key('$k.condition.category.child')), findsNothing);
    await robot.tap(const Key('$k.condition.everyone'));
    await robot.finishTransition();
    // Kids activities has a condition, so nothing may depend on it.
    await robot.tap(const Key('$k.section.hotel.question.confirmation'));
    await robot.finishTransition();
    expect(find.byKey(const Key('$k.condition.kids.yes')), findsNothing);
    expect(find.byKey(const Key('$k.condition.booked.no')), findsOneWidget);
    await robot.finish();
  });

  testWidgets('sections and questions move, and leave the form', (
    tester,
  ) async {
    final robot = await open(tester);
    await robot.tap(const Key('$k.section.kids.menu'));
    await robot.tap(const Key('$k.section.kids.up'));
    final food = tester.getTopLeft(find.byKey(const Key('$k.section.food')));
    final kids = tester.getTopLeft(find.byKey(const Key('$k.section.kids')));
    expect(kids.dy, lessThan(food.dy));
    await robot.tap(const Key('$k.section.shirts.menu'));
    await robot.tap(const Key('$k.section.shirts.remove'));
    expect(find.byKey(const Key('$k.section.shirts')), findsNothing);
    await robot.tap(const Key('$k.save'));
    await robot.finishTransition();
    final s = await saved();
    expect(s.sections.map((x) => x.id), ['kids', 'food']);
    await robot.finish();
  });

  testWidgets('a replacement note needs its date, and nothing is sent '
      'until it has one', (tester) async {
    final robot = await open(tester);
    await robot.typeInto(
      const Key('$k.laterNote'),
      'The hotel block is closed',
    );
    await robot.tap(const Key('$k.save'));
    expect(
      find.text('Choose the date the replacement note starts.'),
      findsWidgets,
    );
    expect(
      harness.calls.calls,
      isNot(contains(startsWith('saveRegistration'))),
    );
    await robot.typeInto(const Key('$k.offerHours'), '999');
    await robot.tap(const Key('$k.save'));
    expect(find.text('Use a whole number from 1 to 336.'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('Req 11 the link name is claimed at once, and a taken one '
      'says so', (tester) async {
    final robot = await open(tester);
    harness.calls.takenSlugs.add('shah-wedding');
    await robot.typeInto(const Key('$k.slug'), 'Shah-Wedding');
    await robot.tap(const Key('$k.slug.save'));
    expect(
      find.text('Another event already uses this link. Try another.'),
      findsOneWidget,
    );
    await robot.typeInto(const Key('$k.slug'), 'convention 2027');
    await robot.tap(const Key('$k.slug.save'));
    expect(
      find.textContaining('Use 3 to 40 letters, numbers and hyphens'),
      findsOneWidget,
    );
    await robot.typeInto(const Key('$k.slug'), 'Convention-2027');
    await robot.tap(const Key('$k.slug.save'));
    expect(harness.calls.calls.last, 'claimEventSlug:convention-2027');
    expect(
      find.text(
        'Your link: ${AppFlavor.current.legalBaseUrl}/e/convention-2027',
      ),
      findsOneWidget,
    );
    expect((await saved()).slug, 'convention-2027');
    await robot.tap(const Key('$k.slug.remove'));
    expect(harness.calls.calls.last, 'claimEventSlug:null');
    expect(find.text('No link name yet.'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('Save also saves a link name typed but not yet claimed, so '
      'nothing typed is dropped', (tester) async {
    final robot = await open(tester);
    await robot.typeInto(const Key('$k.capacity'), '100');
    await robot.typeInto(const Key('$k.slug'), 'Checks-2026');
    await robot.tap(const Key('$k.save'));
    await robot.finishTransition();

    expect(
      harness.calls.calls,
      containsAllInOrder([
        'saveRegistrationSettings:open:100',
        'claimEventSlug:checks-2026',
      ]),
    );
    expect((await saved()).slug, 'checks-2026');
    expect(
      find.text('Your link: ${AppFlavor.current.legalBaseUrl}/e/checks-2026'),
      findsOneWidget,
    );
    expect(find.text('Registration settings saved.'), findsOneWidget);
    // Everything is saved, so nothing is left to save.
    final save = tester.widget<CpButton>(find.byKey(const Key('$k.save')));
    expect(save.onPressed, isNull);
    await robot.finish();
  });

  testWidgets('a link name typed on its own can be saved with Save, and a '
      'taken one says so and stays to fix', (tester) async {
    final robot = await open(tester);
    harness.calls.takenSlugs.add('shah-wedding');
    await robot.typeInto(const Key('$k.slug'), 'shah-wedding');
    await robot.tap(const Key('$k.save'));
    await robot.finishTransition();
    expect(
      find.text('Another event already uses this link. Try another.'),
      findsOneWidget,
    );
    expect(
      harness.calls.calls,
      isNot(contains(startsWith('saveRegistration'))),
    );
    var save = tester.widget<CpButton>(find.byKey(const Key('$k.save')));
    expect(save.onPressed, isNotNull);

    await robot.typeInto(const Key('$k.slug'), 'shah-2027');
    await robot.tap(const Key('$k.save'));
    await robot.finishTransition();
    expect(harness.calls.calls.last, 'claimEventSlug:shah-2027');
    save = tester.widget<CpButton>(find.byKey(const Key('$k.save')));
    expect(save.onPressed, isNull);
    await robot.finish();
  });

  testWidgets('a deadline chosen by date closes at 11:59 PM in the event\'s '
      'zone, not UTC', (tester) async {
    final robot = await open(tester);
    await robot.tap(const Key('$k.deadline'));
    await robot.finishTransition();
    // The picker opens on this month; choose the 28th.
    await tester.tap(find.text('28'));
    await tester.tap(find.text('OK'));
    await robot.finishTransition();
    await robot.tap(const Key('$k.save'));
    await robot.finishTransition();

    final now = DateTime.now();
    expect(
      (await saved()).deadline?.millisecondsSinceEpoch,
      eventLocalToUtc(
        now.year,
        now.month,
        28,
        'America/Chicago',
        hour: 23,
        minute: 59,
      ).millisecondsSinceEpoch,
    );
    await robot.finish();
  });

  testWidgets('#244: the organizer contact line families see once '
      'registration closes', (tester) async {
    final robot = await open(tester);
    await robot.typeInto(
      const Key('$k.contactLine'),
      'Questions? Call Nilesh at 312-555-0123',
    );
    await robot.tap(const Key('$k.save'));
    await robot.finishTransition();
    expect(
      (await saved()).contactLine?.en,
      'Questions? Call Nilesh at 312-555-0123',
    );
    await robot.finish();
  });

  testWidgets('needs event.manage', (tester) async {
    final robot = await open(tester, as: 'sam');
    expect(find.byKey(const Key('$k.body')), findsNothing);
    expect(find.byKey(const Key('$k.save')), findsNothing);
    await robot.finish();
  });

  testWidgets('fits a 320 px phone at 200% text, in dark mode', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final robot = await open(tester, size: const Size(320, 9000));
    expect(tester.takeException(), isNull);
    for (final key in [
      '$k.mode.open',
      '$k.mode.invited',
      '$k.review',
      '$k.slug.save',
      '$k.role',
      '$k.block.people',
      '$k.addSection',
      '$k.section.food.menu',
      '$k.section.food.question.diet',
      '$k.section.food.question.diet.menu',
      '$k.save',
    ]) {
      expect(
        tester.getSize(find.byKey(Key(key))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
    await robot.finish();
  });

  testWidgets('Req 71 in Gujarati, it fits a 320 px phone at 200% text', (
    tester,
  ) async {
    await tester.runAsync(
      () =>
          const AssetFontLoader().load('NotoSansGujarati', gujaratiFontAssets),
    );
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final robot = await open(
      tester,
      size: const Size(320, 9000),
      locale: const Locale('gu'),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('કોણ નોંધણી કરી શકે'), findsOneWidget);
    expect(find.text('લિંક ધરાવનાર કોઈપણ નોંધણી કરી શકે'), findsOneWidget);
    await robot.finish();
  });

  testWidgets('#246, Req 26, 28: the organizer adds a waiver for a session, '
      'and a changed text is a new version', (tester) async {
    final robot = await open(tester);
    await harness.firestore
        .doc('events/${RolesHarness.eventId}/sessions/park')
        .set({
          'title': 'Water park',
          'startAt': DateTime.utc(2027, 7, 17, 15),
          'hidden': false,
        });
    await robot.settle();
    await robot.reveal(find.byKey(const Key('$k.noWaivers')));
    expect(find.text('No waivers yet.'), findsOneWidget);
    await robot.tap(const Key('$k.addWaiver'));
    expect(find.text('New waiver'), findsOneWidget);
    // Nothing typed: Save says what is missing and sends nothing.
    await robot.tap(const Key('registration.waiver.save'));
    expect(find.text('Add a title.'), findsOneWidget);
    expect(harness.calls.savedWaivers, isEmpty);
    await robot.typeInto(const Key('registration.waiver.title'), 'Park waiver');
    await robot.typeInto(
      const Key('registration.waiver.text'),
      '[PLACEHOLDER: the park waiver text]',
    );
    await robot.tap(const Key('registration.waiver.appliesTo'));
    await robot.tap(const Key('registration.waiver.option.session'));
    await robot.tap(const Key('registration.waiver.save'));
    expect(find.text('Choose who it applies to.'), findsOneWidget);
    await robot.tap(const Key('registration.waiver.target'));
    await robot.tap(const Key('registration.waiver.option.park'));
    await robot.tap(const Key('registration.waiver.required'));
    await robot.tap(const Key('registration.waiver.save'));
    await robot.settle();

    final saved = harness.calls.savedWaivers.single;
    expect(saved['appliesTo'], {'kind': 'session', 'id': 'park'});
    expect(saved['required'], isTrue);
    expect(saved['version'], 1);
    // Back on settings, the waiver is listed.
    await robot.reveal(find.text('Park waiver'));
    expect(
      find.text('Version 1 · Signed up for Water park · Required'),
      findsOneWidget,
    );

    await robot.tap(Key('$k.waiver.${saved['id']}'));
    expect(find.text('Version 1'), findsOneWidget);
    await robot.typeInto(const Key('registration.waiver.text'), 'New words');
    await robot.tap(const Key('registration.waiver.save'));
    await robot.settle();
    expect(harness.calls.savedWaivers.last['version'], 2);
    await robot.finish();
  });
}
