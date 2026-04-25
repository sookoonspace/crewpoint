import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const db = admin.firestore();

// Characters: A-Z minus ambiguous (O, I, L) + 2-9
const CHARSET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 6;

function generateCode(): string {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CHARSET[Math.floor(Math.random() * CHARSET.length)];
  }
  return code;
}

/**
 * generateInviteCode — generates a unique 6-char join code for an event.
 *
 * - Caller must be admin or owner of the event
 * - Invalidates any existing code for the event
 * - Saves new code to event_invites/{code}
 * - Returns the code to the client
 */
export const generateInviteCode = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {eventId} = request.data as {eventId?: string};
    if (!eventId) {
      throw new HttpsError("invalid-argument", "eventId is required.");
    }

    const uid = request.auth.uid;

    // Verify caller is admin or owner
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

    // Invalidate any existing code for this event
    const existingCodes = await db
      .collection("event_invites")
      .where("eventId", "==", eventId)
      .get();

    const batch = db.batch();
    for (const doc of existingCodes.docs) {
      batch.delete(doc.ref);
    }

    // Generate unique code (check for collisions)
    let code = generateCode();
    let attempts = 0;
    while (attempts < 10) {
      const existing = await db
        .collection("event_invites")
        .doc(code)
        .get();
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

    // Save new code
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
    batch.set(db.collection("event_invites").doc(code), {
      eventId,
      createdBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });

    await batch.commit();

    logger.info(
      `Generated invite code ${code} for event ${eventId} by ${uid}`
    );

    return {code};
  }
);
