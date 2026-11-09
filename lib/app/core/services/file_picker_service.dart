import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// A file the person chose.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Lets the person choose a file (Req 44a). Tests use a fake.
abstract interface class IFilePicker {
  /// A CSV file, or null if they cancelled.
  Future<PickedFile?> pickCsv();
}

/// Wraps `file_selector`, which works on Android, iOS and the web.
class FileSelectorPicker implements IFilePicker {
  const FileSelectorPicker();

  @override
  Future<PickedFile?> pickCsv() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'CSV',
          extensions: ['csv'],
          mimeTypes: ['text/csv', 'text/comma-separated-values'],
          uniformTypeIdentifiers: ['public.comma-separated-values-text'],
        ),
      ],
    );
    if (file == null) return null;
    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }
}
