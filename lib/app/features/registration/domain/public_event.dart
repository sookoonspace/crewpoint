import 'package:flutter/foundation.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

/// Whether the event page lets people register now (Spec #233 Req 14).
enum PublicEventState { open, notOpen, closed }

@immutable
class PublicVenue {
  const PublicVenue({
    required this.name,
    this.address = '',
    this.mapUrl = '',
    this.directions = '',
  });

  final String name;

  /// Empty means to be announced.
  final String address;
  final String mapUrl;
  final String directions;
}

/// What `getEventPage` returns for `/e/:eventSlug` (#240): only the event's
/// public fields, never its ID, people, counts or money. A draft carries
/// only [state].
@immutable
class PublicEvent {
  const PublicEvent({
    required this.state,
    this.slug = '',
    this.title = '',
    this.description = '',
    this.startDate,
    this.endDate,
    this.dateOnly = false,
    this.timeZone = 'UTC',
    this.venues = const [],
    this.included,
    this.deadline,
    this.mode = RegistrationMode.invited,
    this.placesRemain = true,
    this.hasCover = false,
    this.labels = const {},
    this.contactLine,
  });

  factory PublicEvent.fromMap(Map<String, dynamic> data) {
    DateTime? time(Object? raw) => raw is num
        ? DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true)
        : null;
    String text(Object? raw) => raw is String ? raw : '';
    return PublicEvent(
      state: switch (data['state']) {
        'open' => PublicEventState.open,
        'closed' => PublicEventState.closed,
        _ => PublicEventState.notOpen,
      },
      slug: text(data['slug']),
      title: text(data['title']),
      description: text(data['description']),
      startDate: time(data['startDate']),
      endDate: time(data['endDate']),
      dateOnly: data['dateOnly'] == true,
      timeZone: text(data['timeZone']).isEmpty ? 'UTC' : text(data['timeZone']),
      venues: [
        for (final v in (data['venues'] as List?) ?? const [])
          if (v is Map)
            PublicVenue(
              name: text(v['name']),
              address: text(v['address']),
              mapUrl: text(v['mapUrl']),
              directions: text(v['directions']),
            ),
      ],
      included: LocalText.tryParse(data['included']),
      deadline: time(data['deadline']),
      mode: data['mode'] == 'open'
          ? RegistrationMode.open
          : RegistrationMode.invited,
      placesRemain: data['placesRemain'] != false,
      hasCover: data['hasCover'] == true,
      contactLine: LocalText.tryParse(data['contactLine']),
      labels: data['labels'] is Map
          ? Map<String, dynamic>.from(data['labels'] as Map)
          : const {},
    );
  }

  final PublicEventState state;
  final String slug;
  final String title;
  final String description;

  /// Instants; with [dateOnly] they are calendar dates at midnight UTC.
  final DateTime? startDate;
  final DateTime? endDate;
  final bool dateOnly;
  final String timeZone;
  final List<PublicVenue> venues;
  final LocalText? included;
  final DateTime? deadline;
  final RegistrationMode mode;

  /// Whether someone registering now gets a place. The page never shows how
  /// many.
  final bool placesRemain;
  final bool hasCover;
  final Map<String, dynamic> labels;

  /// How to reach the organizer, shown once registration closes (#244).
  final LocalText? contactLine;

  LabelResolver get words => LabelResolver(labels);

  /// Whether the page offers Register: open, and open to anyone with the
  /// link.
  bool get canRegister =>
      state == PublicEventState.open && mode == RegistrationMode.open;
}
