import {HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions/v2";
import {
  DocumentData,
  FieldValue,
  Firestore,
  Timestamp,
} from "firebase-admin/firestore";

const DAY_MS = 24 * 60 * 60 * 1000;
const BATCH_LIMIT = 500;

/**
 * The status an event from before these statuses should have. #65's migration
 * uses this, and until then `active` keeps working wherever a status is read.
 */
export function mapLegacyStatus(
  status: string | undefined,
  endDate: Date | null | undefined,
  now: Date
): string {
  if (status !== undefined && status !== "active") return status;
  return endDate && endDate.getTime() <= now.getTime() ? "ended" : "published";
}

/** Whether [date] falls exactly on midnight in [timeZone]. */
function isMidnightIn(date: Date, timeZone: string): boolean {
  try {
    const time = new Intl.DateTimeFormat("en-GB", {
      timeZone,
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hourCycle: "h23",
    }).format(date);
    return time === "00:00:00";
  } catch {
    return false;
  }
}

/**
 * When an event ends. The date pickers store midnight, which means the whole of
 * that day, so an end at midnight in the event's zone runs one day further.
 */
function endInstant(end: Date, timeZone: string): number {
  return isMidnightIn(end, timeZone) ? end.getTime() + DAY_MS : end.getTime();
}

/**
 * The status [event] should move to at [now], or null if it should stay. A time
 * only counts if it passed after the last change by hand (`statusSetAt`), so an
 * organizer's choice is not undone by a time that had already passed.
 */
export function nextStatus(event: DocumentData, now: Date): string | null {
  const status = event.status;
  if (status !== "published" && status !== "live") return null;

  const nowMs = now.getTime();
  const setAtMs = (event.statusSetAt as Timestamp | undefined)?.toMillis() ?? 0;
  const passedSinceSet = (ms: number) => ms <= nowMs && ms > setAtMs;

  const end = (event.endDate as Timestamp | null | undefined)?.toDate();
  if (end && passedSinceSet(endInstant(end, event.timeZone ?? "UTC"))) {
    return "ended";
  }
  const start = (event.startDate as Timestamp | null | undefined)?.toDate();
  if (status === "published" && start && passedSinceSet(start.getTime())) {
    return "live";
  }
  return null;
}

/**
 * Applies every due change and returns how many were made. Each write checks
 * the event has not changed since it was read, so it cannot overwrite an
 * organizer's change made in between.
 */
export async function runStatusChanges(
  db: Firestore,
  now: Date
): Promise<number> {
  const events = await db
    .collection("events")
    .where("status", "in", ["published", "live"])
    .get();
  const due = events.docs
    .map((doc) => ({doc, next: nextStatus(doc.data(), now)}))
    .filter(({next}) => next !== null)
    .slice(0, BATCH_LIMIT);

  const results = await Promise.allSettled(
    due.map(({doc, next}) =>
      doc.ref.update(
        {status: next, updatedAt: FieldValue.serverTimestamp()},
        {lastUpdateTime: doc.updateTime}
      )
    )
  );
  results.forEach((result, i) => {
    if (result.status === "rejected") {
      logger.warn(`Status change skipped for ${due[i].doc.id}`, result.reason);
    }
  });
  return results.filter((result) => result.status === "fulfilled").length;
}

function refuse(message: string): HttpsError {
  return new HttpsError("failed-precondition", message);
}

/** Archived events are read-only for everyone. */
export function assertNotArchived(event: DocumentData): void {
  if (event.status === "archived") {
    throw refuse("This event is archived, so it cannot be changed.");
  }
}

/** Only `published` and `live` events are open, along with older `active` ones. */
export function assertOpenToJoin(event: DocumentData): void {
  if (["draft", "ended", "archived"].includes(event.status)) {
    throw refuse("This event is not open to joining right now.");
  }
}

/**
 * After an event ends, tasks are read-only except to `event.manage`, which means
 * owner or admin until permissions land.
 */
export function assertTasksOpen(event: DocumentData, uid: string): void {
  assertNotArchived(event);
  const canManage =
    event.creatorId === uid || (event.adminIds ?? []).includes(uid);
  if (event.status === "ended" && !canManage) {
    throw refuse("This event has ended, so its tasks cannot be changed.");
  }
}
