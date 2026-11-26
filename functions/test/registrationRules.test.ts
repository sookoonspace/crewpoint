/**
 * Spec #233 Req 4, 4a, 22, TD 1-2 (#242): a family reads its own
 * registration; the status mirrored onto its people is the server's, and a
 * registered person leaves only through `registrations.manage`.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc} from 'firebase/firestore';
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
const PEOPLE: Record<string, [string[], string[]]> = {
  owner: [['owner'], []],
  contact: [['participant'], ['f1']],
  spouse: [['participant'], ['f1']],
  other: [['participant'], ['f2']],
};

beforeEach(async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, E), {
      title: 'Convention', status: 'published', creatorId: 'owner', adminIds: ['owner'],
      memberIds: Object.keys(PEOPLE), skipMemberSync: true,
    });
    for (const [uid, [roleIds, groupIds]] of Object.entries(PEOPLE)) {
      await setDoc(doc(db, `${E}/members/${uid}`), {
        uid, roleIds, crewIds: [], groupIds,
        permissions: computePermissions(roleIds, {}, {editsOwnGroup: groupIds.length > 0}),
      });
    }
    await setDoc(doc(db, `${E}/groups/f1`), {name: 'Patel', sortName: 'patel', adultUids: ['contact', 'spouse']});
    await setDoc(doc(db, `${E}/groups/f2`), {name: 'Shah', sortName: 'shah', adultUids: ['other']});
    await setDoc(doc(db, `${E}/registrations/r1`), {groupId: 'f1', contactUid: 'contact', status: 'submitted'});
    await setDoc(doc(db, `${E}/participants/asha`), {
      name: 'Asha', sortName: 'asha', groupId: 'f1', isChild: false, createdBy: 'contact', status: 'active',
      registrationId: 'r1', registrationStatus: 'submitted',
    });
  });
});

describe('registrations', () => {
  test('the contact and the group\'s linked adults read it; another family does not', async () => {
    await assertSucceeds(getDoc(doc(as('contact'), `${E}/registrations/r1`)));
    await assertSucceeds(getDoc(doc(as('spouse'), `${E}/registrations/r1`)));
    await assertFails(getDoc(doc(as('other'), `${E}/registrations/r1`)));
    await assertFails(getDoc(doc(as('contact'), `${E}/registrations/r1/changes/c1`)));
  });

  test('a family edits its person\'s answers but never the mirrored status', async () => {
    const asha = doc(as('contact'), `${E}/participants/asha`);
    await assertSucceeds(updateDoc(asha, {fields: {}, updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(asha, {registrationStatus: 'cancelled'}));
    await assertFails(updateDoc(asha, {registrationId: 'r9'}));
  });

  test('a family cannot add a person claiming a registration', async () => {
    const add = (extra: object) => setDoc(doc(as('contact'), `${E}/participants/new`), {
      name: 'Dev', sortName: 'dev', groupId: 'f1', isChild: true, status: 'active',
      createdBy: 'contact', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra,
    });
    await assertFails(add({registrationStatus: 'submitted'}));
    await assertFails(add({registrationId: 'r1'}));
    await assertSucceeds(add({}));
  });

  test('a registered person is removed only with registrations.manage', async () => {
    await assertFails(deleteDoc(doc(as('contact'), `${E}/participants/asha`)));
    await assertSucceeds(deleteDoc(doc(as('owner'), `${E}/participants/asha`)));
  });
});
