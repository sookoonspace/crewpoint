import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:crewpoint_app/app/core/services/file_export_service.dart';

/// Mobile / desktop implementation: PDFs go through `printing`'s share
/// sheet, CSVs (and any non-PDF byte payload) go through `share_plus`.
class NativeFileExporter implements IFileExporter {
  const NativeFileExporter();

  @override
  Future<void> share({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    if (mimeType == 'application/pdf') {
      await Printing.sharePdf(bytes: bytes, filename: filename);
      return;
    }

    await Share.shareXFiles(
      [XFile.fromData(bytes, name: filename, mimeType: mimeType)],
      fileNameOverrides: [filename],
    );
  }
}

/// Resolves the platform impl. Conditional-imported so the web target
/// gets `WebFileExporter` from `file_export_service_web.dart`.
IFileExporter createFileExporter() => const NativeFileExporter();
