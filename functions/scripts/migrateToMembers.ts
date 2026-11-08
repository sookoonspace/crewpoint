/**
 * Converts each event to member documents (Req 34), keeping the old arrays so
 * rollback stays possible. Idempotent, and a dry run unless `--write` is
 * passed.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=... npx tsx scripts/migrateToMembers.ts \
 *     --project=crewpoint-dev [--write]
 *
 * Running this on a real project is a deliberate manual step in #66, after a
 * fresh backup. Run `verifyMembers.ts` afterwards.
 */
import {applicationDefault, initializeApp} from "firebase-admin/app";
import {
  DocumentData,
  DocumentReference,
  FieldValue,
  Firestore,
  getFirestore,
  QuerySnapshot,
  Timestamp,
} from "firebase-admin/firestore";
import {commitInChunks, BatchOperation} from "../src/utils/batch";
import {memberDoc, rebuildMember} from "../src/events/members";
import {expenseAccessOf} from "../src/events/expenseAccess";
import {profileFrom} from "../src/events/profileFields";
import {EventRoles, legacyRoleIds} from "../src/events/permissions";
import {mapLegacyStatus} from "../src/events/eventStatus";

export interface MigrationResult {
  events: number;
  memberDocs: number;
  statuses: number;
  memberCounts: number;
  involvedUids: number;
  dates: number;
  unknownZones: number;
  taskBudgets: number;
  profiles: number;
  permissions: number;
}

const DAY_MS = 24 * 60 * 60 * 1000;

export async function migrateToMembers(
  db: Firestore,
  {dryRun, now = new Date()}: {dryRun: boolean; now?: Date}
): Promise<MigrationResult> {
  const events = await db.collection("events").get();
  const result: MigrationResult = {
    events: events.size,
    memberDocs: 0,
    statuses: 0,
    memberCounts: 0,
    involvedUids: 0,
    dates: 0,
    unknownZones: 0,
    taskBudgets: 0,
    profiles: 0,
    permissions: 0,
  };
  const ops: BatchOperation[] = [];
  for (const doc of events.docs) {
    const event = doc.data();
    ops.push(...(await memberOps(doc.ref, event, result)));
    const expenses = await doc.ref.collection("expenses").get();
    const tasks = await doc.ref.collection("tasks").get();
    ops.push(...expenseOps(expenses, result));
    ops.push(...budgetOps(doc.ref, tasks, result));
    ops.push(
      ...(await profileOps(db, doc.ref, event, {expenses, tasks}, result))
    );
    const fields = {
      ...eventFields(event, now, result),
      ...(await dateFields(db, event, result)),
    };
    if (Object.keys(fields).length > 0) {
      ops.push({type: "update", ref: doc.ref, data: fields});
    }
  }
  if (!dryRun) await commitInChunks(ops);
  return result;
}

/** Fields on the event document itself that need converting. */
function eventFields(
  event: DocumentData,
  now: Date,
  result: MigrationResult
): Record<string, unknown> {
  const fields: Record<string, unknown> = {};
  // Old end dates were midnight on the creator's device, so the event is over
  // a day later.
  const end = event.endDate?.toDate?.() as Date | undefined;
  const endOfDay = end ? new Date(end.getTime() + DAY_MS) : null;
  const status = mapLegacyStatus(event.status, endOfDay, now);
  if (status !== event.status) {
    fields.status = status;
    result.statuses++;
  }
  const count = (event.memberIds ?? []).length;
  if (event.memberCount !== count) {
    fields.memberCount = count;
    result.memberCounts++;
  }
  return fields;
}

/** The calendar date [instant] shows in [timeZone], as midnight UTC. */
function dateIn(instant: Date, timeZone: string): Date {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "numeric",
    day: "numeric",
  }).formatToParts(instant);
  const part = (type: string) =>
    Number(parts.find((p) => p.type === type)?.value);
  return new Date(Date.UTC(part("year"), part("month") - 1, part("day")));
}

function isTimeZone(value: unknown): value is string {
  if (typeof value !== "string") return false;
  try {
    new Intl.DateTimeFormat("en", {timeZone: value});
    return true;
  } catch {
    return false;
  }
}

/**
 * Before #63, dates were midnight on the creator's device. They become the
 * calendar date they showed there, stored as midnight UTC with `dateOnly`.
 * The event's own zone is used if it has one, or else the creator's stored
 * zone, which the event then takes. With no zone known, dates stay as they
 * are and are counted, so someone can check them by hand.
 */
async function dateFields(
  db: Firestore,
  event: DocumentData,
  result: MigrationResult
): Promise<Record<string, unknown>> {
  if (event.dateOnly === true) return {};
  const fields: Record<string, unknown> = {};
  let zone: string | null = isTimeZone(event.timeZone) ? event.timeZone : null;
  if (!zone && typeof event.creatorId === "string") {
    const profile = await db
      .doc(`users/${event.creatorId}/private/profile`)
      .get();
    const stored = profile.data()?.notificationPrefs?.timezone;
    if (isTimeZone(stored)) {
      zone = stored;
      fields.timeZone = stored;
    }
  }
  const start = event.startDate?.toDate?.() as Date | undefined;
  const end = event.endDate?.toDate?.() as Date | undefined;
  if (!start && !end) return fields;
  if (!zone) {
    result.unknownZones++;
    return fields;
  }
  if (start) fields.startDate = Timestamp.fromDate(dateIn(start, zone));
  if (end) fields.endDate = Timestamp.fromDate(dateIn(end, zone));
  fields.dateOnly = true;
  result.dates++;
  return fields;
}

/**
 * Older expenses have no `involvedUids`, which reads by involvement need
 * (Technical Decision 4a). It is the payer and everyone in the splits, as
 * `saveExpense` and `recordSettlement` write it.
 */
