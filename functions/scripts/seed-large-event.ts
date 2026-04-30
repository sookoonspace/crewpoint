/**
 * Seeds a large event into the local Firebase emulator for manual
 * smoke-testing of the streaming-pagination delete path.
 *
 * Usage:
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *   GCLOUD_PROJECT=crewpoint-dev \
 *   npx tsx scripts/seed-large-event.ts \
 *     --event-id=evtSmoke \
 *     --creator-uid=creatorSmoke \
 *     --messages=10000 \
 *     --expenses=200 \
 *     --tasks=500
 *
 * Defaults: --messages=10000 --expenses=200 --tasks=500.
 *
 * The emulator must be running before invocation. The script writes
 * directly via the Admin SDK and bypasses Firestore rules.
 *
 * After seeding, run a manual smoke:
 *   1. flutter app or curl invoke `deleteEvent({eventId: 'evtSmoke'})`
 *      as the creator,
 *   2. observe `npm --prefix functions logs` (or the Functions tab in
 *      the emulator UI at localhost:4000) for the streaming
 *      `messages page-empty / expenses page-empty / tasks page-empty`
 *      sequence,
 *   3. confirm the function returns within the 540s timeout and the
 *      event doc no longer exists in the emulator UI.
 */

import * as admin from "firebase-admin";

interface SeedArgs {
  eventId: string;
  creatorUid: string;
  messages: number;
  expenses: number;
  tasks: number;
}

const BATCH_SIZE = 500;

function parseArgs(): SeedArgs {
  const args = new Map<string, string>();
  for (const arg of process.argv.slice(2)) {
    const match = /^--([^=]+)=(.*)$/.exec(arg);
    if (match) args.set(match[1], match[2]);
  }
  return {
    eventId: args.get("event-id") ?? "evtSmoke",
    creatorUid: args.get("creator-uid") ?? "creatorSmoke",
    messages: parseInt(args.get("messages") ?? "10000", 10),
    expenses: parseInt(args.get("expenses") ?? "200", 10),
    tasks: parseInt(args.get("tasks") ?? "500", 10),
  };
}

async function commitInPages(
  db: FirebaseFirestore.Firestore,
  factory: (i: number) => {
    ref: FirebaseFirestore.DocumentReference;
    data: Record<string, unknown>;
  },
  count: number,
  label: string
): Promise<void> {
  let written = 0;
  while (written < count) {
    const pageSize = Math.min(BATCH_SIZE, count - written);
    const batch = db.batch();
    for (let i = 0; i < pageSize; i++) {
      const {ref, data} = factory(written + i);
      batch.set(ref, data);
    }
    await batch.commit();
    written += pageSize;
    // eslint-disable-next-line no-console
    console.log(`  ${label}: ${written}/${count}`);
  }
}

async function main(): Promise<void> {
  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT,
    });
  }

  const args = parseArgs();
  const db = admin.firestore();
  const eventRef = db.collection("events").doc(args.eventId);

  // eslint-disable-next-line no-console
  console.log(
    `Seeding ${args.eventId} (creator ${args.creatorUid}): ` +
      `${args.messages} msg, ${args.expenses} exp, ${args.tasks} tasks`
  );

  await eventRef.set({
    creatorId: args.creatorUid,
    memberIds: [args.creatorUid],
    adminIds: [args.creatorUid],
    title: "Large smoke event",
    eventType: "trip",
  });

  await commitInPages(
    db,
    (i) => ({
      ref: eventRef.collection("messages").doc(`m${i.toString().padStart(6, "0")}`),
      data: {
        senderId: args.creatorUid,
        text: `Seed message ${i}`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      },
    }),
    args.messages,
    "messages"
  );

  await commitInPages(
    db,
    (i) => ({
      ref: eventRef.collection("expenses").doc(`e${i.toString().padStart(6, "0")}`),
      data: {
        payerId: args.creatorUid,
        amount: 10 + (i % 50),
        description: `Seed expense ${i}`,
      },
    }),
    args.expenses,
    "expenses"
  );

  await commitInPages(
    db,
    (i) => ({
      ref: eventRef.collection("tasks").doc(`t${i.toString().padStart(6, "0")}`),
      data: {
        eventId: args.eventId,
        createdBy: args.creatorUid,
        title: `Seed task ${i}`,
        status: "todo",
      },
    }),
    args.tasks,
    "tasks"
  );

  // eslint-disable-next-line no-console
  console.log("Seed complete.");
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("seed-large-event failed:", err);
  process.exit(1);
});
