/**
 * Req 30 (WE-07, WE-10, GAP-WED-32, GAP-ANY-31): one Owner and any number of
 * Co-owners. Ownership goes to anyone in the event who accepts it, the old
 * owner becomes a Co-owner, and it can be returned the same way.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {offerOwnership, acceptOwnership, cancelOwnershipOffer} = require('../../src/events/ownership');
const {removeEventMember} = require('../../src/events/removeEventMember');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const rejected = (code: string) => expect.objectContaining({code});
const member = async (uid: string) =>
  (await getAdminDb().doc(`events/${E}/members/${uid}`).get()).data()!;
const event = async () => (await getAdminDb().doc(`events/${E}`).get()).data()!;
const offer = async () =>
  (await getAdminDb().doc(`events/${E}/ownership/offer`).get()).data();

async function seed(over: object = {}) {
  await getAdminDb().doc(`events/${E}`).set({
    title: 'Wedding',
    status: 'published',
    creatorId: 'olivia',
    organizerId: 'olivia',
    adminIds: ['olivia', 'ana'],
    memberIds: ['olivia', 'ana', 'sam'],
    ...over,
  });
  const seeded: [string, string[]][] = [
    ['olivia', ['owner']], ['ana', ['admin']], ['sam', ['participant', 'scorer']],
  ];
  for (const [uid, roleIds] of seeded) {
    await getAdminDb().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds, crewIds: ['food'], permissions: computePermissions(roleIds, {}),
    });
  }
}

const offerTo = (uid: string, toUid: unknown) =>
  ftest.wrap(offerOwnership)({auth: {uid}, data: {eventId: E, toUid}});
const accept = (uid: string) =>
  ftest.wrap(acceptOwnership)({auth: {uid}, data: {eventId: E}});
const cancel = (uid: string) =>
  ftest.wrap(cancelOwnershipOffer)({auth: {uid}, data: {eventId: E}});

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('offerOwnership', () => {
  test('the Owner offers ownership to anyone in the event, even a Participant', async () => {
    await seed();
    await offerTo('olivia', 'sam');
    expect(await offer()).toEqual(expect.objectContaining({from: 'olivia', to: 'sam'}));
    // Nothing changes until it is accepted.
    expect((await member('olivia')).roleIds).toEqual(['owner']);
    expect((await event()).creatorId).toBe('olivia');
  });

  test('a new offer replaces the old one', async () => {
    await seed();
    await offerTo('olivia', 'sam');
    await offerTo('olivia', 'ana');
    expect((await offer())?.to).toBe('ana');
  });

  test('only the Owner can offer, not a Co-owner or Admin', async () => {
    await seed();
    await getAdminDb().doc(`events/${E}/members/ana`).update({
      roleIds: ['coOwner'], permissions: computePermissions(['coOwner'], {}),
    });
    await expect(offerTo('ana', 'sam')).rejects.toEqual(rejected('permission-denied'));
    await expect(offerTo('sam', 'ana')).rejects.toEqual(rejected('permission-denied'));
    expect(await offer()).toBeUndefined();
  });

  test('the new owner must be someone else in the event', async () => {
    await seed();
    await expect(offerTo('olivia', 'olivia')).rejects.toEqual(rejected('invalid-argument'));
    await expect(offerTo('olivia', 'stranger')).rejects.toEqual(rejected('failed-precondition'));
    await expect(offerTo('olivia', 7)).rejects.toEqual(rejected('invalid-argument'));
  });

  test('an archived or missing event is refused', async () => {
    await seed({status: 'archived'});
    await expect(offerTo('olivia', 'sam')).rejects.toEqual(rejected('failed-precondition'));
    await getAdminDb().doc(`events/${E}`).delete();
    await expect(offerTo('olivia', 'sam')).rejects.toEqual(rejected('not-found'));
  });
});

describe('acceptOwnership', () => {
  test('the new owner takes Owner, and the old owner becomes a Co-owner', async () => {
    await seed();
    await offerTo('olivia', 'sam');
    await accept('sam');

    const sam = await member('sam');
    expect(sam.roleIds).toEqual(['scorer', 'owner']);
    expect(sam.permissions).toEqual(computePermissions(['owner'], {}));
    expect(sam.crewIds).toEqual(['food']);
    const olivia = await member('olivia');
    expect(olivia.roleIds).toEqual(['coOwner']);
    expect(olivia.permissions).not.toContain('event.transfer');

    const after = await event();
    expect(after.creatorId).toBe('sam');
    expect(after.organizerId).toBe('sam');
    expect([...after.adminIds].sort()).toEqual(['ana', 'olivia', 'sam']);
    expect(await offer()).toBeUndefined();
  });

  test('an event always has exactly one Owner', async () => {
    await seed();
    await offerTo('olivia', 'ana');
    await accept('ana');
    const owners = (await getAdminDb().collection(`events/${E}/members`).get()).docs
      .filter((d) => d.data().roleIds.includes('owner'));
    expect(owners.map((d) => d.id)).toEqual(['ana']);
    expect((await member('ana')).roleIds).toEqual(['owner']);
  });

  test('WE-10 ownership can be returned the same way', async () => {
    await seed();
    await offerTo('olivia', 'sam');
    await accept('sam');
    await offerTo('sam', 'olivia');
    await accept('olivia');
    expect((await member('olivia')).roleIds).toEqual(['owner']);
    expect((await member('sam')).roleIds).toEqual(['scorer', 'coOwner']);
    expect((await event()).creatorId).toBe('olivia');
  });

  test('only the person offered can accept', async () => {
    await seed();
    await expect(accept('sam')).rejects.toEqual(rejected('failed-precondition'));
    await offerTo('olivia', 'sam');
    await expect(accept('ana')).rejects.toEqual(rejected('permission-denied'));
    await expect(accept('olivia')).rejects.toEqual(rejected('permission-denied'));
    expect((await member('olivia')).roleIds).toEqual(['owner']);
  });

  test('an offer to someone who has since left cannot be accepted', async () => {
    await seed();
    await offerTo('olivia', 'sam');
    await ftest.wrap(removeEventMember)({auth: {uid: 'sam'}, data: {eventId: E, targetUserId: 'sam'}});
    await expect(accept('sam')).rejects.toEqual(rejected('failed-precondition'));
    expect((await event()).creatorId).toBe('olivia');
  });

  test('once transferred, the old owner can leave (Req 17)', async () => {
    await seed();
    await offerTo('olivia', 'sam');
    await accept('sam');
    await ftest.wrap(removeEventMember)({auth: {uid: 'olivia'}, data: {eventId: E, targetUserId: 'olivia'}});
    expect((await event()).memberIds).toEqual(['ana', 'sam']);
  });
});

describe('cancelOwnershipOffer', () => {
  test('the Owner can withdraw it, and the person offered can decline it', async () => {
    await seed();
    await offerTo('olivia', 'sam');
    await cancel('olivia');
    expect(await offer()).toBeUndefined();
    await offerTo('olivia', 'sam');
    await cancel('sam');
    expect(await offer()).toBeUndefined();
    expect((await member('olivia')).roleIds).toEqual(['owner']);
  });

  test('nobody else can cancel it, and cancelling nothing is fine', async () => {
    await seed();
    await cancel('olivia');
    await offerTo('olivia', 'sam');
    await expect(cancel('ana')).rejects.toEqual(rejected('permission-denied'));
    expect((await offer())?.to).toBe('sam');
  });
});
