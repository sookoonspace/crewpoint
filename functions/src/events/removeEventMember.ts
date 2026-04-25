import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * removeEventMember — removes a user from an event.
 *
 * - Caller must be admin or owner
 * - Target cannot be the event owner
 * - Removes from both memberIds and adminIds
 */
export const removeEventMember = onCall(
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

    // Get event
    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Event not found.");
    }

    const eventData = eventDoc.data()!;
    const adminIds: string[] = eventData.adminIds || [];

    // Verify caller is admin or owner
    const callerIsAuthorized =
      eventData.creatorId === uid || adminIds.includes(uid);

    // Allow self-removal (leave event) for any member
    const isSelfRemoval = uid === targetUserId;

    if (!callerIsAuthorized && !isSelfRemoval) {
      throw new HttpsError(
        "permission-denied",
        "Only admins and the event owner can remove members."
      );
    }

    // Owner cannot be removed
    if (targetUserId === eventData.creatorId) {
      throw new HttpsError(
        "failed-precondition",
        "The event owner cannot be removed."
      );
    }

    // Remove from both arrays
    await db.collection("events").doc(eventId).update({
      memberIds: admin.firestore.FieldValue.arrayRemove(targetUserId),
      adminIds: admin.firestore.FieldValue.arrayRemove(targetUserId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(
      `User ${targetUserId} removed from event ${eventId} by ${uid}`
    );

    return {success: true};
  }
);
