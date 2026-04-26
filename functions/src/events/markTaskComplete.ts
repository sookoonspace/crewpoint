import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * markTaskComplete — transitions a task to `done`, stamping completedAt/By.
 *
 * - Caller must be event owner, admin, or the task assignee
 * - Reserves a server-side seam for future side effects (notifications, ledger hooks)
 */
export const markTaskComplete = onCall(
  {timeoutSeconds: 30},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {eventId, taskId} = request.data as {
      eventId?: string;
      taskId?: string;
    };

    if (!eventId || !taskId) {
      throw new HttpsError(
        "invalid-argument",
        "eventId and taskId are required."
      );
    }

    const uid = request.auth.uid;

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
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      completedBy: uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(
      `Task ${taskId} marked complete in event ${eventId} by ${uid}`
    );

    return {success: true};
  }
);
