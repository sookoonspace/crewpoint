import 'package:cloud_functions/cloud_functions.dart';

/// The event's one active invite (Req 31).
typedef InviteCode = ({String code, String roleId});

/// The callables that change who is in an event and what they may do. A seam,
/// so tests never reach Firebase. The server checks every permission.
abstract interface class MemberCalls {
  /// Replaces [uid]'s roles. Needs `roles.manage`.
  Future<void> setMemberRoles({
    required String eventId,
    required String uid,
    required List<String> roleIds,
  });

  /// Saves the event's own version of a preset, or a custom role.
  Future<void> saveEventRole({
    required String eventId,
    required String roleId,
    required String name,
    required List<String> permissions,
  });

  /// Resets an edited preset, or deletes a custom role nobody holds.
  Future<void> deleteEventRole({
    required String eventId,
    required String roleId,
  });

  /// The active invite. A null [roleId] keeps the active invite's role, and a
  /// different one replaces the code.
  Future<InviteCode> generateInviteCode({
    required String eventId,
    String? roleId,
    bool rotate = false,
  });

  /// Removes [uid] from the event, or leaves it when [uid] is the caller.
  Future<void> removeMember({required String eventId, required String uid});

  /// Creates a crew, or renames one. Needs `members.manage`.
  Future<void> saveCrew({
    required String eventId,
    required String crewId,
    required String name,
  });

  /// Sets exactly who is in a crew.
  Future<void> setCrewMembers({
    required String eventId,
    required String crewId,
    required List<String> uids,
  });

  /// Deletes a crew, taking it off people and tasks.
  Future<void> deleteCrew({required String eventId, required String crewId});
}

class FirebaseMemberCalls implements MemberCalls {
  const FirebaseMemberCalls();

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call<Map<String, dynamic>>(data);
    return result.data;
  }

  @override
  Future<void> setMemberRoles({
    required String eventId,
    required String uid,
    required List<String> roleIds,
  }) => _call('setMemberRoles', {
    'eventId': eventId,
    'targetUserId': uid,
    'roleIds': roleIds,
  });

  @override
  Future<void> saveEventRole({
    required String eventId,
    required String roleId,
    required String name,
    required List<String> permissions,
  }) => _call('saveEventRole', {
    'eventId': eventId,
    'roleId': roleId,
    'name': name,
    'permissions': permissions,
  });

  @override
  Future<void> deleteEventRole({
    required String eventId,
    required String roleId,
  }) => _call('deleteEventRole', {'eventId': eventId, 'roleId': roleId});

  @override
  Future<InviteCode> generateInviteCode({
    required String eventId,
    String? roleId,
    bool rotate = false,
  }) async {
    final data = await _call('generateInviteCode', {
      'eventId': eventId,
      'roleId': ?roleId,
      if (rotate) 'rotate': true,
    });
    return (
      code: data['code'] as String,
      // Functions from before #67 return no role.
      roleId: data['roleId'] as String? ?? 'participant',
    );
  }

  @override
  Future<void> removeMember({required String eventId, required String uid}) =>
      _call('removeEventMember', {'eventId': eventId, 'targetUserId': uid});

  @override
  Future<void> saveCrew({
    required String eventId,
    required String crewId,
    required String name,
  }) => _call('saveCrew', {'eventId': eventId, 'crewId': crewId, 'name': name});

  @override
  Future<void> setCrewMembers({
    required String eventId,
    required String crewId,
    required List<String> uids,
  }) => _call('setCrewMembers', {
    'eventId': eventId,
    'crewId': crewId,
    'uids': uids,
  });

  @override
  Future<void> deleteCrew({required String eventId, required String crewId}) =>
      _call('deleteCrew', {'eventId': eventId, 'crewId': crewId});
}
