/// `events/{id}/members/{uid}` (Req 25). Only the server writes it.
class MemberModel {
  const MemberModel({
    required this.uid,
    this.roleIds = const [],
    this.permissions = const {},
  });

  factory MemberModel.fromFirestore(String uid, Map<String, dynamic> data) =>
      MemberModel(
        uid: uid,
        roleIds: _strings(data['roleIds']),
        permissions: _strings(data['permissions']).toSet(),
      );

  final String uid;
  final List<String> roleIds;
  final Set<String> permissions;

  bool get isOwner => roleIds.contains('owner');

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];
}

/// Display names of the built-in presets (Req 26a). Custom roles show their
/// own name once the role screens arrive in #67.
const presetRoleNames = {
  'owner': 'Owner',
  'coOwner': 'Co-owner',
  'admin': 'Admin',
  'finance': 'Finance',
  'crewLead': 'Crew lead',
  'crewMember': 'Crew member',
  'volunteer': 'Volunteer',
  'scorer': 'Scorer',
  'vendor': 'Vendor',
  'sponsor': 'Sponsor',
  'participant': 'Participant',
  'observer': 'Observer',
};
