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

  /// Lower-case, for searching by the start of a name.
  String get sortName => name.trim().toLowerCase();

  ParticipantModel copyWith({
    String? name,
    String? groupId,
    bool clearGroup = false,
    bool? isChild,
  }) => ParticipantModel(
    id: id,
    eventId: eventId,
    name: name ?? this.name,
    groupId: clearGroup ? null : (groupId ?? this.groupId),
    isChild: isChild ?? this.isChild,
    status: status,
    uid: uid,
    createdBy: createdBy,
  );

  @override
  bool operator ==(Object other) =>
      other is ParticipantModel &&
      other.id == id &&
      other.eventId == eventId &&
      other.name == name &&
      other.groupId == groupId &&
      other.isChild == isChild &&
      other.status == status &&
      other.uid == uid &&
      other.createdBy == createdBy;

  @override
  int get hashCode =>
      Object.hash(id, eventId, name, groupId, isChild, status, uid, createdBy);
}

/// A participant's private details (Z-01), in
/// `participants/{id}/private/details`. Read with `participants.readPrivate`
/// or by the group's linked adults.
@immutable
class ParticipantPrivate {
  const ParticipantPrivate({this.birthDate});

  /// A calendar date, `YYYY-MM-DD`.
  final String? birthDate;

  @override
  bool operator ==(Object other) =>
      other is ParticipantPrivate && other.birthDate == birthDate;

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
  });

  factory GroupModel.fromFirestore(String id, Map<String, dynamic> data) =>
      GroupModel(
        id: id,
        name: data['name'] as String? ?? '',
        adultUids: [
          for (final u in (data['adultUids'] as List?) ?? const [])
            if (u is String) u,
        ],
      );

  final String id;
  final String name;

  /// Members with accounts who look after this group (Req 26b).
  final List<String> adultUids;
}
