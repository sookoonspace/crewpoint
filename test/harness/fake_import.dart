import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/core/services/file_picker_service.dart';
import 'package:crewpoint_app/app/features/participants/data/import_repository.dart';

/// Hands out the next file, or null for a cancelled picker.
class FakeFilePicker implements IFilePicker {
  final files = <PickedFile?>[];

  void add(String name, String csv) => files.add(
    PickedFile(name: name, bytes: Uint8List.fromList(utf8.encode(csv))),
  );

  @override
  Future<PickedFile?> pickCsv() async =>
      files.isEmpty ? null : files.removeAt(0);
}

/// Keeps uploads in memory, and can fail the next one.
class FakeImportUploader implements IImportUploader {
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

/// Stands in for `onImportQueued`: answers each queued job with what
/// [respond] returns, written one step at a time. The real checks are in
/// `functions/test/imports/`.
class FakeImportServer {
  FakeImportServer(
    this.firestore,
    String eventId, {
    required this.respond,
  }) {
    _sub = firestore
        .collection('events/$eventId/imports')
        .snapshots()
        .listen((snap) {
          for (final doc in snap.docs) {
            final data = doc.data();
            final key = '${doc.id}:${data['mode']}';
            if (data['status'] == 'queued' && _seen.add(key)) {
              unawaited(_run(doc.reference, data));
            }
          }
        });
  }

  final FirebaseFirestore firestore;

  /// The updates to write for a job, in order.
  final List<Map<String, Object?>> Function(Map<String, dynamic> job) respond;
  final _seen = <String>{};
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _sub;

  /// Jobs as they were queued, for tests to check.
  final queued = <Map<String, dynamic>>[];

  Future<void> _run(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> job,
  ) async {
    queued.add(job);
    for (final update in respond(job)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await ref.update(update);
    }
  }

  Future<void> dispose() => _sub.cancel();
}
