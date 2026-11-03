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
 * - When an admin removes someone, deletes the event's invite codes so the
 *   removed member cannot rejoin with one they already have. Admins get a new
 *   code automatically the next time they open the invite sheet, which also
 *   lets them re-invite the person later. Leaving voluntarily keeps the code.
 *
 * Idempotency: `arrayRemove` is a no-op if the uid is already gone,
 * and deleting already-deleted codes is too, so retries converge on the
 * same end state.
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

        const batch = db.batch();
        batch.update(db.collection("events").doc(eventId), {
          memberIds: FieldValue.arrayRemove(targetUserId),
          adminIds: FieldValue.arrayRemove(targetUserId),
          updatedAt: FieldValue.serverTimestamp(),
        });
        if (!isSelfRemoval) {
          const invites = await db
            .collection("event_invites")
            .where("eventId", "==", eventId)
            .get();
          invites.docs.forEach((invite) => batch.delete(invite.ref));
        }
        await batch.commit();

        return {success: true};
      }
    );
  }
);
