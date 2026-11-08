import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertNotArchived} from "./eventStatus";
import {memberRef, readPermissions, readRoleIds} from "./members";

const db = getFirestore();

/**
 * removeEventMember — removes a user from an event.
 *
 * - Caller must hold `members.manage`, or be removing themselves (leave-event)
 * - Removing someone who holds `members.manage` needs `roles.manage`, which
 *   owners and co-owners hold
 * - Owner cannot be removed, and cannot leave without transferring ownership
 * - Removes target from both memberIds and adminIds, and deletes their
 *   member document, atomically
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
        const eventRef = db.collection("events").doc(eventId);
        const invites = await db
          .collection("event_invites")
          .where("eventId", "==", eventId)
          .get();
        const groups = await eventRef
          .collection("groups")
          .where("adultUids", "array-contains", targetUserId)
          .get();

        await db.runTransaction(async (tx) => {
          const eventDoc = await tx.get(eventRef);
          if (!eventDoc.exists) {
            throw new HttpsError("not-found", "Event not found.");
          }

          const eventData = eventDoc.data()!;
          assertNotArchived(eventData);
          const memberIds: string[] = eventData.memberIds || [];
          const isSelfRemoval = uid === targetUserId;
          const [mine, theirs, theirRoles] = await Promise.all([
            readPermissions(tx, eventRef, eventData, uid),
            readPermissions(tx, eventRef, eventData, targetUserId),
            readRoleIds(tx, eventRef, eventData, targetUserId),
          ]);

          if (!mine.includes("members.manage") && !isSelfRemoval) {
            throw new HttpsError(
              "permission-denied",
              "Only people who manage members can remove someone."
            );
          }

          if (theirRoles.includes("owner")) {
            throw new HttpsError(
              "failed-precondition",
              "The event owner cannot be removed, and can only leave after " +
                "transferring ownership."
            );
          }

          if (
            theirs.includes("members.manage") &&
            !isSelfRemoval &&
            !mine.includes("roles.manage")
          ) {
            throw new HttpsError(
              "permission-denied",
              "Only an owner or co-owner can remove someone who manages members."
            );
          }

          tx.delete(memberRef(eventRef, targetUserId));
          // They no longer look after any group here (Req 26b).
          groups.docs.forEach((g) =>
            tx.update(g.ref, {adultUids: FieldValue.arrayRemove(targetUserId)})
          );
          tx.update(eventRef, {
            memberIds: FieldValue.arrayRemove(targetUserId),
            adminIds: FieldValue.arrayRemove(targetUserId),
            memberCount: memberIds.filter((m) => m !== targetUserId).length,
            updatedAt: FieldValue.serverTimestamp(),
          });
          if (!isSelfRemoval) {
            invites.docs.forEach((invite) => tx.delete(invite.ref));
          }
        });

        return {success: true};
      }
    );
  }
);
