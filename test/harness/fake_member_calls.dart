import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/features/dashboard/data/member_calls.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';

/// Stands in for the member and role callables. With a [firestore], it writes
/// what the server would: member documents with their permissions worked out
/// from roles, role documents, and the arrays. Server-side checks are covered
/// by `functions/test/events/roles.test.ts` and `inviteRoles.test.ts`.
class FakeMemberCalls implements MemberCalls {
  FakeMemberCalls({this.firestore, this.code = 'ABC234'});

  final FirebaseFirestore? firestore;
  final String code;

  /// Every call, as `name:arguments`, for tests to check.
  final calls = <String>[];

  /// Thrown by the next call, then cleared, to test failures.
  Object? failNext;

  String _inviteRole = 'participant';
  int _rotations = 0;

  void _maybeFail() {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  DocumentReference<Map<String, dynamic>> _event(String eventId) =>
      firestore!.collection('events').doc(eventId);

  Future<List<RoleDefinition>> _roles(String eventId) async {
    final snap = await _event(eventId).collection('roles').get();
    return resolveRoles(RoleCatalogue.current, {
      for (final doc in snap.docs) doc.id: doc.data(),
    });
  }

  /// Rewrites [uid]'s member document, then touches the event so its
  /// listeners, and so `fakeMemberships`, see the change.
  Future<void> _writeMember(
    String eventId,
    String uid,
    List<String> roleIds,
  ) async {
    final roles = await _roles(eventId);
    await _event(eventId).collection('members').doc(uid).set({
      'uid': uid,
      'roleIds': roleIds,
      'permissions': computePermissions(roleIds, roles),
    }, SetOptions(merge: true));
    final adminLevel = roleIds.any(
      (r) => r == 'owner' || r == 'coOwner' || r == 'admin',
    );
    await _event(eventId).update({
      'adminIds': adminLevel
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
      'updatedAt': DateTime.now(),
    });
  }

  @override
  Future<void> setMemberRoles({
    required String eventId,
    required String uid,
    required List<String> roleIds,
  }) async {
    calls.add('setMemberRoles:$uid:${roleIds.join(',')}');
    _maybeFail();
    if (firestore != null) await _writeMember(eventId, uid, roleIds);
  }

  Future<void> _recalculateHolders(String eventId, String roleId) async {
    final holders = await _event(
      eventId,
    ).collection('members').where('roleIds', arrayContains: roleId).get();
    for (final doc in holders.docs) {
      final roleIds = (doc.data()['roleIds'] as List).cast<String>();
      await _writeMember(eventId, doc.id, roleIds);
    }
  }

  @override
  Future<void> saveEventRole({
    required String eventId,
    required String roleId,
    required String name,
    required List<String> permissions,
  }) async {
    calls.add('saveEventRole:$roleId:$name:${permissions.join(',')}');
    _maybeFail();
    if (firestore == null) return;
    await _event(eventId).collection('roles').doc(roleId).set({
      'name': name,
      'permissions': permissions,
      'preset': RoleCatalogue.current.presets.any((p) => p.id == roleId),
    });
    await _recalculateHolders(eventId, roleId);
  }

  @override
  Future<void> deleteEventRole({
    required String eventId,
    required String roleId,
  }) async {
    calls.add('deleteEventRole:$roleId');
    _maybeFail();
    if (firestore == null) return;
    final isPreset = RoleCatalogue.current.presets.any((p) => p.id == roleId);
    final held = await _event(
      eventId,
    ).collection('members').where('roleIds', arrayContains: roleId).get();
    if (!isPreset && held.docs.isNotEmpty) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Take this role off everyone who holds it first.',
      );
    }
    await _event(eventId).collection('roles').doc(roleId).delete();
    await _recalculateHolders(eventId, roleId);
  }

  @override
  Future<InviteCode> generateInviteCode({
    required String eventId,
    String? roleId,
    bool rotate = false,
  }) async {
    calls.add('generateInviteCode:${roleId ?? '-'}:$rotate');
    _maybeFail();
    if (roleId != null && roleId != _inviteRole) {
      _inviteRole = roleId;
      _rotations++;
    }
    if (rotate) _rotations++;
    return (
      code: _rotations == 0 ? code : '${code.substring(0, 5)}$_rotations',
      roleId: _inviteRole,
    );
  }

  @override
  Future<void> removeMember({
    required String eventId,
    required String uid,
  }) async {
    calls.add('removeMember:$uid');
    _maybeFail();
    if (firestore == null) return;
    await _event(eventId).collection('members').doc(uid).delete();
    await _event(eventId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
      'adminIds': FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<void> saveCrew({
    required String eventId,
    required String crewId,
    required String name,
  }) async {
    calls.add('saveCrew:$crewId:$name');
    _maybeFail();
    if (firestore == null) return;
    await _event(eventId).collection('crews').doc(crewId).set({
      'name': name.trim(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setCrewMembers({
    required String eventId,
    required String crewId,
    required List<String> uids,
  }) async {
    calls.add('setCrewMembers:$crewId:${uids.join(',')}');
    _maybeFail();
    if (firestore == null) return;
    final members = await _event(eventId).collection('members').get();
    for (final doc in members.docs) {
      final crews = ((doc.data()['crewIds'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      final next = uids.contains(doc.id)
          ? ({...crews, crewId})
          : ({...crews}..remove(crewId));
      if (next.length != crews.length) {
        await doc.reference.update({'crewIds': next.toList()});
      }
    }
  }

  @override
  Future<void> deleteCrew({
    required String eventId,
    required String crewId,
  }) async {
    calls.add('deleteCrew:$crewId');
    _maybeFail();
    if (firestore == null) return;
    await _event(eventId).collection('crews').doc(crewId).delete();
    await setCrewMembers(eventId: eventId, crewId: crewId, uids: const []);
    calls.removeLast();
    final tasks = await _event(
      eventId,
    ).collection('tasks').where('crewId', isEqualTo: crewId).get();
    for (final doc in tasks.docs) {
      await doc.reference.update({'crewId': null});
    }
  }

  DocumentReference<Map<String, dynamic>> _offer(String eventId) =>
      _event(eventId).collection('ownership').doc('offer');

  /// The signed-in person, for ownership calls. Tests set it to act as
  /// someone else on another device.
  String actingAs = 'owner';

  @override
  Future<void> offerOwnership({
    required String eventId,
    required String toUid,
  }) async {
    calls.add('offerOwnership:$toUid');
    _maybeFail();
    if (firestore == null) return;
    await _offer(eventId).set({'from': actingAs, 'to': toUid});
  }

  @override
  Future<void> acceptOwnership({required String eventId}) async {
    calls.add('acceptOwnership');
    _maybeFail();
    if (firestore == null) return;
    final offer = (await _offer(eventId).get()).data()!;
    final from = offer['from'] as String;
    final to = offer['to'] as String;
    Future<List<String>> rolesOf(String uid) async =>
        (((await _event(eventId).collection('members').doc(uid).get())
                    .data()?['roleIds']
                as List?) ??
                const [])
            .cast<String>();
    final toRoles = await rolesOf(to);
    final fromRoles = await rolesOf(from);
    await _offer(eventId).delete();
    await _event(eventId).update({'creatorId': to});
    await _writeMember(eventId, from, [
      for (final r in fromRoles)
        if (r != 'owner' && r != 'coOwner') r,
      'coOwner',
    ]);
    await _writeMember(eventId, to, [
      for (final r in toRoles)
        if (!const {'owner', 'coOwner', 'admin', 'participant'}.contains(r)) r,
      'owner',
    ]);
  }

  @override
  Future<void> cancelOwnershipOffer({required String eventId}) async {
    calls.add('cancelOwnershipOffer');
    _maybeFail();
    if (firestore == null) return;
    await _offer(eventId).delete();
  }
}
