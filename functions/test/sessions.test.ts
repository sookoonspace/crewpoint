/**
 * Req 48 (A-02, GAP-WED-12): an event's schedule. `schedule.edit` writes
 * sessions, and every member reads the ones that are not hidden. A hidden
 * session is a draft only editors see, so anyone else lists with
 * `hidden == false`. Module-off and status rules apply as for tasks.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {
  Timestamp, collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where,
} from 'firebase/firestore';
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
const ROLES: Record<string, string[]> = {
  owner: ['owner'],
  lead: ['crewLead'],
  plain: ['participant'],
  observer: ['observer'],
  vendor: ['vendor'],
};

const seed = (event: object = {}) => env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, E), {
    title: 'Convention', status: 'published', creatorId: 'owner', adminIds: ['owner'],
    memberIds: Object.keys(ROLES), skipMemberSync: true, ...event,
  });
  for (const [uid, roleIds] of Object.entries(ROLES)) {
    await setDoc(doc(db, `${E}/members/${uid}`), {
      uid, roleIds, crewIds: [], permissions: computePermissions(roleIds, {}),
    });
  }
  await setDoc(doc(db, `${E}/sessions/m1`), session());
  await setDoc(doc(db, `${E}/sessions/draft`), session({title: 'Gala', hidden: true}));
});

const at = (iso: string) => Timestamp.fromDate(new Date(iso));

function session(over: object = {}) {
  return {
    title: 'Welcome dinner',
    startAt: at('2027-07-17T00:00:00Z'),
    endAt: at('2027-07-17T02:00:00Z'),
    timeTbc: true,
    venueId: 'garland',
    locationTba: false,
    type: 'Dinner',
    tags: ['outdoor'],
    capacity: 400,
    eligibility: {categoryIds: [], filterTags: []},
    hidden: false,
    updatedBy: 'owner',
    updatedAt: serverTimestamp(),
    ...over,
  };
}

const visible = (uid: string) =>
  query(collection(as(uid), `${E}/sessions`), where('hidden', '==', false));

describe('reading', () => {
  beforeEach(() => seed());

  test('every member reads the visible schedule, Observers and Vendors included', async () => {
    for (const uid of Object.keys(ROLES)) {
      await assertSucceeds(getDocs(visible(uid)));
      await assertSucceeds(getDoc(doc(as(uid), `${E}/sessions/m1`)));
    }
    await assertFails(getDocs(visible('stranger')));
    await assertFails(getDoc(doc(as('stranger'), `${E}/sessions/m1`)));
  });

  test('a hidden session is seen only with schedule.edit', async () => {
    await assertSucceeds(getDoc(doc(as('lead'), `${E}/sessions/draft`)));
    await assertSucceeds(getDocs(collection(as('owner'), `${E}/sessions`)));
    await assertFails(getDoc(doc(as('plain'), `${E}/sessions/draft`)));
    await assertFails(getDocs(collection(as('plain'), `${E}/sessions`)));
  });
});

describe('writing', () => {
  beforeEach(() => seed());
  const write = (uid: string, over: object = {}) =>
    setDoc(doc(as(uid), `${E}/sessions/new`), session({updatedBy: uid, ...over}));

  test('only schedule.edit adds, edits and removes sessions', async () => {
    await assertSucceeds(write('owner'));
    await assertSucceeds(write('lead'));
    for (const uid of ['plain', 'observer', 'vendor']) {
      await assertFails(write(uid));
      await assertFails(updateDoc(doc(as(uid), `${E}/sessions/m1`), {title: 'Mine'}));
      await assertFails(deleteDoc(doc(as(uid), `${E}/sessions/m1`)));
    }
    await assertSucceeds(updateDoc(doc(as('lead'), `${E}/sessions/m1`), {
      startAt: at('2027-07-17T00:30:00Z'), timeTbc: false, updatedBy: 'lead', updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(deleteDoc(doc(as('lead'), `${E}/sessions/m1`)));
  });

  test('a session may leave out its end, venue, type and capacity', async () => {
    await assertSucceeds(write('owner', {endAt: null, venueId: null, locationTba: true, type: null, capacity: null}));
  });

  test('a session must be well formed', async () => {
    await assertFails(write('owner', {title: ''}));
    await assertFails(write('owner', {title: 'x'.repeat(121)}));
    await assertFails(write('owner', {startAt: '7pm'}));
    await assertFails(write('owner', {endAt: at('2027-07-16T23:00:00Z')}));
    await assertFails(write('owner', {timeTbc: 'yes'}));
    await assertFails(write('owner', {locationTba: null}));
    await assertFails(write('owner', {venueId: 7}));
    await assertFails(write('owner', {type: 'x'.repeat(41)}));
    await assertFails(write('owner', {tags: Array.from({length: 21}, (_, i) => `t${i}`)}));
    await assertFails(write('owner', {capacity: 0}));
    await assertFails(write('owner', {capacity: 1.5}));
    await assertFails(write('owner', {eligibility: ['child']}));
    await assertFails(write('owner', {eligibility: {categoryIds: 'child', filterTags: []}}));
    await assertFails(write('owner', {hidden: null}));
    await assertFails(write('owner', {updatedBy: 'lead'}));
    await assertFails(write('owner', {updatedAt: at('2020-01-01T00:00:00Z')}));
    await assertFails(write('owner', {secret: true}));
  });
});

describe('module and status', () => {
  const edit = (uid: string) => updateDoc(doc(as(uid), `${E}/sessions/m1`), {
    title: 'Moved', updatedBy: uid, updatedAt: serverTimestamp(),
  });

  test('with the schedule turned off, writes stop and the sessions stay', async () => {
    await seed({modules: {schedule: false}});
    await assertFails(edit('owner'));
    await assertFails(deleteDoc(doc(as('owner'), `${E}/sessions/m1`)));
    await assertSucceeds(getDocs(visible('plain')));
  });

  test('once ended, only event.manage edits the schedule', async () => {
    await seed({status: 'ended'});
    await assertFails(edit('lead'));
    await assertSucceeds(edit('owner'));
  });

  test('an archived schedule is read-only for everyone', async () => {
    await seed({status: 'archived'});
    await assertFails(edit('owner'));
    await assertSucceeds(getDocs(visible('plain')));
  });
});
