import 'package:flutter/foundation.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

/// One person in "my registration": their name and category only.
@immutable
class MyPerson {
  const MyPerson({required this.name, this.categoryId});

  final String name;
  final String? categoryId;
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
  });

  final String status;
  final int? waitlistPosition;
  final DateTime? submittedAt;
  final String groupName;
  final List<MyPerson> people;
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
              people: [
                for (final p in (r['people'] as List?) ?? const [])
                  if (p is Map && p['name'] is String)
                    MyPerson(
                      name: p['name'] as String,
                      categoryId: p['categoryId'] as String?,
                    ),
              ],
            )
          : null,
      note: LocalText.tryParse(data['note']),
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

  LabelResolver get words => LabelResolver(labels);
}
