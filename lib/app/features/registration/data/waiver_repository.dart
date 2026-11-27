import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:crewpoint_app/app/features/registration/domain/waivers.dart';

/// Reads an event's waivers (#246), which anyone in the event may read.
/// Only `saveWaiver` writes them, through `MemberCalls`.
class WaiverRepository {
  const WaiverRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// The event's waivers, oldest first.
  Stream<List<Waiver>> watch(String eventId) => _firestore
      .collection('events')
      .doc(eventId)
      .collection('waivers')
      .snapshots()
      .map((snap) {
        final docs = [...snap.docs]
          ..sort((a, b) {
            final at = _millis(a.data()['createdAt']);
            final bt = _millis(b.data()['createdAt']);
            return at != bt ? at.compareTo(bt) : a.id.compareTo(b.id);
          });
        return [
          for (final d in docs) ?Waiver.tryParse({...d.data(), 'id': d.id}),
        ];
      });

  static int _millis(Object? v) => switch (v) {
    final Timestamp t => t.millisecondsSinceEpoch,
    final DateTime d => d.millisecondsSinceEpoch,
    _ => 0,
  };
}
