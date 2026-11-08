/// `events/{id}/members/{uid}` (Req 25). Only the server writes it.
class MemberModel {
  const MemberModel({
    required this.uid,
    this.roleIds = const [],
    this.permissions = const {},
    this.crewIds = const [],
  });

  factory MemberModel.fromFirestore(String uid, Map<String, dynamic> data) =>
      MemberModel(
        uid: uid,
        roleIds: _strings(data['roleIds']),
        permissions: _strings(data['permissions']).toSet(),
        crewIds: _strings(data['crewIds']),
      );

  final String uid;
  final List<String> roleIds;
  final Set<String> permissions;

  /// The crews this person is in (Req 25).
  final List<String> crewIds;

  bool get isOwner => roleIds.contains('owner');

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];
}
