import 'dart:io';

/// Abstract image service for picking, taking, and uploading images.
/// Swap implementations for testing or different backends.
abstract class IImageService {
  /// Pick image from gallery. Returns null if cancelled.
  Future<File?> pickFromGallery({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  });

  /// Take photo with camera. Returns null if cancelled.
  Future<File?> takePhoto({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  });

  /// Uploads file to Firebase Storage at [storagePath].
  /// Returns the download URL.
  Future<String> uploadToStorage({
    required File file,
    required String storagePath,
  });
}
