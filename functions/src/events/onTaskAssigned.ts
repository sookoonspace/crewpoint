import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {sendCategorizedPush} from "../notifications/sendPush";

const db = admin.firestore();

/**
 * onTaskAssigned — pushes a notification to the assignee when a task is
 * created with an assignee, or when the `assigneeId` on an existing task
 * changes. Idempotent: only fires when the assignee actually transitions
 * to a new uid (i.e. before !== after && after is non-empty).
 *
 * Skips self-assignment (someone assigning a task to themselves) — no
 * value in pinging your own device.
 *
 * Best-effort: not retried on failure. A missed push is preferable to a
 * duplicate one on retry storms.
 */
export const onTaskAssigned = onDocumentWritten(
  {
    document: "events/{eventId}/tasks/{taskId}",
    timeoutSeconds: 30,
    retry: false,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    // Delete event — nothing to do.
    if (!after) return;

    const beforeAssignee = (before?.assigneeId as string | undefined) ?? "";
    const afterAssignee = (after.assigneeId as string | undefined) ?? "";

    // Fires only on transition to a new (non-empty) assignee.
    if (!afterAssignee || beforeAssignee === afterAssignee) return;

    const eventId = event.params.eventId;
    const taskId = event.params.taskId;
    const taskTitle = (after.title as string | undefined) ?? "Task";
    // `createdBy` is the actor for newly-created tasks; for an update we
    // don't know who flipped the assignee field (the doc doesn't record
    // it) so fall back to createdBy. Either way, suppress self-pings.
    const actorId = (after.createdBy as string | undefined) ?? "";

    if (afterAssignee === actorId) {
      logger.info(
        `Skip self-assign push: task=${taskId} assignee=${afterAssignee}`
      );
      return;
    }

    const eventDoc = await db.collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      logger.warn(
        `Event ${eventId} missing on task-assigned trigger for ${taskId}`
      );
      return;
    }
    const eventTitle =
      (eventDoc.data()?.title as string | undefined) ?? "Event";

    const result = await sendCategorizedPush({
      recipientUids: [afterAssignee],
      senderId: actorId,
      category: "task_assigned",
      eventId,
      title: `New task in ${eventTitle}`,
      body: taskTitle,
      deepLink: `/dashboard/event/${eventId}/tasks/${taskId}`,
      extraData: {eventId, taskId},
    });

    logger.info(
      `Task-assigned push for ${taskId}:` +
        ` ${result.attempted} attempted, ${result.skipped} skipped`
    );
  }
);
