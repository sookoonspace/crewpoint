import 'dart:developer';

import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// How choosing a cover photo ended.
enum CoverOutcome { saved, cancelled, tooLarge, notAnImage, failed }

/// Sets, replaces and removes an event's cover photo (Spec #186 Req 41,
/// 42). The photo is picked already shrunk to 1,600 px at quality 85, then
/// stored at `events/{eventId}/cover.jpg`; Storage rules refuse anything
/// but JPEG, PNG or WebP under 5 MB, and so does this, first.
class EventCoverService {
  EventCoverService({
    required IImageService images,
    required EventRepository events,
  }) : _images = images,
       _events = events;

  final IImageService _images;
  final EventRepository _events;

  static const maxPixels = 1600;
  static const quality = 85;
  static const maxBytes = 5 * 1024 * 1024;
  static const types = {'image/jpeg', 'image/png', 'image/webp'};

  /// Picks a photo from the phone or computer and makes it the cover.
  Future<CoverOutcome> choose(String eventId) async {
    final picked = await _images.pickFromGallery(
      maxWidth: maxPixels,
      maxHeight: maxPixels,
      quality: quality,
    );
    if (picked == null) return CoverOutcome.cancelled;
    if (!types.contains(picked.contentType)) return CoverOutcome.notAnImage;
    if (picked.bytes.length >= maxBytes) return CoverOutcome.tooLarge;
    final path = EventCover.pathFor(eventId);
    try {
      await _images.uploadToStorage(
        bytes: picked.bytes,
        storagePath: path,
        contentType: picked.contentType,
      );
      await _events.setCover(eventId, path);
      return CoverOutcome.saved;
    } catch (e, st) {
      log('Cover upload failed', error: e, stackTrace: st, name: 'cover');
      return CoverOutcome.failed;
    }
  }

  /// Removes the cover: the field first, so nobody looks for the file, then
  /// the file. True once the field is gone; a file left behind by a failed
  /// delete is removed with the event.
  Future<bool> remove(String eventId) async {
    try {
      await _events.clearCover(eventId);
    } catch (e, st) {
      log('Cover removal failed', error: e, stackTrace: st, name: 'cover');
      return false;
    }
    try {
      await _images.deleteFromStorage(EventCover.pathFor(eventId));
    } catch (e, st) {
      log('Cover file delete failed', error: e, stackTrace: st, name: 'cover');
    }
    return true;
  }
}
