import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:crewpoint_app/app/features/schedule/domain/models/attendance.dart';
import 'package:flutter/foundation.dart';

/// A person attending an event, with or without an account, children
/// included (Req 40). `events/{eventId}/participants/{id}`.
@immutable
class ParticipantModel {
  const ParticipantModel({
    required this.id,
    required this.eventId,
    required this.name,
    this.groupId,
    this.isChild = false,
    this.status = 'active',
    this.uid,
    this.createdBy,
    this.categoryId,
    this.fields = const {},
    this.anonymised = false,
    this.filterTags = const [],
    this.arrivalAt,
    this.departureAt,
    this.optOuts = const [],
    this.signUps = const [],
    this.invitedTo = const [],
  });

  factory ParticipantModel.fromFirestore(
    String eventId,
    String id,
    Map<String, dynamic> data,
  ) => ParticipantModel(
    id: id,
    eventId: eventId,
    name: data['name'] as String? ?? '',
    groupId: data['groupId'] as String?,
    isChild: data['isChild'] == true,
    status: data['status'] as String? ?? 'active',
    uid: data['uid'] as String?,
    createdBy: data['createdBy'] as String?,
    categoryId: data['categoryId'] as String?,
    fields: _answers(data['fields']),
    anonymised: data['anonymised'] == true,
    filterTags: _ids(data['filterTags']),
    arrivalAt: _time(data['arrivalAt']),
    departureAt: _time(data['departureAt']),
    optOuts: _ids(data['optOuts']),
    signUps: _ids(data['signUps']),
    invitedTo: _ids(data['invitedTo']),
  );

  final String id;
  final String eventId;
  final String name;
  final String? groupId;
  final bool isChild;

  /// `active`, or `cancelled` once a re-import drops them (Req 45).
  final String status;

  /// The linked account, set only by the server (#78).
  final String? uid;
  final String? createdBy;

  /// Their category, such as an age band (Req 42). Shown in reports instead
  /// of a birth date.
  final String? categoryId;

  /// Standard custom field answers, by field ID (Req 41).
  final Map<String, Object?> fields;

  /// Left by a deleted account (Req 14a): no name, kept only so counts stay
  /// right. Set only by the server.
  final bool anonymised;

  /// Tags from standard answers, as saved (Req 41). Read for eligibility;
  /// saving works them out again from [fields].
  final List<String> filterTags;

  /// When they arrive and leave, for arrival-to-departure attendance
  /// (Req 50). Null means from the start, or to the end.
  final DateTime? arrivalAt;
  final DateTime? departureAt;

  /// Attendance exceptions, as session IDs (Req 50). Only organizers with
  /// `participants.edit` invite.
  final List<String> optOuts;
  final List<String> signUps;
  final List<String> invitedTo;

  /// This person for working out attendance, with their group's invitations.
  Attendee attendee([List<String> groupInvitedTo = const []]) => Attendee(
    status: status,
    categoryId: categoryId,
    filterTags: filterTags,
    arrivalAt: arrivalAt,
    departureAt: departureAt,
    optOuts: optOuts,
    signUps: signUps,
    invitedTo: invitedTo,
    groupInvitedTo: groupInvitedTo,
  );

  /// Lower-case, for searching by the start of a name.
  String get sortName => name.trim().toLowerCase();

  ParticipantModel copyWith({
    String? name,
    String? groupId,
    bool clearGroup = false,
    bool? isChild,
    String? categoryId,
    bool clearCategory = false,
    Map<String, Object?>? fields,
    DateTime? arrivalAt,
    bool clearArrival = false,
    DateTime? departureAt,
    bool clearDeparture = false,
    List<String>? optOuts,
    List<String>? signUps,
    List<String>? invitedTo,
  }) => ParticipantModel(
    id: id,
    eventId: eventId,
    name: name ?? this.name,
    groupId: clearGroup ? null : (groupId ?? this.groupId),
    isChild: isChild ?? this.isChild,
    status: status,
    uid: uid,
    createdBy: createdBy,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    fields: fields ?? this.fields,
    anonymised: anonymised,
    filterTags: filterTags,
    arrivalAt: clearArrival ? null : (arrivalAt ?? this.arrivalAt),
    departureAt: clearDeparture ? null : (departureAt ?? this.departureAt),
    optOuts: optOuts ?? this.optOuts,
    signUps: signUps ?? this.signUps,
    invitedTo: invitedTo ?? this.invitedTo,
  );

  @override
  bool operator ==(Object other) =>
      other is ParticipantModel &&
      other.categoryId == categoryId &&
      mapEquals(other.fields, fields) &&
      other.id == id &&
      other.eventId == eventId &&
      other.name == name &&
      other.groupId == groupId &&
      other.isChild == isChild &&
      other.status == status &&
      other.uid == uid &&
      other.createdBy == createdBy &&
      other.anonymised == anonymised &&
      other.arrivalAt == arrivalAt &&
      other.departureAt == departureAt &&
      listEquals(other.optOuts, optOuts) &&
      listEquals(other.signUps, signUps) &&
      listEquals(other.invitedTo, invitedTo);

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    name,
    groupId,
    isChild,
    status,
    uid,
    createdBy,
    categoryId,
  );
}

List<String> _ids(Object? raw) => [
  if (raw is List)
    for (final v in raw)
      if (v is String) v,
];

DateTime? _time(Object? raw) => raw is Timestamp ? raw.toDate().toUtc() : null;

Map<String, Object?> _answers(Object? raw) => raw is Map
    ? {
        for (final e in raw.entries)
          if (e.key is String)
            e.key as String: e.value is List
                ? List<String>.from((e.value as List).whereType<String>())
                : e.value,
      }
    : const {};

/// A participant's private details (Z-01), in
/// `participants/{id}/private/details`. Read with `participants.readPrivate`
/// or by the group's linked adults.
@immutable
class ParticipantPrivate {
  const ParticipantPrivate({
    this.birthDate,
    this.email,
    this.fields = const {},
  });

  factory ParticipantPrivate.fromFirestore(Map<String, dynamic> data) =>
      ParticipantPrivate(
        birthDate: data['birthDate'] as String?,
        email: data['email'] as String?,
        fields: _answers(data['fields']),
      );

  /// A calendar date, `YYYY-MM-DD`.
  final String? birthDate;

  /// From an import, which linking an account matches on (Req 46). Not
  /// edited in the app, but kept when the details are saved.
  final String? email;

  /// Private custom field answers, by field ID (Req 41).
  final Map<String, Object?> fields;

  @override
  bool operator ==(Object other) =>
      other is ParticipantPrivate &&
      other.birthDate == birthDate &&
      other.email == email &&
      mapEquals(other.fields, fields);

  @override
  int get hashCode => birthDate.hashCode;
}

/// People handled together, such as a household, team or foursome (Req 40).
/// Written only by the group callables.
@immutable
class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    this.adultUids = const [],
    this.fields = const {},
    this.invitedTo = const [],
  });

  factory GroupModel.fromFirestore(String id, Map<String, dynamic> data) =>
      GroupModel(
        id: id,
        name: data['name'] as String? ?? '',
        adultUids: [
          for (final u in (data['adultUids'] as List?) ?? const [])
            if (u is String) u,
        ],
        fields: _answers(data['fields']),
        invitedTo: _ids(data['invitedTo']),
      );

  final String id;
  final String name;

  /// Members with accounts who look after this group (Req 26b).
  final List<String> adultUids;

  /// Standard answers to group fields (Req 41).
  final Map<String, Object?> fields;

  /// Sessions the whole group is invited to (Req 50), set by organizers.
  final List<String> invitedTo;
}
