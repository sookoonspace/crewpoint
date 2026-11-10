/* eslint-disable */
// Acceptance tests for account linking and deleting participant data (#78).
// Test names start with the scenario ID. Runs on the emulators only.
import {getAuth} from 'firebase-admin/auth';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../test/setup';
import {computePermissions} from '../src/events/permissions';

const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {runImportJob} = require('../src/imports/runImport');
const {linkMyParticipants} = require('../src/participants/linkParticipants');
const {deleteUserAccount} = require('../src/account/deleteUserAccount');

const E = 'derod';
const db = () => getAdminDb();
const read = async (path: string) => (await db().doc(path).get()).data();

/** A convention imports three families: two share one email at home. */
async function importConvention() {
  await db().doc(`events/${E}`).set({
    title: 'Convention', status: 'published', creatorId: 'admin', adminIds: ['admin'],
    memberIds: ['admin'], memberCount: 1, dateOnly: true, startDate: new Date('2027-07-16T00:00:00Z'),
    settings: {categories: [{id: 'child', name: 'Child', maxAge: 17, isChild: true}, {id: 'adult', name: 'Adult', minAge: 18}]},
  });
  await db().doc(`events/${E}/members/admin`).set({uid: 'admin', roleIds: ['owner'], permissions: computePermissions(['owner'], {})});
  const csv = [
    'Registration ID,Family,Full name,Age,Email',
    'P1,Patel,Ravi Patel,42,ravi@x.test',
    'P2,Patel,Asha Patel,9,ravi@x.test',
    'S1,Shah,Dev Shah,40,home@x.test',
    'S2,Shah,Nita Shah,38,home@x.test',
    'J1,Joshi,Ila Joshi,35,ila@x.test',
  ].join('\n');
  await db().doc(`events/${E}/imports/j1`).set({
    fileName: 'export.csv', targets: ['externalId', 'group', 'name', 'age', 'email'],
    mode: 'apply', status: 'queued', createdBy: 'admin',
  });
  await runImportJob({eventId: E, jobId: 'j1', readFile: async () => csv, deleteFile: async () => undefined});
  const people = await db().collection(`events/${E}/participants`).get();
  return Object.fromEntries(people.docs.map((d) => [d.data().name, {id: d.id, ...d.data()}])) as Record<string, any>;
}

const signIn = (uid: string, email: string, verified = true) =>
  ftest.wrap(linkMyParticipants)({auth: {uid, token: {email, email_verified: verified}}, data: {}});

async function account(uid: string, name: string) {
  await getAuth().deleteUser(uid).catch(() => undefined);
  await getAuth().createUser({uid});
  await db().doc(`users/${uid}`).set({displayName: name});
}

beforeEach(async () => {
  await clearFirestoreEmulator();
});
afterAll(() => ftest.cleanup());

describe('Convention: linking accounts to the imported roster', () => {
  test('X-05 a person signing in is matched to their own imported family by verified email, never another', async () => {
    const people = await importConvention();
    await account('ravi', 'Ravi Patel');
    // Unverified first: nothing happens.
    await signIn('ravi', 'ravi@x.test', false);
    expect(await read(`events/${E}/members/ravi`)).toBeUndefined();

    await signIn('ravi', 'ravi@x.test');
    const member = (await read(`events/${E}/members/ravi`))!;
    expect(member.roleIds).toEqual(['participant']);
    expect(member.participantId).toBe(people['Ravi Patel'].id);
    expect(member.groupIds).toEqual([people['Ravi Patel'].groupId]);
    // The child sharing his email is never linked to his account.
    expect((await read(`events/${E}/participants/${people['Asha Patel'].id}`))!.uid).toBeUndefined();
    // His access is his own family, not the Shahs or Joshis.
    expect(member.permissions).not.toContain('participants.read');
    expect(member.groupIds).not.toContain(people['Dev Shah'].groupId);
  });

  test('X-05 two adults sharing an email go to an organizer instead', async () => {
    await importConvention();
    await account('dev', 'Dev Shah');
    await expect(signIn('dev', 'home@x.test')).resolves.toEqual({linked: [], asked: [E]});
    expect(await read(`events/${E}/members/dev`)).toBeUndefined();
    expect((await read(`events/${E}/linkRequests/dev`))!.participantIds).toHaveLength(2);
  });

  test('Z-04 deleting a linked account leaves an unnamed entry that still counts, and the person can come back', async () => {
    const people = await importConvention();
    await account('ravi', 'Ravi Patel');
    await signIn('ravi', 'ravi@x.test');
    await ftest.wrap(deleteUserAccount)({auth: {uid: 'ravi'}, data: {}});

    const entry = (await read(`events/${E}/participants/${people['Ravi Patel'].id}`))!;
    expect(entry).toEqual(expect.objectContaining({name: '', anonymised: true, categoryId: 'adult', status: 'active'}));
    expect(JSON.stringify(entry)).not.toMatch(/Ravi|ravi|P1/);
    expect(await read(`events/${E}/participants/${people['Ravi Patel'].id}/private/details`)).toBeUndefined();
    expect(await read(`events/${E}/members/ravi`)).toBeUndefined();
    const adults = await db().collection(`events/${E}/participants`).where('categoryId', '==', 'adult').count().get();
    expect(adults.data().count).toBe(4);

    // He signs up again; then the organizer re-imports. Still one Ravi.
    await account('ravi2', 'Ravi Patel');
    await signIn('ravi2', 'ravi@x.test');
    expect((await read(`events/${E}/participants/${people['Ravi Patel'].id}`))!.uid).toBe('ravi2');
    const again = await db().collection(`events/${E}/participants`).where('categoryId', '==', 'adult').count().get();
    expect(again.data().count).toBe(4);
  }, 60000);
});
