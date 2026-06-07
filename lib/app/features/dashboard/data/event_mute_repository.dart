import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event_mute.dart';

/// Per-user, per-event push-notification mute store.
///
/// Path: `users/{uid}/eventMutes/{eventId}` — mirrors the existing
/// `users/{uid}/chatReads/{eventId}` per-event-per-user pattern.
/// `mutedUntil` is written as an ISO-8601 UTC string for symmetry with
/// the CF reader (`Date.parse`, no Firestore Timestamp SDK dependency
/// on the server).
///
/// Server side enforcement lives in `functions/src/notifications/sendPush.ts`:
/// `sendCategorizedPush` reads this doc per recipient and skips the
/// push when [EventMute.isMutedAt] returns true (with the documented
/// chat_urgent + criticalOptIn bypass).
class EventMuteRepository {
  EventMuteRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _ref({
    required String uid,
    required String eventId,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('eventMutes')
        .doc(eventId);
  }

  /// Writes the mute. `set(merge:false)` because the doc only carries
  /// the single `mutedUntil` field and we want a clean overwrite when
  /// the user picks a new duration.
  Future<void> muteEvent({
    required String uid,
    required String eventId,
    required DateTime mutedUntil,
  }) async {
    try {
      await _ref(
        uid: uid,
        eventId: eventId,
      ).set(EventMute(mutedUntil: mutedUntil).toMap());
    } catch (e, st) {
      log(
        'Failed to mute event $eventId for $uid',
        error: e,
        stackTrace: st,
        name: 'eventMute',
      );
      rethrow;
    }
  }

  /// Deletes the mute doc. Idempotent — no-op when the doc is absent
  /// (Firestore `delete()` returns success).
  Future<void> unmuteEvent({
    required String uid,
    required String eventId,
  }) async {
    try {
      await _ref(uid: uid, eventId: eventId).delete();
    } catch (e, st) {
      log(
        'Failed to unmute event $eventId for $uid',
        error: e,
        stackTrace: st,
        name: 'eventMute',
      );
      rethrow;
    }
  }

  Future<EventMute?> getEventMute({
    required String uid,
    required String eventId,
  }) async {
    try {
      final snap = await _ref(uid: uid, eventId: eventId).get();
      return EventMute.fromMap(snap.data());
    } catch (e, st) {
      log(
        'Failed to read mute for event $eventId / $uid',
        error: e,
        stackTrace: st,
        name: 'eventMute',
      );
      return null;
    }
  }

  /// Emits `null` when the mute doc is absent / cleared, an [EventMute]
  /// when present. Drives the in-app "muted" indicator on the event
  /// dashboard so the UI mirrors the server-side enforcement state.
  Stream<EventMute?> watchEventMute({
    required String uid,
    required String eventId,
  }) {
    return _ref(
      uid: uid,
      eventId: eventId,
    ).snapshots().map((snap) => EventMute.fromMap(snap.data()));
  }
}
