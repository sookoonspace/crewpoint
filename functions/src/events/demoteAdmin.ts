import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertNotArchived} from "./eventStatus";
import {
  prepareRoleChange,
  readRoleIds,
  requirePermission,
} from "./members";

const db = getFirestore();

/**
 * demoteAdmin — removes admin role from an event member.
 *
 * - Caller must hold `roles.manage` (owners and co-owners)
 * - Target must hold the Admin role
 * - Owner cannot be demoted, so the event always keeps its owner
 * - Removes target from adminIds via arrayRemove (stays in memberIds), and
 *   removes Admin from their member document, leaving Participant if no
 *   role is left
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
        const eventRef = db.collection("events").doc(eventId);
        await db.runTransaction(async (tx) => {
          const eventDoc = await tx.get(eventRef);
          if (!eventDoc.exists) {
            throw new HttpsError("not-found", "Event not found.");
          }

          const eventData = eventDoc.data()!;
          assertNotArchived(eventData);
          // Nobody but organizers can see a draft, so its members must stay so.
          if (eventData.status === "draft") {
            throw new HttpsError(
              "failed-precondition",
              "Publish this event before changing its admins."
            );
          }
          await requirePermission(
            tx,
            eventRef,
            eventData,
            uid,
            "roles.manage",
            "Only an owner or co-owner can demote admins."
          );

          const theirRoles = await readRoleIds(
            tx,
            eventRef,
            eventData,
            targetUserId
          );
          if (theirRoles.includes("owner")) {
            throw new HttpsError(
              "failed-precondition",
              "The event owner cannot be demoted."
            );
          }

          if (!theirRoles.includes("admin")) {
            throw new HttpsError(
              "failed-precondition",
              "Target user is not an admin of this event."
            );
          }

          const writeMember = await prepareRoleChange(
            tx,
            eventRef,
            eventData,
            targetUserId,
            (roleIds) => {
              const left = roleIds.filter((r) => r !== "admin");
              return left.length > 0 ? left : ["participant"];
            }
          );
          writeMember();
          tx.update(eventRef, {
            adminIds: FieldValue.arrayRemove(targetUserId),
            updatedAt: FieldValue.serverTimestamp(),
          });
        });

        return {success: true};
      }
    );
  }
);
