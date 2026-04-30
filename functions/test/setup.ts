import * as fs from 'fs';
import * as path from 'path';
import * as admin from 'firebase-admin';
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';

/**
 * Project IDs used by the test harness.
 *
 * Rules tests use a dedicated `RULES_PROJECT_ID` so they're isolated
 * from CF integration test state. CF tests inherit `GCLOUD_PROJECT`
 * from `firebase emulators:exec` (set to `crewpoint-dev` per
 * `.firebaserc`'s default) so the seed data Admin SDK + the CF code's
 * Admin SDK share the same Firestore project namespace.
 */
const RULES_PROJECT_ID = 'crewpoint-rules-test';
const CF_PROJECT_ID = process.env.GCLOUD_PROJECT ?? 'crewpoint-dev';

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

  return initializeTestEnvironment({
    projectId: RULES_PROJECT_ID,
    firestore: {
      rules,
      host: 'localhost',
      port: parseInt(FIRESTORE_HOST_RAW.split(':')[1] ?? '8080', 10),
    },
  });
}

/**
 * Returns the Admin SDK app pointed at the CF test project. Memoized.
 */
let _adminApp: admin.app.App | null = null;
export function getAdminApp(): admin.app.App {
  requireEmulatorHost();
  if (_adminApp) return _adminApp;

  // Reuse the existing default app if functions/src/index.ts has
  // already called initializeApp(); otherwise initialize one.
  if (admin.apps.length > 0 && admin.apps[0]) {
    _adminApp = admin.apps[0]!;
  } else {
    _adminApp = admin.initializeApp({projectId: CF_PROJECT_ID});
  }
  return _adminApp;
}

/** Convenience accessor for the Admin SDK Firestore (CF test project). */
export function getAdminDb(): FirebaseFirestore.Firestore {
  return getAdminApp().firestore();
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
