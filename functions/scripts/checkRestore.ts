/**
 * Compares a restored Firestore database with live (Req 67). Reads only,
 * from both. Every event, expense and member document in the restored copy
 * must match live exactly, unless live changed it after the backup was
 * taken. Exits with 1 if anything differs.
 *
 *   npx tsx scripts/checkRestore.ts --project=crewpoint-dev \
 *     --database=restore-test --snapshot=2026-11-12T14:22:57Z
 *
 * `--snapshot` is the backup's `snapshotTime` from
 * `gcloud firestore backups list`.
 */
import {isDeepStrictEqual} from "node:util";
import {applicationDefault, initializeApp} from "firebase-admin/app";
import {Firestore, Query, getFirestore} from "firebase-admin/firestore";

const TOP = ["events", "users", "event_invites", "config", "organizers"];
const GROUPS = [
  "members", "expenses", "tasks", "messages",
  "participants", "profiles", "sessions", "roles",
];

export interface Comparison {
  name: string;
  restored: number;
  identical: number;
  changedSince: number;
  deletedSince: number;
  mismatched: string[];
}

export async function countAll(db: Firestore): Promise<Record<string, number>> {
  const out: Record<string, number> = {};
  for (const c of TOP) {
    out[c] = (await db.collection(c).count().get()).data().count;
  }
  for (const g of GROUPS) {
    out[`*/${g}`] = (await db.collectionGroup(g).count().get()).data().count;
  }
  return out;
}

export async function compareWithLive(
  name: string,
  restoredQuery: Query,
  live: Firestore,
  snapshotMillis: number,
): Promise<Comparison> {
  const result: Comparison = {
    name, restored: 0, identical: 0, changedSince: 0, deletedSince: 0,
    mismatched: [],
  };
  const docs = (await restoredQuery.get()).docs;
  result.restored = docs.length;
  for (const doc of docs) {
    const current = await live.doc(doc.ref.path).get();
    if (!current.exists) {
      result.deletedSince++;
    } else if (current.updateTime!.toMillis() > snapshotMillis) {
      result.changedSince++;
    } else if (isDeepStrictEqual(doc.data(), current.data())) {
      result.identical++;
    } else {
      result.mismatched.push(doc.ref.path);
    }
  }
  return result;
}

function arg(name: string): string {
  const found = process.argv.find((a) => a.startsWith(`--${name}=`));
  if (!found) throw new Error(`--${name}= is required`);
  return found.slice(name.length + 3);
}

async function main(): Promise<void> {
  const projectId = arg("project");
  const database = arg("database");
  if (database === "(default)") throw new Error("Name the restored copy, not live");
  const snapshotMillis = new Date(arg("snapshot")).getTime();
  if (Number.isNaN(snapshotMillis)) throw new Error("--snapshot is not a date");

  const app = initializeApp({credential: applicationDefault(), projectId});
  const live = getFirestore(app);
  const restored = getFirestore(app, database);

  const [restoredCounts, liveCounts] =
    [await countAll(restored), await countAll(live)];
  console.log("collection".padEnd(18), "restored".padStart(9), "live".padStart(9));
  for (const key of Object.keys(restoredCounts)) {
    console.log(key.padEnd(18), String(restoredCounts[key]).padStart(9),
      String(liveCounts[key]).padStart(9));
  }

  const comparisons = [
    await compareWithLive("events", restored.collection("events"), live, snapshotMillis),
    await compareWithLive("expenses", restored.collectionGroup("expenses"), live, snapshotMillis),
    await compareWithLive("members", restored.collectionGroup("members"), live, snapshotMillis),
  ];
  for (const c of comparisons) {
    console.log(`${c.name}: ${c.restored} restored, ${c.identical} identical, ` +
      `${c.changedSince} changed in live since, ${c.deletedSince} deleted since, ` +
      `${c.mismatched.length} mismatched ${c.mismatched.join(", ")}`);
  }
  process.exit(comparisons.some((c) => c.mismatched.length) ? 1 : 0);
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(2);
  });
}
