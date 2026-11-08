/**
 * Req 37 (H-05): names and payment handles are copied from `users/{uid}` into
 * `events/{eventId}/profiles/{uid}` for each event the person is in, so only
 * people who share an event see their handles. Leaving keeps the name, so
 * older messages still show who wrote them, and drops the handles.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

getAdminApp();
// eslint-disable-next-line @typescript-eslint/no-var-requires
const {handleMemberWritten, handleUserWritten, profileFrom} = require('../../src/events/profiles');

const db = () => getAdminDb();
const profile = async (e: string, uid: string) =>
  (await db().doc(`events/${e}/profiles/${uid}`).get()).data();
const PAT = {
  displayName: 'Pat', photoUrl: 'p.jpg', paymentMethod: 'venmo', paymentHandle: '@pat',
  venmoHandle: 'pat', cashappHandle: '$pat', currency: 'USD',
};

beforeEach(() => clearFirestoreEmulator());

test('a profile holds only the name, photo and payment handles', () => {
  expect(profileFrom('pat', PAT)).toEqual({
    uid: 'pat', displayName: 'Pat', photoUrl: 'p.jpg', paymentMethod: 'venmo',
    paymentHandle: '@pat', venmoHandle: 'pat', cashappHandle: '$pat',
  });
  expect(profileFrom('pat', undefined)).toEqual({
    uid: 'pat', displayName: null, photoUrl: null, paymentMethod: null,
    paymentHandle: null, venmoHandle: null, cashappHandle: null,
  });
});

test('joining copies the person into the event', async () => {
  await db().doc('users/pat').set(PAT);
  await handleMemberWritten({eventId: 'e1', uid: 'pat', before: undefined, after: {uid: 'pat'}});
  expect(await profile('e1', 'pat')).toEqual(profileFrom('pat', PAT));
});

test('a role change leaves the profile alone', async () => {
  await db().doc('users/pat').set(PAT);
  await db().doc('events/e1/profiles/pat').set({uid: 'pat', displayName: 'Old'});
  await handleMemberWritten({eventId: 'e1', uid: 'pat', before: {uid: 'pat'}, after: {uid: 'pat', roleIds: ['admin']}});
  expect((await profile('e1', 'pat'))?.displayName).toBe('Old');
});

test('leaving keeps the name and drops the handles', async () => {
  await db().doc('events/e1/profiles/pat').set(profileFrom('pat', PAT));
  await handleMemberWritten({eventId: 'e1', uid: 'pat', before: {uid: 'pat'}, after: undefined});
  expect(await profile('e1', 'pat')).toEqual({uid: 'pat', displayName: 'Pat', photoUrl: 'p.jpg'});
});

test('leaving after the profile is gone writes nothing', async () => {
  await handleMemberWritten({eventId: 'e1', uid: 'pat', before: {uid: 'pat'}, after: undefined});
  expect(await profile('e1', 'pat')).toBeUndefined();
});

describe('editing your profile', () => {
  beforeEach(async () => {
    for (const e of ['e1', 'e2']) {
      await db().doc(`events/${e}/members/pat`).set({uid: 'pat', roleIds: ['participant']});
      await db().doc(`events/${e}/profiles/pat`).set(profileFrom('pat', PAT));
    }
    // Left e3 earlier: the name stays, and new handles must not reach it.
    await db().doc('events/e3/profiles/pat').set({uid: 'pat', displayName: 'Pat'});
  });

  test('reaches every event you are in, and no other', async () => {
    const after = {...PAT, displayName: 'Patricia', venmoHandle: 'patricia'};
    await handleUserWritten({uid: 'pat', before: PAT, after});
    for (const e of ['e1', 'e2']) {
      expect(await profile(e, 'pat')).toEqual(profileFrom('pat', after));
    }
    expect(await profile('e3', 'pat')).toEqual({uid: 'pat', displayName: 'Pat'});
  });

  test('a change outside the profile fields writes nothing', async () => {
    await db().doc('events/e1/profiles/pat').set({uid: 'pat', displayName: 'Stale'});
    await handleUserWritten({uid: 'pat', before: PAT, after: {...PAT, currency: 'CAD'}});
    expect((await profile('e1', 'pat'))?.displayName).toBe('Stale');
  });

  test('a deleted account is left to deleteUserAccount', async () => {
    await handleUserWritten({uid: 'pat', before: PAT, after: undefined});
    expect((await profile('e1', 'pat'))?.venmoHandle).toBe('pat');
  });
});
