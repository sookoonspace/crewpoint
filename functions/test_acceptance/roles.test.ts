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
const {generateInviteCode} = require('../src/events/generateInviteCode');
const {joinEvent} = require('../src/events/joinEvent');
const {offerOwnership, acceptOwnership} = require('../src/events/ownership');

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

describe('invites carry a role', () => {
  test('GAP-ANY-33 an owner invites a speaker straight into a role, with no promotion after', async () => {
    const {code} = await ftest.wrap(generateInviteCode)({auth: {uid: 'owner'}, data: {eventId: E, roleId: 'crewMember'}});
    await ftest.wrap(joinEvent)({auth: {uid: 'speaker'}, data: {joinCode: code}});
    expect((await member('speaker')).roleIds).toEqual(['crewMember']);
    expect((await member('speaker')).permissions).toContain('incidents.report');
  });
});

describe('co-owners and ownership transfer', () => {
  const offer = (from: string, to: string) =>
    ftest.wrap(offerOwnership)({auth: {uid: from}, data: {eventId: E, toUid: to}});
  const accept = (uid: string) => ftest.wrap(acceptOwnership)({auth: {uid}, data: {eventId: E}});

  test('WE-07 two people co-own one event', async () => {
    await assign('treasurer', ['coOwner']);
    const coOwner = (await member('treasurer')).permissions;
    expect(coOwner).toEqual(expect.arrayContaining(['event.manage', 'roles.manage', 'members.manage']));
    expect(coOwner).not.toContain('event.transfer');
  });

  test('GAP-WED-32 an event can have an Owner and several Co-owners', async () => {
    await assign('treasurer', ['coOwner']);
    await assign('lead', ['coOwner']);
    expect((await member('owner')).roleIds).toEqual(['owner']);
    expect((await member('treasurer')).roleIds).toEqual(['coOwner']);
    expect((await member('lead')).roleIds).toEqual(['coOwner']);
  });

  test('GAP-ANY-31 the Owner hands ownership to someone, who accepts it', async () => {
    await offer('owner', 'lead');
    expect((await member('owner')).roleIds).toEqual(['owner']);
    await accept('lead');
    expect((await member('lead')).roleIds).toEqual(['owner']);
    expect((await member('owner')).roleIds).toEqual(['coOwner']);
  });

  test('WE-10 ownership transfers and can be returned', async () => {
    await offer('owner', 'lead');
    await accept('lead');
    await offer('lead', 'owner');
    await accept('owner');
    expect((await member('owner')).roleIds).toEqual(['owner']);
    expect((await member('lead')).roleIds).toEqual(['coOwner']);
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
