import 'dart:typed_data';

import 'package:crewpoint_app/app/core/services/file_export_service.dart';

/// Test fake recording every `share` call so journey + widget tests can
/// assert filename, mime type, and bytes without invoking a real share
/// sheet or browser download.
class RecordingFileExporter implements IFileExporter {
  final List<RecordedShare> calls = [];

  RecordedShare? get lastShare => calls.isEmpty ? null : calls.last;

  @override
  Future<void> share({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    calls.add(
      RecordedShare(bytes: bytes, filename: filename, mimeType: mimeType),
    );
  }
}

class RecordedShare {
  const RecordedShare({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}
