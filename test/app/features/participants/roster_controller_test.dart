import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/data/participant_repository.dart';

/// Fails the next page read, once.
class _FlakyRepository extends ParticipantRepository {
  _FlakyRepository({required super.firestore});

  bool failNext = false;

  @override
  Future<RosterPage> fetchPage(
    String eventId,
    RosterQuery q, {
    RosterPage? after,
  }) {
    if (failNext) {
      failNext = false;
      throw Exception('offline');
    }
    return super.fetchPage(eventId, q, after: after);
  }
}

/// Req 43: the roster loads a page at a time, searches and filters by group,
/// and keeps what it has when a page fails, so it can try again.
void main() {
  late FakeFirebaseFirestore firestore;
  late _FlakyRepository repo;
  late ProviderContainer container;
  const e = 'evt';

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repo = _FlakyRepository(firestore: firestore);
    container = ProviderContainer(
      overrides: [participantRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    for (var i = 0; i < 70; i++) {
      final name = 'Person ${i.toString().padLeft(3, '0')}';
      await firestore.doc('events/$e/participants/p$i').set({
        'name': name,
        'sortName': name.toLowerCase(),
        'groupId': i < 3 ? 'f1' : null,
        'isChild': false,
        'status': 'active',
      });
    }
    await firestore.doc('events/$e/groups/f1').set({
      'name': 'Shahs',
      'sortName': 'shahs',
      'adultUids': <String>[],
    });
  });

  RosterController controller() => container.read(rosterProvider(e).notifier);
  RosterState state() => container.read(rosterProvider(e));

  test('loads the first page, then more on request', () async {
    container.listen(rosterProvider(e), (_, _) {});
    await controller().start(const RosterQuery());
    expect(state().items, hasLength(ParticipantRepository.pageSize));
    expect(state().hasMore, isTrue);
    await controller().loadMore();
    expect(state().items, hasLength(70));
    expect(state().hasMore, isFalse);
  });

  test('carries the group names for what it shows', () async {
    container.listen(rosterProvider(e), (_, _) {});
    await controller().start(const RosterQuery());
    expect(state().groups['f1']?.name, 'Shahs');
  });

  test('a new search or group starts again from the first page', () async {
    container.listen(rosterProvider(e), (_, _) {});
    await controller().start(const RosterQuery());
    await controller().start(const RosterQuery(groupId: 'f1'));
    expect(state().items, hasLength(3));
    await controller().start(const RosterQuery(search: 'person 06'));
    expect(
      state().items.map((p) => p.name),
      everyElement(startsWith('Person 06')),
    );
  });

  test('a failed page keeps what was shown, says so, and retries', () async {
    container.listen(rosterProvider(e), (_, _) {});
    await controller().start(const RosterQuery());
    repo.failNext = true;
    await controller().loadMore();
    expect(state().items, hasLength(ParticipantRepository.pageSize));
    expect(state().error, isNotNull);
    await controller().loadMore();
    expect(state().error, isNull);
    expect(state().items, hasLength(70));
  });
}
