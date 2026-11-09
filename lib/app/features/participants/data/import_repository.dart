import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/import_job.dart';

/// Uploads an import file to Storage (Req 44a). Tests use a fake.
abstract interface class IImportUploader {
  Future<void> upload(String path, Uint8List bytes);
}

class FirebaseImportUploader implements IImportUploader {
  const FirebaseImportUploader();

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    await FirebaseStorage.instance
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: 'text/csv'));
  }
}

/// Roster import jobs (Req 44a, 75). The app uploads the file and queues a
/// job; `onImportQueued` runs it on the server, so it can be left and
/// reopened from [watchRecent].
class ImportRepository {
  ImportRepository({
    required FirebaseFirestore firestore,
    required IImportUploader uploader,
  }) : _firestore = firestore,
       _uploader = uploader;

  final FirebaseFirestore _firestore;
  final IImportUploader _uploader;

  CollectionReference<Map<String, dynamic>> _jobs(String eventId) =>
      _firestore.collection('events').doc(eventId).collection('imports');

  static String filePath(String eventId, String jobId) =>
      'events/$eventId/imports/$jobId.csv';

  /// Uploads [bytes], then queues a check. Nothing is queued if the upload
  /// fails.
  Future<void> start({
    required String eventId,
    required String jobId,
    required String fileName,
    required Uint8List bytes,
    required List<String> header,
    required List<String> targets,
    required String createdBy,
  }) async {
    await _uploader.upload(filePath(eventId, jobId), bytes);
    await _jobs(eventId).doc(jobId).set({
      'fileName': fileName,
      'header': header,
      'targets': targets,
      'mode': 'dryRun',
      'status': 'queued',
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Applies a checked job, optionally with a corrected mapping.
  Future<void> queueApply({
    required String eventId,
    required String jobId,
    List<String>? targets,
  }) => _jobs(eventId).doc(jobId).update({
    'mode': 'apply',
    'status': 'queued',
    'targets': ?targets,
  });

  Stream<ImportJob?> watch(String eventId, String jobId) =>
      _jobs(eventId).doc(jobId).snapshots().map((doc) {
        final data = doc.data();
        return data == null ? null : ImportJob.fromFirestore(doc.id, data);
      });

  /// The latest jobs, newest first.
  Stream<List<ImportJob>> watchRecent(String eventId, {int limit = 5}) =>
      _jobs(eventId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs)
                ImportJob.fromFirestore(doc.id, doc.data()),
            ],
          );
}
