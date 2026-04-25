import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const db = admin.firestore();
const MAX_MEMBERS = 50;

/**
 * joinEvent — verifies a join code and adds the caller to the event.
 *
 * - Code must exist and not be expired
 * - Caller must not already be a member
 * - Event must not exceed 50 members
 */
export const joinEvent = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {joinCode} = request.data as {joinCode?: string};
    if (!joinCode || joinCode.length !== 6) {
      throw new HttpsError(
        "invalid-argument",
        "A valid 6-character join code is required."
      );
    }

    const uid = request.auth.uid;
    const code = joinCode.toUpperCase();

    // Verify code exists
    const codeDoc = await db.collection("event_invites").doc(code).get();
    if (!codeDoc.exists) {
      throw new HttpsError(
        "not-found",
        "This code is invalid or has expired."
      );
    }

    const codeData = codeDoc.data()!;

    // Check expiration
    const expiresAt = codeData.expiresAt?.toDate();
    if (expiresAt && expiresAt < new Date()) {
      // Clean up expired code
      await db.collection("event_invites").doc(code).delete();
      throw new HttpsError(
        "not-found",
        "This code is invalid or has expired."
      );
    }

    const eventId: string = codeData.eventId;

    // Get event
    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Event no longer exists.");
    }

    const eventData = eventDoc.data()!;
    const memberIds: string[] = eventData.memberIds || [];

    // Check if already a member
    if (memberIds.includes(uid)) {
      throw new HttpsError(
        "already-exists",
        "You're already a member of this event."
      );
    }

    // Check member limit
    if (memberIds.length >= MAX_MEMBERS) {
      throw new HttpsError(
        "resource-exhausted",
        "This event is full (max 50 members)."
      );
    }

    // Add caller to memberIds
    await db.collection("events").doc(eventId).update({
      memberIds: admin.firestore.FieldValue.arrayUnion(uid),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`User ${uid} joined event ${eventId} via code ${code}`);

    return {
      eventId,
      title: eventData.title,
      eventType: eventData.eventType,
    };
  }
);
