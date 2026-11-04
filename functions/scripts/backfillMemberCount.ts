/**
 * Gives existing events a correct `memberCount`, taken from `memberIds`.
 * Idempotent, and a dry run unless `--write` is passed.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=... npx tsx scripts/backfillMemberCount.ts \
 *     --project=crewpoint-dev [--write]
 *
 * Running this on a real project is a deliberate manual step.
 */
import {applicationDefault, initializeApp} from "firebase-admin/app";
import {Firestore, getFirestore} from "firebase-admin/firestore";

const BATCH_SIZE = 400;

export async function backfillMemberCount(
  db: Firestore,
  {dryRun}: {dryRun: boolean}
): Promise<{checked: number; changed: number}> {
  const events = await db.collection("events").get();
  const stale = events.docs.filter((doc) => {
    const data = doc.data();
    return data.memberCount !== (data.memberIds ?? []).length;
  });
  if (!dryRun) {
    for (let i = 0; i < stale.length; i += BATCH_SIZE) {
      const batch = db.batch();
      for (const doc of stale.slice(i, i + BATCH_SIZE)) {
        batch.update(doc.ref, {
          memberCount: (doc.data().memberIds ?? []).length,
        });
      }
      await batch.commit();
    }
  }
  return {checked: events.size, changed: stale.length};
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
  backfillMemberCount(getFirestore(), {dryRun}).then((result) => {
    const mode = dryRun ? "Dry run" : "Wrote";
    console.log(`${mode} on ${project}:`, result);
  });
}
