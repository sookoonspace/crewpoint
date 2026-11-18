import 'dart:typed_data';

import 'package:crewpoint_app/app/core/services/image_service.dart';

/// An in-memory Storage and picker for tests: [next] is what the picker
/// returns, [files] what is stored, by path.
class FakeImageService implements IImageService {
  PickedImage? next;
  final files = <String, Uint8List>{};
  final contentTypes = <String, String>{};

  /// The last picker limits asked for.
  ({int maxWidth, int maxHeight, int quality})? lastPick;
  int downloads = 0;
  Object? failUpload;
  Object? failDelete;

  @override
  Future<PickedImage?> pickFromGallery({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  }) async {
    lastPick = (maxWidth: maxWidth, maxHeight: maxHeight, quality: quality);
    final picked = next;
    next = null;
    return picked;
  }

  @override
  Future<PickedImage?> takePhoto({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  }) => pickFromGallery(
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    quality: quality,
  );

  @override
  Future<String> uploadToStorage({
    required Uint8List bytes,
    required String storagePath,
    required String contentType,
  }) async {
    final error = failUpload;
    if (error != null) {
      failUpload = null;
      throw error;
    }
    files[storagePath] = bytes;
    contentTypes[storagePath] = contentType;
    return 'https://example.test/$storagePath';
  }

  @override
  Future<Uint8List?> downloadBytes(
    String storagePath, {
    int maxSize = 5 * 1024 * 1024,
  }) async {
    downloads++;
    return files[storagePath];
  }

  @override
  Future<void> deleteFromStorage(String storagePath) async {
    final error = failDelete;
    if (error != null) {
      failDelete = null;
      throw error;
    }
    files.remove(storagePath);
  }
}

/// A tiny valid PNG (one pixel), for pickers and image widgets in tests.
final Uint8List onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
