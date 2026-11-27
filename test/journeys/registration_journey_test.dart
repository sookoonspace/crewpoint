import 'package:crewpoint_app/app/features/registration/domain/public_event.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/registration/domain/my_registration.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_form.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';
import 'package:crewpoint_app/app/features/registration/domain/waivers.dart';

import '../harness/sign_in_harness.dart';
import '../robots/registration_robot.dart';

/// #242 (Spec #233 Req 2, 16-21, 25, 33, User Story 1): a family registers
/// on an open event from its page, signing in by email link, through the
/// form's steps, the review and Submit, to the confirmation; and a full
/// event puts the whole group on the waitlist. The server's side is in
/// `functions/test/registration/submitRegistration.test.ts`.
void main() {
  const slug = SignInHarness.slug;
  const k = RegistrationRobot.k;
  const register = '/e/$slug/register';

  final form = RegistrationFormSpec(
    slug: slug,
    title: 'Convention 2027',
    timeZone: 'America/Chicago',
    startDate: DateTime.utc(2027, 7, 16),
    endDate: DateTime.utc(2027, 7, 18),
    dateOnly: true,
    blocks: const {
      RegistrationBlock.people,
      RegistrationBlock.stay,
      RegistrationBlock.sessionChoices,
      RegistrationBlock.contact,
    },
    sections: const [
      RegistrationSection(
        id: 'food',
        name: LocalText('Food'),
        fieldIds: ['diet', 'kids', 'hotel'],
      ),
    ],
    conditions: const {'kids': CategoryCondition('child')},
    categories: const [
      EventCategory(id: 'child', name: 'Child', maxAge: 17, isChild: true),
      EventCategory(id: 'adult', name: 'Adult', minAge: 18),
    ],
    fields: const [
      CustomField(
        id: 'diet',
        label: 'Diet',
        type: FieldType.singleChoice,
        options: ['Veg', 'Jain'],
        required: true,
      ),
      CustomField(
        id: 'kids',
        label: 'Kids activities',
        type: FieldType.yesNo,
        required: true,
      ),
      CustomField(
        id: 'hotel',
        label: 'Hotel',
        type: FieldType.singleChoice,
        options: ['Hilton', 'Marriott'],
        scope: FieldScope.group,
      ),
    ],
    choices: [
      [
        ChoiceSession(
          id: 'park',
          title: 'Park meal',
          startAt: DateTime.utc(2027, 7, 17, 17),
        ),
        ChoiceSession(
          id: 'lunch',
          title: 'Hotel lunch',
          startAt: DateTime.utc(2027, 7, 17, 17, 30),
        ),
      ],
    ],
    labels: const {
      'group': {'one': 'Family', 'other': 'Families'},
    },
  );

  Future<(SignInHarness, RegistrationRobot)> open(
    WidgetTester tester, {
    AuthUser? signedInAs = const AuthUser(
      uid: 'asha',
      email: 'asha@example.com',
    ),
    RegistrationFormSpec? spec,
    Size size = const Size(400, 2400),
    bool dark = false,
    Locale? locale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = SignInHarness(signedInAs: signedInAs);
    // From the event page, so the form below is the one Register loads.
    await h.pump(tester, '/e/$slug', dark: dark, locale: locale);
    h.calls.registrationForms[slug] = spec ?? form;
    if (signedInAs != null) {
      h.router.go(register);
      await h.settle(tester);
    }
    return (h, RegistrationRobot(tester, h));
  }

  /// Fills the whole form for Asha and her son Dev, ending on the review.
  Future<void> fillForm(RegistrationRobot r) async {
    expect(r.progress, 'Step 1 of 6');
    await r.name(0, 'Asha Patel');
    await r.birthDate(0, '03/01/1980');
    await r.addPerson();
    await r.name(1, 'Dev Patel');
    await r.birthDate(1, '05/09/2016');
    // Two people: the group gets a name, in the event's word.
    expect(find.text('Family name'), findsOneWidget);
    await r.type(const Key('$k.groupName'), 'Patel family');
    await r.next();

    expect(r.progress, 'Step 2 of 6');
    await r.chooseForGroup('hotel', 'Hilton');
    await r.choose(0, 'diet', 'Jain');
    await r.choose(1, 'diet', 'Veg');
    // Kids activities is asked of Dev, a child, and not of Asha (Req 18).
    expect(find.byKey(const Key('$k.answer.0.kids')), findsNothing);
    await r.choose(1, 'kids', 'yes');
    await r.next();

    expect(r.progress, 'Step 3 of 6');
    await r.next();

    expect(r.progress, 'Step 4 of 6');
    // The park meal and the hotel lunch are one either/or choice (W-01).
    expect(
      find.text('At the same time: choose one, or neither.'),
      findsNWidgets(2),
    );
    await r.session(0, 'park');
    await r.session(1, 'lunch');
    await r.next();

    expect(r.progress, 'Step 5 of 6');
    await r.type(const Key('$k.phone'), '312 555 0100');
    await r.next();
    expect(r.progress, 'Step 6 of 6');
  }

  testWidgets('User Story 1: a family registers from the event page, '
      'signing in by email link, through review to the confirmation', (
    tester,
  ) async {
    final (h, r) = await open(tester, signedInAs: null);
    await r.tap(const Key('events.page.register'));
    // Signed out: the light sign-in, then the email link opened here.
    await r.type(const Key('auth.light.email'), 'asha@example.com');
    await r.tap(const Key('auth.light.sendLink'));
    h.auth.linkEmails['ok1'] = 'asha@example.com';
    h.router.go(
      '/auth/link?to=${Uri.encodeComponent(register)}&apiKey=k'
      '&oobCode=ok1&mode=signIn&lang=en',
    );
    await h.settle(tester);
    // Let the page transition back to the form finish.
    await tester.pump(const Duration(seconds: 1));
    expect(h.location, register);

    await fillForm(r);
    // The review lists every person and answer, with Edit per step.
    expect(find.text('Asha Patel'), findsWidgets);
    expect(find.text('Dev Patel: Kids activities'), findsOneWidget);
    expect(find.text('Park meal'), findsOneWidget);
    expect(find.text('Hotel lunch'), findsOneWidget);
    await r.tap(const Key('$k.review.people.edit'));
    expect(r.progress, 'Step 1 of 6');
    for (var i = 0; i < 5; i++) {
      await r.next();
    }

    await r.submit();
    // A double tap is one submission (Req 25).
    expect(h.calls.submissions, hasLength(1));
    final sent = h.calls.submissions.single;
    expect(sent['groupName'], 'Patel family');
    expect(sent['groupAnswers'], {'hotel': 'Hilton'});
    expect(sent['contact'], {
      'email': 'asha@example.com',
      'phone': '312 555 0100',
    });
    final people = (sent['people']! as List).cast<Map<String, Object?>>();
    expect(people.first, {
      'name': 'Asha Patel',
      'birthDate': '1980-03-01',
      'answers': {'diet': 'Jain'},
      'signUps': ['park'],
    });
    expect(people.last['answers'], {'diet': 'Veg', 'kids': true});

    expect(find.byKey(const Key('$k.result.submitted')), findsOneWidget);
    expect(find.text("You're registered"), findsOneWidget);
    await r.tap(const Key('$k.result.mine'));
    expect(h.location, '/e/$slug/registration');
    await h.finish(tester);
  });

  testWidgets('Req 21: problems are checked on Submit, beside their fields '
      'with a count at the top, and nothing is sent', (tester) async {
    final (h, r) = await open(tester);
    for (var i = 0; i < 5; i++) {
      await r.next();
    }
    await r.submit();
    expect(h.calls.submissions, isEmpty);
    // Back to the first step with a problem: People.
    expect(r.progress, 'Step 1 of 6');
    expect(find.text('3 things to fix'), findsOneWidget);
    expect(find.text('Enter a name.'), findsOneWidget);
    expect(find.text('Enter a birth date.'), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('Req 2: someone registering alone sees no group words', (
    tester,
  ) async {
    final (h, _) = await open(tester);
    expect(find.text('Family name'), findsNothing);
    await h.finish(tester);
  });

  testWidgets('Req 33: a full event puts the whole group on the waitlist, '
      'with its number', (tester) async {
    final (h, r) = await open(tester);
    h.calls.nextSubmitResult = const SubmitResult(
      registrationId: 'r9',
      status: 'waitlisted',
      waitlistPosition: 4,
    );
    await fillForm(r);
    await r.submit();
    expect(find.byKey(const Key('$k.result.waitlisted')), findsOneWidget);
    expect(find.text("You're on the waitlist, number 4"), findsOneWidget);
    await h.finish(tester);
  });

  testWidgets('someone who has already registered is sent to their '
      'registration', (tester) async {
    final (h, _) = await open(
      tester,
      spec: RegistrationFormSpec(
        slug: slug,
        title: form.title,
        timeZone: form.timeZone,
        registration: const ExistingRegistration(status: 'submitted'),
      ),
    );
    expect(find.byKey(const Key('$k.already')), findsOneWidget);
    await h.finish(tester);
  });

  for (final locale in [null, const Locale('gu')]) {
    testWidgets('Req 71: every step fits a 320 px phone at 200% text in dark '
        'mode (${locale?.languageCode ?? 'en'})', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (h, r) = await open(
        tester,
        size: const Size(320, 2400),
        dark: true,
        locale: locale,
      );
      // With the save indicator showing, offline (#243).
      h.connectivity.online = false;
      await r.addPerson();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(
        find.byKey(const Key('$k.saveState.offline')),
        findsOneWidget,
      );
      for (var step = 0; step < 6; step++) {
        expect(tester.takeException(), isNull, reason: 'step ${step + 1}');
        if (step < 5) await r.next();
      }
      await r.submit();
      expect(tester.takeException(), isNull, reason: 'problems shown');
      await h.finish(tester);
    });
  }

  group('my registration', () {
    MyRegistrationView view({
      String status = 'submitted',
      int? position,
      LocalText? note,
    }) => MyRegistrationView(
      title: 'Convention 2027',
      timeZone: 'America/Chicago',
      registration: MyRegistration(
        status: status,
        waitlistPosition: position,
        submittedAt: DateTime.utc(2026, 12, 1, 18),
        groupName: 'Patel family',
        people: const [
          MyPerson(name: 'Asha Patel', categoryId: 'adult'),
          MyPerson(name: 'Dev Patel', categoryId: 'child'),
        ],
      ),
      note: note,
    );

    testWidgets('after Submit, the family sees its status, who is in it, '
        "and the organizer's note (Req 19, B-07)", (tester) async {
      final (h, r) = await open(tester);
      h.calls.myRegistrations[slug] = view(
        note: const LocalText('Book at hotel.example with code CONV27'),
      );
      await fillForm(r);
      await r.submit();
      await r.tap(const Key('$k.result.mine'));
      expect(h.location, '/e/$slug/registration');
      expect(
        find.byKey(const Key('registration.mine.status.submitted')),
        findsOneWidget,
      );
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Sent Tue, Dec 1, 2026'), findsOneWidget);
      expect(find.text('Patel family'), findsOneWidget);
      expect(find.text('Dev Patel'), findsOneWidget);
      expect(
        find.text('Book at hotel.example with code CONV27'),
        findsOneWidget,
      );
      await h.finish(tester);
    });

    testWidgets('a waitlisted family sees its number and no note', (
      tester,
    ) async {
      final (h, _) = await open(tester);
      h.calls.myRegistrations[slug] = view(status: 'waitlisted', position: 3);
      h.router.go('/e/$slug/registration');
      await h.settle(tester);
      expect(find.text('Waitlisted, number 3'), findsOneWidget);
      expect(
        find.text("If places free up, we'll email you an offer."),
        findsOneWidget,
      );
      expect(find.byKey(const Key('registration.mine.note')), findsNothing);
      await h.finish(tester);
    });

    testWidgets('with no registration yet, it offers Register', (
      tester,
    ) async {
      final (h, r) = await open(tester);
      h.router.go('/e/$slug/registration');
      await h.settle(tester);
      expect(find.byKey(const Key('registration.mine.none')), findsOneWidget);
      await r.tap(const Key('registration.mine.register'));
      expect(h.location, register);
      await h.finish(tester);
    });

    testWidgets('Req 71: fits a 320 px phone at 200% text in dark mode, in '
        'Gujarati', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (h, _) = await open(
        tester,
        size: const Size(320, 2400),
        dark: true,
        locale: const Locale('gu'),
      );
      h.calls.myRegistrations[slug] = view(
        status: 'waitlisted',
        position: 12,
        note: const LocalText('Note', gu: 'નોંધ'),
      );
      h.router.go('/e/$slug/registration');
      await h.settle(tester);
      expect(find.text('રાહ યાદીમાં, નંબર 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.finish(tester);
    });
  });

  group('#243 drafts and connection loss', () {
    /// [form] with a server copy of the form as typed.
    RegistrationFormSpec withServerDraft(
      RegistrationDraft draft,
      DateTime savedAt,
    ) => RegistrationFormSpec(
      slug: form.slug,
      title: form.title,
      timeZone: form.timeZone,
      startDate: form.startDate,
      endDate: form.endDate,
      dateOnly: form.dateOnly,
      blocks: form.blocks,
      sections: form.sections,
      conditions: form.conditions,
      categories: form.categories,
      fields: form.fields,
      choices: form.choices,
      labels: form.labels,
      serverDraft: draft,
      serverDraftSavedAt: savedAt,
    );

    Future<void> pause(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    }

    testWidgets('Req 24: the draft is saved once typing pauses, and on '
        "moving between steps; 'Saved' shows at the top", (tester) async {
      final (h, r) = await open(tester);
      await r.name(0, 'Asha Patel');
      expect(h.calls.savedDrafts, isEmpty);
      await pause(tester);
      expect(find.byKey(const Key('$k.saveState.saved')), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      final people = h.calls.savedDrafts[slug]!.draft['people']! as List;
      expect((people.single as Map)['name'], 'Asha Patel');
      // On the device at once, too (Req 23).
      expect(
        h.drafts.drafts.values.single['draft'],
        isA<Map<String, Object?>>(),
      );

      await r.type(const Key('$k.person.0.name'), 'Asha P');
      await r.next();
      await tester.pump();
      final saved = h.calls.savedDrafts[slug]!.draft['people']! as List;
      expect((saved.single as Map)['name'], 'Asha P');
      await h.finish(tester);
    });

    testWidgets('Req 24, 25: offline, the answers are kept on the device, '
        'the form says so, and Submit explains and sends nothing', (
      tester,
    ) async {
      final (h, r) = await open(tester);
      h.connectivity.online = false;
      await fillForm(r);
      await pause(tester);
      expect(find.text('Not saved yet: no connection'), findsOneWidget);
      expect(h.calls.savedDrafts, isEmpty);
      expect(h.drafts.drafts, isNotEmpty);

      await r.submit();
      expect(
        find.text(
          "You're offline. Your answers are kept; submit when you're back "
          'online.',
        ),
        findsOneWidget,
      );
      expect(h.calls.submissions, isEmpty);

      // Never queued: back online, the family submits themselves.
      h.connectivity.online = true;
      await r.submit();
      expect(h.calls.submissions, hasLength(1));
      expect(find.byKey(const Key('$k.result.submitted')), findsOneWidget);
      // Sent, so the device copy is gone (Req 23).
      expect(h.drafts.drafts, isEmpty);
      await h.finish(tester);
    });

    testWidgets('a draft survives a reload, and a double submit after it is '
        'one registration', (tester) async {
      final (h, r) = await open(tester);
      await fillForm(r);
      final submissionId =
          (h.drafts.drafts.values.single['draft']!
              as Map<String, Object?>)['submissionId'];
      await h.finish(tester);

      // The page reloads: same device, a fresh app.
      final drafts = h.drafts.drafts;
      final (h2, r2) = await open(tester);
      h2.drafts.drafts.addAll(drafts);
      h2.router.go('/e/$slug');
      await h2.settle(tester);
      h2.router.go(register);
      await h2.settle(tester);
      // Back on step 1 with both people and the group's name.
      expect(r2.progress, 'Step 1 of 6');
      expect(find.text('Patel family'), findsOneWidget);
      expect(
        tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const Key('$k.person.1.name')),
            matching: find.byType(EditableText),
          ),
        ).controller.text,
        'Dev Patel',
      );
      for (var i = 0; i < 5; i++) {
        await r2.next();
      }
      await tester.tap(find.byKey(const Key('$k.submit')));
      await tester.tap(find.byKey(const Key('$k.submit')), warnIfMissed: false);
      await h2.settle(tester);
      expect(h2.calls.submissions, hasLength(1));
      expect(h2.calls.submissions.single['submissionId'], submissionId);
      await h2.finish(tester);
    });

    testWidgets("reopening restores the newer of the device's and the "
        "server's drafts", (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = SignInHarness(
        signedInAs: const AuthUser(uid: 'asha', email: 'asha@example.com'),
      );
      await h.pump(tester, '/e/$slug');
      const key = 'registration:$slug:asha';
      h.drafts.drafts[key] = {
        'draft': const RegistrationDraft(
          submissionId: 'phone',
          people: [PersonEntry(name: 'Typed on the phone')],
        ).toMap(),
        'savedAt': DateTime.utc(2026, 11, 20).millisecondsSinceEpoch,
      };
      h.calls.registrationForms[slug] = withServerDraft(
        const RegistrationDraft(
          submissionId: 'laptop',
          people: [PersonEntry(name: 'Typed on the laptop')],
        ),
        DateTime.utc(2026, 11, 21),
      );
      h.router.go(register);
      await h.settle(tester);
      expect(find.text('Typed on the laptop'), findsOneWidget);
      expect(find.byKey(const Key('$k.saveState.saved')), findsOneWidget);
      await h.finish(tester);
    });
  });

  group('#244 edits, the deadline and the change log', () {
    final sat11am = DateTime.utc(2027, 7, 17, 16);
    RegistrationFormSpec editing({
      FormEditable editable = FormEditable.all,
      LocalText? contactLine,
    }) => RegistrationFormSpec(
      slug: form.slug,
      title: form.title,
      timeZone: form.timeZone,
      startDate: form.startDate,
      endDate: form.endDate,
      dateOnly: form.dateOnly,
      blocks: form.blocks,
      sections: form.sections,
      conditions: form.conditions,
      categories: form.categories,
      fields: form.fields,
      choices: form.choices,
      labels: form.labels,
      registration: const ExistingRegistration(status: 'submitted'),
      editable: editable,
      contactLine: contactLine,
      attending: [
        ChoiceSession(
          id: 'M2',
          title: 'Breakfast',
          startAt: DateTime.utc(2027, 7, 17, 13),
        ),
      ],
      current: RegistrationDraft(
        submissionId: 'edit',
        groupName: 'Patel family',
        email: 'asha@example.com',
        groupAnswers: const {'hotel': 'Hilton'},
        people: [
          PersonEntry(
            id: 'p1',
            name: 'Asha Patel',
            birthDate: '1980-03-01',
            answers: const {'diet': 'Jain'},
            arrivalAt: sat11am,
          ),
          const PersonEntry(
            id: 'p2',
            name: 'Dev Patel',
            birthDate: '2016-05-09',
            answers: {'diet': 'Veg', 'kids': true},
          ),
        ],
      ),
    );

    testWidgets('B-06: from my registration, the family changes an answer '
        'and saves; people keep their IDs', (tester) async {
      final (h, r) = await open(tester, spec: editing());
      h.calls.myRegistrations[slug] = const MyRegistrationView(
        title: 'Convention 2027',
        timeZone: 'America/Chicago',
        registration: MyRegistration(
          status: 'submitted',
          people: [MyPerson(name: 'Asha Patel')],
        ),
      );
      h.router.go('/e/$slug/registration');
      await h.settle(tester);
      expect(find.text('Change my registration'), findsOneWidget);
      await r.tap(const Key('registration.mine.change'));
      expect(h.location, register);
      // The form opens on the registration as it stands.
      expect(find.text('Patel family'), findsOneWidget);
      await r.next();
      await r.choose(0, 'diet', 'Veg');
      for (var i = 0; i < 4; i++) {
        await r.next();
      }
      expect(find.text('Save changes'), findsOneWidget);
      await r.submit();
      final sent = h.calls.updates.single;
      final people = (sent['people']! as List).cast<Map<String, Object?>>();
      expect(people.map((p) => p['id']), ['p1', 'p2']);
      expect(people.first['answers'], {'diet': 'Veg'});
      expect(h.calls.submissions, isEmpty);
      expect(find.text('Your changes are saved'), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('B-02, B-03: an arrival time is kept, and switching off '
        'breakfast opts out of it', (tester) async {
      final (h, r) = await open(tester, spec: editing());
      await r.next();
      await r.next();
      // Stay: Saturday, 11:00 AM in Chicago.
      expect(find.text('11:00 AM'), findsOneWidget);
      await r.next();
      expect(find.text("Sessions you'll attend"), findsNWidgets(2));
      await r.tap(const Key('$k.attending.0.M2'));
      await r.next();
      await r.next();
      expect(find.text('Asha Patel: Not attending'), findsOneWidget);
      await r.submit();
      final asha =
          (h.calls.updates.single['people']! as List).first
              as Map<String, Object?>;
      expect(asha['arrivalAt'], sat11am.millisecondsSinceEpoch);
      expect(asha['optOuts'], ['M2']);
      await h.finish(tester);
    });

    testWidgets('Req 32a: adding someone with no room says so, and nothing '
        'changes', (tester) async {
      final (h, r) = await open(tester, spec: editing());
      h.calls.roomFor = 2;
      await r.addPerson();
      await r.name(2, 'Meera Patel');
      await r.birthDate(2, '06/06/1982');
      await r.next();
      await r.choose(2, 'diet', 'Veg');
      for (var i = 0; i < 4; i++) {
        await r.next();
      }
      await r.submit();
      expect(
        find.text(
          "There's no room to add more people. Please contact the organizer.",
        ),
        findsOneWidget,
      );
      expect(h.calls.updates, isEmpty);
      await h.finish(tester);
    });

    testWidgets('B-13: after the deadline only the contact details can '
        'change, with how to reach the organizer', (tester) async {
      final (h, r) = await open(
        tester,
        spec: editing(
          editable: FormEditable.contact,
          contactLine: const LocalText('Questions? Call Nilesh at 312-555-0123'),
        ),
      );
      expect(r.progress, 'Step 1 of 2');
      expect(find.byKey(const Key('$k.contactOnly')), findsOneWidget);
      expect(
        find.text('Questions? Call Nilesh at 312-555-0123'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('$k.person.0.name')), findsNothing);
      await r.type(const Key('$k.email'), 'asha.p@example.com');
      await r.next();
      await r.submit();
      expect(
        (h.calls.updates.single['contact']! as Map)['email'],
        'asha.p@example.com',
      );
      await h.finish(tester);
    });

    testWidgets('B-13: closed to anyone not registered, with the contact '
        'line', (tester) async {
      final (h, _) = await open(tester, signedInAs: null);
      // Leave the event page, so it reads the event again.
      h.router.go('/e/another-event');
      await h.settle(tester);
      h.calls.eventPages[slug] = const PublicEvent(
        state: PublicEventState.closed,
        slug: slug,
        title: 'Convention 2027',
        timeZone: 'America/Chicago',
        mode: RegistrationMode.open,
        contactLine: LocalText('Questions? Call Nilesh at 312-555-0123'),
      );
      h.calls.registrationFormRefusals[slug] = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Registration is closed.',
        details: const {'reason': 'closed'},
      );
      h.auth.setCurrentUser(
        const AuthUser(uid: 'late', email: 'late@example.com'),
      );
      h.router.go(register);
      await h.settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('$k.closed')), findsOneWidget);
      expect(
        find.text('Questions? Call Nilesh at 312-555-0123'),
        findsOneWidget,
      );
      await h.finish(tester);
    });
  });

  group('#246 waivers and consent', () {
    const parkWaiver = Waiver(
      id: 'park',
      title: LocalText('Park waiver'),
      text: LocalText('[PLACEHOLDER: the park waiver text]'),
      appliesTo: WaiverAppliesTo.session('park'),
      required: true,
    );
    final waiverForm = RegistrationFormSpec(
      slug: slug,
      title: 'Convention 2027',
      timeZone: 'America/Chicago',
      startDate: DateTime.utc(2027, 7, 16),
      endDate: DateTime.utc(2027, 7, 18),
      dateOnly: true,
      blocks: const {
        RegistrationBlock.people,
        RegistrationBlock.sessionChoices,
        RegistrationBlock.waivers,
        RegistrationBlock.contact,
      },
      categories: const [
        EventCategory(id: 'child', name: 'Child', maxAge: 17, isChild: true),
        EventCategory(id: 'adult', name: 'Adult', minAge: 18),
      ],
      choices: [
        [
          ChoiceSession(
            id: 'park',
            title: 'Water park',
            startAt: DateTime.utc(2027, 7, 17, 15),
          ),
        ],
      ],
      waivers: const [parkWaiver],
    );

    testWidgets('W-05, Z-03: the contact accepts the park waiver for each '
        'person going, as guardian for a child; Submit waits for it; consent '
        'is asked once', (tester) async {
      final (h, r) = await open(tester, spec: waiverForm);
      expect(r.progress, 'Step 1 of 5');
      await r.name(0, 'Asha Patel');
      await r.birthDate(0, '03/01/1980');
      await r.addPerson();
      await r.name(1, 'Dev Patel');
      await r.birthDate(1, '05/09/2016');
      await r.next();
      await r.session(0, 'park');
      await r.session(1, 'park');
      await r.next();

      expect(r.progress, 'Step 3 of 5');
      expect(find.text('Park waiver'), findsOneWidget);
      expect(find.text('Required to register'), findsOneWidget);
      expect(find.text('I accept for Asha Patel'), findsOneWidget);
      expect(
        find.text("I accept as Dev Patel's parent or guardian"),
        findsOneWidget,
      );
      // The text is behind "Read the waiver".
      expect(find.text('[PLACEHOLDER: the park waiver text]'), findsNothing);
      await r.tap(const Key('$k.waiver.park.read'));
      expect(find.text('[PLACEHOLDER: the park waiver text]'), findsOneWidget);
      await r.acceptWaiver('park', 0);
      await r.next();

      expect(r.progress, 'Step 4 of 5');
      expect(find.text('Announcements'), findsOneWidget);
      await r.tap(const Key('$k.consent.email'));
      await r.next();
      await r.submit();
      // Dev has not accepted: back to the waivers step, nothing sent.
      expect(h.calls.submissions, isEmpty);
      expect(r.progress, 'Step 3 of 5');
      expect(find.text('Please accept this to register.'), findsOneWidget);
      await r.acceptWaiver('park', 1);
      await r.next();
      await r.next();
      expect(find.text('Asha Patel: Park waiver'), findsOneWidget);
      expect(find.text('Accepted'), findsNWidgets(2));
      await r.submit();

      final sent = h.calls.submissions.single;
      final people = (sent['people']! as List).cast<Map<String, Object?>>();
      expect(people.map((p) => p['acceptWaivers']), [
        ['park'],
        ['park'],
      ]);
      expect(sent['consent'], {'email': true, 'sms': false});
      await h.finish(tester);
    });

    for (final locale in [null, const Locale('gu')]) {
      testWidgets('Req 71: the waivers step fits a 320 px phone at 200% text '
          'in dark mode (${locale?.languageCode ?? 'en'})', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final (h, r) = await open(
          tester,
          spec: waiverForm,
          size: const Size(320, 3200),
          dark: true,
          locale: locale,
        );
        await r.addPerson();
        await r.next();
        await r.session(0, 'park');
        await r.session(1, 'park');
        await r.next();
        await r.tap(const Key('$k.waiver.park.read'));
        expect(tester.takeException(), isNull, reason: 'waivers');
        await r.next();
        expect(tester.takeException(), isNull, reason: 'contact and consent');
        await r.next();
        await r.submit();
        expect(tester.takeException(), isNull, reason: 'problems shown');
        await h.finish(tester);
      });
    }

    testWidgets('Z-02 (#247): photos and videos are asked per person, a '
        'guardian answering for a child, and left unanswered until chosen', (
      tester,
    ) async {
      final (h, r) = await open(tester, spec: waiverForm);
      await r.name(0, 'Asha Patel');
      await r.birthDate(0, '03/01/1980');
      await r.addPerson();
      await r.name(1, 'Dev Patel');
      await r.birthDate(1, '05/09/2016');
      await r.addPerson();
      await r.name(2, 'Jaya Patel');
      await r.birthDate(2, '02/02/1950');
      expect(find.text('Photos and videos'), findsNWidgets(3));
      await r.tap(const Key('$k.person.0.photo.yes'));
      await r.tap(const Key('$k.person.1.photo.no'));
      for (var i = 0; i < 4; i++) {
        await r.next();
      }
      expect(r.progress, 'Step 5 of 5');
      expect(find.text('Dev Patel: Photos and videos'), findsOneWidget);
      await r.submit();
      final people = (h.calls.submissions.single['people']! as List)
          .cast<Map<String, Object?>>();
      expect(people.map((p) => p['photoConsent']), [true, false, null]);
      await h.finish(tester);
    });

    testWidgets('someone not signed up for the session is asked nothing', (
      tester,
    ) async {
      final (h, r) = await open(tester, spec: waiverForm);
      await r.name(0, 'Jaya Shah');
      await r.birthDate(0, '02/02/1950');
      await r.next();
      await r.next();
      expect(r.progress, 'Step 3 of 5');
      expect(
        find.text('None of the waivers apply to the people on this form.'),
        findsOneWidget,
      );
      await h.finish(tester);
    });

    testWidgets('W-06: from my registration, the family accepts a waiver '
        'they skipped, even after the deadline', (tester) async {
      final (h, r) = await open(tester);
      h.calls.myRegistrations[slug] = MyRegistrationView(
        title: 'Convention 2027',
        timeZone: 'America/Chicago',
        deadline: DateTime.utc(2026, 1, 1),
        registration: MyRegistration(
          status: 'submitted',
          submittedAt: DateTime.utc(2026, 12, 1, 18),
          people: const [
            MyPerson(id: 'p1', name: 'Asha Patel', categoryId: 'adult'),
            MyPerson(
              id: 'p2',
              name: 'Dev Patel',
              categoryId: 'child',
              isChild: true,
              missingWaivers: ['park'],
            ),
          ],
        ),
        waivers: const [
          Waiver(
            id: 'park',
            title: LocalText('Park waiver'),
            text: LocalText('[PLACEHOLDER]'),
            appliesTo: WaiverAppliesTo.session('park'),
          ),
        ],
      );
      h.router.go('/e/$slug/registration');
      await h.settle(tester);
      expect(find.text('Waivers to accept'), findsOneWidget);
      expect(find.text('I accept for Asha Patel'), findsNothing);
      await r.tap(const Key('registration.mine.acceptWaivers'));
      expect(find.text('Tick at least one to accept.'), findsOneWidget);
      expect(h.calls.acceptedWaivers, isEmpty);
      await r.tap(const Key('registration.mine.waiver.park.accept.1'));
      await r.tap(const Key('registration.mine.acceptWaivers'));
      expect(h.calls.acceptedWaivers, ['p2/park']);
      expect(find.text('Thank you. The waivers are accepted.'), findsOneWidget);
      await h.finish(tester);
    });
  });

  group('#248 waitlist offers', () {
    MyRegistrationView waitlisted({DateTime? offerUntil}) => MyRegistrationView(
      title: 'Convention 2027',
      timeZone: 'America/Chicago',
      labels: const {
        'group': {'one': 'Family', 'other': 'Families'},
      },
      registration: MyRegistration(
        status: 'waitlisted',
        waitlistPosition: 1,
        submittedAt: DateTime.utc(2026, 12, 1, 18),
        groupName: 'Patel family',
        offerExpiresAt: offerUntil,
        people: const [
          MyPerson(name: 'Asha Patel', categoryId: 'adult'),
          MyPerson(name: 'Dev Patel', categoryId: 'child'),
        ],
      ),
    );
    final until = DateTime.now().add(const Duration(days: 2));

    testWidgets('User Story 10: a full event waitlists the family, a '
        'cancellation offers the place, and the family accepts', (
      tester,
    ) async {
      final (h, r) = await open(tester);
      h.calls.nextSubmitResult = const SubmitResult(
        registrationId: 'r9',
        status: 'waitlisted',
        waitlistPosition: 1,
      );
      await fillForm(r);
      await r.submit();
      expect(find.text("You're on the waitlist, number 1"), findsOneWidget);
      // Someone cancels: the server offers the family the place.
      h.calls.myRegistrations[slug] = waitlisted(offerUntil: until);
      await r.tap(const Key('$k.result.mine'));
      expect(find.byKey(const Key('registration.mine.offer')), findsOneWidget);
      expect(
        find.textContaining('A place is available for your family until '),
        findsOneWidget,
      );
      await r.tap(const Key('registration.mine.offer.accept'));
      expect(h.calls.offerAnswers, [true]);
      expect(
        find.text("You're in. We've emailed your confirmation."),
        findsOneWidget,
      );
      await h.finish(tester);
    });

    testWidgets('No thanks asks first, then gives the place up', (
      tester,
    ) async {
      final (h, r) = await open(tester);
      h.calls.myRegistrations[slug] = waitlisted(offerUntil: until);
      h.router.go('/e/$slug/registration');
      await h.settle(tester);
      await r.tap(const Key('registration.mine.offer.decline'));
      expect(find.text('Give up this place?'), findsOneWidget);
      await r.tap(const Key('registration.mine.offer.keep'));
      expect(h.calls.offerAnswers, isEmpty);
      await r.tap(const Key('registration.mine.offer.decline'));
      await r.tap(const Key('registration.mine.offer.declineConfirm'));
      expect(h.calls.offerAnswers, [false]);
      expect(find.text("You've come off the waitlist."), findsOneWidget);
      await h.finish(tester);
    });

    testWidgets('an offer that ran out says so; without one there is no card', (
      tester,
    ) async {
      final (h, r) = await open(tester);
      h.calls.myRegistrations[slug] = waitlisted(offerUntil: until);
      h.calls.offerRefusal = 'expired';
      h.router.go('/e/$slug/registration');
      await h.settle(tester);
      // Meanwhile the server expired it; the refresh drops the card.
      h.calls.myRegistrations[slug] = waitlisted();
      await r.tap(const Key('registration.mine.offer.accept'));
      expect(
        find.text("This offer has expired. You're still on the waitlist."),
        findsOneWidget,
      );
      expect(find.byKey(const Key('registration.mine.offer')), findsNothing);
      await h.finish(tester);
    });

    testWidgets('Req 71: the offer fits a 320 px phone at 200% text in dark '
        'mode', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (h, _) = await open(tester, size: const Size(320, 2400), dark: true);
      h.calls.myRegistrations[slug] = waitlisted(offerUntil: until);
      h.router.go('/e/$slug/registration');
      await h.settle(tester);
      expect(find.byKey(const Key('registration.mine.offer')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.finish(tester);
    });
  });
}
