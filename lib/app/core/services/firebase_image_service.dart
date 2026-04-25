import 'dart:developer';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';

/// Firebase Storage implementation of [IImageService].
class FirebaseImageService implements IImageService {
  FirebaseImageService({ImagePicker? picker, FirebaseStorage? storage})
    : _picker = picker ?? ImagePicker(),
      _storage = storage ?? FirebaseStorage.instance;

  final ImagePicker _picker;
  final FirebaseStorage _storage;

  @override
  Future<File?> pickFromGallery({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );
      return picked != null ? File(picked.path) : null;
    } catch (e, st) {
      log('Gallery pick failed', error: e, stackTrace: st, name: 'image');
      return null;
    }
  }

  @override
  Future<File?> takePhoto({
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 85,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );
      return picked != null ? File(picked.path) : null;
    } catch (e, st) {
      log('Camera capture failed', error: e, stackTrace: st, name: 'image');
      return null;
    }
  }

  @override
  Future<String> uploadToStorage({
    required File file,
    required String storagePath,
  }) async {
    try {
      final ref = _storage.ref().child(storagePath);
      await ref.putFile(file);
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
