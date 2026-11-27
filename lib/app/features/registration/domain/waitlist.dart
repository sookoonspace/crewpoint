import 'package:flutter/foundation.dart';

/// One waiting group on the organizer's waitlist (#248).
@immutable
class WaitingGroup {
  const WaitingGroup({
    required this.registrationId,
    required this.groupName,
    required this.size,
    this.position,
    this.offerExpiresAt,
  });

  final String registrationId;
  final String groupName;
  final int size;
  final int? position;

  /// When an open offer runs out; null while the group only waits.
  final DateTime? offerExpiresAt;

  bool get offered => offerExpiresAt != null;
}

/// The waitlist and the places, from `getWaitlist` (Spec #233 Req 32, 34;
/// #248), for `registrations.manage`.
@immutable
class WaitlistView {
  const WaitlistView({
    this.capacity,
    this.placesUsed = 0,
    this.held = 0,
    this.deadline,
    this.timeZone = 'UTC',
    this.waiting = const [],
  });

  factory WaitlistView.fromMap(Map<String, Object?> data) {
    DateTime? time(Object? v) => v is num
        ? DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true)
        : null;
    return WaitlistView(
      capacity: (data['capacity'] as num?)?.toInt(),
      placesUsed: (data['placesUsed'] as num?)?.toInt() ?? 0,
      held: (data['held'] as num?)?.toInt() ?? 0,
      deadline: time(data['deadline']),
      timeZone: data['timeZone'] as String? ?? 'UTC',
      waiting: [
        for (final w in (data['waiting'] as List?) ?? const [])
          if (w is Map && w['registrationId'] is String)
            WaitingGroup(
              registrationId: w['registrationId'] as String,
              groupName: w['groupName'] as String? ?? '',
              size: (w['size'] as num?)?.toInt() ?? 1,
              position: (w['position'] as num?)?.toInt(),
              offerExpiresAt: time(w['offerExpiresAt']),
            ),
      ],
    );
  }

  final int? capacity;
  final int placesUsed;

  /// Places held by open offers.
  final int held;
  final DateTime? deadline;
  final String timeZone;
  final List<WaitingGroup> waiting;

  /// How many people over a lowered capacity the event is; 0 when not.
  int get over => capacity == null || placesUsed <= capacity!
      ? 0
      : placesUsed - capacity!;

  /// Places neither used nor held, or null with no capacity.
  int? get free => capacity == null
      ? null
      : (capacity! - placesUsed - held).clamp(0, capacity!);

  /// Whether [group] fits in the free places, for Offer a place.
  bool fits(WaitingGroup group) => free == null || group.size <= free!;

  bool closedAt(DateTime now) => deadline != null && now.isAfter(deadline!);
}

/// What an organizer does to an offer (`manageOffer`).
enum OfferAction { withdraw, extend, offer }
