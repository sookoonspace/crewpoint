/**
 * Z-01 (#74, #75, #76, #83): children's data. Only a parent (a linked adult
 * of the child's group) or someone with `participants.edit` enters it, the
 * birth date stays in private details that committee leads and volunteers
 * cannot read, and counts show age bands, never a birth date.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, serverTimestamp, setDoc} from 'firebase/firestore';
import {clearFirestoreEmulator, getAdminDb, getTestEnv} from '../test/setup';
import {computePermissions} from '../src/events/permissions';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const {recalculateEvent} = require('../src/counts/recalculate');

let env: RulesTestEnvironment;
beforeAll(async () => {
  env = await getTestEnv();
});
afterEach(async () => {
  await env.clearFirestore();
  await clearFirestoreEmulator();
});
afterAll(() => env.cleanup());

const E = 'events/conv';
const as = (uid: string) => env.authenticatedContext(uid).firestore();
// uid → [roles, linked groups]
const PEOPLE: Record<string, [string[], string[]]> = {
  owner: [['owner'], []],
  lead: [['crewLead'], []],
  vol: [['volunteer'], []],
  parent: [['participant'], ['f1']],
  other: [['participant'], ['f2']],
};

beforeEach(async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, E), {
      title: 'Convention', status: 'published', creatorId: 'owner', adminIds: ['owner'],
      memberIds: Object.keys(PEOPLE), settings: {attendancePolicy: 'everyone'},
    });
    for (const [uid, [roleIds, groupIds]] of Object.entries(PEOPLE)) {
      await setDoc(doc(db, `${E}/members/${uid}`), {
        uid, roleIds, crewIds: [], groupIds,
        permissions: computePermissions(roleIds, {}, {editsOwnGroup: groupIds.length > 0}),
      });
    }
    for (const g of ['f1', 'f2']) {
      await setDoc(doc(db, `${E}/groups/${g}`), {name: g, sortName: g, adultUids: []});
    }
    await setDoc(doc(db, `${E}/participants/kid`), {
      name: 'Ana', sortName: 'ana', groupId: 'f1', isChild: true, createdBy: 'parent',
      status: 'active', categoryId: 'child', fields: {},
    });
    await setDoc(doc(db, `${E}/participants/kid/private/details`), {birthDate: '2023-05-01'});
  });
});

const child = (createdBy: string, groupId: string) => ({
  name: 'Ravi', sortName: 'ravi', groupId, isChild: true, createdBy,
  status: 'active', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
});

test('Z-01 only a parent, or an organizer who edits people, enters a child', async () => {
  await assertSucceeds(setDoc(doc(as('parent'), `${E}/participants/c1`), child('parent', 'f1')));
  await assertSucceeds(setDoc(doc(as('lead'), `${E}/participants/c2`), child('lead', 'f1')));
  await assertFails(setDoc(doc(as('other'), `${E}/participants/c3`), child('other', 'f1')));
  await assertFails(setDoc(doc(as('vol'), `${E}/participants/c4`), child('vol', 'f1')));
});

test('Z-01 committee leads and volunteers cannot read a child\'s birth date', async () => {
  const details = (uid: string) => getDoc(doc(as(uid), `${E}/participants/kid/private/details`));
  await assertSucceeds(details('parent'));
  await assertFails(details('lead'));
  await assertFails(details('vol'));
  await assertFails(details('other'));
});

test('Z-01 counts show age bands, never a birth date', async () => {
  // The rules environment keeps its own data, so the server's view is seeded here.
  const db = getAdminDb();
  await db.doc(E).set({title: 'Convention', status: 'published', settings: {attendancePolicy: 'everyone'}});
  await db.doc(`${E}/participants/kid`).set({
    name: 'Ana', sortName: 'ana', groupId: 'f1', isChild: true, status: 'active', categoryId: 'child', fields: {},
  });
  await db.doc(`${E}/participants/kid/private/details`).set({birthDate: '2023-05-01'});
  await recalculateEvent(db, 'conv', new Date('2027-07-10T12:00:00Z'));
  const stats = (await db.doc(`${E}/stats/current`).get()).data()!;
  expect(stats.event.byCategory).toEqual({child: 1});
  expect(JSON.stringify(stats)).not.toContain('2023-05-01');
  expect(JSON.stringify(stats)).not.toContain('birthDate');
});
