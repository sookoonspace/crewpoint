import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/mirror_syncs_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/my_records_dao.dart';
import 'package:crewpoint_app/app/features/schedule/data/my_records_repository.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 51, 74: the viewer's own participant record, their group's people and
/// their groups are mirrored on the device, so the agenda works offline.
/// Nobody else's records are read.
void main() {
  late FakeFirebaseFirestore firestore;
  late AppDatabase db;
  late MyRecordsRepository repo;
  const e = 'events/conv';

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    db = AppDatabase(NativeDatabase.memory());
    repo = MyRecordsRepository(
      dao: MyRecordsDao(db),
      firestore: firestore,
      syncs: MirrorSyncsDao(db),
    );
    Future<void> person(String id, {String? groupId, String? uid}) =>
        firestore.doc('$e/participants/$id').set({
          'name': id,
          'sortName': id,
          'groupId': groupId,
          'isChild': false,
          'status': 'active',
          'uid': ?uid,
          'arrivalAt': Timestamp.fromDate(DateTime.utc(2027, 7, 17, 16)),
          'optOuts': ['m3'],
        });
    await person('kunal', groupId: 'f3', uid: 'kunal-uid');
    await person('ramesh', groupId: 'f3');
    await person('solo', uid: 'solo-uid');
    await person('stranger', groupId: 'f9');
    await firestore.doc('$e/groups/f3').set({
      'name': 'Desai',
      'invitedTo': ['gala'],
    });
    await firestore.doc('$e/groups/f9').set({'name': 'Other'});
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  test("a linked adult gets their group's people and the group", () async {
    final mine = await repo
        .watchMine('conv', uid: 'kunal-uid', groupIds: const ['f3'])
        .firstWhere((m) => m.people.length == 2 && m.groups.isNotEmpty);
    expect([for (final p in mine.people) p.id]..sort(), ['kunal', 'ramesh']);
    expect(mine.groups.single.invitedTo, ['gala']);
    final ramesh = mine.people.firstWhere((p) => p.id == 'ramesh');
    expect(ramesh.arrivalAt, DateTime.utc(2027, 7, 17, 16));
    expect(ramesh.optOuts, ['m3']);
  });

  test('someone with no group gets only their own record', () async {
    final mine = await repo
        .watchMine('conv', uid: 'solo-uid', groupIds: const [])
        .firstWhere((m) => m.people.isNotEmpty);
    expect([for (final p in mine.people) p.id], ['solo']);
    expect(mine.groups, isEmpty);
  });

  test('records when it last heard from the server', () async {
    await repo
        .watchMine('conv', uid: 'solo-uid', groupIds: const [])
        .firstWhere((m) => m.people.isNotEmpty);
    final sync = await MirrorSyncsDao(
      db,
    ).watch(MyRecordsRepository.mirrorKey('conv')).firstWhere((s) => s != null);
    expect(sync!.syncedAt, isNotNull);
  });

  test('a person no longer in the group leaves the mirror', () async {
    final stream = repo.watchMine(
      'conv',
      uid: 'kunal-uid',
      groupIds: const ['f3'],
    );
    await stream.firstWhere((m) => m.people.length == 2);
    await firestore.doc('$e/participants/ramesh').update({'groupId': 'f9'});
    final mine = await stream.firstWhere((m) => m.people.length == 1);
    expect(mine.people.single.id, 'kunal');
  });
}
