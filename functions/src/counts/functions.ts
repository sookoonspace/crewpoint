import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentUpdated, onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions/v2";
import {getFirestore} from "firebase-admin/firestore";
import {clock} from "../utils/clock";
import {requireString, withStructuredLogs} from "../utils/logging";
import {requirePermission} from "../events/members";
import {COUNT_INPUTS, queueCounts, recalculateEvent, runQueuedCounts} from "./recalculate";

/**
 * onCountsInputWritten — a participant, group, session or field changed, so
 * the event's counts are queued (Req 52). Other collections are ignored.
 */
export const onCountsInputWritten = onDocumentWritten(
  "events/{eventId}/{collection}/{docId}",
  async (event) => {
    if (!COUNT_INPUTS.has(event.params.collection)) return;
    await queueCounts(getFirestore(), event.params.eventId, new Date(clock.now()));
  }
);

/** onCountsPrivateWritten — private answers changed, so counts are queued. */
export const onCountsPrivateWritten = onDocumentWritten(
  "events/{eventId}/{collection}/{docId}/private/{privateId}",
  async (event) => {
    if (!COUNT_INPUTS.has(event.params.collection)) return;
    await queueCounts(getFirestore(), event.params.eventId, new Date(clock.now()));
  }
);

/** onCountsSettingsChanged — the attendance policy or categories changed. */
export const onCountsSettingsChanged = onDocumentUpdated(
  "events/{eventId}",
  async (event) => {
    const before = event.data?.before.data()?.settings ?? {};
    const after = event.data?.after.data()?.settings ?? {};
    if (JSON.stringify(before.attendancePolicy ?? null) === JSON.stringify(after.attendancePolicy ?? null) &&
      JSON.stringify(before.categories ?? null) === JSON.stringify(after.categories ?? null)) {
      return;
    }
    await queueCounts(getFirestore(), event.params.eventId, new Date(clock.now()));
  }
);

/** onCountsScheduled — counts each queued event, every 5 minutes. */
export const onCountsScheduled = onSchedule(
  {schedule: "every 5 minutes", retryCount: 0, timeoutSeconds: 540},
  async () => {
    const counted = await runQueuedCounts(getFirestore(), new Date(clock.now()));
    logger.info(`Events counted: ${counted}`);
  }
);

/**
 * recalculateCounts — counts an event now, for the counts screen's
 * "Recalculate now". Needs `counts.read`.
 */
export const recalculateCounts = onCall({timeoutSeconds: 120}, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
  const uid = request.auth.uid;
  const eventId = requireString((request.data ?? {}).eventId, "eventId");
  return withStructuredLogs({op: "recalculateCounts", uid, args: {eventId}}, async () => {
    const db = getFirestore();
    const eventRef = db.collection("events").doc(eventId);
    const event = await eventRef.get();
    if (!event.exists) throw new HttpsError("not-found", "Event not found.");
    await requirePermission(null, eventRef, event.data()!, uid, "counts.read",
      "Only people who read counts can recalculate them.");
    const now = new Date(clock.now());
    await recalculateEvent(db, eventId, now);
    return {updatedAt: now.toISOString()};
  });
});
