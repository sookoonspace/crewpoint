import 'dart:typed_data';

/// Test seam for "save / share these bytes as a downloadable file."
///
/// Production impls (web vs mobile) live in `file_export_service_web.dart`
/// and `file_export_service_mobile.dart`. Widget and journey tests
/// override the corresponding Riverpod provider with a
/// `RecordingFileExporter` and assert on captured calls — production
/// share-sheet / browser-download paths are exercised by the manual
/// smokes only.
abstract class IFileExporter {
  Future<void> share({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  });
}

/// Builds a stable, slugified download filename of the form
/// `<event-slug>-<kind>-<yyyy-MM-dd>.<extension>`.
///
/// Pure helper. Slugification: lowercase, replace runs of any non
/// `[a-z0-9]` characters with a single `-`, trim leading/trailing `-`.
/// Falls back to `report` when the slugified title is empty.
String buildExportFilename({
  required String eventTitle,
  required String kind,
  required String extension,
  required DateTime date,
}) {
  final slugged = _slugify(eventTitle);
  final base = slugged.isEmpty ? 'report' : slugged;
  final iso =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return '$base-$kind-$iso.$extension';
}

String _slugify(String input) {
  final lower = input.toLowerCase();
  final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
}
