/**
 * Req 57a: the chat summary is read by those who read chat (`chat.send`),
 * and written only by the server.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';
import {getTestEnv} from './setup';
import {computePermissions} from '../src/events/permissions';

let env: RulesTestEnvironment;
beforeAll(async () => {
  env = await getTestEnv();
});
afterEach(() => env.clearFirestore());
afterAll(() => env.cleanup());

const E = 'events/e1';
const as = (uid: string) => env.authenticatedContext(uid).firestore();
const ROLES: Record<string, string[]> = {owner: ['owner'], plain: ['participant'], vendor: ['vendor']};

beforeEach(() => env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, E), {title: 'T', status: 'published', creatorId: 'owner', adminIds: ['owner'], memberIds: Object.keys(ROLES), skipMemberSync: true});
  for (const [uid, roleIds] of Object.entries(ROLES)) {
    await setDoc(doc(db, `${E}/members/${uid}`), {uid, roleIds, crewIds: [], permissions: computePermissions(roleIds, {})});
  }
  await setDoc(doc(db, `${E}/chatSummary/current`), {count: 3});
}));

test('those who read chat read the summary', async () => {
  await assertSucceeds(getDoc(doc(as('plain'), `${E}/chatSummary/current`)));
  await assertFails(getDoc(doc(as('vendor'), `${E}/chatSummary/current`)));
  await assertFails(getDoc(doc(as('stranger'), `${E}/chatSummary/current`)));
});

test('nobody writes it from the app', async () => {
  await assertFails(setDoc(doc(as('owner'), `${E}/chatSummary/current`), {count: 0}));
});
