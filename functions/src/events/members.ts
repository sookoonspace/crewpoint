import {FieldValue} from "firebase-admin/firestore";
import {
  EventRoles,
  Permission,
  computePermissions,
  legacyRoleIds,
} from "./permissions";

/**
 * `events/{id}/members/{uid}` (Req 25). Only server code writes it, and
 * `permissions` is always worked out here from `roleIds`, never sent by a
 * client (Req 27). Until #66 the old arrays stay the source for reads, so
 * every membership change writes both.
 */
export interface MemberFields {
  roleIds: string[];
  crewIds?: string[];
  participantId?: string | null;
  joinedAt?: FirebaseFirestore.Timestamp | FieldValue;
  editsOwnGroup?: boolean;
}

export function memberRef(
  eventRef: FirebaseFirestore.DocumentReference,
  uid: string
): FirebaseFirestore.DocumentReference {
  return eventRef.collection("members").doc(uid);
}

export function memberDoc(
  uid: string,
  fields: MemberFields,
  eventRoles: EventRoles
): FirebaseFirestore.DocumentData {
  const doc: FirebaseFirestore.DocumentData = {
    uid,
    roleIds: fields.roleIds,
    crewIds: fields.crewIds ?? [],
    permissions: computePermissions(fields.roleIds, eventRoles, {
      editsOwnGroup: fields.editsOwnGroup,
    }),
    participantId: fields.participantId ?? null,
    joinedAt: fields.joinedAt ?? FieldValue.serverTimestamp(),
  };
  // Set by groups from #75, so it is kept only when known.
  if (fields.editsOwnGroup !== undefined) {
    doc.editsOwnGroup = fields.editsOwnGroup;
  }
  return doc;
}

/** The event's own role documents: edited presets and custom roles. */
export async function readEventRoles(
  tx: FirebaseFirestore.Transaction,
  eventRef: FirebaseFirestore.DocumentReference
): Promise<EventRoles> {
  const snapshot = await tx.get(eventRef.collection("roles"));
  const roles: EventRoles = {};
  snapshot.docs.forEach((doc) => (roles[doc.id] = doc.data()));
  return roles;
}

/**
 * Changes someone's roles and recalculates their permissions, keeping the
 * rest of their member document. On an event not yet migrated, it starts
 * from the old arrays. Reads come first, so it can run inside a transaction
 * before any writes.
 */
export async function prepareRoleChange(
  tx: FirebaseFirestore.Transaction,
  eventRef: FirebaseFirestore.DocumentReference,
  eventData: FirebaseFirestore.DocumentData,
  uid: string,
  change: (roleIds: string[], roles: EventRoles) => string[]
): Promise<() => void> {
  const ref = memberRef(eventRef, uid);
  const [existing, roles] = await Promise.all([
    tx.get(ref),
    readEventRoles(tx, eventRef),
  ]);
  const current = existing.data();
  const roleIds = change(
    Array.isArray(current?.roleIds) ?
      current!.roleIds :
      legacyRoleIds(eventData, uid),
    roles
  );
  const doc = rebuildMember(uid, {...current, roleIds}, roles);
  return () => tx.set(ref, doc);
}

/**
 * A member document with its permissions worked out again from its roles,
 * keeping everything else.
 */
export function rebuildMember(
  uid: string,
  current: FirebaseFirestore.DocumentData,
  roles: EventRoles
): FirebaseFirestore.DocumentData {
  return memberDoc(
    uid,
    {
      roleIds: current.roleIds ?? [],
      crewIds: current.crewIds,
      participantId: current.participantId,
      joinedAt: current.joinedAt,
      editsOwnGroup: current.editsOwnGroup,
    },
    roles
  );
}

/**
 * What someone may do in an event: the server-written `permissions` on their
 * member document, or, on an event not yet migrated, what the old arrays map
 * to. Someone outside the event has none.
 */
export async function readPermissions(
  tx: FirebaseFirestore.Transaction,
  eventRef: FirebaseFirestore.DocumentReference,
  eventData: FirebaseFirestore.DocumentData,
  uid: string
): Promise<Permission[]> {
  const doc = await tx.get(memberRef(eventRef, uid));
  if (doc.exists) return doc.data()!.permissions ?? [];
  return computePermissions(legacyRoleIds(eventData, uid), {});
}
