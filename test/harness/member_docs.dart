import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';

/// Gives every event in [firestore] a member document for each person in its
/// arrays, mapped as the migration does: creator as Owner, admins as Admin and
/// everyone else as Participant. Tests seed events in the old shape, and the
/// app finds its events through member documents (#66).
Future<void> seedMemberDocs(FirebaseFirestore firestore) async {
  final events = await firestore.collection('events').get();
  for (final event in events.docs) {
    final data = event.data();
    final memberIds = (data['memberIds'] as List?)?.cast<String>() ?? const [];
    final adminIds = (data['adminIds'] as List?)?.cast<String>() ?? const [];
    for (final uid in memberIds) {
      final ref = event.reference.collection('members').doc(uid);
      if ((await ref.get()).exists) continue;
      final roleIds = data['creatorId'] == uid
          ? const ['owner']
          : adminIds.contains(uid)
          ? const ['admin']
          : const ['participant'];
      await ref.set({
        'uid': uid,
        'roleIds': roleIds,
        'permissions': legacyPermissions(roleIds.single),
      });
    }
  }
}

/// The permissions the server gives the three roles the migration uses.
List<String> legacyPermissions(String role) => switch (role) {
  'owner' => _all,
  'admin' => [
    for (final p in _all)
      if (p != 'event.transfer' && p != 'roles.manage') p,
  ],
  _ => const ['group.readOwn', 'chat.send'],
};

const _all = [
  'event.manage',
  'event.transfer',
  'members.manage',
  'roles.manage',
  'schedule.edit',
  'updates.send',
  'participants.read',
  'participants.edit',
  'participants.readPrivate',
  'participants.import',
  'group.readOwn',
  'group.editOwn',
  'registrations.manage',
  'money.read',
  'money.record',
  'money.refund',
  'money.dueAtDoor',
  'budget.read',
  'budget.edit',
  'expenses.readAll',
  'contributions.manage',
  'tasks.manage',
  'chat.send',
  'chat.urgent',
  'messages.send',
  'checkin.scan',
  'checkin.lookup',
  'counts.read',
  'incidents.report',
  'incidents.receive',
  'reports.export',
  'competition.manage',
  'scores.enter',
];

/// Memberships for tests, read from [firestore]'s `events` collection, whose
/// snapshots the fake does send again on every change, plus each event's
/// member document for [uid]. Write a member document before its event, as
/// [fakeCreateEventCall] and [seedMemberDocs] do, so the event's change
/// carries it. An event with no member document maps from its arrays.
MembershipsSource fakeMemberships(FirebaseFirestore firestore) =>
    (uid) => firestore.collection('events').snapshots().asyncMap((
      events,
    ) async {
      final out = <Membership>[];
      for (final event in events.docs) {
        final member = await event.reference
            .collection('members')
            .doc(uid)
            .get();
        final data = member.data();
        if (data != null) {
          if (data['uid'] != uid) continue;
          out.add((
            eventId: event.id,
            roleIds: ((data['roleIds'] as List?) ?? const []).cast<String>(),
            perms: ((data['permissions'] as List?) ?? const [])
                .cast<String>()
                .toSet(),
          ));
          continue;
        }
        // Events seeded in the old shape map from their arrays, as the
        // migration would have.
        final e = event.data();
        final role = e['creatorId'] == uid
            ? 'owner'
            : ((e['adminIds'] as List?) ?? const []).contains(uid)
            ? 'admin'
            : ((e['memberIds'] as List?) ?? const []).contains(uid)
            ? 'participant'
            : null;
        if (role == null) continue;
        out.add((
          eventId: event.id,
          roleIds: [role],
          perms: legacyPermissions(role).toSet(),
        ));
      }
      return out;
    });
