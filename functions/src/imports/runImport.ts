import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions/v2";
import {parseCsv} from "./csv";
import {
  CategoryDef, FieldDef, ExistingPerson, Plan, Target, filterTagsFor, normalise, planImport,
} from "./plan";
import {externalIdKeyer} from "../participants/matchKeys";

const db = () => getFirestore();

/** Writes per batch, under Firestore's 500. */
const CHUNK = 400;
/** Rows in one file, and errors kept in the report. */
export const MAX_ROWS = 20000;
const MAX_REPORTED_ERRORS = 500;

export const importFilePath = (eventId: string, jobId: string) =>
  `events/${eventId}/imports/${jobId}.csv`;

/** The event's first day as `YYYY-MM-DD`, for ages (Req 42). */
function eventStart(event: FirebaseFirestore.DocumentData): string | null {
  const start = event.startDate;
  const date: Date | null = start instanceof Timestamp ? start.toDate() :
    start instanceof Date ? start : null;
  return date ? date.toISOString().slice(0, 10) : null;
}

function report(plan: Plan) {
  return {
    total: plan.total,
    valid: plan.people.length,
    creates: plan.creates,
    updates: plan.updates,
    newGroups: plan.newGroups.length,
    errorCount: plan.errors.length,
    errors: plan.errors.slice(0, MAX_REPORTED_ERRORS),
    mappingProblems: plan.mappingProblems,
    missingGroups: plan.missingGroups,
  };
}

/**
 * Runs one queued import job (Req 44a, 75): checks the file and reports, or
 * applies it in chunks with progress, so it can be left and reopened. The
 * file is deleted once applied. Only jobs in `queued` are picked up.
 */
export async function runImportJob({
  eventId,
  jobId,
  readFile,
  deleteFile,
}: {
  eventId: string;
  jobId: string;
  readFile: (path: string) => Promise<string>;
  deleteFile: (path: string) => Promise<void>;
}): Promise<void> {
  const eventRef = db().collection("events").doc(eventId);
  const jobRef = eventRef.collection("imports").doc(jobId);
  const claimed = await db().runTransaction(async (tx) => {
    const doc = await tx.get(jobRef);
    if (!doc.exists || doc.data()!.status !== "queued") return null;
    tx.update(jobRef, {status: "running", startedAt: FieldValue.serverTimestamp()});
    return doc.data()!;
  });
  if (!claimed) return;
  const path = importFilePath(eventId, jobId);
  try {
    let rows: string[][];
    try {
      rows = parseCsv(await readFile(path));
    } catch (e) {
      logger.warn("import file unreadable", {eventId, jobId, error: String(e)});
      await jobRef.update({status: "failed", error: "unreadable"});
      return;
    }
    if (rows.length - 1 > MAX_ROWS) {
      await jobRef.update({status: "failed", error: "tooManyRows"});
      return;
    }
    const [event, fieldsSnap, peopleSnap, groupsSnap, keysSnap, keyOf] = await Promise.all([
      eventRef.get(),
      eventRef.collection("fields").get(),
      eventRef.collection("participants").get(),
      eventRef.collection("groups").get(),
      eventRef.collection("participantKeys").get(),
      externalIdKeyer(eventId),
    ]);
    // Unnamed entries a deleted account left (Req 14a).
    const idKeys = new Map(keysSnap.docs.map((d) => [d.id, d.data().externalIdKey ?? null]));
    const eventData = event.data() ?? {};
    const fields = fieldsSnap.docs.map((d) => ({id: d.id, ...d.data()}) as FieldDef);
    const existingDocs = new Map(peopleSnap.docs.map((d) => [d.id, d.data()]));
    const plan = planImport(rows, claimed.targets as Target[], {
      fields,
      categories: (eventData.settings?.categories ?? []) as CategoryDef[],
      eventStart: eventStart(eventData),
      existing: peopleSnap.docs.map((d) => ({
        id: d.id,
        name: d.data().name ?? "",
        groupId: d.data().groupId ?? null,
        externalId: d.data().externalId ?? null,
        imported: d.data().imported === true,
        status: d.data().status ?? "active",
        externalIdKey: idKeys.get(d.id) ?? null,
      }) as ExistingPerson),
      externalIdKey: keyOf,
      existingGroups: groupsSnap.docs.map((d) => ({id: d.id, name: d.data().name ?? ""})),
    });

    if (claimed.mode !== "apply" || plan.mappingProblems.includes("nameNotMapped")) {
      await jobRef.update({
        status: "checked", report: report(plan), checkedAt: FieldValue.serverTimestamp(),
      });
      return;
    }
    await apply(eventRef, jobRef, plan, fields, existingDocs, claimed.createdBy);
    await jobRef.update({
      status: "done", report: report(plan), finishedAt: FieldValue.serverTimestamp(),
    });
    await deleteFile(path).catch((e) =>
      logger.warn("import file not deleted", {eventId, jobId, error: String(e)}));
  } catch (e) {
    logger.error("import failed", {eventId, jobId, error: String(e)});
    await jobRef.update({status: "failed", error: "internal"});
  }
}

