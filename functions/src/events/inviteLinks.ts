import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertOpenToJoin} from "./eventStatus";
import {readEventRoles, readPermissions} from "./members";
import {PRESET_ROLES, type Permission} from "./permissions";
import {checkInviteExpiry, defaultInviteExpiry} from "./inviteExpiry";
import {InviteState, inviteState, inviteView} from "./inviteState";

const db = getFirestore();

// Characters: A-Z minus ambiguous (O, I, L) + 2-9.
const CHARSET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 6;

/** The most links `listInviteLinks` returns, newest first. */
export const MAX_LISTED_LINKS = 100;

function generateCode(): string {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CHARSET[Math.floor(Math.random() * CHARSET.length)];
  }
  return code;
}

/**
 * A code no invite uses yet, retrying up to 10 times on collisions. Reads
 * through the transaction, so the check holds until the write.
 */
export async function pickFreshCode(tx: FirebaseFirestore.Transaction): Promise<string> {
  const invites = db.collection("event_invites");
  for (let attempt = 0; attempt < 10; attempt++) {
    const code = generateCode();
    if (!(await tx.get(invites.doc(code))).exists) return code;
  }
  throw new HttpsError("internal", "Failed to generate unique code. Please try again.");
}

/**
 * Whether [held] may hand out [roleId] through a link: never Owner, only a
 * role the event has, and any role but Participant needs `roles.manage`,
 * because joining with it assigns that role.
 */
export function checkInviteRole(
  roleId: string,
  held: Permission[],
  roles: Record<string, unknown>
): void {
  if (roleId === "owner") {
    throw new HttpsError(
      "failed-precondition",
      "Nobody can join as Owner. Ownership changes only through a transfer."
    );
  }
  if (!PRESET_ROLES[roleId] && !roles[roleId]) {
    throw new HttpsError("invalid-argument", "Unknown role.");
  }
  if (roleId !== "participant" && !held.includes("roles.manage")) {
    throw new HttpsError(
      "permission-denied",
      "Only owners and co-owners can invite someone into a role."
    );
  }
}

function requireManager(held: Permission[]): void {
  if (!held.includes("members.manage")) {
    throw new HttpsError(
      "permission-denied",
      "Only people who manage members can handle invite links."
    );
  }
}

async function readEvent(tx: FirebaseFirestore.Transaction, eventId: string) {
  const eventRef = db.collection("events").doc(eventId);
  const eventDoc = await tx.get(eventRef);
  if (!eventDoc.exists) throw new HttpsError("not-found", "Event not found.");
  return {eventRef, eventData: eventDoc.data()!};
}

/**
 * createInviteLink — a new member invite link (Spec #233 Req 15, #238),
 * alongside the event's other links.
 *
 * - Caller needs `members.manage`; a role other than Participant also needs
 *   `roles.manage`, and nobody can invite into Owner.
 * - `roleId` defaults to Participant. `expiresAt` (milliseconds) is the
 *   organizer's expiry, from 5 minutes to 400 days; without it a link lasts
 *   24 hours on Blank and Party, or until the event starts (Req 56).
 * - `singleUse: true` makes a link that stops working after one join.
 * - Refused for a draft, ended or archived event, as joining is.
 */
export const createInviteLink = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as {
    eventId?: unknown; roleId?: unknown; expiresAt?: unknown; singleUse?: unknown;
  };
  const eventId = requireString(data.eventId, "eventId");
  const roleId =
    data.roleId === undefined || data.roleId === null ?
      "participant" :
      requireString(data.roleId, "roleId");
  const now = Date.now();
  const requestedExpiry =
    data.expiresAt === undefined || data.expiresAt === null ?
      null :
      checkInviteExpiry(data.expiresAt, now);
  if (data.singleUse !== undefined && typeof data.singleUse !== "boolean") {
    throw new HttpsError("invalid-argument", "singleUse must be true or false.");
  }
  const singleUse = data.singleUse === true;

  return withStructuredLogs(
    {op: "createInviteLink", uid, args: {eventId, roleId, singleUse}},
    () => db.runTransaction(async (tx) => {
      const {eventRef, eventData} = await readEvent(tx, eventId);
      const [held, roles] = await Promise.all([
        readPermissions(tx, eventRef, eventData, uid),
        readEventRoles(tx, eventRef),
      ]);
      requireManager(held);
      assertOpenToJoin(eventData);
      checkInviteRole(roleId, held, roles);
      const code = await pickFreshCode(tx);
      const expiresAt = requestedExpiry ?? defaultInviteExpiry(eventData, now);
      const invite = {
        eventId,
        roleId,
        singleUse,
        uses: 0,
        createdBy: uid,
        createdAt: Timestamp.fromMillis(now),
        expiresAt: Timestamp.fromMillis(expiresAt),
      };
      tx.set(db.collection("event_invites").doc(code), invite);
      return inviteView(code, invite, now);
    })
  );
});

