import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {sendCategorizedPush} from "../notifications/sendPush";

/**
 * Window length (hours) for the due-soon scan. Tasks whose `dueDate`
 * falls inside `[now, now + DUE_WINDOW_HOURS]` are eligible for a
 * reminder; anything further out is left for a later run.
 */
const DUE_WINDOW_HOURS = 24;

/**
 * Returns true when [due] falls inside the `[now, now + windowHours]`
 * window. Null / past dates are not eligible.
 */
export function isDueSoon(
  due: Date | null | undefined,
  now: Date,
  windowHours: number
): boolean {
  if (!due) return false;
  const dueMs = due.getTime();
  const nowMs = now.getTime();
  if (dueMs < nowMs) return false;
  const upperMs = nowMs + windowHours * 60 * 60 * 1000;
  return dueMs <= upperMs;
}

/**
 * Reminder selection predicate. Returns true when the task is in a
 * remindable state — assigned, not yet completed, not already pinged.
 *
 * Treats `reminderSent === undefined` as false so legacy task docs
 * (created before the field existed) get reminded once and then
 * persistently flag themselves.
 */
export function shouldSendReminder(input: {
  status: string | null | undefined;
  reminderSent: boolean | null | undefined;
  assigneeId: string | null | undefined;
}): boolean {
  if (!input.assigneeId) return false;
  if (input.status === "done") return false;
  if (input.reminderSent === true) return false;
  return true;
}

/**
 * onTaskDueScheduled — every 15 minutes, scans `collectionGroup('tasks')`
 * for tasks due in the next [DUE_WINDOW_HOURS] hours that haven't been
 * pinged. Pushes via `sendCategorizedPush(category: 'task_due')` to the
 * assignee with a deep-link to the task detail.
 *
 * Idempotency: each successful push sets `reminderSent: true` on the task
 * doc inside the same write batch as the push attempt. Subsequent runs
 * skip the same task via [shouldSendReminder]. The Firestore set is
 * best-effort relative to the FCM send — if the set fails after the push
 * lands, the user gets a duplicate reminder on the next run. Acceptable
 * for the V1 cost profile; a transactional write+send is out of scope.
 *
 * Firestore composite index required (first deploy will print the URL):
 *   collectionGroup: tasks
 *   fields: dueDate asc
 * The status / reminderSent / assigneeId filters happen in memory after
 * the dueDate range query — keeps the index requirement minimal.
 *
 * Manual setup (out of session): enable Pub/Sub API in dev/stg/prod GCP
 * projects + set a cost-monitoring budget alert.
 */
export const onTaskDueScheduled = onSchedule(
  {
    schedule: "every 15 minutes",
    timeoutSeconds: 120,
    retryCount: 0,
  },
  async () => {
    const now = new Date();
    const windowEnd = new Date(
      now.getTime() + DUE_WINDOW_HOURS * 60 * 60 * 1000
    );
    const db = admin.firestore();

    const snap = await db
      .collectionGroup("tasks")
      .where("dueDate", ">=", admin.firestore.Timestamp.fromDate(now))
      .where("dueDate", "<=", admin.firestore.Timestamp.fromDate(windowEnd))
      .get();

    let attempted = 0;
    let skipped = 0;

    for (const taskDoc of snap.docs) {
      const data = taskDoc.data();
      const status = data.status as string | undefined;
      const reminderSent = data.reminderSent as boolean | undefined;
      const assigneeId = data.assigneeId as string | undefined;
      const eligible = shouldSendReminder({
        status,
        reminderSent,
        assigneeId,
      });
      if (!eligible) {
        skipped++;
        continue;
      }

      const due = (data.dueDate as admin.firestore.Timestamp | undefined)
        ?.toDate();
      if (!isDueSoon(due, now, DUE_WINDOW_HOURS)) {
        // Defensive — the Firestore query already filters by the range,
        // but timestamp/clock skew between the CF runtime and Firestore
        // can put boundary docs just outside the window.
        skipped++;
        continue;
      }

      const taskId = taskDoc.id;
      const eventId = (data.eventId as string | undefined) ?? "";
      const title = (data.title as string | undefined) ?? "Task";

      if (!eventId) {
        logger.warn(
          `onTaskDueScheduled: task ${taskId} missing eventId; skipping`
        );
        skipped++;
        continue;
      }

      // Flag first; if the FCM send fails, we still prefer "no second
      // ping" over "double ping". The reverse ordering risks repeated
      // sends on transient errors.
      await taskDoc.ref.set({reminderSent: true}, {merge: true});

      const result = await sendCategorizedPush({
        recipientUids: [assigneeId!],
        senderId: null,
        category: "task_due",
        title: "Task due soon",
        body: title,
        deepLink: `/dashboard/event/${eventId}/tasks/${taskId}`,
        extraData: {eventId, taskId},
      });
      attempted += result.attempted;
      skipped += result.skipped;
    }

    logger.info(
      `Task-due scan @ ${now.toISOString()}:` +
        ` scanned=${snap.size} attempted=${attempted} skipped=${skipped}`
    );
  }
);
