import {onCall, HttpsError} from "firebase-functions/v2/https";
import {expenseAccessOf} from "./expenseAccess";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {
  prepareRoleChange,
  readEventRoles,
  readPermissions,
  rebuildMember,
} from "./members";
import {PERMISSIONS, PRESET_ROLES, isAdminLevel} from "./permissions";
import {assertNotArchived} from "./eventStatus";

const db = getFirestore();

const MAX_ROLES = 20;
const MAX_NAME = 60;

function requirePermissions(value: unknown): string[] {
  const known: readonly string[] = PERMISSIONS;
  const valid =
    Array.isArray(value) &&
    value.every((p) => typeof p === "string" && known.includes(p)) &&
    new Set(value).size === value.length;
  if (!valid) {
    throw new HttpsError(
      "invalid-argument",
      "permissions must be different names from the catalogue."
    );
  }
  return value as string[];
}

function requireRoleIds(value: unknown): string[] {
  const valid =
    Array.isArray(value) &&
    value.length > 0 &&
    value.length <= MAX_ROLES &&
    value.every((r) => typeof r === "string" && r.length > 0) &&
    new Set(value).size === value.length;
  if (!valid) {
    throw new HttpsError(
      "invalid-argument",
      "roleIds must be a list of different roles."
    );
  }
  return value as string[];
}

/**
 * setMemberRoles — replaces a member's roles and recalculates their
 * permissions (Req 27).
 */
export const setMemberRoles = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const targetUserId = requireString(data.targetUserId, "targetUserId");
  const roleIds = requireRoleIds(data.roleIds);

  return withStructuredLogs(
    {op: "setMemberRoles", uid, args: {eventId, targetUserId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        const eventDoc = await tx.get(eventRef);
        if (!eventDoc.exists) {
          throw new HttpsError("not-found", "Event not found.");
        }
        const eventData = eventDoc.data()!;
        assertNotArchived(eventData);
        // Plain members must never be in a draft (L23).
        if (eventData.status === "draft" && !isAdminLevel(roleIds)) {
          throw new HttpsError(
            "failed-precondition",
            "Publish this event before giving someone a non-admin role."
          );
        }
        const mine = await readPermissions(tx, eventRef, eventData, uid);
        if (!mine.includes("roles.manage")) {
          throw new HttpsError(
            "permission-denied",
            "Only owners and co-owners can change roles."
          );
        }
        if (!(eventData.memberIds ?? []).includes(targetUserId)) {
          throw new HttpsError(
            "failed-precondition",
            "This person is not a member of this event."
          );
        }
        const write = await prepareRoleChange(
          tx,
          eventRef,
          eventData,
          targetUserId,
          (current, roles) => {
            if (current.includes("owner") !== roleIds.includes("owner")) {
              throw new HttpsError(
                "failed-precondition",
                "Ownership changes only through a transfer."
              );
            }
            const unknown = roleIds.filter((r) => !PRESET_ROLES[r] && !roles[r]);
            if (unknown.length > 0) {
              throw new HttpsError("invalid-argument", "Unknown role.");
            }
            return roleIds;
          }
        );
        write();
        tx.update(eventRef, {
          adminIds: isAdminLevel(roleIds) ?
            FieldValue.arrayUnion(targetUserId) :
            FieldValue.arrayRemove(targetUserId),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      return {success: true};
    }
  );
});

/**
 * saveEventRole — saves an event's own version of a preset, or a custom role,
 * and recalculates the permissions of everyone holding it (Req 26a, 27).
 */
export const saveEventRole = onCall({timeoutSeconds: 60}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const roleId = requireString(data.roleId, "roleId");
  if (!/^[A-Za-z0-9_-]{1,40}$/.test(roleId)) {
    throw new HttpsError("invalid-argument", "roleId is not valid.");
  }
  const name = requireString(data.name, "name").trim();
  if (name.length === 0 || name.length > MAX_NAME) {
    throw new HttpsError(
      "invalid-argument",
      `A role name needs 1 to ${MAX_NAME} characters.`
    );
  }
  const permissions = requirePermissions(data.permissions);

  return withStructuredLogs(
    {op: "saveEventRole", uid, args: {eventId, roleId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        const eventDoc = await tx.get(eventRef);
        if (!eventDoc.exists) {
          throw new HttpsError("not-found", "Event not found.");
        }
        const eventData = eventDoc.data()!;
        assertNotArchived(eventData);
        const mine = await readPermissions(tx, eventRef, eventData, uid);
        if (!mine.includes("roles.manage")) {
          throw new HttpsError(
            "permission-denied",
            "Only owners and co-owners can change roles."
          );
        }
        // The Owner always holds everything, so ownership stays meaningful.
        if (roleId === "owner") {
          throw new HttpsError(
            "failed-precondition",
            "The Owner role cannot be changed."
          );
        }
        const roles = await readEventRoles(tx, eventRef);
        const holders = await tx.get(
          eventRef.collection("members").where("roleIds", "array-contains", roleId)
        );
        const saved = {
          name,
          permissions,
          preset: Boolean(PRESET_ROLES[roleId]),
          updatedAt: FieldValue.serverTimestamp(),
        };
        const next = {...roles, [roleId]: saved};
        tx.set(eventRef.collection("roles").doc(roleId), saved);
        holders.docs.forEach((doc) =>
          tx.set(
            doc.ref,
            rebuildMember(doc.id, doc.data(), next, expenseAccessOf(eventData))
          )
        );
      });
      return {success: true};
    }
  );
});

/**
 * deleteEventRole — removes an event's own version of a role (Req 26a). For a
 * preset this resets it to the built-in permissions and recalculates everyone
 * holding it. A custom role is deleted only while nobody holds it, so nobody
 * is left with no role.
 */
export const deleteEventRole = onCall({timeoutSeconds: 60}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as Record<string, unknown>;
  const eventId = requireString(data.eventId, "eventId");
  const roleId = requireString(data.roleId, "roleId");
  if (!/^[A-Za-z0-9_-]{1,40}$/.test(roleId)) {
    throw new HttpsError("invalid-argument", "roleId is not valid.");
  }

  return withStructuredLogs(
    {op: "deleteEventRole", uid, args: {eventId, roleId}},
    async () => {
      const eventRef = db.collection("events").doc(eventId);
      await db.runTransaction(async (tx) => {
        const eventDoc = await tx.get(eventRef);
        if (!eventDoc.exists) {
          throw new HttpsError("not-found", "Event not found.");
        }
        const eventData = eventDoc.data()!;
        assertNotArchived(eventData);
        const mine = await readPermissions(tx, eventRef, eventData, uid);
        if (!mine.includes("roles.manage")) {
          throw new HttpsError(
            "permission-denied",
            "Only owners and co-owners can change roles."
          );
        }
        const roles = await readEventRoles(tx, eventRef);
        const holders = await tx.get(
          eventRef.collection("members").where("roleIds", "array-contains", roleId)
        );
        if (!PRESET_ROLES[roleId] && !holders.empty) {
          throw new HttpsError(
            "failed-precondition",
            "Take this role off everyone who holds it first."
          );
        }
        if (!roles[roleId]) return;
        const next = {...roles};
        delete next[roleId];
        tx.delete(eventRef.collection("roles").doc(roleId));
        holders.docs.forEach((doc) =>
          tx.set(
            doc.ref,
            rebuildMember(doc.id, doc.data(), next, expenseAccessOf(eventData))
          )
        );
      });
      return {success: true};
    }
  );
});
