import 'package:flutter/foundation.dart';

import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

DateTime? _time(Object? v) => v is num
    ? DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true)
    : null;

/// The registration statuses the committee sees (Spec #233 Req 4).
const registrationStatuses = [
  'submitted',
  'pending',
  'waitlisted',
  'cancelled',
  'draft',
];

/// Groups and people in one status; drafts have no people yet.
typedef StatusCount = ({int groups, int? people});

/// The Registration summary, from `getRegistrationSummary` (Req 64, 4a).
@immutable
class RegistrationSummary {
  const RegistrationSummary({
    this.byStatus = const {},
    this.capacity,
    this.placesUsed = 0,
    this.held = 0,
    this.deadline,
    this.review = false,
    this.slug,
    this.timeZone = 'UTC',
  });

  factory RegistrationSummary.fromMap(Map<String, Object?> data) {
    final raw = data['byStatus'];
    return RegistrationSummary(
      byStatus: {
        for (final status in registrationStatuses)
          if (raw is Map && raw[status] is Map)
            status: (
              groups: ((raw[status] as Map)['groups'] as num?)?.toInt() ?? 0,
              people: ((raw[status] as Map)['people'] as num?)?.toInt(),
            ),
      },
      capacity: (data['capacity'] as num?)?.toInt(),
      placesUsed: (data['placesUsed'] as num?)?.toInt() ?? 0,
      held: (data['held'] as num?)?.toInt() ?? 0,
      deadline: _time(data['deadline']),
      review: data['review'] == true,
      slug: data['slug'] as String?,
      timeZone: data['timeZone'] as String? ?? 'UTC',
    );
  }

  final Map<String, StatusCount> byStatus;
  final int? capacity;
  final int placesUsed;
  final int held;
  final DateTime? deadline;
  final bool review;
  final String? slug;
  final String timeZone;

  StatusCount count(String status) =>
      byStatus[status] ?? (groups: 0, people: status == 'draft' ? null : 0);

  /// Not confirmed yet (Req 4a): drafts, pending and waitlisted.
  ({int groups, int people}) get notConfirmed => (
    groups:
        count('draft').groups +
        count('pending').groups +
        count('waitlisted').groups,
    people: (count('pending').people ?? 0) + (count('waitlisted').people ?? 0),
  );

  /// How far over capacity the event is; 0 when not.
  int get over =>
      capacity == null || placesUsed <= capacity! ? 0 : placesUsed - capacity!;
}

/// What the committee does to a registration (`manageRegistration`).
enum RegistrationAction { approve, waitlist, reinstate }

/// One change on a registration's log (Req 66).
@immutable
class RegistrationChange {
  const RegistrationChange({
    required this.action,
    this.at,
    this.by = '',
    this.fields = const [],
  });

  final String action;
  final DateTime? at;

  /// Who made it, by name; empty for the system.
  final String by;

  /// The fields an edit changed.
  final List<String> fields;
}

/// One waiver a person accepted, as the group detail lists it.
@immutable
class AcceptedWaiver {
  const AcceptedWaiver({
    required this.title,
    required this.version,
    this.at,
    this.as,
  });

  final LocalText title;
  final int version;
  final DateTime? at;

  /// `self`, `guardian` or `onBehalf`.
  final String? as;
}

@immutable
class GroupRegistrationPerson {
  const GroupRegistrationPerson({
    required this.id,
    required this.name,
    this.missingWaivers = const [],
    this.waivers = const [],
  });

  final String id;
  final String name;
  final List<String> missingWaivers;
  final List<AcceptedWaiver> waivers;
}

/// A group's registration, from `getGroupRegistration` (Req 66).
@immutable
class GroupRegistration {
  const GroupRegistration({
    required this.registrationId,
    required this.status,
    this.waitlistPosition,
    this.offerExpiresAt,
    this.submittedAt,
    this.cancelReason,
    this.contactName,
    this.contactEmail,
    this.linkedAdults = const [],
    this.changes = const [],
    this.people = const [],
  });

  static GroupRegistration? tryParse(Object? raw) {
    if (raw is! Map || raw['registrationId'] is! String) return null;
    final contact = raw['contact'];
    return GroupRegistration(
      registrationId: raw['registrationId'] as String,
      status: raw['status'] as String? ?? 'submitted',
      waitlistPosition: (raw['waitlistPosition'] as num?)?.toInt(),
      offerExpiresAt: _time(raw['offerExpiresAt']),
      submittedAt: _time(raw['submittedAt']),
      cancelReason: raw['cancelReason'] as String?,
      contactName: contact is Map ? contact['name'] as String? : null,
      contactEmail: contact is Map ? contact['email'] as String? : null,
      linkedAdults: [
        for (final a in (raw['linkedAdults'] as List?) ?? const [])
          if (a is Map) a['name'] as String? ?? '',
      ],
      changes: [
        for (final c in (raw['changes'] as List?) ?? const [])
          if (c is Map)
            RegistrationChange(
              action: c['action'] as String? ?? '',
              at: _time(c['at']),
              by: c['by'] as String? ?? '',
              fields: [
                for (final f in (c['changes'] as List?) ?? const [])
                  if (f is Map && f['field'] is String) f['field'] as String,
              ],
            ),
      ],
      people: [
        for (final p in (raw['people'] as List?) ?? const [])
          if (p is Map && p['id'] is String)
            GroupRegistrationPerson(
              id: p['id'] as String,
              name: p['name'] as String? ?? '',
              missingWaivers: [
                for (final w in (p['missingWaivers'] as List?) ?? const [])
                  if (w is String) w,
              ],
              waivers: [
                for (final w in (p['waivers'] as List?) ?? const [])
                  if (w is Map)
                    AcceptedWaiver(
                      title:
                          LocalText.tryParse(w['title']) ?? const LocalText(''),
                      version: (w['version'] as num?)?.toInt() ?? 1,
                      at: _time(w['at']),
                      as: w['as'] as String?,
                    ),
              ],
            ),
      ],
    );
  }

  final String registrationId;
  final String status;
  final int? waitlistPosition;
  final DateTime? offerExpiresAt;
  final DateTime? submittedAt;
  final String? cancelReason;
  final String? contactName;

  /// Only for those who may read private details.
  final String? contactEmail;
  final List<String> linkedAdults;
  final List<RegistrationChange> changes;
  final List<GroupRegistrationPerson> people;

  /// The actions open from this status (Req 66), approve only with review.
  List<RegistrationAction> actions({required bool review}) => switch (status) {
    'pending' => [
      if (review) RegistrationAction.approve,
      RegistrationAction.waitlist,
    ],
    'submitted' => const [RegistrationAction.waitlist],
    'waitlisted' || 'cancelled' => const [RegistrationAction.reinstate],
    _ => const [],
  };

  bool get canCancel =>
      const ['submitted', 'pending', 'waitlisted'].contains(status);
  bool get canResend =>
      const ['submitted', 'pending', 'waitlisted'].contains(status);
}
