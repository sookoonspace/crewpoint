/**
 * Req 38, 38b, 38c (H-05, L15): `setExpenseAccess` lets `event.manage`
 * choose who reads every expense, records each change, and recalculates
 * `expenses.readAll` on every member document. `getMyBalance` gives someone
 * with limited access their own balance and who to pay, worked out on the
 * server from all of the event's expenses.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {setExpenseAccess, getMyBalance} = require('../../src/events/expenseAccessCallables');
const {setMemberRoles} = require('../../src/events/roles');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const db = () => getAdminDb();
const perms = async (uid: string) =>
  ((await db().doc(`events/${E}/members/${uid}`).get()).data()?.permissions ?? []) as string[];
const rejected = (code: string) => expect.objectContaining({code});
const PEOPLE: [string, string[]][] = [
  ['owner', ['owner']], ['admin', ['admin']], ['lead', ['crewLead']],
  ['pat', ['participant']], ['sam', ['participant']], ['obs', ['observer']],
];

async function seed(over: object = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Fest', status: 'published', creatorId: 'owner', adminIds: ['owner', 'admin'],
    memberIds: PEOPLE.map(([u]) => u), ...over,
  });
  for (const [uid, roleIds] of PEOPLE) {
    await db().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds, crewIds: ['food'], participantId: null,
      permissions: computePermissions(roleIds, {}, {readsAllExpenses: roleIds[0] !== 'observer'}),
    });
  }
}

const set = (uid: string, access: unknown) =>
  ftest.wrap(setExpenseAccess)({auth: {uid}, data: {eventId: E, access}});
const balance = (uid: string, eventId = E) =>
  ftest.wrap(getMyBalance)({auth: {uid}, data: {eventId}});

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('setExpenseAccess', () => {
  test('needs event.manage', async () => {
    await seed();
    await expect(set('lead', {mode: 'involved'})).rejects.toEqual(rejected('permission-denied'));
    await expect(set('pat', {mode: 'involved'})).rejects.toEqual(rejected('permission-denied'));
    await expect(set('admin', {mode: 'involved'})).resolves.toEqual(expect.objectContaining({success: true}));
  });

  test('saves the option and recalculates everyone', async () => {
    await seed();
    await set('owner', {mode: 'selected', roleIds: ['crewLead'], uids: ['sam']});
    const saved = (await db().doc(`events/${E}`).get()).data()!;
    expect(saved.settings.expenseAccess).toEqual({
      mode: 'selected', includeNonContributors: false, roleIds: ['crewLead'], uids: ['sam'],
    });
    expect(await perms('lead')).toContain('expenses.readAll');
    expect(await perms('sam')).toContain('expenses.readAll');
    expect(await perms('pat')).not.toContain('expenses.readAll');
    expect(await perms('obs')).not.toContain('expenses.readAll');
    // Permission holders keep it through their role.
    expect(await perms('owner')).toContain('expenses.readAll');
  });

  test('keeps each member document as it was apart from permissions', async () => {
    await seed();
    await set('owner', {mode: 'involved'});
    const pat = (await db().doc(`events/${E}/members/pat`).get()).data()!;
    expect(pat.roleIds).toEqual(['participant']);
    expect(pat.crewIds).toEqual(['food']);
  });

  test('Everyone with the switch on includes Observers', async () => {
    await seed();
    await set('owner', {mode: 'everyone', includeNonContributors: true});
    expect(await perms('obs')).toContain('expenses.readAll');
    await set('owner', {mode: 'everyone'});
    expect(await perms('obs')).not.toContain('expenses.readAll');
  });

  test('records who changed it and when, with what it was before', async () => {
    await seed();
    await set('admin', {mode: 'involved'});
    const log = await db().collection(`events/${E}/settingsLog`).get();
    expect(log.size).toBe(1);
    const entry = log.docs[0].data();
    expect(entry).toEqual(expect.objectContaining({
      setting: 'expenseAccess',
      changedBy: 'admin',
      from: {mode: 'everyone', includeNonContributors: false, roleIds: [], uids: []},
      to: {mode: 'involved', includeNonContributors: false, roleIds: [], uids: []},
    }));
    expect(entry.changedAt).toBeDefined();
  });

  test('saving the same option again records nothing new', async () => {
    await seed();
    await set('owner', {mode: 'involved'});
    await set('owner', {mode: 'involved'});
    expect((await db().collection(`events/${E}/settingsLog`).get()).size).toBe(1);
  });

  test('refuses a malformed option, and an archived event', async () => {
    await seed();
    await expect(set('owner', {mode: 'some'})).rejects.toEqual(rejected('invalid-argument'));
    await seed({status: 'archived'});
    await expect(set('owner', {mode: 'involved'})).rejects.toEqual(rejected('failed-precondition'));
  });

  test('a later role change follows the setting', async () => {
    await seed();
    await set('owner', {mode: 'selected', roleIds: ['crewLead']});
    await ftest.wrap(setMemberRoles)({auth: {uid: 'owner'}, data: {eventId: E, targetUserId: 'pat', roleIds: ['crewLead']}});
    expect(await perms('pat')).toContain('expenses.readAll');
  });
});

describe('getMyBalance (Req 38c)', () => {
  async function expense(id: string, payerId: string, splits: [string, number][], isPayment = false) {
    const amount = isPayment ? splits[0][1] : splits.reduce((t, [, a]) => t + a, 0);
    await db().doc(`events/${E}/expenses/${id}`).set({
      payerId, amount, isPayment, isDonation: false,
      splits: splits.map(([userId, a]) => ({userId, amount: a})),
      involvedUids: [...new Set([payerId, ...splits.map(([u]) => u)])],
    });
  }

  beforeEach(async () => {
    await seed({currency: 'CAD', settings: {expenseAccess: {mode: 'involved'}}});
    // Pat shares only the first. The others are between other people.
    await expense('dinner', 'owner', [['owner', 20], ['pat', 20], ['sam', 20]]);
    await expense('venue', 'sam', [['owner', 50], ['sam', 50]]);
    await expense('paid', 'pat', [['owner', 5]], true);
  });

  test('your balance and who to pay, from every expense in the event', async () => {
    const result = await balance('pat');
    // Pat owes 20 for dinner and has paid 5 back. Debts are simplified
    // across the event, as in the app, so Pat pays Sam, who is owed most.
    expect(result.net).toBe(-15);
    expect(result.currency).toBe('CAD');
    expect(result.transfers).toEqual([{fromUserId: 'pat', toUserId: 'sam', amount: 15}]);
  });

  test('shows only transfers that involve you', async () => {
    const result = await balance('sam');
    for (const t of result.transfers) {
      expect([t.fromUserId, t.toUserId]).toContain('sam');
    }
    expect(result).not.toHaveProperty('totalExpenses');
  });

  test('someone outside the event gets nothing', async () => {
    await expect(balance('stranger')).rejects.toEqual(rejected('permission-denied'));
    await expect(balance('pat', 'missing')).rejects.toEqual(rejected('not-found'));
  });
});
