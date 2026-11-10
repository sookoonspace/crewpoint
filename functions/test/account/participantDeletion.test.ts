/**
 * Req 14a (Z-04), decided in #78: deleting an account removes that person's
 * member documents and their own private documents. Their participant record
 * stays as an unnamed entry, because deleting an account does not mean they
 * stop attending: age band, status, group and choice answers only. In an
 * event that has not ended it keeps a server-only match key, so a new account
 * with the same verified email links back to it. A past event keeps counts
 * only. Children they entered in their own group go with them, unless another
 * linked adult remains.
 */
import {getAuth} from 'firebase-admin/auth';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {deleteUserAccount} = require('../../src/account/deleteUserAccount');
const {linkMyParticipants} = require('../../src/participants/linkParticipants');
const {emailMatchKey, externalIdMatchKey} = require('../../src/participants/matchKeys');
/* eslint-enable @typescript-eslint/no-var-requires */

const db = () => getAdminDb();
const read = async (path: string) => (await db().doc(path).get()).data();
const UPCOMING = 'events/conv26';
const PAST = 'events/conv25';

async function event(path: string, status: string, members: [string, string[], string[]][]) {
  await db().doc(path).set({
    title: path, status, creatorId: 'owner', adminIds: ['owner'],
    memberIds: members.map(([u]) => u), memberCount: members.length,
  });
  for (const [uid, roleIds, groupIds] of members) {
    await db().doc(`${path}/members/${uid}`).set({
      uid, roleIds, crewIds: [], groupIds, participantId: uid === 'ravi' ? 'pRavi' : null,
      permissions: computePermissions(roleIds, {}, {editsOwnGroup: groupIds.length > 0}),
    });
  }
}

async function person(path: string, id: string, data: object, details?: object) {
  await db().doc(`${path}/participants/${id}`).set({
    sortName: 'x', groupId: 'f1', isChild: false, status: 'active', createdBy: 'owner', ...data,
  });
  if (details) await db().doc(`${path}/participants/${id}/private/details`).set(details);
}

async function seed(path: string, status: string, {otherAdult = false} = {}) {
  await event(path, status, [
    ['owner', ['owner'], []],
    ['ravi', ['participant'], ['f1']],
    ...(otherAdult ? [['mira', ['participant'], ['f1']] as [string, string[], string[]]] : []),
  ]);
  await db().doc(`${path}/groups/f1`).set({
    name: 'Patel', sortName: 'patel', adultUids: otherAdult ? ['ravi', 'mira'] : ['ravi'],
  });
  await db().doc(`${path}/groups/f2`).set({name: 'Shah', sortName: 'shah', adultUids: []});
  await person(path, 'pRavi', {
    name: 'Ravi Patel', sortName: 'ravi patel', uid: 'ravi', externalId: 'P1', imported: true,
    categoryId: 'adult', fields: {diet: 'Jain', note: 'Room 12'}, filterTags: ['diet=Jain'],
  }, {email: 'ravi@x.test', birthDate: '1984-02-01', fields: {allergy: 'Nuts'}});
  // A child Ravi added himself, one the organizer imported, and one Ravi
  // typed in for another family.
  await person(path, 'kid', {name: 'Asha Patel', isChild: true, createdBy: 'ravi'}, {birthDate: '2015-01-01'});
  await person(path, 'importedKid', {name: 'Dev Patel', isChild: true, createdBy: 'ravi', imported: true});
  await person(path, 'shahKid', {name: 'Ana Shah', isChild: true, createdBy: 'ravi', groupId: 'f2'});
  await db().doc(`${path}/linkRequests/ravi`).set({uid: 'ravi', status: 'open'});
}

async function account(uid: string) {
  await getAuth().deleteUser(uid).catch(() => undefined);
  await getAuth().createUser({uid});
  await db().doc(`users/${uid}`).set({displayName: 'Ravi Patel'});
}
const remove = (uid: string) => ftest.wrap(deleteUserAccount)({auth: {uid}, data: {}});