/**
 * updateInviteLink — changes one of the event's links (#238).
 *
 * - `turnOff: true` turns it off for good, so it can no longer be used;
 *   `members.manage` is enough, whatever its role.
 * - `expiresAt` (milliseconds, 5 minutes to 400 days) changes its expiry and
 *   keeps the code (Req 56). A link into a role other than Participant
 *   needs `roles.manage` for this, as making one does. A turned-off or used
 *   link cannot be given a new expiry.
 * - The code must belong to `eventId`.
 */
export const updateInviteLink = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as {
    eventId?: unknown; code?: unknown; expiresAt?: unknown; turnOff?: unknown;
  };
  const eventId = requireString(data.eventId, "eventId");
  const code = requireString(data.code, "code").trim().toUpperCase();
  const now = Date.now();
  const turnOff = data.turnOff === true;
  const expiresAt =
    data.expiresAt === undefined || data.expiresAt === null ?
      null :
      checkInviteExpiry(data.expiresAt, now);
  if (turnOff === (expiresAt !== null)) {
    throw new HttpsError("invalid-argument", "Give either turnOff or expiresAt.");
  }

  return withStructuredLogs(
    {op: "updateInviteLink", uid, args: {eventId, code, turnOff}},
    () => db.runTransaction(async (tx) => {
      const {eventRef, eventData} = await readEvent(tx, eventId);
      const inviteRef = db.collection("event_invites").doc(code);
      const [held, inviteDoc] = await Promise.all([
        readPermissions(tx, eventRef, eventData, uid),
        tx.get(inviteRef),
      ]);
      requireManager(held);
      const invite = inviteDoc.data();
      if (!invite || invite.eventId !== eventId) {
        throw new HttpsError("not-found", "No such invite link in this event.");
      }
      const state = inviteState(invite, now);
      let changes: Record<string, unknown>;
      if (turnOff) {
        // Turning off twice keeps the first time.
        if (state === "off") return inviteView(code, invite, now);
        changes = {turnedOffAt: Timestamp.fromMillis(now), turnedOffBy: uid};
      } else {
        if (state === "off" || state === "used") {
          throw new HttpsError(
            "failed-precondition",
            "This link is turned off or used, so it cannot be extended."
          );
        }
        const roleId = typeof invite.roleId === "string" ? invite.roleId : "participant";
        if (roleId !== "participant" && !held.includes("roles.manage")) {
          throw new HttpsError(
            "permission-denied",
            "Only owners and co-owners can change a link into a role."
          );
        }
        changes = {expiresAt: Timestamp.fromMillis(expiresAt!)};
      }
      tx.update(inviteRef, changes);
      return inviteView(code, {...invite, ...changes}, now);
    })
  );
});

/**
 * listInviteLinks — the event's member invite links, newest first, at most
 * [MAX_LISTED_LINKS], with whether each can be used (#238). Needs
 * `members.manage`. `event_invites` has no client access, so this is the
 * only way to read them.
 */
export const listInviteLinks = onCall({timeoutSeconds: 30}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as {eventId?: unknown};
  const eventId = requireString(data.eventId, "eventId");

  return withStructuredLogs({op: "listInviteLinks", uid, args: {eventId}}, async () => {
    const eventRef = db.collection("events").doc(eventId);
    const eventDoc = await eventRef.get();
    if (!eventDoc.exists) throw new HttpsError("not-found", "Event not found.");
    requireManager(await readPermissions(null, eventRef, eventDoc.data()!, uid));
    const invites = await db
      .collection("event_invites")
      .where("eventId", "==", eventId)
      .orderBy("createdAt", "desc")
      .limit(MAX_LISTED_LINKS)
      .get();
    const now = Date.now();
    return {links: invites.docs.map((d) => inviteView(d.id, d.data(), now))};
  });
});

/** Marks [invite] used by [uid]'s join, inside the join's transaction. */
export function recordInviteUse(
  tx: FirebaseFirestore.Transaction,
  ref: FirebaseFirestore.DocumentReference,
  invite: FirebaseFirestore.DocumentData,
  uid: string
): void {
  tx.update(ref, {
    uses: FieldValue.increment(1),
    lastUsedAt: FieldValue.serverTimestamp(),
    ...(invite.singleUse === true ?
      {usedBy: uid, usedAt: FieldValue.serverTimestamp()} :
      {}),
  });
}

/**
 * Why a known link cannot be used (#238): `not-found`, as before, with
 * `details.reason` so the app can say why.
 */
export function unusableInvite(state: Exclude<InviteState, "active">): HttpsError {
  const message = {
    expired: "This invite has expired.",
    off: "This invite link was turned off.",
    used: "This single-use invite link has already been used.",
  }[state];
  return new HttpsError("not-found", message, {reason: state});
}
