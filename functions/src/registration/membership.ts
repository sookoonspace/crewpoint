import {FieldValue} from "firebase-admin/firestore";
import {expenseAccessOf} from "../events/expenseAccess";
import {MemberFields, memberDoc, memberRef, readEventRoles, rebuildMember} from "../events/members";
import {EventRoles, legacyRoleIds} from "../events/permissions";
import {registrationOf} from "./registrationSettings";

/**
 * Membership through the registration role (Spec #233 Req 60-63, TD 10;
 * #245). A submitted registration makes its contact and each linked adult
 * (the group's `adultUids`) a member with the event's
 * `registrationRoleId`; members keep their roles and gain it. Cancelling
 * (or merging away) takes back only what registering gave, recorded as the
 * member's `registrationGrant`: the role, unless they already held it, and
 * the group's access. Someone left with no role leaves the event. Member
 * documents are written only here and by the other server paths, with
 * `permissions` from `computePermissions` and the arrays kept in step.
 * Children never have accounts, so never become members this way; personal
 * RSVP links (#252) call this only once a guest is linked.
 */

type Data = FirebaseFirestore.DocumentData;

/** [current]'s fields after registering through [groupId]. */
export function granted(
  current: Data | null,
  roleId: string,
  groupId: string,
  participantId: string | null,
  legacyRoles: string[]
): MemberFields {
  const roleIds: string[] = current ? [...(current.roleIds ?? [])] : [...legacyRoles];
  const grant = current?.registrationGrant as MemberFields["registrationGrant"] | undefined;
  const alreadyHeld = roleIds.includes(roleId);
  if (!alreadyHeld) roleIds.push(roleId);
  return {
    roleIds,
    crewIds: current?.crewIds,
    participantId: current?.participantId ?? participantId,
    joinedAt: current?.joinedAt,
    editsOwnGroup: true,
    groupIds: [...new Set([...(current?.groupIds ?? []), groupId])],
    registrationGrant: {
      // Kept from an earlier grant; null when they held it before.
      roleId: grant ? grant.roleId : alreadyHeld ? null : roleId,
      groupIds: [...new Set([...(grant?.groupIds ?? []), groupId])],
    },
  };
}

/** [current]'s fields once [groupId]'s registration no longer counts, or null when they leave. */
export function revoked(current: Data, groupId: string): MemberFields | null {
  const grant = current.registrationGrant as MemberFields["registrationGrant"] | undefined;
  const groupIds = (current.groupIds ?? []).filter((g: string) => g !== groupId);
  let roleIds: string[] = [...(current.roleIds ?? [])];
  let registrationGrant: MemberFields["registrationGrant"];
  if (grant) {
    const left = grant.groupIds.filter((g) => g !== groupId);
    if (left.length === 0) {
      if (grant.roleId) roleIds = roleIds.filter((r) => r !== grant.roleId);
      registrationGrant = undefined;
    } else {
      registrationGrant = {roleId: grant.roleId, groupIds: left};
    }
  }
  if (roleIds.length === 0) return null;
  return {
    roleIds,
    crewIds: current.crewIds,
    participantId: current.participantId ?? null,
    joinedAt: current.joinedAt,
    editsOwnGroup: groupIds.length > 0,
    groupIds,
    registrationGrant,
  };
}

/** What a transaction read, to apply membership for one registration. */
export interface MembershipPlan {
  eventRef: FirebaseFirestore.DocumentReference;
  event: Data;
  roles: EventRoles;
  groupId: string;
  roleId: string;
  /** The contact's participant, for their member document. */
  contactParticipantId: Record<string, string | null>;
  members: Array<{uid: string; snap: FirebaseFirestore.DocumentSnapshot}>;
}

/**
 * Reads what [write] needs, for the registration at [registrationRef]: the
 * event, its roles, the group's adults and their member documents. Call
 * before any write in the transaction. [adults] replaces the group's
 * `adultUids` when the group is written in the same transaction.
 */
async function read(
  tx: FirebaseFirestore.Transaction,
  eventRef: FirebaseFirestore.DocumentReference,
  registrationRef: FirebaseFirestore.DocumentReference,
  known?: {event?: Data; groupId?: string; adults?: string[]; contactUid?: string; contactParticipantId?: string | null}
): Promise<MembershipPlan> {
  const event = known?.event ?? (await tx.get(eventRef)).data()!;
  let groupId = known?.groupId;
  let contactUid = known?.contactUid;
  if (!groupId || !contactUid) {
    const reg = (await tx.get(registrationRef)).data() ?? {};
    groupId = groupId ?? String(reg.groupId);
    contactUid = contactUid ?? reg.contactUid;
  }
  const adults = known?.adults ??
    ((await tx.get(eventRef.collection("groups").doc(groupId))).data()?.adultUids ?? []);
  const uids = [...new Set([contactUid, ...adults].filter((u): u is string => typeof u === "string"))];
  const [roles, ...snaps] = await Promise.all([
    readEventRoles(tx, eventRef),
    ...uids.map((u) => tx.get(memberRef(eventRef, u))),
  ]);
  return {
    eventRef,
    event,
    roles: roles as EventRoles,
    groupId,
    roleId: registrationOf(event).registrationRoleId,
    contactParticipantId: contactUid ? {[contactUid]: known?.contactParticipantId ?? null} : {},
    members: uids.map((uid, i) => ({uid, snap: snaps[i] as FirebaseFirestore.DocumentSnapshot})),
  };
}

/**
 * Grants (status `submitted`) or takes back (`cancelled`) membership for
 * the plan's people, updating member documents and the event's arrays and
 * count once. Any other status changes nothing: pending and waitlisted
 * groups are not members yet (Req 60).
 */
function write(tx: FirebaseFirestore.Transaction, plan: MembershipPlan, status: string): void {
  if (status !== "submitted" && status !== "cancelled") return;
  const access = expenseAccessOf(plan.event);
  const memberIds: string[] = plan.event.memberIds ?? [];
  const joined: string[] = [];
  const left: string[] = [];
  for (const {uid, snap} of plan.members) {
    const ref = memberRef(plan.eventRef, uid);
    const isMember = snap.exists || memberIds.includes(uid);
    if (status === "submitted") {
      const current = snap.exists ? snap.data()! : null;
      const fields = granted(current, plan.roleId, plan.groupId,
        plan.contactParticipantId[uid] ?? null, isMember ? legacyRoleIds(plan.event, uid) : []);
      tx.set(ref, current ?
        rebuildMember(uid, {...current, ...fields}, plan.roles, access) :
        memberDoc(uid, fields, plan.roles, access));
      if (!isMember) joined.push(uid);
    } else if (snap.exists) {
      const fields = revoked(snap.data()!, plan.groupId);
      if (fields === null) {
        tx.delete(ref);
        left.push(uid);
      } else {
        tx.set(ref, memberDoc(uid, fields, plan.roles, access));
      }
    }
  }
  if (joined.length === 0 && left.length === 0) return;
  const after = [...memberIds.filter((u) => !left.includes(u)), ...joined.filter((u) => !memberIds.includes(u))];
  tx.update(plan.eventRef, {
    ...(joined.length ? {memberIds: FieldValue.arrayUnion(...joined)} : {}),
    ...(left.length ? {memberIds: FieldValue.arrayRemove(...left), adminIds: FieldValue.arrayRemove(...left)} : {}),
    memberCount: after.length,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

export const applyRegistrationMembership = {read, write};
