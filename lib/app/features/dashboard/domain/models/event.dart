import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';

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

/// Event status (Req 19).
enum EventStatus {
  /// Visible only to `event.manage`, and nobody can join.
  draft,

  /// Visible to members and open to joining.
  published,

  /// Set automatically from the start time, or by hand.
  live,

  /// Set automatically after the end time, or by hand. Settlements, expenses
  /// and chat stay open, and everything else is read-only except to
  /// `event.manage`.
  ended,

  /// Set by hand, and read-only for everyone. `event.manage` can restore it.
  archived;

  /// Reads a stored status. An event from before these statuses is `active`,
  /// which means `ended` if its end date has passed, or else `published`.
  static EventStatus fromStored(
    String? value,
    DateTime? endDate,
    DateTime now,
  ) => switch (value) {
    'draft' => draft,
    'published' => published,
    'live' => live,
    'ended' => ended,
    'archived' => archived,
    _ => (endDate != null && !endDate.isAfter(now)) ? ended : published,
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
    this.dateOnly = false,
    this.startDate,
    this.endDate,
    this.adminIds = const [],
    this.memberIds = const [],
    this.status = EventStatus.published,
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

  /// Whether [startDate] and [endDate] are calendar dates, stored as midnight
  /// UTC so they stay on the chosen date in every zone. False on older events,
  /// whose dates are midnight on the device that created them.
  final bool dateOnly;
  final String creatorId;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> adminIds;
  final List<String> memberIds;
  final EventStatus status;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// This event's words for each concept.
  LabelResolver get words => LabelResolver(labels);

  /// [displayType] with a capital letter, or null when there is none.
  String? get typeLabel {
    final type = displayType;
    if (type == null || type.isEmpty) return null;
    return '${type[0].toUpperCase()}${type.substring(1)}';
  }

  /// Whether [uid] holds `event.manage`, which means owner or admin until
  /// permissions land.
  bool canManage(String uid) => isAdmin(uid);

  /// The dates to show or edit, as local dates.
  DateTime? get displayStart => _display(startDate);
  DateTime? get displayEnd => _display(endDate);

  DateTime? _display(DateTime? date) {
    if (date == null) return null;
    if (!dateOnly) return date.toLocal();
    final utc = date.toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// [instant] as the clock reads where the event is.
  DateTime inZone(DateTime instant) => inEventZone(instant, timeZone);

  /// The instant a chosen calendar day starts where the event is.
  DateTime startOfDay(DateTime picked) =>
      eventLocalToUtc(picked.year, picked.month, picked.day, timeZone);

  /// The calendar day [instant] falls on where the event is, as a local date.
  DateTime calendarDay(DateTime instant) {
    final there = inZone(instant);
    return DateTime(there.year, there.month, there.day);
  }

  /// Whether the event's last day is over where the event is.
  bool isPast(DateTime now) {
    final last = dateOnly ? displayEnd ?? displayStart : null;
    if (last != null) return last.isBefore(calendarDay(now));
    final boundary = endDate ?? startDate;
    if (boundary == null) return false;
    return boundary.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// A module is on unless turned off, so events from before modules keep
  /// working. Turning one off keeps its data.
  bool isModuleOn(String module) => modules[module] ?? true;

  /// A draft is visible only to `event.manage`.
  bool isVisibleTo(String uid) => status != EventStatus.draft || canManage(uid);

  bool get isJoinable =>
      status == EventStatus.published || status == EventStatus.live;

  /// Settlements, expenses and chat stay open until an event is archived.
  bool get allowsChatAndMoney => status != EventStatus.archived;

  /// Once an event ends, only `event.manage` can change its tasks.
  bool canEditTasks(String uid) => switch (status) {
    EventStatus.archived => false,
    EventStatus.ended => canManage(uid),
    _ => true,
  };

  /// Nobody but organizers may see a draft, so an event with plain members
  /// cannot go back to one.
  bool get canBeDraft =>
      memberIds.every((uid) => uid == creatorId || adminIds.contains(uid));

  /// The status an archived event returns to.
  EventStatus restoredStatus(DateTime now) => (endDate != null && isPast(now))
      ? EventStatus.ended
      : EventStatus.published;

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
    Map<String, dynamic>? labels,
    Map<String, bool>? modules,
    bool? dateOnly,
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
      modules: modules ?? this.modules,
      labels: labels ?? this.labels,
      settings: settings,
      capacity: clearCapacity ? null : (capacity ?? this.capacity),
      memberLimit: clearMemberLimit ? null : (memberLimit ?? this.memberLimit),
      dateOnly: dateOnly ?? this.dateOnly,
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
