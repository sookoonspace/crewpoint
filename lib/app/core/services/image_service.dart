import 'dart:typed_data';

/// Resolves a content-type string from a filename. Used as a fallback when
/// `XFile.mimeType` is null (notably on iOS native pickers). Defaults to
/// `image/jpeg` for unknown / extensionless inputs.
String mimeTypeFor(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  return 'image/jpeg';
}

/// Bytes + metadata produced by the image picker. Carries everything needed
/// to (a) preview via `MemoryImage` and (b) upload via Firebase Storage's
/// `putData(bytes, SettableMetadata(contentType: ...))`. Web-safe: no
/// `dart:io` `File` references.
class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

/// Abstract image service for picking, taking, and uploading images.
/// Swap implementations for testing or different backends.
abstract class IImageService {
  /// Pick image from gallery. Returns null if cancelled.
  ///
  /// Resize/quality args are forwarded to the underlying picker so bytes
  /// returned are already downscaled — keeps web uploads from ballooning.
  Future<PickedImage?> pickFromGallery({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  });

  /// Take photo with camera. Returns null if cancelled. On web, the picker
  /// translates `ImageSource.camera` into a file `<input>` with the
  /// `capture="user"` hint — mobile browsers may surface the camera; desktop
  /// browsers fall back to the file dialog.
  Future<PickedImage?> takePhoto({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  });

  /// Uploads [bytes] to Firebase Storage at [storagePath] with [contentType]
  /// metadata. Returns the download URL.
  Future<String> uploadToStorage({
    required Uint8List bytes,
    required String storagePath,
    required String contentType,
  });
}
