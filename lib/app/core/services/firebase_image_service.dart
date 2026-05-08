import 'dart:developer';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';

/// Pluggable picker function — defaults to `ImagePicker().pickImage` but
/// tests inject a stub returning a hand-crafted `XFile`.
typedef PickerFn =
    Future<XFile?> Function(
      ImageSource source, {
      double? maxWidth,
      double? maxHeight,
      int? imageQuality,
    });

/// Firebase Storage implementation of [IImageService]. Web + native via the
/// same `putData(bytes, ...)` path — no `dart:io` references.
class FirebaseImageService implements IImageService {
  FirebaseImageService({FirebaseStorage? storage, PickerFn? pickerOverride})
    : _storageOverride = storage,
      _pick = pickerOverride ?? _defaultPicker;

  // Lazy: only resolves `FirebaseStorage.instance` on first upload, so unit
  // tests that exercise only the picker path don't trip Firebase init.
  final FirebaseStorage? _storageOverride;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;
  final PickerFn _pick;

  static Future<XFile?> _defaultPicker(
    ImageSource source, {
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) {
    return ImagePicker().pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }

  @override
  Future<PickedImage?> pickFromGallery({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  }) => _pickFrom(ImageSource.gallery, maxWidth, maxHeight, quality);

  @override
  Future<PickedImage?> takePhoto({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  }) => _pickFrom(ImageSource.camera, maxWidth, maxHeight, quality);

  Future<PickedImage?> _pickFrom(
    ImageSource source,
    int maxWidth,
    int maxHeight,
    int quality,
  ) async {
    try {
      final picked = await _pick(
        source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? mimeTypeFor(picked.name);
      return PickedImage(
        bytes: bytes,
        filename: picked.name,
        contentType: mime,
      );
    } catch (e, st) {
      log(
        '${source == ImageSource.camera ? "Camera" : "Gallery"} pick failed',
        error: e,
        stackTrace: st,
        name: 'image',
      );
      return null;
    }
  }

  @override
  Future<String> uploadToStorage({
    required Uint8List bytes,
    required String storagePath,
    required String contentType,
  }) async {
    try {
      final ref = _storage.ref().child(storagePath);
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      return await ref.getDownloadURL();
    } catch (e, st) {
      log(
        'Upload failed: $storagePath',
        error: e,
        stackTrace: st,
        name: 'image',
      );
      rethrow;
    }
  }
}
