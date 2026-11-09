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
      other.createdBy == createdBy;

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
  const ParticipantPrivate({this.birthDate, this.fields = const {}});

  factory ParticipantPrivate.fromFirestore(Map<String, dynamic> data) =>
      ParticipantPrivate(
        birthDate: data['birthDate'] as String?,
        fields: _answers(data['fields']),
      );

  /// A calendar date, `YYYY-MM-DD`.
  final String? birthDate;

  /// Private custom field answers, by field ID (Req 41).
  final Map<String, Object?> fields;

  @override
  bool operator ==(Object other) =>
      other is ParticipantPrivate &&
      other.birthDate == birthDate &&
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
      );

  final String id;
  final String name;

  /// Members with accounts who look after this group (Req 26b).
  final List<String> adultUids;

  /// Standard answers to group fields (Req 41).
  final Map<String, Object?> fields;
}
