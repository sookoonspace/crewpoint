import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/participants/data/import_repository.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/import_job.dart';

class _Uploader implements IImportUploader {
  final uploads = <String, Uint8List>{};
  Object? failNext;

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    final error = failNext;
    failNext = null;
    if (error != null) throw error;
    uploads[path] = bytes;
  }
}

/// Req 44a, 75: the app uploads the file, then queues a job the server runs,
/// and can reopen it later.
void main() {
  late FakeFirebaseFirestore firestore;
  late _Uploader uploader;
  late ImportRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    uploader = _Uploader();
    repo = ImportRepository(firestore: firestore, uploader: uploader);
  });

  final bytes = Uint8List.fromList(utf8.encode('Name\nAna\n'));

  test('uploads the file, then queues a check', () async {
    await repo.start(
      eventId: 'e',
      jobId: 'j1',
      fileName: 'roster.csv',
      bytes: bytes,
      header: const ['Name'],
      targets: const ['name'],
      createdBy: 'owner',
    );
    expect(uploader.uploads.keys, ['events/e/imports/j1.csv']);
    final job = (await firestore.doc('events/e/imports/j1').get()).data()!;
    expect(job, containsPair('status', 'queued'));
    expect(job, containsPair('mode', 'dryRun'));
    expect(job['targets'], ['name']);
    expect(job['createdBy'], 'owner');
  });

  test('a failed upload queues nothing', () async {
    uploader.failNext = Exception('offline');
    await expectLater(
      repo.start(
        eventId: 'e',
        jobId: 'j1',
        fileName: 'roster.csv',
        bytes: bytes,
        header: const ['Name'],
        targets: const ['name'],
        createdBy: 'owner',
      ),
      throwsException,
    );
    expect((await firestore.doc('events/e/imports/j1').get()).exists, isFalse);
  });

  test('queues the apply of a checked job', () async {
    await firestore.doc('events/e/imports/j1').set({
      'status': 'checked',
      'mode': 'dryRun',
      'targets': ['name'],
    });
    await repo.queueApply(eventId: 'e', jobId: 'j1');
    final job = (await firestore.doc('events/e/imports/j1').get()).data()!;
    expect(job['status'], 'queued');
    expect(job['mode'], 'apply');
  });

  test('reads a job and its report as the server writes them', () async {
    await firestore.doc('events/e/imports/j1').set({
      'fileName': 'roster.csv',
      'status': 'done',
      'mode': 'apply',
      'targets': ['name'],
      'progress': {'processed': 3, 'total': 3},
      'report': {
        'total': 5,
        'valid': 3,
        'creates': 2,
        'updates': 1,
        'newGroups': 1,
        'errorCount': 2,
        'errors': [
          {'row': 4, 'column': 'Age', 'problem': 'unknownAge'},
        ],
        'mappingProblems': ['requiredFieldNotMapped:diet'],
        'missingGroups': [
          {'groupId': 'g', 'name': 'Joshi', 'participantIds': ['p']},
        ],
      },
      'cancelledGroupIds': ['g'],
    });
    final job = await repo.watch('e', 'j1').first;
    expect(job!.status, ImportStatus.done);
    expect(job.progress, (processed: 3, total: 3));
    expect(job.report!.errors.single.row, 4);
    expect(job.report!.errors.single.problem, 'unknownAge');
    expect(job.report!.missingGroups.single.name, 'Joshi');
    expect(job.report!.missingGroups.single.people, 1);
    expect(job.cancelledGroupIds, ['g']);
    expect(job.report!.unmappedRequiredFields, ['diet']);
  });

  test('lists recent jobs, newest first, to reopen', () async {
    for (final (id, minute) in [('a', 1), ('b', 3), ('c', 2)]) {
      await firestore.doc('events/e/imports/$id').set({
        'status': 'checked',
        'fileName': '$id.csv',
        'createdAt': DateTime.utc(2026, 1, 1, 0, minute),
      });
    }
    final jobs = await repo.watchRecent('e').first;
    expect(jobs.map((j) => j.id), ['b', 'c', 'a']);
  });
}
