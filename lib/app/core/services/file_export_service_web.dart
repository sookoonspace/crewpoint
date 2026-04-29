import 'dart:js_interop';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;
import 'package:crewpoint_app/app/core/services/file_export_service.dart';

/// Web implementation. PDFs route through `printing`'s share sheet
/// (Wasm-safe). Other byte payloads (CSV, JSON, etc.) build a `Blob`
/// + transient `<a download>` and click it — implemented against
/// **`package:web`** + **`dart:js_interop`** so the bundle stays
/// compatible with `flutter build web --wasm` (`dart:html` would
/// block that migration).
class WebFileExporter implements IFileExporter {
  const WebFileExporter();

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

    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';

    web.document.body!.append(anchor as JSAny);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }
}

/// Resolves the platform impl on the web target.
IFileExporter createFileExporter() => const WebFileExporter();
