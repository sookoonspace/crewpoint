/**
 * Compares every event's old arrays with its member documents (Req 34,
 * step 5). Reads only. Exits with 1 if anything differs.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=... npx tsx scripts/verifyMembers.ts \
 *     --project=crewpoint-dev
 */
import {applicationDefault, initializeApp} from "firebase-admin/app";
import {
  DocumentData,
  DocumentReference,
  Firestore,
  getFirestore,
} from "firebase-admin/firestore";
import {
  EventRoles,
  computePermissions,
  isAdminLevel,
} from "../src/events/permissions";
import {
  expenseAccessOf,
  readsAllExpensesUnder,
} from "../src/events/expenseAccess";

export interface VerifyResult {
  events: number;
  problems: string[];
}

export async function verifyMembers(db: Firestore): Promise<VerifyResult> {
  const events = await db.collection("events").get();
  const problems: string[] = [];
  for (const doc of events.docs) {
    const found = await checkEvent(doc.ref, doc.data());
    problems.push(...found.map((p) => `${doc.id}: ${p}`));
  }
  return {events: events.size, problems};
}

async function checkEvent(
  eventRef: DocumentReference,
  event: DocumentData
): Promise<string[]> {
  const [members, roleDocs] = await Promise.all([
    eventRef.collection("members").get(),
    eventRef.collection("roles").get(),
  ]);
  const roles: EventRoles = {};
  roleDocs.docs.forEach((d) => (roles[d.id] = d.data()));
  const access = expenseAccessOf(event);
  const memberIds: string[] = event.memberIds ?? [];
  const adminIds: string[] = event.adminIds ?? [];
  const docs = new Map(members.docs.map((d) => [d.id, d.data()]));
  const problems: string[] = [];

  for (const uid of memberIds) {
    if (!docs.has(uid)) {
      problems.push(`${uid} is in memberIds but has no member document`);
    }
  }
  for (const [uid, member] of docs) {
    if (!memberIds.includes(uid)) {
      problems.push(`${uid} has a member document but is not in memberIds`);
      continue;
    }
    const roleIds: string[] = member.roleIds ?? [];
    if (uid === event.creatorId && !roleIds.includes("owner")) {
      problems.push(`${uid} created the event but is not Owner`);
    }
    const admin = isAdminLevel(roleIds);
    if (adminIds.includes(uid) && !admin) {
      problems.push(`${uid} is in adminIds but holds no admin role`);
    }
    if (!adminIds.includes(uid) && admin) {
      problems.push(`${uid} holds an admin role but is not in adminIds`);
    }
    const expected = computePermissions(roleIds, roles, {
      editsOwnGroup: member.editsOwnGroup,
      readsAllExpenses: readsAllExpensesUnder(access, uid, roleIds),
    });
    if (JSON.stringify(member.permissions) !== JSON.stringify(expected)) {
      problems.push(`${uid} has stale permissions`);
    }
  }
  if (event.memberCount !== memberIds.length) {
    problems.push(
      `memberCount is ${event.memberCount}, but memberIds has ${memberIds.length}`
    );
  }
  return problems;
}

if (require.main === module) {
  const project = process.argv
    .find((arg) => arg.startsWith("--project="))
    ?.split("=")[1];
  if (!project) {
    console.error("Pass --project=<project id>.");
    process.exit(1);
  }
  initializeApp({credential: applicationDefault(), projectId: project});
  verifyMembers(getFirestore()).then((result) => {
    console.log(`Checked ${result.events} events on ${project}.`);
    result.problems.forEach((p) => console.log(`- ${p}`));
    if (result.problems.length > 0) process.exit(1);
    console.log("Every event matches.");
  });
}