beforeEach(async () => {
  await clearFirestoreEmulator();
  await account('ravi');
});
afterAll(() => ftest.cleanup());

describe('deleting a linked account', () => {
  test('Z-04 an upcoming event keeps an unnamed entry with a match key', async () => {
    await seed(UPCOMING, 'published');
    await remove('ravi');
    const entry = (await read(`${UPCOMING}/participants/pRavi`))!;
    expect(entry).toEqual({
      name: '', sortName: '', anonymised: true, groupId: 'f1', isChild: false,
      status: 'active', categoryId: 'adult', filterTags: ['diet=Jain'], imported: true,
      createdBy: 'owner', updatedAt: expect.anything(),
    });
    expect(await read(`${UPCOMING}/participants/pRavi/private/details`)).toBeUndefined();
    expect(await read(`${UPCOMING}/participantKeys/pRavi`)).toEqual({
      emailKey: await emailMatchKey('ravi@x.test'),
      externalIdKey: await externalIdMatchKey('conv26', 'P1'),
    });
    expect(await read(`${UPCOMING}/members/ravi`)).toBeUndefined();
    expect((await read(`${UPCOMING}/groups/f1`))!.adultUids).toEqual([]);
    expect(await read(`${UPCOMING}/linkRequests/ravi`)).toBeUndefined();
  });

  test('Z-04 a past event keeps anonymous counts only, with no key', async () => {
    await seed(PAST, 'ended');
    await remove('ravi');
    const entry = (await read(`${PAST}/participants/pRavi`))!;
    expect(entry.name).toBe('');
    expect(entry.categoryId).toBe('adult');
    expect(entry.uid).toBeUndefined();
    expect(entry.externalId).toBeUndefined();
    expect(await read(`${PAST}/participantKeys/pRavi`)).toBeUndefined();
    expect(await read(`${PAST}/participants/pRavi/private/details`)).toBeUndefined();
  });

  test('children he entered in his own group go with him; imported ones and other groups stay', async () => {
    await seed(UPCOMING, 'published');
    await remove('ravi');
    expect(await read(`${UPCOMING}/participants/kid`)).toBeUndefined();
    expect(await read(`${UPCOMING}/participants/kid/private/details`)).toBeUndefined();
    expect(await read(`${UPCOMING}/participants/importedKid`)).toBeDefined();
    expect(await read(`${UPCOMING}/participants/shahKid`)).toBeDefined();
  });

  test('another linked adult in the group keeps the children', async () => {
    await seed(UPCOMING, 'published', {otherAdult: true});
    await remove('ravi');
    expect(await read(`${UPCOMING}/participants/kid`)).toBeDefined();
    expect((await read(`${UPCOMING}/groups/f1`))!.adultUids).toEqual(['mira']);
  });

  test('a member document the arrays missed is removed too', async () => {
    await db().doc('events/stray').set({title: 'Stray', memberIds: ['owner'], creatorId: 'owner'});
    await db().doc('events/stray/members/ravi').set({uid: 'ravi', roleIds: ['participant']});
    await remove('ravi');
    expect(await read('events/stray/members/ravi')).toBeUndefined();
  });

  test('X-05 a new account with the same verified email links back, with no duplicate', async () => {
    await seed(UPCOMING, 'published');
    await remove('ravi');
    await account('ravi2');
    await ftest.wrap(linkMyParticipants)({
      auth: {uid: 'ravi2', token: {email: 'ravi@x.test', email_verified: true}}, data: {},
    });
    const back = (await read(`${UPCOMING}/participants/pRavi`))!;
    expect(back).toEqual(expect.objectContaining({uid: 'ravi2', name: 'Ravi Patel'}));
    expect(back.anonymised).toBeUndefined();
    const all = await db().collection(`${UPCOMING}/participants`).where('categoryId', '==', 'adult').get();
    expect(all.size).toBe(1);
  });
});
