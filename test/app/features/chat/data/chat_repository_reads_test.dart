import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/chat_reads_dao.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/data/firestore_chat_service.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

void main() {
  late AppDatabase db;
  late ChatReadsDao readsDao;
  late FakeFirebaseFirestore firestore;
  late ChatRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    readsDao = ChatReadsDao(db);
    firestore = FakeFirebaseFirestore();
    repo = ChatRepository(
      chatService: FirestoreChatService(firestore: firestore),
      firestore: firestore,
      chatReadsDao: readsDao,
    );
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  test(
    'markEventRead writes users/{uid}/chatReads/{eventId} in Firestore AND upserts Drift cache',
    () async {
      await repo.markEventRead('u-1', 'e-1');

      // Firestore source-of-truth row
      final doc = await firestore
          .collection('users')
          .doc('u-1')
          .collection('chatReads')
          .doc('e-1')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['lastReadAt'], isNotNull);

      // Drift cache row mirrors it
      final cached = await readsDao
          .watchLastReadAt(eventId: 'e-1', uid: 'u-1')
          .first;
      expect(cached, isNotNull);
    },
  );

  test(
    'markEventRead never throws even when Firestore is null (defensive)',
    () async {
      // ChatRepository without firestore wired — simulates the legacy
      // construction path. markEventRead must NOT crash the caller.
      final naked = ChatRepository(
        chatService: FirestoreChatService(firestore: firestore),
      );
      addTearDown(naked.dispose);

      // Fire-and-forget contract: no throw.
      await naked.markEventRead('u-1', 'e-1');
    },
  );

  test(
    'backfillReadStateForExistingEvents writes a doc per event when none exist',
    () async {
      const events = [
        EventModel(
          id: 'e-1',
          title: 'Trip',
          creatorId: 'u-1',
          memberIds: ['u-1'],
        ),
        EventModel(
          id: 'e-2',
          title: 'Sync',
          creatorId: 'u-1',
          memberIds: ['u-1'],
        ),
      ];

      await repo.backfillReadStateForExistingEvents('u-1', events);

      final readsCol = firestore
          .collection('users')
          .doc('u-1')
          .collection('chatReads');
      final docs = await readsCol.get();
      expect(docs.docs.map((d) => d.id).toSet(), {'e-1', 'e-2'});
    },
  );

  test(
    'backfillReadStateForExistingEvents skips events whose read doc already exists (idempotent)',
    () async {
      const events = [
        EventModel(
          id: 'e-1',
          title: 'Trip',
          creatorId: 'u-1',
          memberIds: ['u-1'],
        ),
      ];
      final readsCol = firestore
          .collection('users')
          .doc('u-1')
          .collection('chatReads');

      // Pre-seed a sentinel string so we can detect overwrite (Firestore
      // type-conversion makes raw DateTime comparison fragile; a string
      // value will pass straight through round-trip).
      const sentinel = 'pre-existing';
      await readsCol.doc('e-1').set({'lastReadAt': sentinel});

      await repo.backfillReadStateForExistingEvents('u-1', events);

      final doc = await readsCol.doc('e-1').get();
      // Sentinel must survive — backfill should NOT overwrite existing rows.
      expect(doc.data()!['lastReadAt'], sentinel);
    },
  );

  test(
    'watchLastRead emits the Drift-cached timestamp first, then propagates Firestore writes',
    () async {
      // Pre-seed the Drift cache so the first emission is non-null.
      final seeded = DateTime(2026, 5, 14, 9);
      await readsDao.upsert(eventId: 'e-1', uid: 'u-1', lastReadAt: seeded);

      final stream = repo.watchLastRead('u-1', 'e-1');
      // First emission: Drift cache value.
      final first = await stream.first;
      expect(first, seeded);

      // Now write to Firestore via the repo's own markEventRead. The
      // stream should re-emit the newer timestamp.
      final emissions = <DateTime?>[];
      final sub = stream.listen(emissions.add);
      addTearDown(sub.cancel);
      await repo.markEventRead('u-1', 'e-1');
      // Allow micro-task drain.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Last emission should be newer than `seeded`.
      expect(emissions.isNotEmpty, isTrue);
      expect(emissions.last!.isAfter(seeded), isTrue);
    },
  );
}