async function apply(
  eventRef: FirebaseFirestore.DocumentReference,
  jobRef: FirebaseFirestore.DocumentReference,
  plan: Plan,
  fields: FieldDef[],
  existing: Map<string, FirebaseFirestore.DocumentData>,
  createdBy: string
): Promise<void> {
  const now = FieldValue.serverTimestamp();
  // New groups first, so people can go in them.
  const groupIds = new Map<string, string>();
  for (const name of plan.newGroups) {
    const ref = eventRef.collection("groups").doc();
    await ref.set({
      name, sortName: name.toLowerCase(), adultUids: [], imported: true,
      createdBy, createdAt: now, updatedAt: now,
    });
    groupIds.set(normalise(name), ref.id);
  }
  const total = plan.people.length;
  await jobRef.update({progress: {processed: 0, total}});
  const groupAnswers = new Map<string, Record<string, unknown>>();
  for (let i = 0; i < total; i += CHUNK) {
    const batch = db().batch();
    for (const person of plan.people.slice(i, i + CHUNK)) {
      const groupId = person.groupId ??
        (person.groupName ? groupIds.get(normalise(person.groupName)) ?? null : null);
      const ref = person.match ?
        eventRef.collection("participants").doc(person.match) :
        eventRef.collection("participants").doc();
      const before = person.match ? existing.get(person.match) ?? {} : {};
      // Only mapped columns are written, so manual edits to others are kept.
      const answers = {...(before.fields ?? {}), ...person.standard};
      const data: Record<string, unknown> = {
        name: person.name,
        sortName: person.name.trim().toLowerCase(),
        status: "active",
        imported: true,
        fields: answers,
        filterTags: filterTagsFor(fields, answers),
        updatedAt: now,
      };
      if (person.groupName !== null || !person.match) data.groupId = groupId;
      if (person.externalId) data.externalId = person.externalId;
      if (person.isChild !== undefined) data.isChild = person.isChild;
      if (person.categoryId !== undefined) data.categoryId = person.categoryId;
      if (!person.match) {
        Object.assign(data, {
          isChild: person.isChild ?? false, createdBy, createdAt: now,
          categoryId: person.categoryId ?? null,
        });
        batch.set(ref, data);
      } else {
        if (before.anonymised === true) {
          // Found again by its match key: it is a named record once more.
          data.anonymised = FieldValue.delete();
          batch.delete(eventRef.collection("participantKeys").doc(ref.id));
        }
        batch.update(ref, data);
      }
      const privateData: Record<string, unknown> = {};
      if (person.birthDate !== undefined) privateData.birthDate = person.birthDate;
      if (person.email !== undefined) privateData.email = person.email;
      if (Object.keys(person.private).length > 0) privateData.fields = person.private;
      if (Object.keys(privateData).length > 0) {
        batch.set(ref.collection("private").doc("details"), {...privateData, updatedAt: now}, {merge: true});
      }
      if (groupId && Object.keys(person.groupStandard).length > 0) {
        groupAnswers.set(groupId, {...(groupAnswers.get(groupId) ?? {}), ...person.groupStandard});
      }
    }
    await batch.commit();
    await jobRef.update({progress: {processed: Math.min(i + CHUNK, total), total}});
  }
  for (const [groupId, answers] of groupAnswers) {
    const ref = eventRef.collection("groups").doc(groupId);
    const current = (await ref.get()).data()?.fields ?? {};
    const merged = {...current, ...answers};
    await ref.update({fields: merged, filterTags: filterTagsFor(fields, merged, "group"), updatedAt: now});
  }
}
