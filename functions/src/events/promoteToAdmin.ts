import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * promoteToAdmin — promotes an event member to admin.
 *
 * - Caller must be event owner (creatorId)
 * - Target must be an existing member
 * - Adds target to adminIds via arrayUnion
 */
export const promoteToAdmin = onCall(
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
    const memberIds: string[] = eventData.memberIds || [];

    if (eventData.creatorId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "Only the event owner can promote admins."
      );
    }

    if (!memberIds.includes(targetUserId)) {
      throw new HttpsError(
        "failed-precondition",
        "Target user is not a member of this event."
      );
    }

    await db.collection("events").doc(eventId).update({
      adminIds: admin.firestore.FieldValue.arrayUnion(targetUserId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(
      `User ${targetUserId} promoted to admin in event ${eventId} by ${uid}`
    );

    return {success: true};
  }
);
