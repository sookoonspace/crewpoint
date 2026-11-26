import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_form.dart';

/// Spec #233 Req 2, 17, 18, 20, 21 (#242): the registration form's steps
/// and the checks made on Submit, before anything is sent. The server
/// checks the same again (`submitRegistration`).
void main() {
  Map<String, Object?> formMap({
    Map<String, Object?> blocks = const {},
    List<Object?>? choices,
  }) => {
    'slug': 'convention-2027',
    'title': 'Convention 2027',
    'timeZone': 'America/Chicago',
    'startDate': DateTime.utc(2027, 7, 16).millisecondsSinceEpoch,
    'endDate': DateTime.utc(2027, 7, 18).millisecondsSinceEpoch,
    'dateOnly': true,
    'deadline': null,
    'review': false,
    'blocks': {
      'people': true,
      'ageOnly': false,
      'stay': true,
      'sessionChoices': true,
      'waivers': false,
      'contact': true,
      ...blocks,
    },
    'sections': [
      {
        'id': 'food',
        'name': {'en': 'Food'},
        'fieldIds': ['diet', 'kids', 'hotel'],
      },
    ],
    'conditions': {
      'kids': {'categoryId': 'child'},
    },
    'categories': [
      {'id': 'child', 'name': 'Child', 'maxAge': 17, 'isChild': true},
      {'id': 'adult', 'name': 'Adult', 'minAge': 18},
    ],
    'fields': [
      {
        'id': 'diet',
        'label': 'Diet',
        'type': 'singleChoice',
        'options': ['Veg', 'Jain'],
        'required': true,
        'scope': 'participant',
        'visibility': 'standard',
      },
      {
        'id': 'kids',
        'label': 'Kids activities',
        'type': 'yesNo',
        'options': <String>[],
        'required': true,
        'scope': 'participant',
        'visibility': 'standard',
      },
      {
        'id': 'hotel',
        'label': 'Hotel',
        'type': 'text',
        'options': <String>[],
        'required': true,
        'scope': 'group',
        'visibility': 'standard',
      },
    ],
    'choices':
        choices ??
        [
          [
            {
              'id': 'park',
              'title': 'Park meal',
              'startAt': DateTime.utc(2027, 7, 17, 17).millisecondsSinceEpoch,
              'endAt': null,
            },
            {
              'id': 'lunch',
              'title': 'Hotel lunch',
              'startAt': DateTime.utc(
                2027,
                7,
                17,
                17,
                30,
              ).millisecondsSinceEpoch,
              'endAt': null,
            },
          ],
        ],
    'labels': <String, Object?>{},
    'registration': null,
  };

  final spec = RegistrationFormSpec.fromMap(formMap());

  test('reads the form the server sends', () {
    expect(spec.title, 'Convention 2027');
    expect(spec.startDate, DateTime.utc(2027, 7, 16));
    expect(spec.fields.map((f) => f.id), ['diet', 'kids', 'hotel']);
    expect(spec.choices.single.map((s) => s.id), ['park', 'lunch']);
    expect(spec.registration, isNull);
  });

  test(
    'steps follow the switched-on blocks, sections in order, then review',
    () {
      expect(spec.steps.map((s) => s.id), [
        'people',
        'section:food',
        'stay',
        'sessions',
        'contact',
        'review',
      ]);
      final bare = RegistrationFormSpec.fromMap(
        formMap(
          blocks: {'stay': false, 'sessionChoices': false, 'contact': false},
          choices: const [],
        ),
      );
      expect(bare.steps.map((s) => s.id), ['people', 'section:food', 'review']);
    },
  );

  test("a person's category comes from their birth date on the first day", () {
    expect(
      spec.categoryOf(const PersonEntry(birthDate: '2016-05-09'))?.id,
      'child',
    );
    expect(
      spec.categoryOf(const PersonEntry(birthDate: '1980-03-01'))?.id,
      'adult',
    );
    expect(spec.categoryOf(const PersonEntry()), isNull);
    final ages = RegistrationFormSpec.fromMap(
      formMap(blocks: {'ageOnly': true}),
    );
    expect(ages.categoryOf(const PersonEntry(age: 9))?.id, 'child');
  });

  group('problems on Submit', () {
    const asha = PersonEntry(
      name: 'Asha Patel',
      birthDate: '1980-03-01',
      answers: {'diet': 'Jain'},
    );
    const dev = PersonEntry(
      name: 'Dev Patel',
      birthDate: '2016-05-09',
      answers: {'diet': 'Veg', 'kids': true},
    );
    RegistrationDraft draft({
      List<PersonEntry> people = const [asha, dev],
      Map<String, Object?> groupAnswers = const {'hotel': 'Hilton'},
      String email = 'asha@example.com',
    }) => RegistrationDraft(
      submissionId: 's1',
      people: people,
      groupAnswers: groupAnswers,
      email: email,
    );

    test('a complete form has none', () {
      expect(spec.problems(draft()), isEmpty);
    });

    test('names, birth dates and required questions shown to someone', () {
      final found = spec.problems(
        draft(
          people: [
            const PersonEntry(name: ' ', answers: {'diet': 'Veg'}),
            dev.copyWith(answers: {'diet': 'Veg'}),
          ],
          groupAnswers: const {},
        ),
      );
      expect(found, [
        const FormProblem('people', 'name', person: 0),
        const FormProblem('people', 'birthDate', person: 0),
        const FormProblem('section:food', 'kids', person: 1),
        const FormProblem('section:food', 'hotel'),
      ]);
    });

    test('a hidden question is never required', () {
      // Kids activities is shown to children only; Asha is an adult.
      expect(spec.problems(draft(people: const [asha])), isEmpty);
    });

    test('at least one person, and an email for the confirmation', () {
      expect(spec.problems(draft(people: const [])), [
        const FormProblem('people', 'noPeople'),
      ]);
      expect(spec.problems(draft(email: 'nope')), [
        const FormProblem('contact', 'email'),
      ]);
    });

    test('one side of an either/or only, and leaving before arriving', () {
      final found = spec.problems(
        draft(
          people: [
            asha.copyWith(
              signUps: {'park', 'lunch'},
              arrivalAt: DateTime.utc(2027, 7, 17),
              departureAt: DateTime.utc(2027, 7, 16),
            ),
          ],
        ),
      );
      expect(found, [
        const FormProblem('stay', 'departureAt', person: 0),
        const FormProblem('sessions', 'signUps', person: 0),
      ]);
    });
  });

  test('what is sent drops answers a condition hides', () {
    const asha = PersonEntry(
      name: 'Asha Patel',
      birthDate: '1980-03-01',
      answers: {'diet': 'Jain', 'kids': true},
      signUps: {'park'},
    );
    final sent = spec.toSubmitMap(
      const RegistrationDraft(
        submissionId: 's1',
        people: [asha],
        groupAnswers: {'hotel': 'Hilton'},
        email: 'asha@example.com',
        phone: '312 555 0100',
      ),
    );
    expect(sent, {
      'slug': 'convention-2027',
      'submissionId': 's1',
      'groupName': '',
      'groupAnswers': {'hotel': 'Hilton'},
      'contact': {'email': 'asha@example.com', 'phone': '312 555 0100'},
      'people': [
        {
          'name': 'Asha Patel',
          'birthDate': '1980-03-01',
          'answers': {'diet': 'Jain'},
          'signUps': ['park'],
        },
      ],
    });
  });

  test('#243: a draft survives a trip to storage and back, submission ID '
      'included', () {
    final draft = RegistrationDraft(
      submissionId: 's1',
      groupName: 'Patel family',
      email: 'asha@example.com',
      phone: '312 555 0100',
      groupAnswers: const {'hotel': 'Hilton'},
      people: [
        PersonEntry(
          name: 'Asha Patel',
          birthDate: '1980-03-01',
          answers: const {
            'diet': 'Jain',
            'kids': true,
            'days': ['Fri', 'Sat'],
          },
          arrivalAt: DateTime.utc(2027, 7, 16, 5),
          departureAt: DateTime.utc(2027, 7, 19, 4, 59),
          signUps: const {'park'},
        ),
        const PersonEntry(name: 'Dev', age: 9),
      ],
    );
    final back = RegistrationDraft.fromMap(draft.toMap());
    expect(back.submissionId, 's1');
    expect(back.groupName, 'Patel family');
    expect(back.email, 'asha@example.com');
    expect(back.phone, '312 555 0100');
    expect(back.groupAnswers, {'hotel': 'Hilton'});
    expect(back.people.first.name, 'Asha Patel');
    expect(back.people.first.birthDate, '1980-03-01');
    expect(back.people.first.answers, {
      'diet': 'Jain',
      'kids': true,
      'days': ['Fri', 'Sat'],
    });
    expect(back.people.first.arrivalAt, DateTime.utc(2027, 7, 16, 5));
    expect(back.people.first.departureAt, DateTime.utc(2027, 7, 19, 4, 59));
    expect(back.people.first.signUps, {'park'});
    expect(back.people.last.age, 9);
    // Something unreadable gives nothing, rather than a broken form.
    expect(RegistrationDraft.tryParse('nope'), isNull);
    expect(RegistrationDraft.tryParse(const {'people': 7}), isNull);
  });

  group('#244 editing', () {
    final editing = RegistrationFormSpec.fromMap({
      ...formMap(),
      'editable': 'all',
      'contactLine': const {'en': 'Call Nilesh at 312-555-0123'},
      'attending': [
        {
          'id': 'M2',
          'title': 'Breakfast',
          'startAt': DateTime.utc(2027, 7, 17, 13).millisecondsSinceEpoch,
          'endAt': null,
        },
      ],
      'current': {
        'groupName': 'Patel family',
        'email': 'asha@example.com',
        'phone': '+13125550100',
        'groupAnswers': const {'hotel': 'Hilton'},
        'people': [
          {
            'id': 'p1',
            'name': 'Asha Patel',
            'birthDate': '1980-03-01',
            'age': null,
            'answers': const {'diet': 'Jain'},
            'arrivalAt': DateTime.utc(2027, 7, 17, 16).millisecondsSinceEpoch,
            'departureAt': null,
            'signUps': const ['park'],
            'optOuts': const ['M2'],
          },
        ],
      },
    });

    test('reads the registration to edit, the sessions to opt out of and '
        'the contact line', () {
      expect(editing.editable, FormEditable.all);
      expect(editing.contactLine?.en, 'Call Nilesh at 312-555-0123');
      expect(editing.attending.single.id, 'M2');
      final current = editing.current!;
      expect(current.groupName, 'Patel family');
      expect(current.phone, '+13125550100');
      final asha = current.people.single;
      expect(asha.id, 'p1');
      expect(asha.arrivalAt, DateTime.utc(2027, 7, 17, 16));
      expect(asha.optOuts, {'M2'});
    });

    test('what is sent keeps each person\'s ID and opt-outs', () {
      final sent = editing.toSubmitMap(editing.current!);
      final person = (sent['people']! as List).single as Map<String, Object?>;
      expect(person['id'], 'p1');
      expect(person['optOuts'], ['M2']);
      expect(person['arrivalAt'], DateTime.utc(2027, 7, 17, 16).millisecondsSinceEpoch);
    });

    test('after the deadline the form is the contact details only', () {
      final closed = RegistrationFormSpec.fromMap({
        ...formMap(),
        'editable': 'contact',
      });
      expect(closed.steps.map((s) => s.id), ['contact', 'review']);
    });

    test('a draft keeps IDs and opt-outs too', () {
      final back = RegistrationDraft.fromMap(editing.current!.toMap());
      expect(back.people.single.id, 'p1');
      expect(back.people.single.optOuts, {'M2'});
    });
  });
}
