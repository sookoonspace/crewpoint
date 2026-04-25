import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * demoteAdmin — removes admin role from an event member.
 *
 * - Caller must be event owner (creatorId)
 * - Target must currently be in adminIds
 * - Owner cannot be demoted
 * - Removes target from adminIds via arrayRemove (stays in memberIds)
 */
export const demoteAdmin = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {eventId, targetUserId} = request.data as {
      eventId?: string;
      targetUserId?: string;
    };

    if (!eventId || !targetUserId) {
      throw new HttpsError(
        "invalid-argument",
        "eventId and targetUserId are required."
      );
    }

    const uid = request.auth.uid;

    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Event not found.");
    }

    const eventData = eventDoc.data()!;
    const adminIds: string[] = eventData.adminIds || [];

    if (eventData.creatorId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "Only the event owner can demote admins."
      );
    }

    if (targetUserId === eventData.creatorId) {
      throw new HttpsError(
        "failed-precondition",
        "The event owner cannot be demoted."
      );
    }

    if (!adminIds.includes(targetUserId)) {
      throw new HttpsError(
        "failed-precondition",
        "Target user is not an admin of this event."
      );
    }

    await db.collection("events").doc(eventId).update({
      adminIds: admin.firestore.FieldValue.arrayRemove(targetUserId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(
      `User ${targetUserId} demoted from admin in event ${eventId} by ${uid}`
    );

    return {success: true};
  }
);
