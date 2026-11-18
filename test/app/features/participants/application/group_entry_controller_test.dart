import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/connectivity.dart';
import 'package:crewpoint_app/app/features/participants/application/group_entry_controller.dart';
import 'package:crewpoint_app/app/features/participants/data/participant_repository.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/group_draft.dart';

import '../../../../harness/fake_member_calls.dart';

/// Fails the people batch while [failPeople] is set, and counts answer
/// saves.
class _FlakyRepository extends ParticipantRepository {
  _FlakyRepository({required super.firestore});

  bool failPeople = false;
  int answerSaves = 0;

  @override
  Future<void> saveGroupAnswers(
    String eventId,
    String groupId, {
    required Map<String, Object?> standard,
    Map<String, Object?>? private,
    List<CustomField> definitions = const [],
  }) {
    answerSaves++;
    return super.saveGroupAnswers(
      eventId,
      groupId,
      standard: standard,
      private: private,
      definitions: definitions,
    );
  }

  @override
  Future<void> saveNewPeople(
    String eventId,
    List<PersonRecord> records, {
    List<CustomField> definitions = const [],
  }) {
    if (failPeople) throw Exception('network');
    return super.saveNewPeople(eventId, records, definitions: definitions);
  }
}

class _FakeConnectivity implements IConnectivity {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeMemberCalls calls;
  late _FakeConnectivity connectivity;
  late _FlakyRepository repo;
  late ProviderContainer container;
  const args = GroupEntryArgs(eventId: 'e1');

  setUp(() {
    firestore = FakeFirebaseFirestore();
    calls = FakeMemberCalls(firestore: firestore);
    connectivity = _FakeConnectivity();
    repo = _FlakyRepository(firestore: firestore);
    container = ProviderContainer(
      overrides: [
        participantRepositoryProvider.overrideWithValue(repo),
        memberCallsProvider.overrideWithValue(calls),
        connectivityProvider.overrideWithValue(connectivity),
      ],
    );
    addTearDown(container.dispose);
  });

  GroupEntryController controller() =>
      container.read(groupEntryProvider(args).notifier);
  GroupEntryState state() => container.read(groupEntryProvider(args));

  void fill() => controller().edit(
    (d) => GroupDraft(
      groupId: d.groupId,
      isNewGroup: true,
      groupName: 'Mehta',
      groupAnswers: const {'arriving': 'Fri'},
      people: [
        d.people.first.copyWith(name: 'Neha Mehta'),
        d.people.last,
      ],
    ),
  );

  const arriving = CustomField(
    id: 'arriving',
    label: 'Arriving on',
    type: FieldType.singleChoice,
    options: ['Fri', 'Sat'],
    scope: FieldScope.group,
  );

  Future<GroupSaveOutcome> save() => controller().save(
    fields: const [arriving],
    readsPrivate: true,
    createdBy: 'owner',
    categories: const [],
    eventStart: DateTime.utc(2027, 7, 9),
  );

  test('offline, nothing is sent and the draft stays', () async {
    container.listen(groupEntryProvider(args), (_, _) {});
    fill();
    connectivity.online = false;
    final before = state().draft;
    expect(await save(), GroupSaveOutcome.offline);
    expect(calls.calls, isEmpty);
    expect(state().draft, same(before));
    expect(state().saving, isFalse);
  });

  test('saves a new group, then its answers, then its people', () async {
    container.listen(groupEntryProvider(args), (_, _) {});
    fill();
    final draft = state().draft;
    expect(await save(), GroupSaveOutcome.saved);

    expect(calls.calls, ['saveGroup:${draft.groupId}:Mehta']);
    final group = await firestore
        .doc('events/e1/groups/${draft.groupId}')
        .get();
    expect(group.data()!['fields'], {'arriving': 'Fri'});
    expect(group.data()!['adultUids'], isEmpty);
    final people = await firestore.collection('events/e1/participants').get();
    expect([for (final d in people.docs) d.id], [draft.people.first.id]);
    expect(people.docs.single.data()['groupId'], draft.groupId);
    expect(people.docs.single.data()['sortName'], 'neha mehta');
  });

  test('a failed batch keeps the draft, and a retry repeats only what '
      'failed, without duplicates', () async {
    container.listen(groupEntryProvider(args), (_, _) {});
    fill();
    final draft = state().draft;
    repo.failPeople = true;
    expect(await save(), GroupSaveOutcome.failed);
    expect(state().failedStep, GroupSaveStep.people);
    expect(state().draft, same(draft));
    expect(state().saving, isFalse);

    repo.failPeople = false;
    expect(await save(), GroupSaveOutcome.saved);
    expect(calls.calls, ['saveGroup:${draft.groupId}:Mehta']);
    expect(repo.answerSaves, 1);
    final people = await firestore.collection('events/e1/participants').get();
    expect(people.docs, hasLength(1));
  });

  test('a failed group step is retried before anything else', () async {
    container.listen(groupEntryProvider(args), (_, _) {});
    fill();
    calls.failNext = Exception('network');
    expect(await save(), GroupSaveOutcome.failed);
    expect(state().failedStep, GroupSaveStep.group);
    expect(repo.answerSaves, 0);

    expect(await save(), GroupSaveOutcome.saved);
    expect(calls.calls, hasLength(2));
    expect(repo.answerSaves, 1);
  });

