/* eslint-disable */
// Acceptance tests for the data parts of roles (#65). Test names start with the
// scenario ID. These scenarios finish with the role screens in #67, so they are
// not yet on the finished list. Runs on the emulators only.
import {assertFails, RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb, getTestEnv} from '../test/setup';
import {PRESET_ROLES, computePermissions} from '../src/events/permissions';

const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {setMemberRoles, saveEventRole} = require('../src/events/roles');

const E = 'roles';
const member = async (uid: string) =>
  (await getAdminDb().doc(`events/${E}/members/${uid}`).get()).data()!;
const assign = (target: string, roleIds: string[]) =>
  ftest.wrap(setMemberRoles)({auth: {uid: 'owner'}, data: {eventId: E, targetUserId: target, roleIds}});

beforeEach(async () => {
  await clearFirestoreEmulator();
  await getAdminDb().doc(`events/${E}`).set({
    title: 'Convention',
    status: 'published',
    creatorId: 'owner',
    adminIds: ['owner'],
    memberIds: ['owner', 'treasurer', 'lead', 'sponsor', 'vendor'],
  });
  await getAdminDb().doc(`events/${E}/members/owner`).set({
    uid: 'owner', roleIds: ['owner'], permissions: computePermissions(['owner'], {}),
  });
});
afterAll(() => ftest.cleanup());

describe('roles', () => {
  test('H-01 committee roles such as Finance and Crew lead can be assigned', async () => {
    await assign('treasurer', ['finance']);
    await assign('lead', ['crewLead']);
    expect((await member('treasurer')).permissions).toContain('expenses.readAll');
    expect((await member('lead')).permissions).toContain('tasks.manage');
    expect((await member('lead')).permissions).not.toContain('money.read');
  });

  test('GE-03 a custom role is saved and its permissions are worked out on the server', async () => {
    await ftest.wrap(saveEventRole)({
      auth: {uid: 'owner'},
      data: {eventId: E, roleId: 'hospitality', name: 'Hospitality', permissions: ['participants.read', 'chat.send']},
    });
    await assign('lead', ['hospitality']);
    expect((await member('lead')).permissions).toEqual(['participants.read', 'chat.send']);
  });

  test('GAP-CRK-29 Sponsor and Observer presets give chat at most, never money or tasks', async () => {
    await assign('sponsor', ['sponsor']);
    expect((await member('sponsor')).permissions).toEqual(['group.readOwn', 'chat.send']);
    expect(PRESET_ROLES.observer.permissions).toEqual(['group.readOwn']);
  });

  test('GAP-CON-30 a Vendor holds nothing beyond their own group', async () => {
    await assign('vendor', ['vendor']);
    expect((await member('vendor')).permissions).toEqual(['group.readOwn']);
  });
});

describe('H-06 dual roles', () => {
  test('H-06 two roles grant the union of their permissions', async () => {
    await assign('lead', ['crewMember', 'scorer']);
    const permissions = (await member('lead')).permissions;
    expect(permissions).toEqual(expect.arrayContaining(['incidents.report', 'scores.enter']));
    expect(permissions).not.toContain('money.read');
  });

  test("H-06 a group's contact edits their own group, whatever their roles", async () => {
    await getAdminDb().doc(`events/${E}/members/lead`).set({uid: 'lead', roleIds: ['participant'], editsOwnGroup: true});
    await assign('lead', ['crewMember']);
    expect((await member('lead')).permissions).toEqual(expect.arrayContaining(['group.readOwn', 'group.editOwn']));
  });

  // Planned gap until #72 limits expense reads to the people involved.
  test('H-06 sees no expense they are not part of', async () => {
    const env: RulesTestEnvironment = await getTestEnv();
    try {
      await env.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'events/h06'), {
          title: 'Convention', status: 'published', creatorId: 'owner',
          adminIds: ['owner'], memberIds: ['owner', 'amit', 'other'],
        });
        await setDoc(doc(db, 'events/h06/expenses/fee'), {
          payerId: 'other', amount: 50, splits: [{userId: 'other', amount: 50}], involvedUids: ['other'],
        });
      });
      await assertFails(getDoc(doc(env.authenticatedContext('amit').firestore(), 'events/h06/expenses/fee')));
    } finally {
      await env.clearFirestore();
      await env.cleanup();
    }
  });
});
