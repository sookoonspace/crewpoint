import 'package:crewpoint_app/app/features/dashboard/domain/models/expense_access.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/invite.dart';
import 'package:crewpoint_app/app/features/registration/domain/public_event.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_form.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';

/// What linking a signed-in account found (Req 46): events it was linked
/// in, events where an organizer must decide, and whether the email still
/// needs verifying.
typedef LinkResult = ({
  List<String> linked,
  List<String> asked,
  bool unverified,
});

/// Why a known invite link cannot be used (#238): `expired`, `off` or
/// `used`, from the `not-found` error's details. Null for an unknown code.
String? unusableInviteReason(FirebaseFunctionsException e) {
  final details = e.details;
  if (e.code != 'not-found' || details is! Map) return null;
  final reason = details['reason'];
  return reason is String ? reason : null;
}

/// What an invite link leads to, before joining (Req 47, `/join/:code`).
typedef InvitePreview = ({
  String eventId,
  String title,
  String roleName,
  bool open,

  /// Why it cannot be joined: `draft`, `ended` or `archived`.
  String? reason,
  bool alreadyMember,
  bool full,
  DateTime? startDate,
  bool dateOnly,
});

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

  /// The event's member invite links, newest first (#238). Needs
  /// `members.manage`.
  Future<List<InviteLink>> listInviteLinks(String eventId);

  /// A new invite link into [roleId], expiring at [expiresAt] or the
  /// template's default, working for one join when [singleUse] (#238).
  Future<InviteLink> createInviteLink({
    required String eventId,
    required String roleId,
    DateTime? expiresAt,
    bool singleUse = false,
  });

  /// Changes when [code] expires, keeping the code (Req 56).
  Future<InviteLink> setInviteLinkExpiry({
    required String eventId,
    required String code,
    required DateTime expiresAt,
  });

  /// Turns [code] off for good (#238).
  Future<InviteLink> turnOffInviteLink({
    required String eventId,
    required String code,
  });

  /// What [code] leads to. Throws `not-found` for an unknown or expired code.
  Future<InvitePreview> previewInvite(String code);

  /// Joins with [code] and returns the event's ID.
  Future<String> joinEvent(String code);

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

  /// Links the signed-in account to its own participant records by verified
  /// email (Req 46). Safe to repeat.
  Future<LinkResult> linkMyParticipants();

  /// Settles an ambiguous link (Req 46): one adult record, one group when
  /// only children matched, or not a match. Needs `participants.edit` and
  /// `participants.readPrivate`.
  Future<void> resolveLinkRequest({
    required String eventId,
    required String uid,
    String? participantId,
    String? groupId,
    bool dismiss = false,
  });

  /// Counts the event now (Req 52), into `stats/current`. Needs
  /// `counts.read`.
  Future<void> recalculateCounts(String eventId);

  /// The roster as CSV (Req 53). Private answers and birth dates only with
  /// [includePrivate], which needs `participants.readPrivate`. Needs
  /// `reports.export`.
  Future<String> exportRoster(String eventId, {bool includePrivate = false});

  /// Counts now and keeps the numbers with the date (Req 54). Needs
  /// `reports.export`.
  Future<void> freezeCounts(String eventId, {String? label});

  /// Keeps the event's configuration as the caller's own template (Req 65).
  /// Needs `event.manage`.
  Future<void> saveAsTemplate(String eventId, String name);

  /// Saves how the event registers and its capacity (#239), checked on the
  /// server against its fields and roles. Needs `event.manage`.
  Future<void> saveRegistrationSettings({
    required String eventId,
    required RegistrationSettings settings,
    required int? capacity,
  });

  /// Claims [slug] for the event's public link, or releases it with null,
  /// returning the name as kept. A name another event holds throws
  /// `already-exists` with `details.reason` `taken`. Needs `event.manage`.
  Future<String?> claimEventSlug({required String eventId, String? slug});

  /// The public event page for [slug] (#240), for anyone, signed in or
  /// not. Throws `not-found` for an unknown name, and `resource-exhausted`
  /// with `details.reason` `rateLimited` when one address opens too many.
  Future<PublicEvent> getEventPage(String slug);

  /// What the registration form for [slug] asks (#242), for a signed-in
  /// visitor. Throws `failed-precondition` (`notOpen`, `closed`) or
  /// `permission-denied` (`invitedOnly`) with `details.reason`.
  Future<RegistrationFormSpec> getRegistrationForm(String slug);

  /// Submits a registration (#242), [payload] as
  /// [RegistrationFormSpec.toSubmitMap] makes it. A repeat with the same
  /// `submissionId` returns the first result.
  Future<SubmitResult> submitRegistration(Map<String, Object?> payload);
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
  Future<List<InviteLink>> listInviteLinks(String eventId) async {
    final data = await _call('listInviteLinks', {'eventId': eventId});
    return [
      for (final l in (data['links'] as List?) ?? const [])
        if (l is Map) InviteLink.fromMap(l),
    ];
  }

  @override
  Future<InviteLink> createInviteLink({
    required String eventId,
    required String roleId,
    DateTime? expiresAt,
    bool singleUse = false,
  }) async => InviteLink.fromMap(
    await _call('createInviteLink', {
      'eventId': eventId,
      'roleId': roleId,
      if (expiresAt != null) 'expiresAt': expiresAt.millisecondsSinceEpoch,
      'singleUse': singleUse,
    }),
  );

  @override
  Future<InviteLink> setInviteLinkExpiry({
    required String eventId,
    required String code,
    required DateTime expiresAt,
  }) async => InviteLink.fromMap(
    await _call('updateInviteLink', {
      'eventId': eventId,
      'code': code,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    }),
  );

  @override
  Future<InviteLink> turnOffInviteLink({
    required String eventId,
    required String code,
  }) async => InviteLink.fromMap(
    await _call('updateInviteLink', {
      'eventId': eventId,
      'code': code,
      'turnOff': true,
    }),
  );

  @override
  Future<InvitePreview> previewInvite(String code) async {
    final data = await _call('previewInvite', {'code': code});
    final start = data['startDate'];
    return (
      eventId: data['eventId'] as String,
      title: data['title'] as String? ?? '',
      roleName: data['roleName'] as String? ?? '',
      open: data['open'] == true,
      reason: data['reason'] as String?,
      alreadyMember: data['alreadyMember'] == true,
      full: data['full'] == true,
      startDate: start is num
          ? DateTime.fromMillisecondsSinceEpoch(start.toInt(), isUtc: true)
          : null,
      dateOnly: data['dateOnly'] == true,
    );
  }

  @override
  Future<String> joinEvent(String code) async {
    final data = await _call('joinEvent', {'joinCode': code});
    return data['eventId'] as String;
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

  @override
  Future<LinkResult> linkMyParticipants() async {
    final data = await _call('linkMyParticipants', const {});
    List<String> ids(Object? v) =>
        v is List ? v.whereType<String>().toList() : const [];
    return (
      linked: ids(data['linked']),
      asked: ids(data['asked']),
      unverified: data['unverified'] == true,
    );
  }

  @override
  Future<void> resolveLinkRequest({
    required String eventId,
    required String uid,
    String? participantId,
    String? groupId,
    bool dismiss = false,
  }) => _call('resolveLinkRequest', {
    'eventId': eventId,
    'uid': uid,
    'participantId': ?participantId,
    'groupId': ?groupId,
    if (dismiss) 'dismiss': true,
  });

  @override
  Future<void> recalculateCounts(String eventId) =>
      _call('recalculateCounts', {'eventId': eventId});

  @override
  Future<String> exportRoster(
    String eventId, {
    bool includePrivate = false,
  }) async {
    final data = await _call('exportRoster', {
      'eventId': eventId,
      'includePrivate': includePrivate,
    });
    return data['csv'] as String? ?? '';
  }

  @override
  Future<void> freezeCounts(String eventId, {String? label}) =>
      _call('freezeCounts', {'eventId': eventId, 'label': ?label});

  @override
  Future<void> saveAsTemplate(String eventId, String name) =>
      _call('saveAsTemplate', {'eventId': eventId, 'name': name});

  @override
  Future<void> saveRegistrationSettings({
    required String eventId,
    required RegistrationSettings settings,
    required int? capacity,
  }) => _call('saveRegistrationSettings', {
    'eventId': eventId,
    'registration': settings.toCallMap(),
    'capacity': capacity,
  });

  @override
  Future<String?> claimEventSlug({
    required String eventId,
    String? slug,
  }) async {
    final data = await _call('claimEventSlug', {
      'eventId': eventId,
      'slug': slug,
    });
    return data['slug'] as String?;
  }

  @override
  Future<PublicEvent> getEventPage(String slug) async =>
      PublicEvent.fromMap(await _call('getEventPage', {'slug': slug}));

  @override
  Future<RegistrationFormSpec> getRegistrationForm(String slug) async =>
      RegistrationFormSpec.fromMap(
        await _call('getRegistrationForm', {'slug': slug}),
      );

  @override
  Future<SubmitResult> submitRegistration(
    Map<String, Object?> payload,
  ) async => SubmitResult.fromMap(await _call('submitRegistration', payload));
}
