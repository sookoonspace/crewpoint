import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertNotArchived} from "./eventStatus";
import {prepareRoleChange, requirePermission} from "./members";

const db = getFirestore();

/**
 * promoteToAdmin — promotes an event member to admin.
 *
 * - Caller must hold `roles.manage` (owners and co-owners)
 * - Target must be an existing member
 * - Adds target to adminIds via arrayUnion, and swaps Participant for Admin
 *   on their member document
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
        const eventRef = db.collection("events").doc(eventId);
        await db.runTransaction(async (tx) => {
          const eventDoc = await tx.get(eventRef);
          if (!eventDoc.exists) {
            throw new HttpsError("not-found", "Event not found.");
          }

          const eventData = eventDoc.data()!;
          assertNotArchived(eventData);
          const memberIds: string[] = eventData.memberIds || [];

          await requirePermission(
            tx,
            eventRef,
            eventData,
            uid,
            "roles.manage",
            "Only an owner or co-owner can promote admins."
          );

          if (!memberIds.includes(targetUserId)) {
            throw new HttpsError(
              "failed-precondition",
              "Target user is not a member of this event."
            );
          }

          const writeMember = await prepareRoleChange(
            tx,
            eventRef,
            eventData,
            targetUserId,
            (roleIds) => [
              ...roleIds.filter((r) => r !== "participant" && r !== "admin"),
              "admin",
            ]
          );
          writeMember();
          tx.update(eventRef, {
            adminIds: FieldValue.arrayUnion(targetUserId),
            updatedAt: FieldValue.serverTimestamp(),
          });
        });

        return {success: true};
      }
    );
  }
);
