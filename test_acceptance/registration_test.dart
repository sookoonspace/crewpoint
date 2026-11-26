import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/registration/domain/my_registration.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_form.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

import '../test/harness/sign_in_harness.dart';
import '../test/robots/registration_robot.dart';

/// Stage 2A registration acceptance (#242). Test names start with the
/// scenario ID from docs/testing/CREWPOINT_CONVENTION_TEST_v4.md.
void main() {
  const slug = SignInHarness.slug;
  const k = RegistrationRobot.k;

  testWidgets('B-09 Savita registers on the web in Gujarati: form, review, '
      'confirmation and her registration', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = SignInHarness(
      signedInAs: const AuthUser(uid: 'savita', email: 'savita@example.com'),
    );
    await h.pump(tester, '/e/$slug', locale: const Locale('gu'));
    h.calls.registrationForms[slug] = RegistrationFormSpec(
      slug: slug,
      title: 'Derod Gaam Convention 2027',
      timeZone: 'America/Chicago',
      startDate: DateTime.utc(2027, 7, 16),
      endDate: DateTime.utc(2027, 7, 18),
      dateOnly: true,
      blocks: const {RegistrationBlock.people, RegistrationBlock.contact},
      sections: const [
        RegistrationSection(
          id: 'food',
          name: LocalText('Food', gu: 'ભોજન'),
          fieldIds: ['diet'],
        ),
      ],
      categories: const [EventCategory(id: 'adult', name: 'Adult', minAge: 18)],
      fields: const [
        CustomField(
          id: 'diet',
          label: 'Diet',
          type: FieldType.singleChoice,
          options: ['V', 'J', 'N'],
          required: true,
        ),
      ],
    );
    h.router.go('/e/$slug/register');
    await h.settle(tester);
    final r = RegistrationRobot(tester, h);

    expect(find.text('કોણ આવે છે'), findsOneWidget);
    expect(r.progress, 'પગલું 1 માંથી 4');
    await r.name(0, 'સવિતા મિસ્ત્રી');
    // The Gujarati date picker's input mode reads dd/MM/yyyy.
    await r.tap(const Key('$k.person.0.birthDate'));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await h.settle(tester);
    await tester.enterText(find.byType(TextField).last, '01/01/1953');
    await tester.tap(find.text('ઓકે'));
    await h.settle(tester);
    await r.next();
    expect(find.text('ભોજન'), findsOneWidget);
    await r.choose(0, 'diet', 'V');
    await r.next();
    await r.next();
    expect(find.text('તપાસો અને સબમિટ કરો'), findsOneWidget);
    expect(find.text('ફેરફાર કરો'), findsNWidgets(3));
    await r.submit();
    expect(h.calls.submissions.single['people'], [
      {
        'name': 'સવિતા મિસ્ત્રી',
        'birthDate': '1953-01-01',
        'answers': {'diet': 'V'},
      },
    ]);
    expect(find.text('તમારી નોંધણી થઈ ગઈ છે'), findsOneWidget);

    h.calls.myRegistrations[slug] = const MyRegistrationView(
      title: 'Derod Gaam Convention 2027',
      timeZone: 'America/Chicago',
      registration: MyRegistration(
        status: 'submitted',
        people: [MyPerson(name: 'સવિતા મિસ્ત્રી')],
      ),
    );
    await r.tap(const Key('$k.result.mine'));
    expect(find.text('મારી નોંધણી'), findsNothing); // the event's own title
    expect(find.text('સબમિટ થયું'), findsOneWidget);
    expect(find.text('સવિતા મિસ્ત્રી'), findsOneWidget);
    await h.finish(tester);
  });
}
