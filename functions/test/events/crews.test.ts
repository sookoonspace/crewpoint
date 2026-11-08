/**
 * Req 33 (Crews), 72 (H-02): organizers create crews and assign members, and
 * `crewIds` on the member document is written only by server code.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {saveCrew, deleteCrew, setCrewMembers} = require('../../src/events/crews');
const {setMemberRoles} = require('../../src/events/roles');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const rejected = (code: string) => expect.objectContaining({code});
const member = async (uid: string) =>
  (await getAdminDb().doc(`events/${E}/members/${uid}`).get()).data()!;
const crew = async (id: string) =>
  (await getAdminDb().doc(`events/${E}/crews/${id}`).get()).data();

async function seed(over: object = {}) {
  await getAdminDb().doc(`events/${E}`).set({
    title: 'Convention',
    status: 'published',
    creatorId: 'owner',
    adminIds: ['owner', 'admin'],
    memberIds: ['owner', 'admin', 'lead', 'm'],
    ...over,
  });
  const seeded: [string, string[]][] = [
    ['owner', ['owner']], ['admin', ['admin']], ['lead', ['crewLead']], ['m', ['participant']],
  ];
  for (const [uid, roleIds] of seeded) {
    await getAdminDb().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds, crewIds: [], permissions: computePermissions(roleIds, {}),
    });
  }
}

const save = (uid: string, data: object) =>
  ftest.wrap(saveCrew)({auth: {uid}, data: {eventId: E, ...data}});
const remove = (uid: string, crewId: unknown) =>
  ftest.wrap(deleteCrew)({auth: {uid}, data: {eventId: E, crewId}});
const assign = (uid: string, crewId: string, uids: unknown) =>
  ftest.wrap(setCrewMembers)({auth: {uid}, data: {eventId: E, crewId, uids}});

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('saveCrew', () => {
  test('an Admin creates a crew and can rename it', async () => {
    await seed();
    await save('admin', {crewId: 'food', name: '  Food team '});
    expect(await crew('food')).toEqual(expect.objectContaining({name: 'Food team'}));
    await save('admin', {crewId: 'food', name: 'Catering'});
    expect((await crew('food'))?.name).toBe('Catering');
  });

  test('needs members.manage', async () => {
    await seed();
    await expect(save('lead', {crewId: 'food', name: 'Food'})).rejects.toEqual(rejected('permission-denied'));
    await expect(save('m', {crewId: 'food', name: 'Food'})).rejects.toEqual(rejected('permission-denied'));
    expect(await crew('food')).toBeUndefined();
  });

  test('the ID and name must be valid', async () => {
    await seed();
    for (const bad of [
      {crewId: 'a/b', name: 'X'},
      {crewId: 'x', name: ' '},
      {crewId: 'x', name: 'n'.repeat(61)},
      {crewId: 'x', name: 7},
    ]) {
      await expect(save('owner', bad)).rejects.toEqual(rejected('invalid-argument'));
    }
  });

  test('an archived or missing event is refused', async () => {
    await seed({status: 'archived'});
    await expect(save('owner', {crewId: 'x', name: 'X'})).rejects.toEqual(rejected('failed-precondition'));
    await getAdminDb().doc(`events/${E}`).delete();
    await expect(save('owner', {crewId: 'x', name: 'X'})).rejects.toEqual(rejected('not-found'));
  });
});

describe('setCrewMembers', () => {
  test('sets who is in a crew, adding and removing crewIds', async () => {
    await seed();
    await save('owner', {crewId: 'food', name: 'Food'});
    await assign('owner', 'food', ['lead', 'm']);
    expect((await member('lead')).crewIds).toEqual(['food']);
    expect((await member('m')).crewIds).toEqual(['food']);
    await assign('owner', 'food', ['lead']);
    expect((await member('lead')).crewIds).toEqual(['food']);
    expect((await member('m')).crewIds).toEqual([]);
  });

  test('keeps other crews and roles, and permissions stay worked out', async () => {
    await seed();
    await save('owner', {crewId: 'food', name: 'Food'});
    await save('owner', {crewId: 'hotel', name: 'Hotel'});
    await assign('owner', 'hotel', ['lead']);
    await assign('owner', 'food', ['lead']);
    const lead = await member('lead');
    expect([...lead.crewIds].sort()).toEqual(['food', 'hotel']);
    expect(lead.roleIds).toEqual(['crewLead']);
    expect(lead.permissions).toEqual(computePermissions(['crewLead'], {}));
  });

  test('a role change keeps crews', async () => {
    await seed();
    await save('owner', {crewId: 'food', name: 'Food'});
    await assign('owner', 'food', ['m']);
    await ftest.wrap(setMemberRoles)({auth: {uid: 'owner'}, data: {eventId: E, targetUserId: 'm', roleIds: ['volunteer']}});
    expect((await member('m')).crewIds).toEqual(['food']);
  });

  test('the crew must exist, and everyone must be a member', async () => {
    await seed();
    await expect(assign('owner', 'nope', ['m'])).rejects.toEqual(rejected('not-found'));
    await save('owner', {crewId: 'food', name: 'Food'});
    await expect(assign('owner', 'food', ['stranger'])).rejects.toEqual(rejected('failed-precondition'));
    await expect(assign('owner', 'food', 'm')).rejects.toEqual(rejected('invalid-argument'));
    await expect(assign('owner', 'food', ['m', 'm'])).rejects.toEqual(rejected('invalid-argument'));
    expect((await member('m')).crewIds).toEqual([]);
  });

  test('needs members.manage', async () => {
    await seed();
    await save('owner', {crewId: 'food', name: 'Food'});
    await expect(assign('lead', 'food', ['lead'])).rejects.toEqual(rejected('permission-denied'));
  });
});

describe('deleteCrew', () => {
  test('removes the crew from everyone and from its tasks', async () => {
    await seed();
    await save('owner', {crewId: 'food', name: 'Food'});
    await assign('owner', 'food', ['lead', 'm']);
    await getAdminDb().doc(`events/${E}/tasks/t1`).set({title: 'Caterer', eventId: E, crewId: 'food'});
    await getAdminDb().doc(`events/${E}/tasks/t2`).set({title: 'DJ', eventId: E, crewId: 'program'});
    await remove('owner', 'food');
    expect(await crew('food')).toBeUndefined();
    expect((await member('lead')).crewIds).toEqual([]);
    expect((await getAdminDb().doc(`events/${E}/tasks/t1`).get()).data()!.crewId).toBeNull();
    expect((await getAdminDb().doc(`events/${E}/tasks/t2`).get()).data()!.crewId).toBe('program');
  });

  test('needs members.manage', async () => {
    await seed();
    await save('owner', {crewId: 'food', name: 'Food'});
    await expect(remove('m', 'food')).rejects.toEqual(rejected('permission-denied'));
    expect(await crew('food')).toBeDefined();
  });

  test('deleting a crew that is gone changes nothing', async () => {
    await seed();
    await remove('owner', 'gone');
    expect((await member('m')).crewIds).toEqual([]);
  });
});
