/// Event types for categorization and filtering.
enum EventType {
  trip,
  project,
  social,
  custom;

  String get label => switch (this) {
    EventType.trip => 'Trip',
    EventType.project => 'Project',
    EventType.social => 'Social',
    EventType.custom => 'Custom',
  };

  static EventType fromString(String? value) => switch (value) {
    'trip' => EventType.trip,
    'project' => EventType.project,
    'social' => EventType.social,
    _ => EventType.custom,
  };
}

/// Event status.
enum EventStatus {
  active,
  archived;

  static EventStatus fromString(String? value) => switch (value) {
    'archived' => EventStatus.archived,
    _ => EventStatus.active,
  };
}

/// Domain model for an event.
class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.creatorId,
    this.description,
    this.eventType = EventType.custom,
    this.startDate,
    this.endDate,
    this.adminIds = const [],
    this.memberIds = const [],
    this.status = EventStatus.active,
    this.currency = 'USD',
  });

  final String id;
  final String title;
  final String? description;
  final EventType eventType;
  final String creatorId;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> adminIds;
  final List<String> memberIds;
  final EventStatus status;
  final String currency;

  /// Check if [uid] is the event owner (creator).
  bool isOwner(String uid) => creatorId == uid;

  /// Check if [uid] is an admin (or owner — owner is implicit admin).
  bool isAdmin(String uid) => creatorId == uid || adminIds.contains(uid);

  /// Check if [uid] is a member (memberIds includes admins and owner).
  bool isMember(String uid) => memberIds.contains(uid);
}