  test('an incomplete draft sends nothing and shows what is missing', () async {
    container.listen(groupEntryProvider(args), (_, _) {});
    expect(await save(), GroupSaveOutcome.incomplete);
    expect(calls.calls, isEmpty);
    expect(repo.answerSaves, 0);
    expect(state().check!.noPeople, isTrue);
    expect(state().check!.groupNameMissing, isTrue);
  });

  test('a second save while one runs does nothing', () async {
    container.listen(groupEntryProvider(args), (_, _) {});
    fill();
    final first = save();
    expect(state().saving, isTrue);
    expect(await save(), GroupSaveOutcome.busy);
    expect(await first, GroupSaveOutcome.saved);
    expect(state().saving, isFalse);
    expect(calls.calls, hasLength(1));
    final people = await firestore.collection('events/e1/participants').get();
    expect(people.docs, hasLength(1));
  });

  test("after a partial save, changing the group's answers or name "
      'sends them again', () async {
    container.listen(groupEntryProvider(args), (_, _) {});
    fill();
    repo.failPeople = true;
    expect(await save(), GroupSaveOutcome.failed);
    repo.failPeople = false;
    controller().edit(
      (d) => GroupDraft(
        groupId: d.groupId,
        isNewGroup: true,
        groupName: 'Mehtas',
        groupAnswers: const {'arriving': 'Sat'},
        people: d.people,
      ),
    );
    expect(await save(), GroupSaveOutcome.saved);
    final groupId = state().draft.groupId;
    expect(calls.calls, [
      'saveGroup:$groupId:Mehta',
      'saveGroup:$groupId:Mehtas',
    ]);
    expect(repo.answerSaves, 2);
  });

  group('adding to an existing group', () {
    const existing = GroupEntryArgs(
      eventId: 'e1',
      groupId: 'g9',
      groupName: 'Shah',
    );

    setUp(() async {
      await firestore.doc('events/e1/groups/g9').set({
        'name': 'Shah',
        'sortName': 'shah',
        'adultUids': ['parent'],
        'fields': {'arriving': 'Fri'},
      });
    });

    GroupEntryController existingController() =>
        container.read(groupEntryProvider(existing).notifier);

    Future<GroupSaveOutcome> saveExisting() => existingController().save(
      fields: const [arriving],
      readsPrivate: true,
      createdBy: 'owner',
      categories: const [],
      eventStart: DateTime.utc(2027, 7, 9),
    );

    void addRavi() => existingController().edit(
      (d) => GroupDraft(
        groupId: d.groupId,
        isNewGroup: d.isNewGroup,
        groupName: d.groupName,
        groupAnswers: d.groupAnswers,
        people: [
          d.people.first.copyWith(name: 'Ravi Shah'),
          d.people.last,
        ],
      ),
    );

    test('saves only the people, leaving the group as it was', () async {
      container.listen(groupEntryProvider(existing), (_, _) {});
      existingController().loadGroupAnswers({'arriving': 'Fri'}, null);
      addRavi();
      expect(await saveExisting(), GroupSaveOutcome.saved);
      expect(calls.calls, isEmpty);
      expect(repo.answerSaves, 0);
      final group = await firestore.doc('events/e1/groups/g9').get();
      expect(group.data()!['fields'], {'arriving': 'Fri'});
      expect(group.data()!['adultUids'], ['parent']);
      final people = await firestore.collection('events/e1/participants').get();
      expect(people.docs.single.data()['groupId'], 'g9');
    });

    test("saves the group's answers when they changed", () async {
      container.listen(groupEntryProvider(existing), (_, _) {});
      existingController().loadGroupAnswers({'arriving': 'Fri'}, null);
      addRavi();
      existingController().edit(
        (d) => GroupDraft(
          groupId: d.groupId,
          isNewGroup: d.isNewGroup,
          groupName: d.groupName,
          groupAnswers: const {'arriving': 'Sat'},
          people: d.people,
        ),
      );
      expect(await saveExisting(), GroupSaveOutcome.saved);
      expect(repo.answerSaves, 1);
    });
  });

  test('knows whether anything has been entered, to ask before leaving', () {
    container.listen(groupEntryProvider(args), (_, _) {});
    expect(state().hasEntries, isFalse);
    controller().edit(
      (d) => GroupDraft(
        groupId: d.groupId,
        isNewGroup: true,
        groupName: 'M',
        people: d.people,
      ),
    );
    expect(state().hasEntries, isTrue);
    controller().edit(
      (d) => GroupDraft(
        groupId: d.groupId,
        isNewGroup: true,
        people: [d.people.first.copyWith(isChild: true), d.people.last],
      ),
    );
    expect(state().hasEntries, isFalse);
    controller().edit(
      (d) => GroupDraft(
        groupId: d.groupId,
        isNewGroup: true,
        people: [
          d.people.first.copyWith(email: 'a@b.c'),
          d.people.last,
        ],
      ),
    );
    expect(state().hasEntries, isTrue);
  });
}
