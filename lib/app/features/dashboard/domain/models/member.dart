/// `events/{id}/members/{uid}` (Req 25). Only the server writes it.
class MemberModel {
  const MemberModel({
    required this.uid,
    this.roleIds = const [],
    this.permissions = const {},
    this.crewIds = const [],
    this.groupIds = const [],
    this.participantId,
  });

  factory MemberModel.fromFirestore(String uid, Map<String, dynamic> data) =>
      MemberModel(
        uid: uid,
        roleIds: _strings(data['roleIds']),
        permissions: _strings(data['permissions']).toSet(),
        crewIds: _strings(data['crewIds']),
        groupIds: _strings(data['groupIds']),
        participantId: data['participantId'] as String?,
      );

  final String uid;
  final List<String> roleIds;
  final Set<String> permissions;

  /// The crews this person is in (Req 25).
  final List<String> crewIds;

  /// The groups this person is a linked adult of (Req 26b).
  final List<String> groupIds;

  /// Their own participant record, once linked by verified email (#78).
  final String? participantId;

  bool get isOwner => roleIds.contains('owner');

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];
}
