/**
 * Req 40, 43, 26b (PA-05, Z-01): participants are people attending, with or
 * without an account, including children. The roster needs
 * `participants.read`; a group's linked adults see and edit their own group,
 * through the group IDs on their member document. Children, like anyone, are
 * entered only with `participants.edit` or by a linked adult in their group.
 * A participant's birth date lives in `private`, read with
 * `participants.readPrivate` or by the group's linked adults.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where,
  getCountFromServer,
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
// uid → [roles, linked groups]
const PEOPLE: Record<string, [string[], string[]]> = {
  owner: [['owner'], []],
  lead: [['crewLead'], []],
  vol: [['volunteer'], []],
  parent: [['participant'], ['f1']],
  other: [['participant'], ['f2']],
  plain: [['participant'], []],
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
    for (const g of ['f1', 'f2']) {
      await setDoc(doc(db, `${E}/groups/${g}`), {name: g, sortName: g, adultUids: []});
    }
    await setDoc(doc(db, `${E}/participants/kid`), {
      name: 'Ana', sortName: 'ana', groupId: 'f1', isChild: true, createdBy: 'owner', status: 'active',
    });
    await setDoc(doc(db, `${E}/participants/kid/private/details`), {birthDate: '2020-05-01'});
    await setDoc(doc(db, `${E}/participants/guest`), {
      name: 'Guest', sortName: 'guest', groupId: null, isChild: false, createdBy: 'owner', status: 'active',
    });
  });
});

const person = (over: object = {}) => ({
  name: 'Ravi', sortName: 'ravi', groupId: 'f1', isChild: true, createdBy: 'parent',
  status: 'active', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over,
});

describe('reading the roster (Req 43)', () => {
  test('participants.read browses everyone, and counts them', async () => {
    await assertSucceeds(getDocs(collection(as('lead'), `${E}/participants`)));
    await assertSucceeds(getCountFromServer(collection(as('owner'), `${E}/participants`)));
    await assertSucceeds(getDocs(collection(as('owner'), `${E}/groups`)));
  });

  test('other members cannot browse it', async () => {
    await assertFails(getDocs(collection(as('plain'), `${E}/participants`)));
    await assertFails(getDocs(collection(as('parent'), `${E}/participants`)));
    await assertFails(getDoc(doc(as('plain'), `${E}/participants/kid`)));
    await assertFails(getDocs(collection(as('plain'), `${E}/groups`)));
  });

  test('a linked adult sees their own group, and no other', async () => {
    await assertSucceeds(getDocs(query(collection(as('parent'), `${E}/participants`), where('groupId', 'in', ['f1']))));
    await assertSucceeds(getDoc(doc(as('parent'), `${E}/participants/kid`)));
    await assertSucceeds(getDoc(doc(as('parent'), `${E}/groups/f1`)));
    await assertFails(getDoc(doc(as('other'), `${E}/participants/kid`)));
    await assertFails(getDoc(doc(as('parent'), `${E}/groups/f2`)));
    await assertFails(getDocs(query(collection(as('parent'), `${E}/participants`), where('groupId', '==', 'f2'))));
  });

  test('people outside the event see nothing', async () => {
    await assertFails(getDoc(doc(as('stranger'), `${E}/participants/guest`)));
  });
});

describe('adding and editing people (Req 40, Z-01)', () => {
  test('participants.edit adds anyone, including a child and someone with no group', async () => {
    await assertSucceeds(setDoc(doc(as('lead'), `${E}/participants/p1`), person({createdBy: 'lead'})));
    await assertSucceeds(setDoc(doc(as('lead'), `${E}/participants/p2`), person({createdBy: 'lead', groupId: null, isChild: false})));
  });

  test('a linked adult adds a child to their own group only', async () => {
    await assertSucceeds(setDoc(doc(as('parent'), `${E}/participants/p1`), person()));
    await assertFails(setDoc(doc(as('parent'), `${E}/participants/p2`), person({groupId: 'f2'})));
    await assertFails(setDoc(doc(as('parent'), `${E}/participants/p3`), person({groupId: null})));
  });

  test('nobody else adds people, children included', async () => {
    await assertFails(setDoc(doc(as('plain'), `${E}/participants/p1`), person({createdBy: 'plain'})));
    await assertFails(setDoc(doc(as('vol'), `${E}/participants/p1`), person({createdBy: 'vol'})));
  });

  test('a linked adult edits their group, but cannot move someone out of it', async () => {
    await assertSucceeds(updateDoc(doc(as('parent'), `${E}/participants/kid`), {name: 'Anaya', sortName: 'anaya'}));
    await assertFails(updateDoc(doc(as('parent'), `${E}/participants/kid`), {groupId: 'f2'}));
    await assertFails(updateDoc(doc(as('other'), `${E}/participants/kid`), {name: 'X', sortName: 'x'}));
    await assertSucceeds(updateDoc(doc(as('lead'), `${E}/participants/kid`), {groupId: 'f2'}));
  });

  test('the shape is checked: name, sort name, group, child flag and the creator', async () => {
    const write = (over: object) => setDoc(doc(as('lead'), `${E}/participants/p9`), person({createdBy: 'lead', ...over}));
    await assertFails(write({name: ''}));
    await assertFails(write({name: 'x'.repeat(121), sortName: 'x'.repeat(121)}));
    await assertFails(write({sortName: 'Ravi'}));
    await assertFails(write({groupId: 'missing'}));
    await assertFails(write({isChild: 'yes'}));
    await assertFails(write({createdBy: 'owner'}));
    await assertFails(write({status: 'deleted'}));
    await assertFails(write({birthDate: '2020-01-01'}));
  });

  test('the linked account and import ID are set only by the server', async () => {
    await assertFails(setDoc(doc(as('lead'), `${E}/participants/p1`), person({createdBy: 'lead', uid: 'plain'})));
    await assertFails(setDoc(doc(as('lead'), `${E}/participants/p1`), person({createdBy: 'lead', externalId: 'R1'})));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), `${E}/participants/guest`), {uid: 'plain', externalId: 'R7'});
    });
    // Other edits keep them.
    await assertSucceeds(updateDoc(doc(as('lead'), `${E}/participants/guest`), {name: 'Gil', sortName: 'gil'}));
    await assertFails(updateDoc(doc(as('lead'), `${E}/participants/guest`), {uid: 'other'}));
  });

  test('removing someone needs the same access', async () => {
    await assertFails(deleteDoc(doc(as('other'), `${E}/participants/kid`)));
    await assertSucceeds(deleteDoc(doc(as('parent'), `${E}/participants/kid`)));
  });

  test('groups are written only by the server', async () => {
    await assertFails(setDoc(doc(as('owner'), `${E}/groups/f3`), {name: 'X', sortName: 'x', adultUids: []}));
  });

  test('an archived event takes no changes', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), E), {status: 'archived'});
    });
    await assertFails(setDoc(doc(as('lead'), `${E}/participants/p1`), person({createdBy: 'lead'})));
  });
});

describe('private details (Z-01)', () => {
  const details = (uid: string) => doc(as(uid), `${E}/participants/kid/private/details`);

  test("a child's birth date is read only with participants.readPrivate or by their group's adults", async () => {
    await assertSucceeds(getDoc(details('owner')));
    await assertSucceeds(getDoc(details('parent')));
    // Crew leads read the roster but not private details.
    await assertFails(getDoc(details('lead')));
    await assertFails(getDoc(details('vol')));
    await assertFails(getDoc(details('other')));
  });

  test('written by whoever may edit the person, with a known shape', async () => {
    await assertSucceeds(setDoc(details('parent'), {birthDate: '2020-05-02', updatedAt: serverTimestamp()}));
    await assertSucceeds(setDoc(details('lead'), {birthDate: null}));
    await assertFails(setDoc(details('other'), {birthDate: '2020-05-02'}));
    await assertFails(setDoc(details('parent'), {birthDate: 20200502}));
    await assertFails(setDoc(details('parent'), {notes: 'x'}));
  });
});
