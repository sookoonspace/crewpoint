import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {requireString, withStructuredLogs} from "../utils/logging";

const db = admin.firestore();

/**
 * demoteAdmin — removes admin role from an event member.
 *
 * - Caller must be event owner (creatorId)
 * - Target must currently be in adminIds
 * - Owner cannot be demoted
 * - Refuses to demote the last remaining admin (would leave the
 *   event in a degraded zero-admins state)
 * - Removes target from adminIds via arrayRemove (stays in memberIds)
 *
 * Idempotency: arrayRemove is no-op when uid is already gone.
 */
export const demoteAdmin = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const data = (request.data ?? {}) as {
      eventId?: unknown;
      targetUserId?: unknown;
    };
    const eventId = requireString(data.eventId, "eventId");
    const targetUserId = requireString(data.targetUserId, "targetUserId");

    const uid = request.auth.uid;

    return withStructuredLogs(
      {op: "demoteAdmin", uid, args: {eventId, targetUserId}},
      async () => {
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

        if (adminIds.length <= 1) {
          throw new HttpsError(
            "failed-precondition",
            "Cannot demote the last remaining admin. " +
              "Promote another member first."
          );
        }

        await db.collection("events").doc(eventId).update({
          adminIds: admin.firestore.FieldValue.arrayRemove(targetUserId),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return {success: true};
      }
    );
  }
);
