import 'package:crewpoint_app/app/features/dashboard/domain/models/expense_access.dart';
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

  /// The Owner offers ownership to [toUid] (Req 30).
  Future<void> offerOwnership({required String eventId, required String toUid});

  /// The person offered becomes Owner, and the old owner a Co-owner.
  Future<void> acceptOwnership({required String eventId});

  /// The Owner withdraws the offer, or the person offered declines it.
  Future<void> cancelOwnershipOffer({required String eventId});

  /// Creates a group of participants, or renames one. Needs
  /// `participants.edit` (Req 40).
  Future<void> saveGroup({
    required String eventId,
    required String groupId,
    required String name,
  });

  /// Sets exactly which members are a group's linked adults (Req 26b).
  Future<void> setGroupAdults({
    required String eventId,
    required String groupId,
    required List<String> uids,
  });

  /// Deletes an empty group.
  Future<void> deleteGroup({required String eventId, required String groupId});

  /// Cancels groups a re-import listed as missing (Req 45). Needs
  /// `participants.import`.
  Future<void> cancelImportedGroups({
    required String eventId,
    required String jobId,
    required List<String> groupIds,
  });

  /// Chooses who reads every expense (Req 38). Needs `event.manage`.
  Future<void> setExpenseAccess({
    required String eventId,
    required ExpenseAccess access,
  });
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

  @override
  Future<void> offerOwnership({
    required String eventId,
    required String toUid,
  }) => _call('offerOwnership', {'eventId': eventId, 'toUid': toUid});

  @override
  Future<void> acceptOwnership({required String eventId}) =>
      _call('acceptOwnership', {'eventId': eventId});

  @override
  Future<void> cancelOwnershipOffer({required String eventId}) =>
      _call('cancelOwnershipOffer', {'eventId': eventId});

  @override
  Future<void> saveGroup({
    required String eventId,
    required String groupId,
    required String name,
  }) => _call('saveGroup', {
    'eventId': eventId,
    'groupId': groupId,
    'name': name,
  });

  @override
  Future<void> setGroupAdults({
    required String eventId,
    required String groupId,
    required List<String> uids,
  }) => _call('setGroupAdults', {
    'eventId': eventId,
    'groupId': groupId,
    'uids': uids,
  });

  @override
  Future<void> deleteGroup({
    required String eventId,
    required String groupId,
  }) => _call('deleteGroup', {'eventId': eventId, 'groupId': groupId});

  @override
  Future<void> cancelImportedGroups({
    required String eventId,
    required String jobId,
    required List<String> groupIds,
  }) => _call('cancelImportedGroups', {
    'eventId': eventId,
    'jobId': jobId,
    'groupIds': groupIds,
  });

  @override
  Future<void> setExpenseAccess({
    required String eventId,
    required ExpenseAccess access,
  }) =>
      _call('setExpenseAccess', {'eventId': eventId, 'access': access.toMap()});
}
