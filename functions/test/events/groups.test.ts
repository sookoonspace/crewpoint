/**
 * Req 40, 26b (PA-05, Z-01): groups of participants, such as a household or
 * a team. `participants.edit` creates and renames them, and links the adults
 * with accounts who look after a group. Linking copies the group ID onto the
 * adult's member document and grants `group.editOwn`, so rules can check
 * own-group access with the one member-document read they already make.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {saveGroup, setGroupAdults, deleteGroup} = require('../../src/events/groups');
const {setMemberRoles} = require('../../src/events/roles');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const db = () => getAdminDb();
const member = async (uid: string) =>
  (await db().doc(`events/${E}/members/${uid}`).get()).data()!;
const group = async (id: string) => (await db().doc(`events/${E}/groups/${id}`).get()).data();
const rejected = (code: string) => expect.objectContaining({code});
const PEOPLE: [string, string[]][] = [
  ['owner', ['owner']], ['lead', ['crewLead']], ['pat', ['participant']], ['sam', ['participant']],
];

async function seed(over: object = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Convention', status: 'published', creatorId: 'owner', adminIds: ['owner'],
    memberIds: PEOPLE.map(([u]) => u), ...over,
  });
  for (const [uid, roleIds] of PEOPLE) {
    await db().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds, crewIds: ['food'], participantId: null,
      permissions: computePermissions(roleIds, {}, {readsAllExpenses: true}),
    });
  }
}

const call = (fn: unknown, uid: string, data: object) =>
  ftest.wrap(fn)({auth: {uid}, data: {eventId: E, ...data}});

beforeEach(async () => {
  await clearFirestoreEmulator();
  await seed();
});
afterAll(() => ftest.cleanup());

describe('saveGroup', () => {
  test('needs participants.edit', async () => {
    await expect(call(saveGroup, 'pat', {groupId: 'f1', name: 'Shahs'}))
      .rejects.toEqual(rejected('permission-denied'));
    await expect(call(saveGroup, 'lead', {groupId: 'f1', name: 'Shahs'}))
      .resolves.toEqual({success: true});
  });

  test('creates a group, then renames it, keeping who made it', async () => {
    await call(saveGroup, 'owner', {groupId: 'f1', name: '  Shahs '});
    expect(await group('f1')).toEqual(expect.objectContaining({
      name: 'Shahs', sortName: 'shahs', createdBy: 'owner', adultUids: [],
    }));
    await call(saveGroup, 'lead', {groupId: 'f1', name: 'Shah household'});
    const saved = await group('f1');
    expect(saved?.name).toBe('Shah household');
    expect(saved?.createdBy).toBe('owner');
  });

  test('refuses an empty or long name, a bad ID, and an archived event', async () => {
    await expect(call(saveGroup, 'owner', {groupId: 'f1', name: ' '})).rejects.toEqual(rejected('invalid-argument'));
    await expect(call(saveGroup, 'owner', {groupId: 'f1', name: 'x'.repeat(121)})).rejects.toEqual(rejected('invalid-argument'));
    await expect(call(saveGroup, 'owner', {groupId: 'a/b', name: 'X'})).rejects.toEqual(rejected('invalid-argument'));
    await seed({status: 'archived'});
    await expect(call(saveGroup, 'owner', {groupId: 'f1', name: 'X'})).rejects.toEqual(rejected('failed-precondition'));
  });
});

describe('setGroupAdults', () => {
  beforeEach(async () => {
    await call(saveGroup, 'owner', {groupId: 'f1', name: 'Shahs'});
    await call(saveGroup, 'owner', {groupId: 'f2', name: 'Patels'});
  });

  test('copies the group onto each adult and grants group.editOwn', async () => {
    await call(setGroupAdults, 'owner', {groupId: 'f1', uids: ['pat']});
    const pat = await member('pat');
    expect(pat.groupIds).toEqual(['f1']);
    expect(pat.permissions).toContain('group.editOwn');
    // The rest of the member document is kept.
    expect(pat.roleIds).toEqual(['participant']);
    expect(pat.crewIds).toEqual(['food']);
    expect((await group('f1'))?.adultUids).toEqual(['pat']);
  });

  test('sets exactly who is linked, and someone in no group loses group.editOwn', async () => {
    await call(setGroupAdults, 'owner', {groupId: 'f1', uids: ['pat']});
    await call(setGroupAdults, 'owner', {groupId: 'f2', uids: ['pat', 'sam']});
    expect((await member('pat')).groupIds.sort()).toEqual(['f1', 'f2']);
    await call(setGroupAdults, 'owner', {groupId: 'f1', uids: ['sam']});
    expect((await member('pat')).groupIds).toEqual(['f2']);
    await call(setGroupAdults, 'owner', {groupId: 'f2', uids: ['sam']});
    const pat = await member('pat');
    expect(pat.groupIds).toEqual([]);
    expect(pat.permissions).not.toContain('group.editOwn');
  });

  test('a later role change keeps the group and group.editOwn', async () => {
    await call(setGroupAdults, 'owner', {groupId: 'f1', uids: ['pat']});
    await call(setMemberRoles, 'owner', {targetUserId: 'pat', roleIds: ['volunteer']});
    const pat = await member('pat');
    expect(pat.groupIds).toEqual(['f1']);
    expect(pat.permissions).toContain('group.editOwn');
  });

  test('needs participants.edit, members of the event, and a group that exists', async () => {
    await expect(call(setGroupAdults, 'pat', {groupId: 'f1', uids: ['pat']})).rejects.toEqual(rejected('permission-denied'));
    await expect(call(setGroupAdults, 'owner', {groupId: 'f1', uids: ['stranger']})).rejects.toEqual(rejected('failed-precondition'));
    await expect(call(setGroupAdults, 'owner', {groupId: 'nope', uids: []})).rejects.toEqual(rejected('not-found'));
    await expect(call(setGroupAdults, 'owner', {groupId: 'f1', uids: ['pat', 'pat']})).rejects.toEqual(rejected('invalid-argument'));
  });
});

describe('deleteGroup', () => {
  beforeEach(async () => {
    await call(saveGroup, 'owner', {groupId: 'f1', name: 'Shahs'});
    await call(setGroupAdults, 'owner', {groupId: 'f1', uids: ['pat']});
  });

  test('removes the group and unlinks its adults', async () => {
    await db().doc(`events/${E}/groups/f1/private/details`).set({fields: {phone: '555'}});
    await call(deleteGroup, 'owner', {groupId: 'f1'});
    expect(await group('f1')).toBeUndefined();
    expect((await db().doc(`events/${E}/groups/f1/private/details`).get()).exists).toBe(false);
    const pat = await member('pat');
    expect(pat.groupIds).toEqual([]);
    expect(pat.permissions).not.toContain('group.editOwn');
  });

  test('refuses while people are still in it', async () => {
    await db().doc(`events/${E}/participants/p1`).set({name: 'Ana', groupId: 'f1', isChild: true});
    await expect(call(deleteGroup, 'owner', {groupId: 'f1'})).rejects.toEqual(rejected('failed-precondition'));
  });

  test('needs participants.edit, and is safe to repeat', async () => {
    await expect(call(deleteGroup, 'pat', {groupId: 'f1'})).rejects.toEqual(rejected('permission-denied'));
    await call(deleteGroup, 'owner', {groupId: 'f1'});
    await expect(call(deleteGroup, 'owner', {groupId: 'f1'})).resolves.toEqual({success: true});
  });
});

describe('leaving the event', () => {
  test("someone removed is no longer one of their groups' adults", async () => {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const {removeEventMember} = require('../../src/events/removeEventMember');
    await call(saveGroup, 'owner', {groupId: 'f1', name: 'Shahs'});
    await call(setGroupAdults, 'owner', {groupId: 'f1', uids: ['pat', 'sam']});
    await call(removeEventMember, 'owner', {targetUserId: 'pat'});
    expect((await group('f1'))?.adultUids).toEqual(['sam']);
  });
});
