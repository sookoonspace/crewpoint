import {onCall, HttpsError} from "firebase-functions/v2/https";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {requireString, withStructuredLogs} from "../utils/logging";
import {assertTasksOpen} from "./eventStatus";
import {readPermissions} from "./members";
import {assertModuleOn} from "./eventModules";

const db = getFirestore();

/**
 * markTaskComplete — transitions a task to `done`, stamping
 * completedAt/completedBy. Rules deny clients these writes, so this is the only
 * way to finish a task.
 *
 * - Caller must be a current member, and the event owner, an admin, the task's
 *   creator or its assignee. `assigneeId` and `createdBy` outlive membership, so
 *   neither is enough alone.
 * - Reserves a server-side seam for future side effects (notifications,
 *   ledger hooks)
 *
 * Completion is a write-once event: a second call on a finished task succeeds
 * and changes nothing, so the first `completedBy` stands. Reopening a task
 * clears it, and completing it again then counts as a new completion.
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
        const eventRef = db.collection("events").doc(eventId);
        const taskRef = eventRef.collection("tasks").doc(taskId);

        await db.runTransaction(async (tx) => {
          const eventDoc = await tx.get(eventRef);
          if (!eventDoc.exists) {
            throw new HttpsError("not-found", "Event not found.");
          }
          const eventData = eventDoc.data()!;
          const permissions = await readPermissions(
            tx,
            eventRef,
            eventData,
            uid
          );
          assertTasksOpen(eventData, permissions);
          assertModuleOn(eventData, "tasks");
          const memberIds: string[] = eventData.memberIds || [];

          const taskDoc = await tx.get(taskRef);
          if (!taskDoc.exists) {
            throw new HttpsError("not-found", "Task not found.");
          }
          const taskData = taskDoc.data()!;

          const managesTasks = permissions.includes("tasks.manage");
          const isCreatorOrAssignee =
            memberIds.includes(uid) &&
            (taskData.createdBy === uid || taskData.assigneeId === uid);

          if (!managesTasks && !isCreatorOrAssignee) {
            throw new HttpsError(
              "permission-denied",
              "Only someone who manages tasks, the creator or the assignee " +
                "can complete tasks."
            );
          }

          if (taskData.status === "done") return;

          tx.update(taskRef, {
            status: "done",
            completedAt: FieldValue.serverTimestamp(),
            completedBy: uid,
            updatedAt: FieldValue.serverTimestamp(),
          });
        });

        return {success: true};
      }
    );
  }
);
