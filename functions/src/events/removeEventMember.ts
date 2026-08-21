import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";

const db = getFirestore();

/**
 * removeEventMember — removes a user from an event.
 *
 * - Caller must be admin/owner OR removing themselves (leave-event)
 * - Owner cannot be removed (prevents accidental orphaning)
 * - Removes target from both memberIds and adminIds atomically
 *
 * Idempotency: `arrayRemove` is a no-op if the uid is already gone,
 * so retries converge on the same end state.
 */
export const removeEventMember = onCall(
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
      {op: "removeEventMember", uid, args: {eventId, targetUserId}},
      async () => {
        const eventDoc = await db.collection("events").doc(eventId).get();
        if (!eventDoc.exists) {
          throw new HttpsError("not-found", "Event not found.");
        }

        const eventData = eventDoc.data()!;
        const adminIds: string[] = eventData.adminIds || [];

        const callerIsAuthorized =
          eventData.creatorId === uid || adminIds.includes(uid);
        const isSelfRemoval = uid === targetUserId;

        if (!callerIsAuthorized && !isSelfRemoval) {
          throw new HttpsError(
            "permission-denied",
            "Only admins and the event owner can remove members."
          );
        }

        if (targetUserId === eventData.creatorId) {
          throw new HttpsError(
            "failed-precondition",
            "The event owner cannot be removed."
          );
        }

        await db.collection("events").doc(eventId).update({
          memberIds: FieldValue.arrayRemove(targetUserId),
          adminIds: FieldValue.arrayRemove(targetUserId),
          updatedAt: FieldValue.serverTimestamp(),
        });

        return {success: true};
      }
    );
  }
);
