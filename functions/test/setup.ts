import * as fs from 'fs';
import * as path from 'path';
import {App, getApps, initializeApp} from 'firebase-admin/app';
import {Firestore, getFirestore} from 'firebase-admin/firestore';
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';

/**
 * Project IDs used by the test harness.
 *
 * Rules tests use a dedicated `RULES_PROJECT_ID` so they're isolated
 * from CF integration test state. CF tests inherit `GCLOUD_PROJECT`
 * from `firebase emulators:exec` (set to `demo-crewpoint` by the npm
 * scripts) so the seed data Admin SDK + the CF code's Admin SDK share
 * the same Firestore project namespace. A `demo-` project can only
 * reach emulators, never a real Firebase project.
 */
const RULES_PROJECT_ID = 'crewpoint-rules-test';
const CF_PROJECT_ID = process.env.GCLOUD_PROJECT ?? 'demo-crewpoint';

const FIRESTORE_HOST_RAW = process.env.FIRESTORE_EMULATOR_HOST ?? '';

function requireEmulatorHost(): void {
  if (!FIRESTORE_HOST_RAW) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST is not set. Run via ' +
        '`firebase emulators:exec` or set the env var manually.'
    );
  }
}

/**
 * Returns a fresh `RulesTestEnvironment` per call, loading the
 * production rules and pointing at the local emulator.
 *
 * Tests must:
 *   1. seed via `withSecurityRulesDisabled()` for any preconditions,
 *   2. acquire an `authenticatedContext()` for the assertion,
 *   3. call `clearFirestore()` between tests to keep state isolated.
 */
export async function getTestEnv(): Promise<RulesTestEnvironment> {
  requireEmulatorHost();

  const rulesPath = path.resolve(__dirname, '..', '..', 'firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  const env = await initializeTestEnvironment({
    projectId: RULES_PROJECT_ID,
    firestore: {
      rules,
      host: 'localhost',
      port: parseInt(FIRESTORE_HOST_RAW.split(':')[1] ?? '8080', 10),
    },
  });
  // Most tests seed events in the old shape, with arrays. Rules read member
  // documents, so each seed also writes them, mapped as the migration does.
  const disabled = env.withSecurityRulesDisabled.bind(env);
  env.withSecurityRulesDisabled = (callback) =>
    disabled(async (ctx) => {
      await callback(ctx);
      await syncMemberDocs(ctx.firestore() as unknown as ClientFirestore);
    });
  return env;
}

type ClientFirestore = import('firebase/firestore').Firestore;

/**
 * Gives every event a member document for each person in its arrays, using
 * the migration mapping, and deletes documents for people no longer in them.
 * Documents a test wrote itself are kept, unless the person has left. An
 * event with `skipMemberSync: true` is left alone.
 */
async function syncMemberDocs(db: ClientFirestore): Promise<void> {
  const {collection, doc, getDocs, setDoc, deleteDoc} = await import('firebase/firestore');
  const {computePermissions, legacyRoleIds} = await import('../src/events/permissions');
  const events = await getDocs(collection(db, 'events'));
  for (const event of events.docs) {
    const data = event.data();
    // A test that controls member documents itself opts out.
    if (data.skipMemberSync === true) continue;
    const memberIds: string[] = Array.isArray(data.memberIds) ? data.memberIds : [];
    const members = await getDocs(collection(db, `events/${event.id}/members`));
    const have = new Map(members.docs.map((m) => [m.id, m.data()]));
    for (const uid of memberIds) {
      const existing = have.get(uid);
      if (existing && existing.seededFromArrays !== true) continue;
      const roleIds = legacyRoleIds(data, uid);
      await setDoc(doc(db, `events/${event.id}/members/${uid}`), {
        uid,
        roleIds,
        crewIds: [],
        permissions: computePermissions(roleIds, {}),
        participantId: null,
        seededFromArrays: true,
      });
    }
    for (const uid of have.keys()) {
      if (!memberIds.includes(uid)) {
        await deleteDoc(doc(db, `events/${event.id}/members/${uid}`));
      }
    }
  }
}

/**
 * Returns the Admin SDK app pointed at the CF test project. Memoized.
 */
let _adminApp: App | null = null;
export function getAdminApp(): App {
  requireEmulatorHost();
  if (_adminApp) return _adminApp;

  // Reuse the existing default app if functions/src/index.ts has
  // already called initializeApp(); otherwise initialize one.
  if (getApps().length > 0 && getApps()[0]) {
    _adminApp = getApps()[0]!;
  } else {
    _adminApp = initializeApp({projectId: CF_PROJECT_ID});
  }
  return _adminApp;
}

/** Convenience accessor for the Admin SDK Firestore (CF test project). */
export function getAdminDb(): Firestore {
  return getFirestore(getAdminApp());
}

/** Wipes Firestore in the CF test project via the emulator REST API. */
export async function clearFirestoreEmulator(): Promise<void> {
  const url = `http://${FIRESTORE_HOST_RAW}/emulator/v1/projects/${CF_PROJECT_ID}/databases/(default)/documents`;
  const res = await fetch(url, {method: 'DELETE'});
  if (!res.ok) {
    throw new Error(
      `Failed to clear Firestore emulator: ${res.status} ${res.statusText}`
    );
  }
}
