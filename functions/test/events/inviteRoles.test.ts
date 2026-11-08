/**
 * Req 31 (GAP-ANY-33): an event has one active invite, which carries a role
 * applied on join.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {generateInviteCode} = require('../../src/events/generateInviteCode');
const {joinEvent} = require('../../src/events/joinEvent');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const rejected = (code: string) => expect.objectContaining({code});
const member = async (uid: string) =>
  (await getAdminDb().doc(`events/${E}/members/${uid}`).get()).data();
const event = async () => (await getAdminDb().doc(`events/${E}`).get()).data()!;
const invites = async () =>
  (await getAdminDb().collection('event_invites').where('eventId', '==', E).get()).docs;

async function seed() {
  await getAdminDb().doc(`events/${E}`).set({
    title: 'Convention',
    status: 'published',
    creatorId: 'owner',
    adminIds: ['owner', 'admin'],
    memberIds: ['owner', 'admin'],
    memberCount: 2,
  });
  for (const [uid, roleIds] of [['owner', ['owner']], ['admin', ['admin']]] as const) {
    await getAdminDb().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds, crewIds: [], permissions: computePermissions(roleIds, {}),
    });
  }
}

const invite = (uid: string, data: object = {}) =>
  ftest.wrap(generateInviteCode)({auth: {uid}, data: {eventId: E, ...data}});
const join = (uid: string, code: string) =>
  ftest.wrap(joinEvent)({auth: {uid}, data: {joinCode: code}});

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('an invite carries a role', () => {
  test('with no role given, the invite is for Participant', async () => {
    await seed();
    const result = await invite('owner');
    expect(result.roleId).toBe('participant');
    await join('newcomer', result.code);
    expect((await member('newcomer'))?.roleIds).toEqual(['participant']);
  });

  test('an owner invites someone straight into a role, with no promotion after', async () => {
    await seed();
    const {code, roleId} = await invite('owner', {roleId: 'crewLead'});
    expect(roleId).toBe('crewLead');
    await join('speaker', code);
    const saved = await member('speaker');
    expect(saved?.roleIds).toEqual(['crewLead']);
    expect(saved?.permissions).toEqual(computePermissions(['crewLead'], {}, {readsAllExpenses: true}));
    expect((await event()).adminIds).toEqual(['owner', 'admin']);
  });

  test('joining into an admin-level role keeps adminIds in step', async () => {
    await seed();
    const {code} = await invite('owner', {roleId: 'coOwner'});
    await join('partner', code);
    expect((await event()).adminIds).toEqual(['owner', 'admin', 'partner']);
  });

  test('a custom role can be the invite role, and uses the event version', async () => {
    await seed();
    await getAdminDb().doc(`events/${E}/roles/hospitality`).set({
      name: 'Hospitality', permissions: ['participants.read'], preset: false,
    });
    const {code} = await invite('owner', {roleId: 'hospitality'});
    await join('host', code);
    expect((await member('host'))?.permissions).toEqual(['participants.read', 'expenses.readAll']);
  });

  test('a role removed since the invite was made falls back to Participant', async () => {
    await seed();
    await getAdminDb().doc(`events/${E}/roles/temp`).set({name: 'Temp', permissions: ['counts.read']});
    const {code} = await invite('owner', {roleId: 'temp'});
    await getAdminDb().doc(`events/${E}/roles/temp`).delete();
    await join('late', code);
    expect((await member('late'))?.roleIds).toEqual(['participant']);
  });

  test('an invite from before roles counts as Participant', async () => {
    await seed();
    await getAdminDb().doc('event_invites/OLD234').set({
      eventId: E, expiresAt: Timestamp.fromDate(new Date(Date.now() + 86400000)),
    });
    await join('old', 'OLD234');
    expect((await member('old'))?.roleIds).toEqual(['participant']);
  });
});

describe('one active invite per event', () => {
  test('asking again with no role returns the active invite and its role', async () => {
    await seed();
    const first = await invite('owner', {roleId: 'volunteer'});
    const again = await invite('owner');
    expect(again).toEqual({code: first.code, roleId: 'volunteer'});
    expect(await invites()).toHaveLength(1);
  });

  test('asking for the same role keeps the code', async () => {
    await seed();
    const first = await invite('owner', {roleId: 'volunteer'});
    expect((await invite('owner', {roleId: 'volunteer'})).code).toBe(first.code);
  });

  test('changing the role replaces the invite, so the old code stops working', async () => {
    await seed();
    const first = await invite('owner', {roleId: 'coOwner'});
    const second = await invite('owner', {roleId: 'participant'});
    expect(second.code).not.toBe(first.code);
    expect(second.roleId).toBe('participant');
    expect((await invites()).map((d) => d.id)).toEqual([second.code]);
    await expect(join('late', first.code)).rejects.toEqual(rejected('not-found'));
  });

  test('rotating keeps the role and changes the code', async () => {
    await seed();
    const first = await invite('owner', {roleId: 'scorer'});
    const rotated = await invite('owner', {rotate: true});
    expect(rotated.code).not.toBe(first.code);
    expect(rotated.roleId).toBe('scorer');
    expect(await invites()).toHaveLength(1);
  });
});

describe('who may invite into which role', () => {
  test('an Admin can invite Participants but not into other roles', async () => {
    await seed();
    expect((await invite('admin')).roleId).toBe('participant');
    await expect(invite('admin', {roleId: 'finance'})).rejects.toEqual(rejected('permission-denied'));
  });

  test('an Admin cannot be handed an active invite into another role', async () => {
    await seed();
    await invite('owner', {roleId: 'coOwner'});
    await expect(invite('admin')).rejects.toEqual(rejected('permission-denied'));
    await expect(invite('admin', {rotate: true})).rejects.toEqual(rejected('permission-denied'));
  });

  test('nobody invites into Owner, and unknown roles are refused', async () => {
    await seed();
    await expect(invite('owner', {roleId: 'owner'})).rejects.toEqual(rejected('failed-precondition'));
    await expect(invite('owner', {roleId: 'nope'})).rejects.toEqual(rejected('invalid-argument'));
    await expect(invite('owner', {roleId: 7})).rejects.toEqual(rejected('invalid-argument'));
    expect(await invites()).toHaveLength(0);
  });
});
