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

/** How far [timeZone] is ahead of UTC at [instantMs]. Unknown zones read as UTC. */
function zoneOffsetMs(instantMs: number, timeZone: string): number {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone,
      hourCycle: "h23",
      year: "numeric",
      month: "numeric",
      day: "numeric",
      hour: "numeric",
      minute: "numeric",
      second: "numeric",
    }).formatToParts(new Date(instantMs));
    const part = (type: string) =>
      Number(parts.find((p) => p.type === type)?.value);
    const asUtc = Date.UTC(
      part("year"),
      part("month") - 1,
      part("day"),
      part("hour"),
      part("minute"),
      part("second")
    );
    return asUtc - instantMs;
  } catch {
    return 0;
  }
}

/**
 * The instant a calendar date starts in [timeZone]. The date arrives as midnight
 * UTC, which is how date-only events store it. The offset is checked again at
 * the result, because the first guess can sit across a daylight-saving change.
 */
function startOfDateIn(dateAsUtcMs: number, timeZone: string): number {
  const firstGuess = dateAsUtcMs - zoneOffsetMs(dateAsUtcMs, timeZone);
  return dateAsUtcMs - zoneOffsetMs(firstGuess, timeZone);
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
 * When [event] starts, in milliseconds, or null without a start date. A
 * date-only start means the start of that day in the event's time zone.
 */
export function eventStartMs(event: DocumentData): number | null {
  const start = (event.startDate as Timestamp | null | undefined)?.toDate?.();
  if (!start) return null;
  return event.dateOnly === true ?
    startOfDateIn(start.getTime(), event.timeZone ?? "UTC") :
    start.getTime();
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

  const zone = event.timeZone ?? "UTC";
  const dateOnly = event.dateOnly === true;
  const end = (event.endDate as Timestamp | null | undefined)?.toDate();
  if (end) {
    const endMs = dateOnly ?
      startOfDateIn(end.getTime() + DAY_MS, zone) :
      endInstant(end, zone);
    if (passedSinceSet(endMs)) return "ended";
  }
  const startMs = eventStartMs(event);
  if (status === "published" && startMs !== null && passedSinceSet(startMs)) {
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
 * After an event ends, tasks are read-only except to `event.manage`.
 * [permissions] are the caller's.
 */
export function assertTasksOpen(
  event: DocumentData,
  permissions: readonly string[]
): void {
  assertNotArchived(event);
  if (event.status === "ended" && !permissions.includes("event.manage")) {
    throw refuse("This event has ended, so its tasks cannot be changed.");
  }
}
