import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {requireString, withStructuredLogs} from "../utils/logging";

const db = admin.firestore();

/**
 * promoteToAdmin — promotes an event member to admin.
 *
 * - Caller must be event owner (creatorId)
 * - Target must be an existing member
 * - Adds target to adminIds via arrayUnion
 *
 * Idempotency: arrayUnion is no-op when uid is already present, so
 * retries converge.
 */
export const promoteToAdmin = onCall(
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
      {op: "promoteToAdmin", uid, args: {eventId, targetUserId}},
      async () => {
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

        return {success: true};
      }
    );
  }
);
