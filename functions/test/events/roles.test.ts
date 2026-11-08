/**
 * Req 26a, 27: a callable recalculates `permissions` whenever a role or an
 * assignment changes. Clients cannot write it.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {PRESET_ROLES, computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {setMemberRoles, saveEventRole, deleteEventRole} = require('../../src/events/roles');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const member = async (uid: string) =>
  (await getAdminDb().doc(`events/${E}/members/${uid}`).get()).data();
const event = async () => (await getAdminDb().doc(`events/${E}`).get()).data()!;
const rejected = (code: string) => expect.objectContaining({code});
const sorted = (list: readonly string[]) => [...list].sort();

async function seed(over: object = {}) {
  await getAdminDb().doc(`events/${E}`).set({
    title: 'Fest',
    status: 'published',
    creatorId: 'owner',
    adminIds: ['owner', 'admin'],
    memberIds: ['owner', 'admin', 'm'],
    ...over,
  });
  const seeded: [string, string[]][] = [['owner', ['owner']], ['admin', ['admin']], ['m', ['participant']]];
  for (const [uid, roleIds] of seeded) {
    await getAdminDb().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds, crewIds: [], permissions: computePermissions(roleIds, {}),
    });
  }
}

const assign = (uid: string, target: string, roleIds: unknown) =>
  ftest.wrap(setMemberRoles)({auth: {uid}, data: {eventId: E, targetUserId: target, roleIds}});

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('setMemberRoles', () => {
  test('an owner assigns a role, and permissions are recalculated', async () => {
    await seed();
    await assign('owner', 'm', ['finance']);
    const saved = await member('m');
    expect(saved?.roleIds).toEqual(['finance']);
    expect([...saved?.permissions].sort()).toEqual(sorted(PRESET_ROLES.finance.permissions));
  });

  test('needs roles.manage: an Admin or a plain member is refused', async () => {
    await seed();
    await expect(assign('admin', 'm', ['finance'])).rejects.toEqual(rejected('permission-denied'));
    await expect(assign('m', 'm', ['admin'])).rejects.toEqual(rejected('permission-denied'));
    await expect(assign('stranger', 'm', ['finance'])).rejects.toEqual(rejected('permission-denied'));
    expect((await member('m'))?.roleIds).toEqual(['participant']);
  });

  test('a Co-owner holds roles.manage, so can assign', async () => {
    await seed();
    await getAdminDb().doc(`events/${E}/members/admin`).update({
      roleIds: ['coOwner'], permissions: computePermissions(['coOwner'], {}),
    });
    await assign('admin', 'm', ['volunteer']);
    expect((await member('m'))?.roleIds).toEqual(['volunteer']);
  });

  test('roles must be a non-empty list of known roles', async () => {
    await seed();
    for (const bad of [[], 'finance', ['finance', 'finance'], ['nope'], [7]]) {
      await expect(assign('owner', 'm', bad)).rejects.toEqual(rejected('invalid-argument'));
    }
    await getAdminDb().doc(`events/${E}/roles/hospitality`).set({name: 'Hospitality', permissions: ['chat.send']});
    await assign('owner', 'm', ['hospitality']);
    expect((await member('m'))?.roleIds).toEqual(['hospitality']);
  });

  test('the target must be a member, and the event must exist', async () => {
    await seed();
    await expect(assign('owner', 'stranger', ['finance'])).rejects.toEqual(rejected('failed-precondition'));
    expect(await member('stranger')).toBeUndefined();
    await getAdminDb().doc(`events/${E}`).delete();
    await expect(assign('owner', 'm', ['finance'])).rejects.toEqual(rejected('not-found'));
  });

  test('the Owner role cannot be given or taken here: that is a transfer', async () => {
    await seed();
    await expect(assign('owner', 'm', ['owner'])).rejects.toEqual(rejected('failed-precondition'));
    await expect(assign('owner', 'owner', ['admin'])).rejects.toEqual(rejected('failed-precondition'));
    await assign('owner', 'owner', ['owner', 'scorer']);
    expect((await member('owner'))?.roleIds).toEqual(['owner', 'scorer']);
  });

  test('adminIds follows: Co-owner and Admin are in it, other roles are not', async () => {
    await seed();
    await assign('owner', 'm', ['coOwner']);
    expect((await event()).adminIds).toEqual(['owner', 'admin', 'm']);
    await assign('owner', 'admin', ['finance']);
    expect((await event()).adminIds).toEqual(['owner', 'm']);
    expect((await event()).memberIds).toEqual(['owner', 'admin', 'm']);
  });

  test('in a draft, nobody can be left without an admin role (L23)', async () => {
    await seed({status: 'draft', memberIds: ['owner', 'admin']});
    await expect(assign('owner', 'admin', ['finance'])).rejects.toEqual(rejected('failed-precondition'));
    await assign('owner', 'admin', ['coOwner']);
    expect((await member('admin'))?.roleIds).toEqual(['coOwner']);
  });

  test('an archived event cannot change', async () => {
    await seed({status: 'archived'});
    await expect(assign('owner', 'm', ['finance'])).rejects.toEqual(rejected('failed-precondition'));
  });
});

const saveRole = (uid: string, data: object) =>
  ftest.wrap(saveEventRole)({auth: {uid}, data: {eventId: E, ...data}});
const role = async (id: string) =>
  (await getAdminDb().doc(`events/${E}/roles/${id}`).get()).data();

describe('saveEventRole', () => {
  test('editing a preset saves it and recalculates everyone holding it', async () => {
    await seed();
    await saveRole('owner', {roleId: 'participant', name: 'Guest', permissions: ['chat.send', 'counts.read']});
    expect(await role('participant')).toEqual(expect.objectContaining({
      name: 'Guest', permissions: ['chat.send', 'counts.read'], preset: true,
    }));
    expect((await member('m'))?.permissions).toEqual(['expenses.readAll', 'chat.send', 'counts.read']);
    expect((await member('admin'))?.permissions).toEqual(computePermissions(['admin'], {}));
  });
});

describe('saveEventRole guards', () => {
  test('a custom role can be created and assigned (GE-03)', async () => {
    await seed();
    await saveRole('owner', {roleId: 'hospitality', name: 'Hospitality', permissions: ['participants.read']});
    expect((await role('hospitality'))?.preset).toBe(false);
    await assign('owner', 'm', ['hospitality']);
    expect((await member('m'))?.permissions).toEqual(['participants.read', 'expenses.readAll']);
  });

  test('needs roles.manage', async () => {
    await seed();
    await expect(saveRole('admin', {roleId: 'x', name: 'X', permissions: []}))
      .rejects.toEqual(rejected('permission-denied'));
    expect(await role('x')).toBeUndefined();
  });

  test('the Owner role cannot be edited', async () => {
    await seed();
    await expect(saveRole('owner', {roleId: 'owner', name: 'Boss', permissions: []}))
      .rejects.toEqual(rejected('failed-precondition'));
  });

  test('permissions must come from the catalogue, and the ID and name must be valid', async () => {
    await seed();
    const bad = [
      {roleId: 'x', name: 'X', permissions: ['money.steal']},
      {roleId: 'x', name: 'X', permissions: 'chat.send'},
      {roleId: 'x', name: 'X', permissions: ['chat.send', 'chat.send']},
      {roleId: 'a/b', name: 'X', permissions: []},
      {roleId: 'x', name: '  ', permissions: []},
      {roleId: 'x', name: 'n'.repeat(61), permissions: []},
    ];
    for (const data of bad) {
      await expect(saveRole('owner', data)).rejects.toEqual(rejected('invalid-argument'));
    }
  });

  test('an archived or missing event is refused', async () => {
    await seed({status: 'archived'});
    await expect(saveRole('owner', {roleId: 'x', name: 'X', permissions: []}))
      .rejects.toEqual(rejected('failed-precondition'));
    await getAdminDb().doc(`events/${E}`).delete();
    await expect(saveRole('owner', {roleId: 'x', name: 'X', permissions: []}))
      .rejects.toEqual(rejected('not-found'));
  });
});

const deleteRole = (uid: string, roleId: unknown) =>
  ftest.wrap(deleteEventRole)({auth: {uid}, data: {eventId: E, roleId}});

describe('deleteEventRole', () => {
  test('deleting an edited preset resets it, and recalculates its holders', async () => {
    await seed();
    await saveRole('owner', {roleId: 'participant', name: 'Guest', permissions: ['counts.read']});
    await deleteRole('owner', 'participant');
    expect(await role('participant')).toBeUndefined();
    expect((await member('m'))?.permissions).toEqual(computePermissions(['participant'], {}, {readsAllExpenses: true}));
  });

  test('a custom role nobody holds is deleted', async () => {
    await seed();
    await saveRole('owner', {roleId: 'hospitality', name: 'Hospitality', permissions: ['chat.send']});
    await deleteRole('owner', 'hospitality');
    expect(await role('hospitality')).toBeUndefined();
  });

  test('a custom role someone still holds is kept, so nobody is left with no role', async () => {
    await seed();
    await saveRole('owner', {roleId: 'hospitality', name: 'Hospitality', permissions: ['chat.send']});
    await assign('owner', 'm', ['hospitality']);
    await expect(deleteRole('owner', 'hospitality')).rejects.toEqual(rejected('failed-precondition'));
    expect(await role('hospitality')).toBeDefined();
  });

  test('needs roles.manage, and the event must be open and exist', async () => {
    await seed();
    await saveRole('owner', {roleId: 'x', name: 'X', permissions: []});
    await expect(deleteRole('admin', 'x')).rejects.toEqual(rejected('permission-denied'));
    await expect(deleteRole('owner', 'a/b')).rejects.toEqual(rejected('invalid-argument'));
    await getAdminDb().doc(`events/${E}`).update({status: 'archived'});
    await expect(deleteRole('owner', 'x')).rejects.toEqual(rejected('failed-precondition'));
    await getAdminDb().doc(`events/${E}`).delete();
    await expect(deleteRole('owner', 'x')).rejects.toEqual(rejected('not-found'));
    expect(await role('x')).toBeDefined();
  });

  test('deleting a role the event has no version of changes nothing', async () => {
    await seed();
    await deleteRole('owner', 'finance');
    expect((await member('m'))?.roleIds).toEqual(['participant']);
  });
});
