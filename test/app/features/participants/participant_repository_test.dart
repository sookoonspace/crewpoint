import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/participants/data/participant_repository.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';

/// Req 40, 43 (#75): participants are read online, a page at a time, and are
/// never mirrored. Search is by the start of a name, ignoring case.
void main() {
  late FakeFirebaseFirestore firestore;
  late ParticipantRepository repo;
  const e = 'evt';

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repo = ParticipantRepository(firestore: firestore);
  });

  Future<void> seed(
    int count, {
    String? groupId,
    String prefix = 'Person',
  }) async {
    for (var i = 0; i < count; i++) {
      final name = '$prefix ${i.toString().padLeft(4, '0')}';
      await firestore.doc('events/$e/participants/$prefix-$i').set({
        'name': name,
        'sortName': name.toLowerCase(),
        'groupId': groupId,
        'isChild': false,
        'status': 'active',
        'createdBy': 'owner',
      });
    }
  }

  test('pages through everyone in name order', () async {
    await seed(120);
    final first = await repo.fetchPage(e, const RosterQuery());
    expect(first.items, hasLength(50));
    expect(first.items.first.name, 'Person 0000');
    expect(first.hasMore, isTrue);
    final second = await repo.fetchPage(e, const RosterQuery(), after: first);
    expect(second.items.first.name, 'Person 0050');
    final third = await repo.fetchPage(e, const RosterQuery(), after: second);
    expect(third.items, hasLength(20));
    expect(third.hasMore, isFalse);
  });

  test('searches by the start of a name, ignoring case', () async {
    await seed(3, prefix: 'Asha');
    await seed(3, prefix: 'Ben');
    final page = await repo.fetchPage(e, const RosterQuery(search: 'AS'));
    expect(page.items.map((p) => p.name), everyElement(startsWith('Asha')));
    expect(page.items, hasLength(3));
  });

  test('filters by one group, or by the viewer’s own groups', () async {
    await seed(2, groupId: 'f1', prefix: 'Shah');
    await seed(2, groupId: 'f2', prefix: 'Patel');
    await seed(2, prefix: 'Solo');
    final one = await repo.fetchPage(e, const RosterQuery(groupId: 'f1'));
    expect(one.items.map((p) => p.groupId), everyElement('f1'));
    final mine = await repo.fetchPage(
      e,
      const RosterQuery(groupIds: ['f1', 'f2']),
    );
    expect(mine.items, hasLength(4));
  });

  test(
    'saves a person with a lower-case sort name, and the birth date apart',
    () async {
      await repo.save(
        const ParticipantModel(
          id: 'p1',
          eventId: e,
          name: 'Ana Shah',
          groupId: 'f1',
          isChild: true,
          createdBy: 'parent',
        ),
        privateDetails: const ParticipantPrivate(birthDate: '2020-05-01'),
      );
      final saved = (await firestore.doc('events/$e/participants/p1').get())
          .data()!;
      expect(saved['sortName'], 'ana shah');
      expect(saved['isChild'], isTrue);
      expect(saved, isNot(contains('birthDate')));
      expect(saved, isNot(contains('uid')));
      final private =
          (await firestore
                  .doc('events/$e/participants/p1/private/details')
                  .get())
              .data()!;
      expect(private['birthDate'], '2020-05-01');
      expect(
        await repo.readPrivate(e, 'p1'),
        const ParticipantPrivate(birthDate: '2020-05-01'),
      );
    },
  );

  test(
    'saving again keeps who created it and leaves the private part when not given',
    () async {
      const person = ParticipantModel(
        id: 'p1',
        eventId: e,
        name: 'Ana',
        createdBy: 'parent',
      );
      await repo.save(
        person,
        privateDetails: const ParticipantPrivate(birthDate: '2020-05-01'),
      );
      await repo.save(person.copyWith(name: 'Anaya'));
      expect((await repo.readPrivate(e, 'p1'))?.birthDate, '2020-05-01');
      final saved = (await firestore.doc('events/$e/participants/p1').get())
          .data()!;
      expect(saved['name'], 'Anaya');
      expect(saved['createdBy'], 'parent');
    },
  );

  test('editing private details keeps an imported email, which linking '
      'reads (Req 46), and replaces the answers', () async {
    const person = ParticipantModel(id: 'p1', eventId: e, name: 'Ravi');
    await firestore.doc('events/$e/participants/p1').set({
      'name': 'Ravi',
      'sortName': 'ravi',
      'isChild': false,
    });
    await firestore.doc('events/$e/participants/p1/private/details').set({
      'email': 'ravi@x.test',
      'fields': {'allergy': 'Nuts', 'old': 'x'},
    });
    // The screen saves what it read, email included.
    final read = await repo.readPrivate(e, 'p1');
    await repo.save(
      person,
      privateDetails: ParticipantPrivate(
        birthDate: '1984-02-01',
        email: read?.email,
        fields: const {'allergy': 'None'},
      ),
    );
    final details =
        (await firestore.doc('events/$e/participants/p1/private/details').get())
            .data()!;
    expect(details['email'], 'ravi@x.test');
    expect(details['birthDate'], '1984-02-01');
    expect(details['fields'], {'allergy': 'None'});
  });

  test('finds people by ID, and open link requests', () async {
    await seed(3);
    final found = await repo.participantsByIds(e, [
      'Person-0',
      'Person-2',
      'gone',
    ]);
    expect(found.keys, unorderedEquals(['Person-0', 'Person-2']));
    await firestore.doc('events/$e/linkRequests/u1').set({
      'uid': 'u1',
      'email': 'b@x.test',
      'participantIds': ['Person-0'],
      'status': 'open',
    });
    await firestore.doc('events/$e/linkRequests/u2').set({
      'uid': 'u2',
      'name': 'Ann',
      'email': 'a@x.test',
      'status': 'dismissed',
    });
    final requests = await repo.watchLinkRequests(e).first;
    expect(requests.map((r) => r.uid), ['u1']);
    expect(requests.single.participantIds, ['Person-0']);
  });

  test('deleting removes the private details too', () async {
    await repo.save(
      const ParticipantModel(id: 'p1', eventId: e, name: 'Ana', createdBy: 'o'),
      privateDetails: const ParticipantPrivate(birthDate: '2020-05-01'),
    );
    await repo.delete(e, 'p1');
    expect(
      (await firestore.doc('events/$e/participants/p1').get()).exists,
      isFalse,
    );
    expect(
      (await firestore.doc('events/$e/participants/p1/private/details').get())
          .exists,
      isFalse,
    );
  });

  test('counts people for capacity, leaving out cancelled ones', () async {
    await seed(7);
    await firestore.doc('events/$e/participants/Person-0').update({
      'status': 'cancelled',
    });
    expect(await repo.count(e), 6);
  });

  test('finds groups by the start of their name, and by ID', () async {
    for (final (id, name) in [
      ('f1', 'Shahs'),
      ('f2', 'Shroffs'),
      ('f3', 'Patels'),
    ]) {
      await firestore.doc('events/$e/groups/$id').set({
        'name': name,
        'sortName': name.toLowerCase(),
        'adultUids': id == 'f1' ? ['parent'] : <String>[],
      });
    }
    final found = await repo.searchGroups(e, 'sh');
    expect(found.map((g) => g.name), ['Shahs', 'Shroffs']);
    final byId = await repo.groupsByIds(e, const ['f3', 'f1']);
    expect(byId['f1']!.adultUids, ['parent']);
    expect(byId['f3']!.name, 'Patels');
  });

  group('custom fields and categories (Req 41, 42)', () {
    const diet = CustomField(
      id: 'diet',
      label: 'Diet',
      type: FieldType.singleChoice,
      options: ['Jain', 'Veg'],
    );
    const allergy = CustomField(
      id: 'allergy',
      label: 'Allergy',
      type: FieldType.text,
      visibility: FieldVisibility.private,
    );

    test(
      'saves standard answers with filter tags, and private ones apart',
      () async {
        await repo.save(
          const ParticipantModel(
            id: 'p1',
            eventId: e,
            name: 'Ana',
            createdBy: 'o',
            categoryId: 'child',
            fields: {'diet': 'Jain'},
          ),
          privateDetails: const ParticipantPrivate(
            birthDate: '2020-05-01',
            fields: {'allergy': 'Nuts'},
          ),
          definitions: const [diet, allergy],
        );
        final saved = (await firestore.doc('events/$e/participants/p1').get())
            .data()!;
        expect(saved['fields'], {'diet': 'Jain'});
        expect(saved['filterTags'], ['diet=Jain']);
        expect(saved['categoryId'], 'child');
        expect(saved.toString(), isNot(contains('Nuts')));
        final private = await repo.readPrivate(e, 'p1');
        expect(private?.fields, {'allergy': 'Nuts'});
        final back = await repo.fetchPage(e, const RosterQuery());
        expect(back.items.single.fields, {'diet': 'Jain'});
        expect(back.items.single.categoryId, 'child');
      },
    );

    test('the roster filters by category and by a field answer', () async {
      for (final (id, cat, d) in [
        ('a', 'child', 'Jain'),
        ('b', 'adult', 'Jain'),
        ('c', 'child', 'Veg'),
      ]) {
        await repo.save(
          ParticipantModel(
            id: id,
            eventId: e,
            name: id,
            createdBy: 'o',
            categoryId: cat,
            fields: {'diet': d},
          ),
          definitions: const [diet],
        );
      }
      final children = await repo.fetchPage(
        e,
        const RosterQuery(categoryId: 'child'),
      );
      expect(children.items.map((p) => p.id), ['a', 'c']);
      final jain = await repo.fetchPage(e, const RosterQuery(tag: 'diet=Jain'));
      expect(jain.items.map((p) => p.id), ['a', 'b']);
      final both = await repo.fetchPage(
        e,
        const RosterQuery(categoryId: 'child', tag: 'diet=Jain'),
      );
      expect(both.items.map((p) => p.id), ['a']);
    });

    test('defines, orders and deletes fields', () async {
      await repo.saveField(e, allergy.copyWith(order: 1));
      await repo.saveField(e, diet);
      final fields = await repo.watchFields(e).first;
      expect(fields.map((f) => f.id), ['diet', 'allergy']);
      await repo.deleteField(e, 'diet');
      expect((await repo.watchFields(e).first).map((f) => f.id), ['allergy']);
    });

    test('saves the event categories into its settings', () async {
      await firestore.doc('events/$e').set({
        'title': 'Convention',
        'settings': {
          'expenseAccess': {'mode': 'involved'},
        },
      });
      await repo.saveCategories(e, const [
        EventCategory(id: 'child', name: 'Child', maxAge: 17, isChild: true),
      ]);
      final settings =
          (await firestore.doc('events/$e').get()).data()!['settings'] as Map;
      expect(categoriesOf(settings.cast()).single.maxAge, 17);
      // Other settings are kept.
      expect(settings['expenseAccess'], {'mode': 'involved'});
    });

    test("saves a group's answers, standard and private", () async {
      await firestore.doc('events/$e/groups/f1').set({
        'name': 'Shahs',
        'sortName': 'shahs',
        'adultUids': <String>[],
      });
      const hotel = CustomField(
        id: 'hotel',
        label: 'Hotel',
        type: FieldType.singleChoice,
        options: ['Inn'],
        scope: FieldScope.group,
      );
      const phone = CustomField(
        id: 'phone',
        label: 'Phone',
        type: FieldType.text,
        scope: FieldScope.group,
        visibility: FieldVisibility.private,
      );
      await repo.saveGroupAnswers(
        e,
        'f1',
        standard: {'hotel': 'Inn'},
        private: {'phone': '555'},
        definitions: const [hotel, phone],
      );
      final group = (await firestore.doc('events/$e/groups/f1').get()).data()!;
      expect(group['fields'], {'hotel': 'Inn'});
      expect(group['filterTags'], ['hotel=Inn']);
      expect(group['name'], 'Shahs');
      expect(await repo.readGroupPrivate(e, 'f1'), {'phone': '555'});
    });
  });
}
