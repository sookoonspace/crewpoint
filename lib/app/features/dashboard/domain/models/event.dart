/// A place an event happens. Map link, directions and "to be announced" arrive
/// with sessions.
class EventVenue {
  const EventVenue({required this.id, required this.name, this.address});

  factory EventVenue.fromMap(Map<String, dynamic> map) => EventVenue(
    id: (map['id'] as String?) ?? '',
    name: (map['name'] as String?) ?? '',
    address: map['address'] as String?,
  );

  final String id;
  final String name;
  final String? address;

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'address': address};

  @override
  bool operator ==(Object other) =>
      other is EventVenue &&
      other.id == id &&
      other.name == name &&
      other.address == address;

  @override
  int get hashCode => Object.hash(id, name, address);
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
    this.templateId = defaultTemplateId,
    this.displayType,
    this.organizerId,
    this.timeZone = defaultTimeZone,
    this.venues = const [],
    this.languages = defaultLanguages,
    this.modules = defaultModules,
    this.labels = const {},
    this.settings = const {},
    this.capacity,
    this.memberLimit,
    this.startDate,
    this.endDate,
    this.adminIds = const [],
    this.memberIds = const [],
    this.status = EventStatus.active,
    this.currency = 'USD',
    this.createdAt,
    this.updatedAt,
  });

  static const defaultTemplateId = 'blank';
  static const defaultTimeZone = 'UTC';
  static const defaultLanguages = ['en'];
  static const defaultModules = {'tasks': true, 'budget': true, 'chat': true};

  final String id;
  final String title;
  final String? description;
  final String templateId;

  /// The name of the old event type, kept as display text only (Req 21). Newer
  /// events have none.
  final String? displayType;

  /// Null on an event from before organizers.
  final String? organizerId;
  final String timeZone;
  final List<EventVenue> venues;
  final List<String> languages;
  final Map<String, bool> modules;
  final Map<String, dynamic> labels;
  final Map<String, dynamic> settings;

  /// How many people can attend, with or without an account. Not enforced in
  /// Stage 1. Null means not set.
  final int? capacity;

  /// How many people can log in to the event. Null means unlimited.
  final int? memberLimit;
  final String creatorId;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> adminIds;
  final List<String> memberIds;
  final EventStatus status;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// [displayType] with a capital letter, or null when there is none.
  String? get typeLabel {
    final type = displayType;
    if (type == null || type.isEmpty) return null;
    return '${type[0].toUpperCase()}${type.substring(1)}';
  }

  /// Whether [uid] holds `event.manage`, which means owner or admin until
  /// permissions land.
  bool canManage(String uid) => isAdmin(uid);

  /// Check if [uid] is the event owner (creator).
  bool isOwner(String uid) => creatorId == uid;

  /// Check if [uid] is an admin (or owner — owner is implicit admin).
  bool isAdmin(String uid) => creatorId == uid || adminIds.contains(uid);

  /// Whether [actor] may remove [target], matching `removeEventMember`: the
  /// owner can remove anyone else, and an admin can remove other members.
  bool canRemoveMember({required String actor, required String target}) =>
      actor != target &&
      !isOwner(target) &&
      (isOwner(actor) || (isAdmin(actor) && !isAdmin(target)));

  /// Check if [uid] is a member (memberIds includes admins and owner).
  bool isMember(String uid) => memberIds.contains(uid);

  EventModel copyWith({
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    EventStatus? status,
    String? currency,
    String? timeZone,
    List<EventVenue>? venues,
    List<String>? languages,
    int? capacity,
    int? memberLimit,
    bool clearCapacity = false,
    bool clearMemberLimit = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return EventModel(
      id: id,
      title: title ?? this.title,
      creatorId: creatorId,
      description: description ?? this.description,
      templateId: templateId,
      displayType: displayType,
      organizerId: organizerId,
      timeZone: timeZone ?? this.timeZone,
      venues: venues ?? this.venues,
      languages: languages ?? this.languages,
      modules: modules,
      labels: labels,
      settings: settings,
      capacity: clearCapacity ? null : (capacity ?? this.capacity),
      memberLimit: clearMemberLimit ? null : (memberLimit ?? this.memberLimit),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      adminIds: adminIds,
      memberIds: memberIds,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
