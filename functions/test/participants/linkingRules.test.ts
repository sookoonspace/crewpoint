/**
 * Req 46, 14a (X-05): what a linked person may read, and what stays with the
 * server. A linked participant sees their own record and their own group,
 * never another person's. Link requests show an email, so they need
 * `participants.readPrivate`. Match keys and their secret are never read by a
 * client, and only the server marks a record unnamed.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where} from 'firebase/firestore';
import {getTestEnv} from '../setup';
import {computePermissions} from '../../src/events/permissions';

let env: RulesTestEnvironment;
beforeAll(async () => {
  env = await getTestEnv();
});
afterEach(() => env.clearFirestore());
afterAll(() => env.cleanup());

const E = 'events/conv';
const as = (uid: string) => env.authenticatedContext(uid).firestore();
// uid → [roles, linked groups, linked record]
const PEOPLE: Record<string, [string[], string[], string | null]> = {
  owner: [['owner'], [], null],
  lead: [['crewLead'], [], null],
  ravi: [['participant'], ['f1'], 'pRavi'],
  solo: [['participant'], [], 'pSolo'],
};

beforeEach(async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, E), {
      title: 'Convention', status: 'published', creatorId: 'owner', adminIds: ['owner'],
      memberIds: Object.keys(PEOPLE), skipMemberSync: true,
    });
    for (const [uid, [roleIds, groupIds, participantId]] of Object.entries(PEOPLE)) {
      await setDoc(doc(db, `${E}/members/${uid}`), {
        uid, roleIds, crewIds: [], groupIds, participantId,
        permissions: computePermissions(roleIds, {}, {editsOwnGroup: groupIds.length > 0}),
      });
    }
    for (const g of ['f1', 'f2']) {
      await setDoc(doc(db, `${E}/groups/${g}`), {name: g, sortName: g, adultUids: g === 'f1' ? ['ravi'] : []});
    }
    const person = (id: string, groupId: string | null, uid?: string) => setDoc(doc(db, `${E}/participants/${id}`), {
      name: id, sortName: id.toLowerCase(), groupId, isChild: false, createdBy: 'owner', status: 'active',
      ...(uid ? {uid} : {}),
    });
    await person('pRavi', 'f1', 'ravi');
    await person('pSolo', null, 'solo');
    await person('pShah', 'f2');
    await person('pGuest', null);
    for (const id of ['pRavi', 'pSolo', 'pShah', 'pGuest']) {
      await setDoc(doc(db, `${E}/participants/${id}/private/details`), {email: `${id}@x.test`});
    }
    await setDoc(doc(db, `${E}/linkRequests/u9`), {uid: 'u9', email: 'home@x.test', status: 'open'});
    await setDoc(doc(db, `${E}/participantKeys/anon`), {emailKey: 'k'});
    await setDoc(doc(db, 'serverSecrets/participantKeys'), {value: 's'});
    await setDoc(doc(db, `${E}/participants/anon`), {
      name: '', sortName: '', anonymised: true, groupId: null, isChild: false,
      createdBy: 'owner', status: 'active',
    });
  });
});

describe('a linked participant (Req 46)', () => {
  test('X-05 sees their own record and private details, and nobody else', async () => {
    await assertSucceeds(getDoc(doc(as('solo'), `${E}/participants/pSolo`)));
    await assertSucceeds(getDoc(doc(as('solo'), `${E}/participants/pSolo/private/details`)));
    await assertFails(getDoc(doc(as('solo'), `${E}/participants/pGuest`)));
    await assertFails(getDoc(doc(as('solo'), `${E}/participants/pGuest/private/details`)));
    await assertFails(getDocs(collection(as('solo'), `${E}/participants`)));
    await assertSucceeds(getDocs(query(collection(as('solo'), `${E}/participants`), where('uid', '==', 'solo'))));
  });

  test('X-05 a linked adult sees their own group only', async () => {
    await assertSucceeds(getDoc(doc(as('ravi'), `${E}/participants/pRavi`)));
    await assertSucceeds(getDocs(query(collection(as('ravi'), `${E}/participants`), where('groupId', 'in', ['f1']))));
    await assertFails(getDoc(doc(as('ravi'), `${E}/participants/pShah`)));
    await assertFails(getDoc(doc(as('ravi'), `${E}/participants/pShah/private/details`)));
  });

  test('nobody changes who a record is linked to', async () => {
    await assertFails(updateDoc(doc(as('owner'), `${E}/participants/pGuest`), {uid: 'owner'}));
    await assertFails(updateDoc(doc(as('ravi'), `${E}/participants/pRavi`), {uid: 'lead'}));
  });
});

describe('server-only data (Req 14a)', () => {
  test('link requests need participants.readPrivate, and only the server writes them', async () => {
    await assertSucceeds(getDoc(doc(as('owner'), `${E}/linkRequests/u9`)));
    await assertSucceeds(getDocs(collection(as('owner'), `${E}/linkRequests`)));
    await assertFails(getDoc(doc(as('lead'), `${E}/linkRequests/u9`)));
    await assertFails(setDoc(doc(as('owner'), `${E}/linkRequests/u9`), {status: 'dismissed'}));
  });

  test('match keys and their secret are never readable', async () => {
    await assertFails(getDoc(doc(as('owner'), `${E}/participantKeys/anon`)));
    await assertFails(getDocs(collection(as('owner'), `${E}/participantKeys`)));
    await assertFails(getDoc(doc(as('owner'), 'serverSecrets/participantKeys')));
  });

  test('an organizer may name an unnamed entry, but only the server marks one', async () => {
    await assertSucceeds(updateDoc(doc(as('owner'), `${E}/participants/anon`), {name: 'Ravi', sortName: 'ravi'}));
    await assertFails(updateDoc(doc(as('owner'), `${E}/participants/anon`), {anonymised: false}));
    await assertFails(setDoc(doc(as('owner'), `${E}/participants/new1`), {
      name: 'X', sortName: 'x', groupId: null, isChild: false, createdBy: 'owner', status: 'active', anonymised: true,
    }));
  });
});
