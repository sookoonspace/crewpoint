import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crewpoint_app/app/core/services/firebase_image_service.dart';

/// On native, `XFile.fromData(name: ...)` ignores the name parameter and
/// derives `.name` from `_file.path`. We pass the filename as `path:` so
/// `.name` returns it. `_bytes` is set via `bytes:`, so `readAsBytes()`
/// returns the buffer without touching disk.
XFile _buildXFile(Uint8List bytes, {required String name, String? mimeType}) {
  return XFile.fromData(bytes, path: name, mimeType: mimeType);
}

class _RecordingPicker {
  ImageSource? lastSource;
  double? lastMaxWidth;
  double? lastMaxHeight;
  int? lastQuality;
  XFile? next;

  Future<XFile?> call(
    ImageSource source, {
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    lastSource = source;
    lastMaxWidth = maxWidth;
    lastMaxHeight = maxHeight;
    lastQuality = imageQuality;
    return next;
  }
}

void main() {
  late _RecordingPicker picker;
  late FirebaseImageService service;

  setUp(() {
    picker = _RecordingPicker();
    // Storage left at the firebase_auth default; the upload-side codepath is
    // exercised through `expense_repository_receipt_test.dart` against a
    // hand-rolled IImageService fake. This test focuses on the picker seam
    // and contentType derivation — the new behavior on web.
    service = FirebaseImageService(pickerOverride: picker.call);
  });

  group('pickFromGallery', () {
    test('forwards default size + quality to underlying picker and returns '
        'PickedImage with bytes from XFile', () async {
      picker.next = _buildXFile(
        Uint8List.fromList([1, 2, 3]),
        name: 'photo.jpg',
        mimeType: 'image/jpeg',
      );

      final picked = await service.pickFromGallery();

      expect(picker.lastSource, equals(ImageSource.gallery));
      expect(picker.lastMaxWidth, equals(512.0));
      expect(picker.lastMaxHeight, equals(512.0));
      expect(picker.lastQuality, equals(85));
      expect(picked, isNotNull);
      expect(picked!.bytes, equals(Uint8List.fromList([1, 2, 3])));
      expect(picked.filename, equals('photo.jpg'));
      expect(picked.contentType, equals('image/jpeg'));
    });

    test(
      'derives contentType from filename when XFile.mimeType is null',
      () async {
        picker.next = _buildXFile(Uint8List.fromList([9]), name: 'cover.PNG');

        final picked = await service.pickFromGallery();

        expect(picked!.contentType, equals('image/png'));
      },
    );

    test('returns null when picker returns null (user cancel)', () async {
      picker.next = null;
      expect(await service.pickFromGallery(), isNull);
    });
  });

  group('takePhoto', () {
    test(
      'uses ImageSource.camera with the supplied size + quality args',
      () async {
        picker.next = _buildXFile(
          Uint8List.fromList([7]),
          name: 'snap.jpg',
          mimeType: 'image/jpeg',
        );

        await service.takePhoto(maxWidth: 1600, maxHeight: 1600, quality: 70);

        expect(picker.lastSource, equals(ImageSource.camera));
        expect(picker.lastMaxWidth, equals(1600.0));
        expect(picker.lastMaxHeight, equals(1600.0));
        expect(picker.lastQuality, equals(70));
      },
    );
  });
}
