/**
 * Loads an event's people, groups, sessions and fields, counts them with
 * [computeStats], and stores the result in `events/{id}/stats/current` with
 * an `updatedAt` time (Req 52). Changes only queue the event in
 * `countsQueue/{eventId}`; a scheduled job counts each queued event once
 * (owner's decision, 2026-11-11), so an import of 400 people costs one run.
 */
import {Firestore, Timestamp} from "firebase-admin/firestore";
import {computeStats, CountField, CountGroup, CountPerson} from "./stats";

/** Collections whose changes change counts. */
export const COUNT_INPUTS = new Set(["participants", "groups", "sessions", "fields"]);

const CHUNK = 300;

/** Reads `{parent}/{id}/private/details` for each ID, as answers by ID. */
async function privateAnswers(
  db: Firestore,
  parent: FirebaseFirestore.CollectionReference,
  ids: string[],
): Promise<Map<string, Record<string, unknown>>> {
  const result = new Map<string, Record<string, unknown>>();
  for (let i = 0; i < ids.length; i += CHUNK) {
    const refs = ids.slice(i, i + CHUNK).map((id) => parent.doc(id).collection("private").doc("details"));
    if (refs.length === 0) continue;
    for (const snap of await db.getAll(...refs)) {
      const fields = snap.data()?.fields;
      if (fields && typeof fields === "object") {
        result.set(snap.ref.parent.parent!.id, fields as Record<string, unknown>);
      }
    }
  }
  return result;
}

/** Counts [eventId] now and stores the result. */
export async function recalculateEvent(db: Firestore, eventId: string, now: Date): Promise<void> {
  const eventRef = db.collection("events").doc(eventId);
  const [event, fieldSnap, peopleSnap, groupSnap, sessionSnap] = await Promise.all([
    eventRef.get(),
    eventRef.collection("fields").get(),
    eventRef.collection("participants").get(),
    eventRef.collection("groups").get(),
    eventRef.collection("sessions").get(),
  ]);
  if (!event.exists) return;

  const fields: (CountField & {private: boolean})[] = fieldSnap.docs.map((d) => ({
    id: d.id,
    type: String(d.data().type ?? "text"),
    scope: String(d.data().scope ?? "participant"),
    private: d.data().visibility === "private",
  }));
  const counted = (scope: string) =>
    fields.some((f) => f.private && f.scope === scope &&
      ["singleChoice", "multiChoice", "yesNo"].includes(f.type));

  // Private answers are read only when a private choice field exists.
  const peoplePrivate = counted("participant") ?
    await privateAnswers(db, eventRef.collection("participants"), peopleSnap.docs.map((d) => d.id)) :
    new Map<string, Record<string, unknown>>();
  const groupsPrivate = counted("group") ?
    await privateAnswers(db, eventRef.collection("groups"), groupSnap.docs.map((d) => d.id)) :
    new Map<string, Record<string, unknown>>();

  const people: CountPerson[] = peopleSnap.docs.map((d) => {
    const p = d.data();
    return {
      id: d.id,
      status: p.status ?? "active",
      groupId: p.groupId ?? null,
      categoryId: p.categoryId ?? null,
      filterTags: p.filterTags ?? [],
      arrivalAt: p.arrivalAt ?? null,
      departureAt: p.departureAt ?? null,
      optOuts: p.optOuts ?? [],
      signUps: p.signUps ?? [],
      invitedTo: p.invitedTo ?? [],
      answers: {...(p.fields ?? {}), ...(peoplePrivate.get(d.id) ?? {})},
    };
  });
  const groups: CountGroup[] = groupSnap.docs.map((d) => ({
    id: d.id,
    invitedTo: d.data().invitedTo ?? [],
    answers: {...(d.data().fields ?? {}), ...(groupsPrivate.get(d.id) ?? {})},
  }));
  const sessions = sessionSnap.docs.map((d) => ({
    id: d.id,
    startAt: d.data().startAt,
    attendance: d.data().attendance ?? null,
    eligibility: d.data().eligibility ?? null,
  }));

  const stats = computeStats({
    policy: event.data()?.settings?.attendancePolicy ?? null,
    sessions, people, groups, fields,
  });
  await eventRef.collection("stats").doc("current").set({
    ...stats,
    updatedAt: Timestamp.fromDate(now),
  });
}

/** Queues [eventId] to be counted on the next scheduled run. */
export async function queueCounts(db: Firestore, eventId: string, now: Date): Promise<void> {
  await db.collection("countsQueue").doc(eventId).set({eventId, requestedAt: Timestamp.fromDate(now)});
}

/**
 * Counts every queued event once. An event queued again while it was being
 * counted stays queued for the next run. Returns how many were counted.
 */
export async function runQueuedCounts(db: Firestore, now: Date): Promise<number> {
  const queued = await db.collection("countsQueue").get();
  let done = 0;
  for (const doc of queued.docs) {
    const requestedAt = doc.data().requestedAt as Timestamp | undefined;
    try {
      await recalculateEvent(db, doc.id, now);
      done++;
    } catch (e) {
      // Left queued, to try again next run.
      console.error(`Counting ${doc.id} failed`, e);
      continue;
    }
    await db.runTransaction(async (tx) => {
      const current = await tx.get(doc.ref);
      const later = current.data()?.requestedAt as Timestamp | undefined;
      if (!later || !requestedAt || later.isEqual(requestedAt)) tx.delete(doc.ref);
    });
  }
  return done;
}
