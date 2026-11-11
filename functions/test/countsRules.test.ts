/**
 * Req 52: counts need `counts.read`, and only the server writes them or its
 * queue.
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

const E = 'events/conv';
const as = (uid: string) => env.authenticatedContext(uid).firestore();
const ROLES: Record<string, string[]> = {owner: ['owner'], lead: ['crewLead'], plain: ['participant'], vendor: ['vendor']};

beforeEach(() => env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, E), {title: 'C', status: 'published', creatorId: 'owner', adminIds: ['owner'], memberIds: Object.keys(ROLES), skipMemberSync: true});
  for (const [uid, roleIds] of Object.entries(ROLES)) {
    await setDoc(doc(db, `${E}/members/${uid}`), {uid, roleIds, crewIds: [], permissions: computePermissions(roleIds, {})});
  }
  await setDoc(doc(db, `${E}/stats/current`), {event: {total: 26}});
  await setDoc(doc(db, 'countsQueue/conv'), {eventId: 'conv'});
}));

test('counts.read reads the counts', async () => {
  await assertSucceeds(getDoc(doc(as('owner'), `${E}/stats/current`)));
  await assertSucceeds(getDoc(doc(as('lead'), `${E}/stats/current`)));
  await assertFails(getDoc(doc(as('plain'), `${E}/stats/current`)));
  await assertFails(getDoc(doc(as('vendor'), `${E}/stats/current`)));
});

test('nobody writes counts or the queue from the app', async () => {
  await assertFails(setDoc(doc(as('owner'), `${E}/stats/current`), {event: {total: 1}}));
  await assertFails(getDoc(doc(as('owner'), 'countsQueue/conv')));
  await assertFails(setDoc(doc(as('owner'), 'countsQueue/conv'), {eventId: 'conv'}));
});
