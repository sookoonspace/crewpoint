import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {requireString, withStructuredLogs} from "../utils/logging";

const db = admin.firestore();

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

/**
 * generateInviteCode — generates or reuses a 6-char join code for an
 * event.
 *
 * - Caller must be admin or owner of the event.
 * - **Default (no `rotate` flag, or `rotate !== true`):** returns the
 *   existing non-expired code if one exists, else generates a new one.
 *   This preserves codes already shared via text/email until their
 *   24-hour expiry. Wrapped in `runTransaction` for race-safety against
 *   concurrent calls.
 * - **`rotate: true`:** invalidates ALL existing codes for the event and
 *   generates a fresh one. Use only when an admin suspects code leakage.
 *   Non-transactional batch — simultaneous rotate calls from two admin
 *   devices can race; accepted V1 since the path is low-frequency.
 * - **Strict coercion:** only the literal boolean `true` opts into
 *   rotation. `'true'`, `1`, truthy objects, etc. are treated as
 *   `false` (reuse). Avoids the `Boolean('false') === true` JS pitfall.
 * - Self-heal: if multiple non-expired docs exist for one event (data
 *   corruption from a prior race), the reuse path returns the most
 *   recent and deletes the older siblings in the same transaction.
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
    };
    const eventId = requireString(data.eventId, "eventId");
    // Strict coercion: only the literal boolean `true` opts into rotation.
    const rotate = data.rotate === true;

    const uid = request.auth.uid;
    const mode: "rotate" | "reuse" = rotate ? "rotate" : "reuse";

    return withStructuredLogs(
      {op: "generateInviteCode", uid, args: {eventId, mode}},
      async () => {
        // Permission check runs BEFORE the transaction so we fail fast.
        const eventDoc = await db.collection("events").doc(eventId).get();
        if (!eventDoc.exists) {
          throw new HttpsError("not-found", "Event not found.");
        }
        const eventData = eventDoc.data()!;
        const adminIds: string[] = eventData.adminIds || [];
        const isAuthorized =
          eventData.creatorId === uid || adminIds.includes(uid);
        if (!isAuthorized) {
          throw new HttpsError(
            "permission-denied",
            "Only admins and the event owner can generate invite codes."
          );
        }

        const invitesRef = db.collection("event_invites");

        if (rotate) {
          return rotatePath(invitesRef, eventId, uid);
        }
        return reusePath(invitesRef, eventId, uid);
      }
    );
  }
);

/**
 * Reuse path: race-safe via `runTransaction`. Inside the transaction:
 *  1. Read all `event_invites` docs for the event ordered by `createdAt`
 *     desc.
 *  2. If a non-expired doc exists, return its code. If multiple
 *     non-expired exist, return the most recent and delete the siblings
 *     (self-heal).
 *  3. Otherwise: delete any expired docs and write a new code.
 */
async function reusePath(
  invitesRef: FirebaseFirestore.CollectionReference,
  eventId: string,
  uid: string
): Promise<{code: string}> {
  return db.runTransaction(async (tx) => {
    // ── PHASE 1: all reads ────────────────────────────────────────
    // Firestore transactions require every read to precede every
    // write. Gather the existing invite docs AND any collision-check
    // reads BEFORE issuing tx.delete / tx.set below.
    const existing = await tx.get(
      invitesRef.where("eventId", "==", eventId).orderBy("createdAt", "desc")
    );
    const now = Date.now();
    const nonExpired = existing.docs.filter((doc) => {
      const expiresAt = doc.data().expiresAt;
      const expiresMs =
        expiresAt && typeof expiresAt.toMillis === "function"
          ? (expiresAt.toMillis() as number)
          : 0;
      return expiresMs > now;
    });

    // Reuse hit — winner is the most-recent non-expired doc; any
    // remaining non-expired docs are siblings to self-heal.
    if (nonExpired.length > 0) {
      const winner = nonExpired[0];
      const siblings = nonExpired.slice(1);
      // ── PHASE 2: writes ─────────────────────────────────────────
      if (siblings.length > 0) {
        logger.warn(
          `generateInviteCode self-heal: ${siblings.length} duplicate ` +
            `non-expired codes for event ${eventId}; deleting siblings`,
          {op: "generateInviteCode", uid, eventId, mode: "reuse"}
        );
        for (const sib of siblings) tx.delete(sib.ref);
      }
      logger.info("generateInviteCode reuse hit", {
        op: "generateInviteCode",
        uid,
        eventId,
        mode: "reuse",
        existingCode: true,
        code: winner.id,
      });
      return {code: winner.id};
    }

    // Reuse miss — need to allocate a fresh code. Collision-check
    // reads MUST happen before the tx.delete / tx.set below.
    const freshCode = await pickFreshCode(invitesRef, tx);

    // ── PHASE 2: writes ───────────────────────────────────────────
    for (const doc of existing.docs) tx.delete(doc.ref);
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(now + EXPIRY_MS)
    );
    tx.set(invitesRef.doc(freshCode), {
      eventId,
      createdBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt,
    });

    logger.info("generateInviteCode reuse miss → fresh", {
      op: "generateInviteCode",
      uid,
      eventId,
      mode: "reuse",
      existingCode: false,
      code: freshCode,
    });
    return {code: freshCode};
  });
}

/**
 * Rotate path: existing batch-based behavior. Deletes all existing
 * codes for the event and issues a new one.
 *
 * Non-transactional. Two simultaneous rotate calls from different admin
 * devices can race and produce duplicate codes — accepted V1 since
 * this path is low-frequency. The reuse path's self-heal cleans up if
 * it ever happens.
 */
async function rotatePath(
  invitesRef: FirebaseFirestore.CollectionReference,
  eventId: string,
  uid: string
): Promise<{code: string}> {
  const existingCodes = await invitesRef
    .where("eventId", "==", eventId)
    .get();

  const batch = db.batch();
  for (const doc of existingCodes.docs) {
    batch.delete(doc.ref);
  }

  let code = generateCode();
  let attempts = 0;
  while (attempts < 10) {
    const existing = await invitesRef.doc(code).get();
    if (!existing.exists) break;
    code = generateCode();
    attempts++;
  }
  if (attempts >= 10) {
    throw new HttpsError(
      "internal",
      "Failed to generate unique code. Please try again."
    );
  }

  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + EXPIRY_MS)
  );
  batch.set(invitesRef.doc(code), {
    eventId,
    createdBy: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt,
  });

  await batch.commit();
  logger.info("generateInviteCode rotate", {
    op: "generateInviteCode",
    uid,
    eventId,
    mode: "rotate",
    existingCode: false,
    code,
  });
  return {code};
}

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
