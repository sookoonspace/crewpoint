import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";

const db = getFirestore();

/**
 * markTaskComplete — transitions a task to `done`, stamping
 * completedAt/completedBy.
 *
 * - Caller must be event owner, admin, or the task assignee
 * - Reserves a server-side seam for future side effects (notifications,
 *   ledger hooks)
 *
 * Idempotency: a retry that finds the task already in `done` state will
 * re-stamp `completedAt`/`completedBy` to the second invocation's
 * timestamp/uid. Callers should treat completion as a write-once event;
 * the second-write semantics are acceptable for V1 (no audit trail).
 */
export const markTaskComplete = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const data = (request.data ?? {}) as {
      eventId?: unknown;
      taskId?: unknown;
    };
    const eventId = requireString(data.eventId, "eventId");
    const taskId = requireString(data.taskId, "taskId");

    const uid = request.auth.uid;

    return withStructuredLogs(
      {op: "markTaskComplete", uid, args: {eventId, taskId}},
      async () => {
        const eventDoc = await db.collection("events").doc(eventId).get();
        if (!eventDoc.exists) {
          throw new HttpsError("not-found", "Event not found.");
        }
        const eventData = eventDoc.data()!;
        const adminIds: string[] = eventData.adminIds || [];

        const taskRef = db
          .collection("events")
          .doc(eventId)
          .collection("tasks")
          .doc(taskId);
        const taskDoc = await taskRef.get();
        if (!taskDoc.exists) {
          throw new HttpsError("not-found", "Task not found.");
        }
        const taskData = taskDoc.data()!;

        const isOwner = eventData.creatorId === uid;
        const isAdmin = adminIds.includes(uid);
        const isAssignee = taskData.assigneeId === uid;

        if (!isOwner && !isAdmin && !isAssignee) {
          throw new HttpsError(
            "permission-denied",
            "Only the event owner, admins, or the assignee can complete tasks."
          );
        }

        await taskRef.update({
          status: "done",
          completedAt: FieldValue.serverTimestamp(),
          completedBy: uid,
          updatedAt: FieldValue.serverTimestamp(),
        });

        return {success: true};
      }
    );
  }
);
