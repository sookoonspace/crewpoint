import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertOpenToJoin} from "./eventStatus";

import {readEventRoles, readPermissions} from "./members";
import {PRESET_ROLES} from "./permissions";
const db = getFirestore();

// Characters: A-Z minus ambiguous (O, I, L) + 2-9.
const CHARSET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 6;
const EXPIRY_MS = 24 * 60 * 60 * 1000;

function generateCode(): string {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CHARSET[Math.floor(Math.random() * CHARSET.length)];
  }
  return code;
}

/** The role an invite carries. Invites from before roles mean Participant. */
export function inviteRoleId(invite: FirebaseFirestore.DocumentData): string {
  return typeof invite.roleId === "string" ? invite.roleId : "participant";
}

/**
 * generateInviteCode — returns the event's one active invite (Req 31, L19),
 * which carries a role applied on join.
 *
 * - Caller needs `members.manage`. An invite into any role other than
 *   Participant also needs `roles.manage`, because joining with it assigns
 *   that role. Nobody can invite into Owner.
 * - **No `roleId`:** returns the active invite with its role, or a new
 *   Participant invite if there is none.
 * - **`roleId` the same as the active invite's:** returns that invite, so
 *   codes already shared keep working until their 24-hour expiry.
 * - **A different `roleId`:** replaces the invite with a new code, so an old
 *   code never grants the new role.
 * - **`rotate: true`:** replaces the code and keeps the role. Use when a code
 *   may have leaked. Only the literal boolean `true` rotates, avoiding the
 *   `Boolean('false') === true` JS pitfall.
 * - Everything runs in one transaction, so simultaneous calls cannot leave two
 *   active invites. If older data holds several, the most recent wins and the
 *   rest are deleted (self-heal).
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
    };
    const eventId = requireString(data.eventId, "eventId");
    const rotate = data.rotate === true;
    const requestedRole =
      data.roleId === undefined || data.roleId === null ?
        null :
        requireString(data.roleId, "roleId");

    const uid = request.auth.uid;
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
          const active = existing.docs.filter((doc) => {
            const expiresAt = doc.data().expiresAt;
            const expiresMs =
              expiresAt && typeof expiresAt.toMillis === "function" ?
                (expiresAt.toMillis() as number) :
                0;
            return expiresMs > now;
          });
          const current = active[0];
          const roleId =
            requestedRole ?? (current ? inviteRoleId(current.data()) : "participant");

          if (roleId === "owner") {
            throw new HttpsError(
              "failed-precondition",
              "Nobody can join as Owner. Ownership changes only through a transfer."
            );
          }
          if (!PRESET_ROLES[roleId] && !roles[roleId]) {
            throw new HttpsError("invalid-argument", "Unknown role.");
          }
          if (roleId !== "participant" && !mine.includes("roles.manage")) {
            throw new HttpsError(
              "permission-denied",
              "Only owners and co-owners can invite someone into a role."
            );
          }

          // Reuse hit: same role, not rotating.
          if (current && !rotate && inviteRoleId(current.data()) === roleId) {
            // ── PHASE 2: writes ───────────────────────────────────────
            const siblings = active.slice(1);
            if (siblings.length > 0) {
              logger.warn(
                `generateInviteCode self-heal: ${siblings.length} duplicate ` +
                  `non-expired codes for event ${eventId}; deleting siblings`,
                {op: "generateInviteCode", uid, eventId, mode}
              );
              for (const sib of siblings) tx.delete(sib.ref);
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
            return {code: current.id, roleId};
          }

          const freshCode = await pickFreshCode(invitesRef, tx);

          // ── PHASE 2: writes ─────────────────────────────────────────
          for (const doc of existing.docs) tx.delete(doc.ref);
          tx.set(invitesRef.doc(freshCode), {
            eventId,
            roleId,
            createdBy: uid,
            createdAt: FieldValue.serverTimestamp(),
            expiresAt: Timestamp.fromDate(new Date(now + EXPIRY_MS)),
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
          return {code: freshCode, roleId};
        });
      }
    );
  }
);

/**
 * Generates a fresh code, retrying up to 10 times on collisions.
 * Reads via the transaction so the uniqueness check is consistent with
 * the eventual write.
 */
async function pickFreshCode(
  invitesRef: FirebaseFirestore.CollectionReference,
  tx: FirebaseFirestore.Transaction
): Promise<string> {
  let code = generateCode();
  let attempts = 0;
  while (attempts < 10) {
    const existing = await tx.get(invitesRef.doc(code));
    if (!existing.exists) return code;
    code = generateCode();
    attempts++;
  }
  throw new HttpsError(
    "internal",
    "Failed to generate unique code. Please try again."
  );
}
