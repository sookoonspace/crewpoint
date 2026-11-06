/**
 * Req 34 rollback, before the arrays are removed: redeploy the previous rules
 * and functions and lower the minimum version. This proves the previous rules
 * still give everyone the same access after the migration and after the new
 * callables have run, because the arrays are kept in step.
 */
import * as path from 'path';
import {assertFails, assertSucceeds, RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where} from 'firebase/firestore';
import {getTestEnv} from '../setup';

const OLD_RULES = path.resolve(__dirname, '..', 'fixtures', 'firestore.pre-cutover.rules');

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await getTestEnv(OLD_RULES);
});
afterEach(() => env.clearFirestore());
afterAll(() => env.cleanup());

describe('rolling back to the previous rules', () => {
  // The state after the migration and some role changes: arrays kept in step
  // with member documents, as every membership callable now writes both.
  async function seedMigrated() {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'events/e'), {
        title: 'Fest', status: 'published', creatorId: 'owner',
        adminIds: ['owner', 'coOwner'],
        memberIds: ['owner', 'coOwner', 'finance', 'plain'],
        skipMemberSync: true,
      });
      const members: [string, string[]][] = [
        ['owner', ['owner']], ['coOwner', ['coOwner']], ['finance', ['finance']], ['plain', ['participant']],
      ];
      for (const [uid, roleIds] of members) {
        await setDoc(doc(db, `events/e/members/${uid}`), {uid, roleIds, permissions: []});
      }
      await setDoc(doc(db, 'events/e/tasks/t'), {eventId: 'e', title: 'T', createdBy: 'plain', status: 'todo'});
    });
  }

  test('members still list and read their events through the arrays', async () => {
    await seedMigrated();
    for (const uid of ['owner', 'coOwner', 'finance', 'plain']) {
      const db = env.authenticatedContext(uid).firestore();
      await assertSucceeds(getDocs(query(collection(db, 'events'), where('memberIds', 'array-contains', uid))));
      await assertSucceeds(getDoc(doc(db, 'events/e/tasks/t')));
    }
    await assertFails(getDoc(doc(env.authenticatedContext('stranger').firestore(), 'events/e')));
  });

  test('admins in the array, including a Co-owner, can still manage the event', async () => {
    await seedMigrated();
    const coOwner = env.authenticatedContext('coOwner').firestore();
    await assertSucceeds(updateDoc(doc(coOwner, 'events/e'), {title: 'Renamed'}));
    const plain = env.authenticatedContext('plain').firestore();
    await assertFails(updateDoc(doc(plain, 'events/e'), {title: 'No'}));
  });
});
