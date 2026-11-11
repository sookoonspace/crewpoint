import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/mirror_syncs_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/sessions_dao.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart'
    show EventWriteResult;
import 'package:crewpoint_app/app/features/schedule/data/session_repository.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Req 48: sessions are written to Firestore and mirrored into Drift. Anyone
/// without `schedule.edit` lists only sessions that are not hidden.
void main() {
  late FakeFirebaseFirestore firestore;
  late AppDatabase db;
  late SessionRepository repo;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    db = AppDatabase(NativeDatabase.memory());
    repo = SessionRepository(
      dao: SessionsDao(db),
      firestore: firestore,
      syncs: MirrorSyncsDao(db),
    );
    for (final (id, hidden) in [('m1', false), ('gala', true)]) {
      await firestore.doc('events/e1/sessions/$id').set({
        'title': id,
        'startAt': Timestamp.fromDate(DateTime.utc(2027, 7, 17)),
        'timeTbc': false,
        'locationTba': false,
        'tags': <String>[],
        'eligibility': {'categoryIds': <String>[], 'filterTags': <String>[]},
        'hidden': hidden,
      });
    }
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  Future<List<String>> ids(Stream<List<SessionModel>> stream) async {
    final list = await stream.firstWhere((l) => l.isNotEmpty);
    return [for (final s in list) s.id]..sort();
  }

  test('an editor sees hidden sessions too', () async {
    expect(await ids(repo.watchSessions('e1', withHidden: true)), [
      'gala',
      'm1',
    ]);
  });

  test('everyone else sees only visible sessions', () async {
    expect(await ids(repo.watchSessions('e1', withHidden: false)), ['m1']);
  });

  test('losing schedule.edit drops hidden sessions from the mirror', () async {
    await ids(repo.watchSessions('e1', withHidden: true));
    expect(await ids(repo.watchSessions('e1', withHidden: false)), ['m1']);
    expect((await db.select(db.sessions).get()).map((r) => r.id), ['m1']);
  });

  test('mirrors changes and removals', () async {
    final stream = repo.watchSessions('e1', withHidden: true);
    await ids(stream);
    await firestore.doc('events/e1/sessions/gala').delete();
    await firestore.doc('events/e1/sessions/m1').update({'title': 'Dinner'});
    final list = await stream.firstWhere(
      (l) => l.length == 1 && l.single.title == 'Dinner',
    );
    expect(list.single.id, 'm1');
  });

  test('saves a new session with a fresh ID, and who saved it', () async {
    final (result, id) = await repo.save(
      'e1',
      SessionModel(
        id: '',
        title: 'Kids activities',
        startAt: DateTime.utc(2027, 7, 17, 18, 30),
        tags: const ['outdoor'],
      ),
      uid: 'lead',
    );
    expect(result, EventWriteResult.saved);
    expect(id, isNotEmpty);
    final data = (await firestore.doc('events/e1/sessions/$id').get()).data()!;
    expect(data['title'], 'Kids activities');
    expect(data['updatedBy'], 'lead');
    expect(data['tags'], ['outdoor']);
  });

  test('saves an edit to an existing session', () async {
    final (_, id) = await repo.save(
      'e1',
      SessionModel(
        id: 'm1',
        title: 'Welcome dinner',
        startAt: DateTime.utc(2027, 7, 17, 0, 30),
      ),
      uid: 'owner',
    );
    expect(id, 'm1');
    final data = (await firestore.doc('events/e1/sessions/m1').get()).data()!;
    expect(data['title'], 'Welcome dinner');
    expect(data['timeTbc'], isFalse);
  });

  test('removes a session', () async {
    expect(await repo.remove('e1', 'm1'), EventWriteResult.saved);
    expect((await firestore.doc('events/e1/sessions/m1').get()).exists, false);
  });

  test('records when the mirror last heard from the server (Req 74)', () async {
    await ids(repo.watchSessions('e1', withHidden: true));
    final sync = await MirrorSyncsDao(
      db,
    ).watch(SessionRepository.mirrorKey('e1')).firstWhere((s) => s != null);
    expect(sync!.fromCache, isFalse);
    expect(sync.syncedAt, isNotNull);
  });

  test("keeps a session's own attendance rule through the mirror", () async {
    await firestore.doc('events/e1/sessions/m1').update({
      'attendance': 'bySession',
    });
    final list = await repo
        .watchSessions('e1', withHidden: false)
        .firstWhere((l) => l.isNotEmpty);
    expect(list.single.attendance, AttendancePolicy.bySession);
  });
}
