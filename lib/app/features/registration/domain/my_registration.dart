import 'package:flutter/foundation.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';
import 'package:crewpoint_app/app/features/registration/domain/waivers.dart';

/// One person in "my registration": their name and category, and the
/// waivers they still need to accept (#246).
@immutable
class MyPerson {
  const MyPerson({
    required this.name,
    this.id = '',
    this.categoryId,
    this.isChild = false,
    this.missingWaivers = const [],
  });

  final String id;
  final String name;
  final String? categoryId;
  final bool isChild;
  final List<String> missingWaivers;
}

/// The caller's registration, from `getMyRegistration` (#242).
@immutable
class MyRegistration {
  const MyRegistration({
    required this.status,
    this.waitlistPosition,
    this.submittedAt,
    this.groupName = '',
    this.people = const [],
    this.offerExpiresAt,
  });

  final String status;
  final int? waitlistPosition;
  final DateTime? submittedAt;
  final String groupName;
  final List<MyPerson> people;

  /// When a waitlist offer for the group runs out (#248); null without one.
  final DateTime? offerExpiresAt;

  /// Whether a place is on offer at [now].
  bool offeredAt(DateTime now) =>
      status == 'waitlisted' &&
      offerExpiresAt != null &&
      now.isBefore(offerExpiresAt!);
}

/// "My registration" for an event (Spec #233 Req 9, 19, 35; #242): the
/// event's name and dates, the caller's registration if they have one, and
/// the after-registration note, which the server sends only to submitted
/// groups and replaces from its date.
@immutable
class MyRegistrationView {
  const MyRegistrationView({
    required this.title,
    required this.timeZone,
    this.startDate,
    this.endDate,
    this.dateOnly = false,
    this.deadline,
    this.labels = const {},
    this.registration,
    this.note,
    this.waivers = const [],
  });

  factory MyRegistrationView.fromMap(Map<String, Object?> data) {
    DateTime? time(Object? raw) => raw is num
        ? DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true)
        : null;
    final r = data['registration'];
    return MyRegistrationView(
      title: data['title'] as String? ?? '',
      timeZone: data['timeZone'] as String? ?? 'UTC',
      startDate: time(data['startDate']),
      endDate: time(data['endDate']),
      dateOnly: data['dateOnly'] == true,
      deadline: time(data['deadline']),
      labels: data['labels'] is Map
          ? Map<String, dynamic>.from(data['labels'] as Map)
          : const {},
      registration: r is Map && r['status'] is String
          ? MyRegistration(
              status: r['status'] as String,
              waitlistPosition: (r['waitlistPosition'] as num?)?.toInt(),
              submittedAt: time(r['submittedAt']),
              groupName: r['groupName'] as String? ?? '',
              offerExpiresAt: time(r['offerExpiresAt']),
              people: [
                for (final p in (r['people'] as List?) ?? const [])
                  if (p is Map && p['name'] is String)
                    MyPerson(
                      id: p['id'] as String? ?? '',
                      name: p['name'] as String,
                      categoryId: p['categoryId'] as String?,
                      isChild: p['isChild'] == true,
                      missingWaivers: [
                        for (final w in (p['missingWaivers'] as List?) ?? const [])
                          if (w is String) w,
                      ],
                    ),
              ],
            )
          : null,
      note: LocalText.tryParse(data['note']),
      waivers: [
        for (final raw in (data['waivers'] as List?) ?? const [])
          ?Waiver.tryParse(raw),
      ],
    );
  }

  final String title;
  final String timeZone;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool dateOnly;
  final DateTime? deadline;
  final Map<String, dynamic> labels;
  final MyRegistration? registration;
  final LocalText? note;

  /// The event's waivers (#246), to accept the missing ones here.
  final List<Waiver> waivers;

  LabelResolver get words => LabelResolver(labels);
}

/// A registration of mine that is not confirmed yet, for home (#292):
/// waitlisted or pending, so I am not a member of its event yet.
@immutable
class WaitingRegistration {
  const WaitingRegistration({
    required this.eventId,
    required this.slug,
    required this.title,
    required this.status,
    this.startDate,
    this.endDate,
    this.dateOnly = false,
    this.timeZone = 'UTC',
    this.waitlistPosition,
    this.offerExpiresAt,
  });

  static WaitingRegistration? tryParse(Object? raw) {
    if (raw is! Map || raw['eventId'] is! String || raw['slug'] is! String) {
      return null;
    }
    DateTime? time(Object? v) => v is num
        ? DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true)
        : null;
    return WaitingRegistration(
      eventId: raw['eventId'] as String,
      slug: raw['slug'] as String,
      title: raw['title'] as String? ?? '',
      status: raw['status'] as String? ?? 'waitlisted',
      startDate: time(raw['startDate']),
      endDate: time(raw['endDate']),
      dateOnly: raw['dateOnly'] == true,
      timeZone: raw['timeZone'] as String? ?? 'UTC',
      waitlistPosition: (raw['waitlistPosition'] as num?)?.toInt(),
      offerExpiresAt: time(raw['offerExpiresAt']),
    );
  }

  final String eventId;
  final String slug;
  final String title;

  /// `waitlisted` or `pending`.
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool dateOnly;
  final String timeZone;
  final int? waitlistPosition;
  final DateTime? offerExpiresAt;

  bool offeredAt(DateTime now) =>
      status == 'waitlisted' &&
      offerExpiresAt != null &&
      now.isBefore(offerExpiresAt!);

  /// Whether the event is over at [now], so home leaves it out.
  bool isPastAt(DateTime now) {
    final end = endDate ?? startDate;
    return end != null && end.add(const Duration(days: 1)).isBefore(now);
  }
}