function expenseOps(
  expenses: QuerySnapshot,
  result: MigrationResult
): BatchOperation[] {
  const ops: BatchOperation[] = [];
  for (const doc of expenses.docs) {
    const expense = doc.data();
    if (Array.isArray(expense.involvedUids)) continue;
    const splits: {userId?: unknown}[] = expense.splits ?? [];
    const involved = [expense.payerId, ...splits.map((s) => s.userId)].filter(
      (uid): uid is string => typeof uid === "string"
    );
    ops.push({
      type: "update",
      ref: doc.ref,
      data: {involvedUids: [...new Set(involved)]},
    });
    result.involvedUids++;
  }
  return ops;
}

/**
 * A task's budget figure moves to `taskBudgets/{taskId}`, which needs
 * `budget.read` (Req 36), and leaves the task.
 */
function budgetOps(
  eventRef: DocumentReference,
  tasks: QuerySnapshot,
  result: MigrationResult
): BatchOperation[] {
  const ops: BatchOperation[] = [];
  for (const doc of tasks.docs) {
    const task = doc.data();
    if (!("budgetEstimate" in task)) continue;
    if (typeof task.budgetEstimate === "number") {
      ops.push({
        type: "set",
        ref: eventRef.collection("taskBudgets").doc(doc.id),
        data: {estimate: task.budgetEstimate},
      });
      result.taskBudgets++;
    }
    ops.push({
      type: "update",
      ref: doc.ref,
      data: {budgetEstimate: FieldValue.delete()},
    });
  }
  return ops;
}

const sameData = (a: DocumentData | undefined, b: DocumentData) =>
  a !== undefined &&
  Object.keys(a).length === Object.keys(b).length &&
  Object.entries(b).every(([k, v]) => a[k] === v);

/**
 * Names and handles move from the public `users/{uid}` into the event
 * (Req 37). Members get both. People who left but still appear on messages,
 * expenses or tasks get only their name, so those records still show it.
 */
async function profileOps(
  db: Firestore,
  eventRef: DocumentReference,
  event: DocumentData,
  {expenses, tasks}: {expenses: QuerySnapshot; tasks: QuerySnapshot},
  result: MigrationResult
): Promise<BatchOperation[]> {
  const memberDocs = await eventRef.collection("members").get();
  const members = new Set<string>([
    ...((event.memberIds ?? []) as string[]),
    ...memberDocs.docs.map((d) => d.id),
  ]);
  const others = new Set<string>();
  const add = (uid: unknown) => {
    if (typeof uid === "string" && uid && !members.has(uid)) others.add(uid);
  };
  const messages = await eventRef.collection("messages").select("senderId").get();
  messages.docs.forEach((m) => add(m.data().senderId));
  for (const e of expenses.docs) {
    const expense = e.data();
    add(expense.payerId);
    ((expense.splits ?? []) as {userId?: unknown}[]).forEach((s) => add(s.userId));
  }
  for (const t of tasks.docs) {
    const task = t.data();
    [task.createdBy, task.assigneeId, task.completedBy].forEach(add);
  }
  const existing = await eventRef.collection("profiles").get();
  const have = new Map(existing.docs.map((d) => [d.id, d.data()]));
  const ops: BatchOperation[] = [];
  for (const uid of [...members, ...others]) {
    const user = (await db.collection("users").doc(uid).get()).data();
    const full = profileFrom(uid, user);
    const data = members.has(uid) ?
      full :
      {uid, displayName: full.displayName, photoUrl: full.photoUrl};
    if (sameData(have.get(uid), data)) continue;
    ops.push({type: "set", ref: eventRef.collection("profiles").doc(uid), data});
    result.profiles++;
  }
  return ops;
}

async function memberOps(
  eventRef: DocumentReference,
  event: DocumentData,
  result: MigrationResult
): Promise<BatchOperation[]> {
  const existing = await eventRef.collection("members").get();
  const have = new Set(existing.docs.map((d) => d.id));
  const roleDocs = await eventRef.collection("roles").get();
  const roles: EventRoles = {};
  roleDocs.docs.forEach((d) => (roles[d.id] = d.data()));
  const access = expenseAccessOf(event);
  const ops: BatchOperation[] = [];
  // Existing documents are recalculated from their roles, so they carry what
  // the expense access setting adds (Req 38).
  for (const doc of existing.docs) {
    const rebuilt = rebuildMember(doc.id, doc.data(), roles, access);
    const before = JSON.stringify(doc.data().permissions ?? []);
    if (JSON.stringify(rebuilt.permissions) === before) continue;
    ops.push({type: "update", ref: doc.ref, data: {permissions: rebuilt.permissions}});
    result.permissions++;
  }
  for (const uid of (event.memberIds ?? []) as string[]) {
    if (have.has(uid)) continue;
    const data = memberDoc(
      uid,
      {roleIds: legacyRoleIds(event, uid), joinedAt: event.createdAt},
      roles,
      access
    );
    ops.push({type: "set", ref: eventRef.collection("members").doc(uid), data});
    result.memberDocs++;
  }
  return ops;
}

if (require.main === module) {
  const project = process.argv
    .find((arg) => arg.startsWith("--project="))
    ?.split("=")[1];
  if (!project) {
    console.error("Pass --project=<project id>.");
    process.exit(1);
  }
  const dryRun = !process.argv.includes("--write");
  initializeApp({credential: applicationDefault(), projectId: project});
  migrateToMembers(getFirestore(), {dryRun}).then((result) => {
    const mode = dryRun ? "Dry run" : "Wrote";
    console.log(`${mode} on ${project}:`, result);
  });
}
