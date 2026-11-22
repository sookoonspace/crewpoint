import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/group_draft.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/phone.dart';

void main() {
  var counter = 0;
  String nextId() => 'p${counter++}';

  setUp(() => counter = 0);

  group('GroupDraft.start', () {
    test('opens with two empty people whose IDs are fixed', () {
      final draft = GroupDraft.start(
        groupId: 'g1',
        isNewGroup: true,
        newId: nextId,
      );
      expect(draft.groupId, 'g1');
      expect([for (final p in draft.people) p.id], ['p0', 'p1']);
      expect(draft.people.every((p) => p.isEmpty), isTrue);
    });
  });

  group('toSave', () {
    test('leaves out cards with nothing entered', () {
      const draft = GroupDraft(
        groupId: 'g1',
        isNewGroup: true,
        people: [
          PersonDraft(id: 'a', name: 'Neha'),
          PersonDraft(id: 'b'),
          PersonDraft(id: 'c', answers: {'diet': 'Veg'}),
          PersonDraft(id: 'd', isChild: true),
        ],
      );
      expect([for (final p in draft.toSave) p.id], ['a', 'c']);
    });
  });

  group('adding and removing people', () {
    test('adds a card with a fresh ID and removes one by ID', () {
      final draft = GroupDraft.start(
        groupId: 'g1',
        isNewGroup: true,
        newId: nextId,
      ).addPerson(nextId()).removePerson('p0');
      expect([for (final p in draft.people) p.id], ['p1', 'p2']);
    });

    test('stops at 20 people', () {
      var draft = GroupDraft.start(
        groupId: 'g1',
        isNewGroup: true,
        newId: nextId,
      );
      while (draft.canAddPerson) {
        draft = draft.addPerson(nextId());
      }
      expect(draft.people, hasLength(GroupDraft.maxPeople));
      expect(GroupDraft.maxPeople, 20);
      expect(draft.addPerson('extra').people, hasLength(20));
    });
  });

  group('copyFromPrevious', () {
    const neha = PersonDraft(
      id: 'a',
      name: 'Neha Mehta',
      email: 'neha@example.com',
      answers: {'diet': 'Veg', 'shirt': 'M'},
      privateAnswers: {'allergies': 'Peanuts'},
    );
    const kabir = PersonDraft(
      id: 'b',
      name: 'Kabir Mehta',
      isChild: true,
      birthDate: '2018-03-14',
      answers: {'shirt': 'YS'},
    );
    const draft = GroupDraft(
      groupId: 'g1',
      isNewGroup: true,
      people: [neha, kabir],
    );

    test('copies every answer the viewer can see, standard and private', () {
      final copied = draft
          .copyFromPrevious('b', readsPrivate: true)
          .people
          .last;
      expect(copied.answers, {'diet': 'Veg', 'shirt': 'M'});
      expect(copied.privateAnswers, {'allergies': 'Peanuts'});
    });

    test('never copies name, adult or child, birth date or email', () {
      final copied = draft
          .copyFromPrevious('b', readsPrivate: true)
          .people
          .last;
      expect(copied.id, 'b');
      expect(copied.name, 'Kabir Mehta');
      expect(copied.isChild, isTrue);
      expect(copied.birthDate, '2018-03-14');
      expect(copied.email, '');
    });

    test('leaves private answers alone for someone who cannot see them', () {
      final copied = draft
          .copyFromPrevious('b', readsPrivate: false)
          .people
          .last;
      expect(copied.answers, {'diet': 'Veg', 'shirt': 'M'});
      expect(copied.privateAnswers, isEmpty);
    });

    test('the first person has no one to copy from', () {
      expect(
        draft.copyFromPrevious('a', readsPrivate: true).people,
        draft.people,
      );
    });
  });

  group('check', () {
    const diet = CustomField(
      id: 'diet',
      label: 'Diet',
      type: FieldType.singleChoice,
      options: ['Veg', 'Jain'],
      required: true,
    );
    const shirt = CustomField(
      id: 'shirt',
      label: 'T-shirt size',
      type: FieldType.singleChoice,
      options: ['S', 'M'],
    );
    const allergies = CustomField(
      id: 'allergies',
      label: 'Allergies',
      type: FieldType.text,
      required: true,
      visibility: FieldVisibility.private,
    );
    const arriving = CustomField(
      id: 'arriving',
      label: 'Arriving on',
      type: FieldType.singleChoice,
      options: ['Fri', 'Sat'],
      required: true,
      scope: FieldScope.group,
    );
    const fields = [diet, shirt, allergies, arriving];

    GroupDraft draftOf(List<PersonDraft> people, {String name = 'Mehta'}) =>
        GroupDraft(
          groupId: 'g1',
          isNewGroup: true,
          groupName: name,
          groupAnswers: const {'arriving': 'Fri'},
          people: people,
        );

    test('a complete draft passes', () {
      final check = draftOf([
        const PersonDraft(
          id: 'a',
          name: 'Neha',
          answers: {'diet': 'Veg'},
          privateAnswers: {'allergies': 'None'},
        ),
      ]).check(fields, readsPrivate: true);
      expect(check.ok, isTrue);
      expect(check.missingCount, 0);
    });

    test('a new group needs a name', () {
      final check = draftOf([
        const PersonDraft(id: 'a', name: 'Neha', answers: {'diet': 'Veg'}),
      ], name: ' ').check(fields, readsPrivate: false);
      expect(check.groupNameMissing, isTrue);
      expect(check.ok, isFalse);
    });

    test('needs at least one person, ignoring empty cards', () {
      final check = draftOf(const [
        PersonDraft(id: 'a'),
        PersonDraft(id: 'b'),
      ]).check(fields, readsPrivate: false);
      expect(check.noPeople, isTrue);
      expect(check.ok, isFalse);
    });

    test('a started card needs a name', () {
      final check = draftOf([
        const PersonDraft(id: 'a', answers: {'diet': 'Veg'}),
      ]).check(fields, readsPrivate: false);
      expect(check.people['a']!.nameMissing, isTrue);
      expect(check.ok, isFalse);
    });

    test('points to required answers that are missing', () {
      final check = draftOf([
        const PersonDraft(id: 'a', name: 'Neha'),
        const PersonDraft(id: 'b', name: 'Kabir', answers: {'diet': 'Jain'}),
      ]).check(fields, readsPrivate: true);
      expect(check.people['a']!.missing, {'diet', 'allergies'});
      expect(check.people['b']!.missing, {'allergies'});
      expect(check.missingCount, 3);
    });

    test('does not ask for private answers the viewer cannot see', () {
      final check = draftOf([
        const PersonDraft(id: 'a', name: 'Neha', answers: {'diet': 'Veg'}),
      ]).check(fields, readsPrivate: false);
      expect(check.ok, isTrue);
    });

    test("checks the group's own required answers", () {
      const draft = GroupDraft(
        groupId: 'g1',
        isNewGroup: true,
        groupName: 'Mehta',
        people: [
          PersonDraft(id: 'a', name: 'Neha', answers: {'diet': 'Veg'}),
        ],
      );
      final check = draft.check(fields, readsPrivate: false);
      expect(check.groupMissing, {'arriving'});
      expect(check.missingCount, 1);
    });
  });

  group('records', () {
    const categories = [
      EventCategory(
        id: 'kids',
        name: '6–12',
        minAge: 6,
        maxAge: 12,
        isChild: true,
      ),
      EventCategory(id: 'adults', name: 'Adults', minAge: 18),
    ];
    final start = DateTime.utc(2027, 7, 9);
    const draft = GroupDraft(
      groupId: 'g1',
      isNewGroup: true,
      groupName: 'Mehta',
      people: [
        PersonDraft(
          id: 'a',
          name: '  Neha Mehta ',
          email: 'neha@example.com',
          birthDate: '1990-01-01',
          answers: {'diet': 'Veg'},
        ),
        PersonDraft(id: 'empty'),
        PersonDraft(
          id: 'b',
          name: 'Kabir Mehta',
          isChild: true,
          birthDate: '2018-03-14',
          email: 'typed-before-switching@example.com',
          privateAnswers: {'allergies': 'Peanuts'},
        ),
      ],
    );

    List<PersonRecord> records() => draft.records(
      eventId: 'e1',
      createdBy: 'owner',
      categories: categories,
      eventStart: start,
    );

    test('one record per person to save, in the group', () {
      final people = [for (final r in records()) r.person];
      expect([for (final p in people) p.id], ['a', 'b']);
      expect(people.every((p) => p.groupId == 'g1'), isTrue);
      expect(people.every((p) => p.eventId == 'e1'), isTrue);
      expect(people.every((p) => p.createdBy == 'owner'), isTrue);
      expect(people.first.name, 'Neha Mehta');
      expect(people.first.sortName, 'neha mehta');
      expect(people.first.fields, {'diet': 'Veg'});
    });

    test('an adult keeps an email and no birth date', () {
      final neha = records().first;
      expect(neha.person.isChild, isFalse);
      expect(neha.person.categoryId, isNull);
      expect(neha.private!.email, 'neha@example.com');
      expect(neha.private!.birthDate, isNull);
    });

    test('a child keeps a birth date that sets the age band, no email', () {
      final kabir = records().last;
      expect(kabir.person.isChild, isTrue);
      expect(kabir.person.categoryId, 'kids');
      expect(kabir.private!.birthDate, '2018-03-14');
      expect(kabir.private!.email, isNull);
      expect(kabir.private!.fields, {'allergies': 'Peanuts'});
    });

    test('no private details when there is nothing private', () {
      const plain = GroupDraft(
        groupId: 'g1',
        isNewGroup: false,
        people: [
          PersonDraft(id: 'a', name: 'Ravi', answers: {'diet': 'Veg'}),
        ],
      );
      final record = plain
          .records(
            eventId: 'e1',
            createdBy: 'owner',
            categories: categories,
            eventStart: start,
          )
          .single;
      expect(record.private, isNull);
    });
  });

  group('editing existing people', () {
    const loaded = PersonDraft(
      id: 'a',
      name: 'Neha Mehta',
      answers: {'diet': 'Veg'},
    );
    final existing = PersonDraft.existing(loaded);

    test('an unchanged person is not saved again; a changed one is', () {
      final changed = PersonDraft.existing(
        const PersonDraft(id: 'b', name: 'Kabir'),
      ).copyWith(answers: {'diet': 'Jain'});
      final draft = GroupDraft(
        groupId: 'g1',
        isNewGroup: false,
        people: [existing, changed],
      );
      expect([for (final p in draft.toSave) p.id], ['b']);
      expect(changed.isExisting, isTrue);
    });

    test('an existing person cleared of everything is still saved, and '
        'needs a name', () {
      final cleared = existing.copyWith(name: '', answers: {});
      final draft = GroupDraft(
        groupId: 'g1',
        isNewGroup: false,
        people: [cleared],
      );
      expect(draft.toSave, [cleared]);
      expect(
        draft.check(const [], readsPrivate: false).people['a']!.nameMissing,
        isTrue,
      );
    });

    test('editing answers needs no new person', () {
      final draft = GroupDraft(
        groupId: 'g1',
        isNewGroup: false,
        editing: true,
        groupAnswers: const {'arriving': 'Sat'},
        people: [existing],
      );
      expect(draft.check(const [], readsPrivate: false).ok, isTrue);
    });

    test("keeps what an edit card hides: an adult's birth date, a child's "
        'email', () {
      final adult = PersonDraft.existing(
        const PersonDraft(
          id: 'a',
          name: 'Neha',
          birthDate: '1990-01-01',
          email: 'neha@example.com',
        ),
      ).copyWith(answers: {'diet': 'Veg'});
      final child = PersonDraft.existing(
        const PersonDraft(
          id: 'b',
          name: 'Kabir',
          isChild: true,
          birthDate: '2018-03-14',
          email: 'imported@example.com',
        ),
      ).copyWith(answers: {'diet': 'Jain'});
      final records =
          GroupDraft(
            groupId: 'g1',
            isNewGroup: false,
            editing: true,
            people: [adult, child],
          ).records(
            eventId: 'e1',
            createdBy: 'owner',
            categories: const [],
            eventStart: DateTime.utc(2027, 7, 9),
          );
      expect(records.first.existing, isTrue);
      expect(records.first.private!.birthDate, '1990-01-01');
      expect(records.first.private!.email, 'neha@example.com');
      expect(records.last.private!.email, 'imported@example.com');
      expect(records.last.private!.birthDate, '2018-03-14');
    });
  });

  group('phone numbers (Spec #233 Req 13, #237)', () {
    final start = DateTime.utc(2027, 7, 9);
    GroupDraft draftWith(List<PersonDraft> people) =>
        GroupDraft(groupId: 'g1', isNewGroup: false, people: people);
    List<PersonRecord> records(GroupDraft d, PhoneCountry country) => d.records(
      eventId: 'e1',
      createdBy: 'owner',
      categories: const [],
      eventStart: start,
      phoneCountry: country,
    );

    test("an adult's number is kept in E.164, read in the event's country", () {
      final d = draftWith(const [
        PersonDraft(id: 'a', name: 'Neha', phone: '(214) 555-0100'),
        PersonDraft(id: 'b', name: 'Ravi', phone: '+44 7700 900123'),
      ]);
      expect(
        [for (final r in records(d, PhoneCountry.us)) r.private!.phone],
        ['+12145550100', '+447700900123'],
      );
      final uk = draftWith(const [
        PersonDraft(id: 'a', name: 'Neha', phone: '07700 900123'),
      ]);
      expect(
        records(uk, PhoneCountry.gb).single.private!.phone,
        '+447700900123',
      );
    });

    test('a new child keeps no number, and an empty one is none', () {
      final d = draftWith(const [
        PersonDraft(
          id: 'a',
          name: 'Kabir',
          isChild: true,
          phone: '214 555 0100',
        ),
        PersonDraft(id: 'b', name: 'Neha', phone: '  '),
      ]);
      expect(
        [for (final r in records(d, PhoneCountry.us)) r.private],
        [null, null],
      );
    });

    test('a number that is not whole stops the save, on that person only', () {
      final d = draftWith(const [
        PersonDraft(id: 'a', name: 'Neha', phone: '555-0100'),
        PersonDraft(id: 'b', name: 'Ravi', phone: '214 555 0100'),
        PersonDraft(id: 'c', name: 'Kabir', isChild: true, phone: '555'),
      ]);
      final check = d.check(
        const [],
        readsPrivate: false,
        phoneCountry: PhoneCountry.us,
      );
      expect(check.people['a']!.phoneInvalid, isTrue);
      expect(check.people['a']!.ok, isFalse);
      expect(check.people['b']!.ok, isTrue);
      // A child's card shows no phone, so what was typed is not checked.
      expect(check.people['c']!.ok, isTrue);
      expect(check.ok, isFalse);
    });

    test('a changed number counts as a change', () {
      const saved = PersonDraft(id: 'a', name: 'Neha', phone: '+12145550100');
      final edited = PersonDraft.existing(
        saved,
      ).copyWith(phone: '+12145550199');
      expect(PersonDraft.existing(saved).isChanged, isFalse);
      expect(edited.isChanged, isTrue);
      expect(const PersonDraft(id: 'x', phone: '1').isEmpty, isFalse);
    });
  });
}
