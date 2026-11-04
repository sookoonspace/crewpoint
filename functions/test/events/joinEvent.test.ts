/**
 * Req 12, 55 (FND-06, S-01): `memberLimit` caps how many people can log in. It is
 * optional and off by default, and simultaneous joins cannot exceed it.
 */
import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
/* eslint-disable @typescript-eslint/no-var-requires */
const {joinEvent} = require('../../src/events/joinEvent');
const {removeEventMember} = require('../../src/events/removeEventMember');
const {deleteUserAccount} = require('../../src/account/deleteUserAccount');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const CODE = 'ABC234';
const join = (uid: string) =>
  ftest.wrap(joinEvent)({auth: {uid}, data: {joinCode: CODE}});
const event = () => getAdminDb().doc(`events/${E}`).get();

async function seed(over: object = {}, members = ['owner']) {
  await getAdminDb().doc(`events/${E}`).set({
    title: 'Trip',
    creatorId: 'owner',
    adminIds: ['owner'],
    memberIds: members,
    memberCount: members.length,
    ...over,
  });
  await getAdminDb().doc(`event_invites/${CODE}`).set({
    eventId: E,
    expiresAt: Timestamp.fromDate(new Date(Date.now() + 86400000)),
  });
}

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('joinEvent and memberLimit', () => {
  test('joining adds the person and updates memberCount', async () => {
    await seed();
    await join('a');
    const saved = (await event()).data()!;
    expect(saved.memberIds).toEqual(['owner', 'a']);
    expect(saved.memberCount).toBe(2);
  });

  test('with no memberLimit there is no cap, including past 50', async () => {
    const members = Array.from({length: 60}, (_, i) => `u${i}`);
    await seed({}, members);
    await join('new');
    expect((await event()).data()!.memberCount).toBe(61);
  });

  test('a join is allowed up to memberLimit', async () => {
    await seed({memberLimit: 2});
    await join('a');
    expect((await event()).data()!.memberCount).toBe(2);
  });

  test('a join past memberLimit is refused', async () => {
    await seed({memberLimit: 1});
    await expect(join('a')).rejects.toMatchObject({code: 'resource-exhausted'});
    const saved = (await event()).data()!;
    expect(saved.memberIds).toEqual(['owner']);
    expect(saved.memberCount).toBe(1);
  });

  test('8 simultaneous joins at one place remaining admit exactly 1', async () => {
    await seed({memberLimit: 2});
    const results = await Promise.allSettled(
      Array.from({length: 8}, (_, i) => join(`joiner${i}`))
    );
    const admitted = results.filter((r) => r.status === 'fulfilled');
    const refused = results.filter((r) => r.status === 'rejected') as PromiseRejectedResult[];
    expect(admitted).toHaveLength(1);
    expect(refused).toHaveLength(7);
    for (const r of refused) expect(r.reason.code).toBe('resource-exhausted');
    const saved = (await event()).data()!;
    expect(saved.memberIds).toHaveLength(2);
    expect(saved.memberCount).toBe(2);
  });

  test('simultaneous joins with no limit all count', async () => {
    await seed();
    await Promise.all(Array.from({length: 8}, (_, i) => join(`joiner${i}`)));
    const saved = (await event()).data()!;
    expect(saved.memberIds).toHaveLength(9);
    expect(saved.memberCount).toBe(9);
  });

  test('an event from before memberCount gets a correct count on join', async () => {
    await seed({}, ['owner', 'a']);
    await getAdminDb().doc(`events/${E}`).update({memberCount: FieldValue.delete()});
    await join('b');
    expect((await event()).data()!.memberCount).toBe(3);
  });

  test('joining twice is refused and does not change the count', async () => {
    await seed();
    await join('a');
    await expect(join('a')).rejects.toMatchObject({code: 'already-exists'});
    expect((await event()).data()!.memberCount).toBe(2);
  });

  test('removing someone frees a place', async () => {
    await seed({memberLimit: 2}, ['owner', 'a']);
    await ftest.wrap(removeEventMember)({
      auth: {uid: 'owner'},
      data: {eventId: E, targetUserId: 'a'},
    });
    expect((await event()).data()!.memberCount).toBe(1);
    // Removing someone rotates the code, so this joins with a new one.
    await seed({memberLimit: 2}, ['owner']);
    await join('b');
    expect((await event()).data()!.memberIds).toEqual(['owner', 'b']);
  });

  test('deleting an account updates the count', async () => {
    await seed({}, ['owner', 'gone']);
    const {getAuth} = require('firebase-admin/auth'); // eslint-disable-line
    await getAuth().createUser({uid: 'gone'}).catch(() => undefined);
    await ftest.wrap(deleteUserAccount)({auth: {uid: 'gone'}, data: {}});
    expect((await event()).data()!.memberCount).toBe(1);
  });
});

describe('removeEventMember and who may remove whom', () => {
  const remove = (uid: string, targetUserId: string) =>
    ftest.wrap(removeEventMember)({auth: {uid}, data: {eventId: E, targetUserId}});
  const members = () => event().then((e) => e.data()!.memberIds);

  beforeEach(() =>
    seed({adminIds: ['owner', 'admin', 'admin2']}, ['owner', 'admin', 'admin2', 'member', 'other'])
  );

  test('an admin can remove a member', async () => {
    await remove('admin', 'member');
    expect(await members()).not.toContain('member');
  });

  test('an admin cannot remove another admin', async () => {
    await expect(remove('admin', 'admin2')).rejects.toMatchObject({code: 'permission-denied'});
    expect(await members()).toContain('admin2');
  });

  test('the owner can remove an admin', async () => {
    await remove('owner', 'admin');
    expect(await members()).not.toContain('admin');
  });

  test('an admin can still leave', async () => {
    await remove('admin', 'admin');
    expect(await members()).not.toContain('admin');
  });

  test('a member cannot remove anyone', async () => {
    await expect(remove('member', 'other')).rejects.toMatchObject({code: 'permission-denied'});
    await expect(remove('member', 'admin')).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('nobody can remove the owner', async () => {
    await expect(remove('admin', 'owner')).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('an owner cannot leave without transferring ownership', async () => {
    await expect(remove('owner', 'owner')).rejects.toMatchObject({code: 'failed-precondition'});
    expect(await members()).toContain('owner');
  });
});
