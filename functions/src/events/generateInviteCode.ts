import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertOpenToJoin} from "./eventStatus";

import {readEventRoles, readPermissions} from "./members";
import {checkInviteExpiry, defaultInviteExpiry} from "./inviteExpiry";
import {checkInviteRole, pickFreshCode} from "./inviteLinks";
import {inviteState} from "./inviteState";
const db = getFirestore();

/** The role an invite carries. Invites from before roles mean Participant. */
export function inviteRoleId(invite: FirebaseFirestore.DocumentData): string {
  return typeof invite.roleId === "string" ? invite.roleId : "participant";
}

/**
 * generateInviteCode — the newest usable invite link, for apps from before
 * #238, which showed one invite per event (Req 31). Current apps use
 * `createInviteLink`, `updateInviteLink` and `listInviteLinks`, and this
 * never deletes or changes the event's other links.
 *
 * - Caller needs `members.manage`. An invite into any role other than
 *   Participant also needs `roles.manage`, because joining with it assigns
 *   that role. Nobody can invite into Owner.
 * - **No `roleId`:** returns the newest usable link with its role, or a
 *   new Participant link if there is none.
 * - **`expiresAt`** (milliseconds): the organizer's expiry, from 5 minutes
 *   to a whole registration period (Req 56). Changing only the expiry keeps
 *   the code. Without it, the current expiry stays, and a new invite gets
 *   24 hours on Blank and Party or lasts until the event starts otherwise.
 * - **`roleId` the same as the active invite's:** returns that invite, so
 *   codes already shared keep working until their 24-hour expiry.
 * - **A different `roleId`:** turns that link off and makes a new one with
 *   the new role, so an old code never grants the new role.
 * - **`rotate: true`:** turns that link off and makes a new one with the
 *   same role and expiry. Use when a code may have leaked. Only the literal
 *   boolean `true` rotates, avoiding the `Boolean('false') === true` pitfall.
 * - Everything runs in one transaction.
 */
export const generateInviteCode = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const data = (request.data ?? {}) as {
      eventId?: unknown;
      rotate?: unknown;
      roleId?: unknown;
      expiresAt?: unknown;
    };
    const eventId = requireString(data.eventId, "eventId");
    const rotate = data.rotate === true;
    const requestedRole =
      data.roleId === undefined || data.roleId === null ?
        null :
        requireString(data.roleId, "roleId");

    const uid = request.auth.uid;
    const requestedExpiry =
      data.expiresAt === undefined || data.expiresAt === null ?
        null :
        checkInviteExpiry(data.expiresAt, Date.now());
    const mode: "rotate" | "reuse" = rotate ? "rotate" : "reuse";

    return withStructuredLogs(
      {op: "generateInviteCode", uid, args: {eventId, mode, roleId: requestedRole}},
      async () => {
        const eventRef = db.collection("events").doc(eventId);
        const invitesRef = db.collection("event_invites");
        return db.runTransaction(async (tx) => {
          // ── PHASE 1: all reads ──────────────────────────────────────
          // Firestore transactions require every read to precede every
          // write, including the collision checks for a fresh code.
          const eventDoc = await tx.get(eventRef);
          if (!eventDoc.exists) {
            throw new HttpsError("not-found", "Event not found.");
          }
          const eventData = eventDoc.data()!;
          assertOpenToJoin(eventData);
          // Reads all finish before any check throws, so no read is left
          // running after the transaction ends.
          const [mine, roles, existing] = await Promise.all([
            readPermissions(tx, eventRef, eventData, uid),
            readEventRoles(tx, eventRef),
            tx.get(
              invitesRef
                .where("eventId", "==", eventId)
                .orderBy("createdAt", "desc")
            ),
          ]);
          if (!mine.includes("members.manage")) {
            throw new HttpsError(
              "permission-denied",
              "Only people who manage members can generate invite codes."
            );
          }
          const now = Date.now();
          // Single-use links are left to the apps that make them.
          const active = existing.docs.filter(
            (doc) =>
              inviteState(doc.data(), now) === "active" &&
              doc.data().singleUse !== true
          );
          const current = active[0];
          const roleId =
            requestedRole ?? (current ? inviteRoleId(current.data()) : "participant");

          checkInviteRole(roleId, mine, roles);

          const currentExpiry: number | null =
            current?.data().expiresAt?.toMillis?.() ?? null;
          // The organizer's expiry, else the current one, else the default
          // for the event's template (Req 56).
          const expiresAt =
            requestedExpiry ?? currentExpiry ?? defaultInviteExpiry(eventData, now);

          // Reuse hit: same role, not rotating. A new expiry keeps the link.
          if (current && !rotate && inviteRoleId(current.data()) === roleId) {
            if (expiresAt !== currentExpiry) {
              tx.update(current.ref, {expiresAt: Timestamp.fromMillis(expiresAt)});
            }
            logger.info("generateInviteCode reuse hit", {
              op: "generateInviteCode",
              uid,
              eventId,
              mode,
              existingCode: true,
              code: current.id,
              roleId,
            });
            return {code: current.id, roleId, expiresAt};
          }

          const freshCode = await pickFreshCode(tx);

          // ── PHASE 2: writes ─────────────────────────────────────────
          // The link this call showed is replaced, as older apps say.
          if (current) {
            tx.update(current.ref, {
              turnedOffAt: Timestamp.fromMillis(now),
              turnedOffBy: uid,
            });
          }
          tx.set(invitesRef.doc(freshCode), {
            eventId,
            roleId,
            singleUse: false,
            uses: 0,
            createdBy: uid,
            createdAt: FieldValue.serverTimestamp(),
            expiresAt: Timestamp.fromMillis(expiresAt),
          });
          logger.info("generateInviteCode fresh", {
            op: "generateInviteCode",
            uid,
            eventId,
            mode,
            existingCode: false,
            code: freshCode,
            roleId,
          });
          return {code: freshCode, roleId, expiresAt};
        });
      }
    );
  }
);
