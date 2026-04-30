import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';

const PROJECT_ID = 'crewpoint-test';

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
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST is not set. Run via ' +
        '`firebase emulators:exec` or set the env var manually.'
    );
  }

  const rulesPath = path.resolve(__dirname, '..', '..', 'firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: 'localhost',
      port: parseInt(
        process.env.FIRESTORE_EMULATOR_HOST?.split(':')[1] ?? '8080',
        10
      ),
    },
  });
}
