/**
 * Req 14 (FND-08, Z-04): deletion removes personal documents, and shared records
 * keep balancing under one anonymous ID per person per event.
 */
import {getAuth} from 'firebase-admin/auth';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
/* eslint-disable @typescript-eslint/no-var-requires */
const {deleteUserAccount} = require('../../src/account/deleteUserAccount');
const {deleteEvent} = require('../../src/events/deleteEvent');
/* eslint-enable @typescript-eslint/no-var-requires */

const db = () => getAdminDb();
const E = 'events/shared';
const exists = async (path: string) => (await db().doc(path).get()).exists;
const read = async (path: string) => (await db().doc(path).get()).data()!;

async function user(uid: string) {
  await getAuth().deleteUser(uid).catch(() => undefined);
  await getAuth().createUser({uid});
  await db().doc(`users/${uid}`).set({displayName: uid});
  await db().doc(`users/${uid}/private/profile`).set({email: `${uid}@x.test`});
  await db().doc(`users/${uid}/private/other`).set({note: 'x'});
  await db().doc(`users/${uid}/chatReads/shared`).set({lastReadAt: 'x'});
  await db().doc(`users/${uid}/eventMutes/shared`).set({mutedUntil: 'x'});
}
const remove = (uid: string) => ftest.wrap(deleteUserAccount)({auth: {uid}, data: {}});

function netBalances(expenses: FirebaseFirestore.DocumentData[]) {
  const net: Record<string, number> = {};
  for (const e of expenses) {
    net[e.payerId] = (net[e.payerId] ?? 0) + e.amount;
    for (const s of e.splits) net[s.userId] = (net[s.userId] ?? 0) - Math.abs(s.amount);
  }
  return net;
}

beforeEach(async () => {
  await clearFirestoreEmulator();
  await db().doc(E).set({
    title: 'Trip',
    creatorId: 'owner',
    adminIds: ['owner'],
    memberIds: ['owner', 'ann', 'bob'],
    memberCount: 3,
  });
  await db().doc(`${E}/expenses/annPaid`).set({
    payerId: 'ann',
    amount: 30,
    involvedUids: ['ann', 'bob', 'owner'],
    splits: [
      {userId: 'ann', amount: 10},
      {userId: 'bob', amount: 10},
      {userId: 'owner', amount: 10},
    ],
  });
  // An older record, from before involvedUids existed.
  await db().doc(`${E}/expenses/ownerPaid`).set({
    payerId: 'owner',
    amount: 20,
    splits: [
      {userId: 'ann', amount: 10},
      {userId: 'owner', amount: 10},
    ],
  });
  await db().doc(`${E}/expenses/unrelated`).set({
    payerId: 'owner',
    amount: 5,
    involvedUids: ['owner'],
    splits: [{userId: 'owner', amount: 5}],
  });
  await db().doc(`${E}/tasks/made`).set({createdBy: 'ann', completedBy: 'owner', assigneeId: 'ann'});
  await db().doc(`${E}/tasks/done`).set({createdBy: 'owner', completedBy: 'ann', assigneeId: 'owner'});
  await db().doc(`${E}/messages/said`).set({senderId: 'ann', text: 'hi'});
  await db().doc(`${E}/messages/disputed`).set({
    senderId: 'owner',
    kind: 'settlement_disputed',
    payerId: 'ann',
    payeeId: 'owner',
  });
  await db().doc(`${E}/urgentRates/ann`).set({sentAt: [1]});
  await user('ann');
  await user('bob');
});
afterAll(() => ftest.cleanup());

describe('organizers on deletion (Req 18a)', () => {
  test('the personal organizer goes, and the event moves to the next owner', async () => {
    await user('owner');
    await db().doc(E).update({organizerId: 'owner'});
    await db().doc('organizers/owner').set({ownerId: 'owner', verified: false});
    await remove('owner');
    expect(await exists('organizers/owner')).toBe(false);
    const event = await read(E);
    expect(event.organizerId).toBe(event.creatorId);
    expect(event.organizerId).not.toBe('owner');
    expect((await read(`organizers/${event.creatorId}`)).ownerId).toBe(event.creatorId);
  });

  test('moving an event keeps the next owner\'s verified flag', async () => {
    await user('owner');
    await db().doc(E).update({organizerId: 'owner'});
    await db().doc('organizers/ann').set({ownerId: 'ann', verified: true});
    await remove('owner');
    const event = await read(E);
    expect(event.creatorId).toBe('ann');
    expect((await read('organizers/ann')).verified).toBe(true);
  });

  test('another person leaving does not change the organizer', async () => {
    await user('ann');
    await db().doc(E).update({organizerId: 'owner'});
    await remove('ann');
    expect((await read(E)).organizerId).toBe('owner');
  });
});

describe('who becomes Owner when the Owner deletes their account (Req 14b)', () => {
  const {Timestamp} = require('firebase-admin/firestore');
  const at = (day: number) => Timestamp.fromDate(new Date(2026, 0, day));
  async function members(list: [string, string[], number][]) {
    await db().doc(E).update({memberIds: list.map(([uid]) => uid)});
    for (const [uid, roleIds, day] of list) {
      await db().doc(`${E}/members/${uid}`).set({uid, roleIds, permissions: [], joinedAt: at(day)});
    }
  }

  test('a Co-owner first, even over an Admin who joined earlier', async () => {
    await user('owner');
    await members([['owner', ['owner'], 1], ['ann', ['admin'], 2], ['bob', ['coOwner'], 5]]);
    await remove('owner');
    expect((await read(E)).creatorId).toBe('bob');
    expect((await read(`${E}/members/bob`)).roleIds).toEqual(['owner']);
  });

  test('else the longest-standing Admin', async () => {
    await user('owner');
    await members([['owner', ['owner'], 1], ['bob', ['admin'], 9], ['ann', ['admin'], 3]]);
    await remove('owner');
    expect((await read(E)).creatorId).toBe('ann');
  });

  test('else the longest-standing member', async () => {
    await user('owner');
    await members([['owner', ['owner'], 1], ['ann', ['participant'], 7], ['bob', ['volunteer'], 4]]);
    await remove('owner');
    expect((await read(E)).creatorId).toBe('bob');
    expect((await read(`${E}/members/bob`)).roleIds).toEqual(['volunteer', 'owner']);
  });

  test('a pending ownership offer is cleared', async () => {
    await user('owner');
    await db().doc(`${E}/ownership/offer`).set({from: 'owner', to: 'ann'});
    await remove('owner');
    expect(await exists(`${E}/ownership/offer`)).toBe(false);
  });
});

describe('deleting an account', () => {
  test('removes every personal document', async () => {
    await remove('ann');
    for (const path of [
      'users/ann',
      'users/ann/private/profile',
      'users/ann/private/other',
      'users/ann/chatReads/shared',
      'users/ann/eventMutes/shared',
      `${E}/urgentRates/ann`,
    ]) {
      expect(await exists(path)).toBe(false);
    }
  });

  test('leaves no trace of the user ID in shared records', async () => {
    await remove('ann');
    const docs = [
      await read(E),
      await read(`${E}/expenses/annPaid`),
      await read(`${E}/expenses/ownerPaid`),
      await read(`${E}/tasks/made`),
      await read(`${E}/tasks/done`),
      await read(`${E}/messages/said`),
      await read(`${E}/messages/disputed`),
    ];
    expect(JSON.stringify(docs)).not.toMatch(/"ann"/);
  });

  test('uses one anonymous ID across every field', async () => {
    await remove('ann');
    const paid = await read(`${E}/expenses/annPaid`);
    const anon = paid.payerId;
    expect(anon).toMatch(/^deleted_/);
    expect(paid.splits[0].userId).toBe(anon);
    expect(paid.involvedUids).toContain(anon);
    expect(paid.involvedUids).not.toContain('ann');
    expect(paid.involvedUids).toContain('bob');
    expect((await read(`${E}/expenses/ownerPaid`)).splits[0].userId).toBe(anon);
    expect((await read(`${E}/tasks/made`)).createdBy).toBe(anon);
    expect((await read(`${E}/tasks/done`)).completedBy).toBe(anon);
    expect((await read(`${E}/messages/said`)).senderId).toBe(anon);
    expect((await read(`${E}/messages/disputed`)).payerId).toBe(anon);
  });

  test('keeps other people and amounts as they were', async () => {
    await remove('ann');
    const paid = await read(`${E}/expenses/annPaid`);
    expect(paid.amount).toBe(30);
    expect(paid.splits[1]).toEqual({userId: 'bob', amount: 10});
    expect((await read(`${E}/expenses/unrelated`)).payerId).toBe('owner');
    expect((await read(`${E}/tasks/made`)).completedBy).toBe('owner');
  });

  test('unassigns their tasks', async () => {
    await remove('ann');
    expect((await read(`${E}/tasks/made`)).assigneeId).toBeNull();
    expect((await read(`${E}/tasks/done`)).assigneeId).toBe('owner');
  });

  test('the ledger still balances, with the same debts', async () => {
    const load = async () =>
      (await db().collection(`${E}/expenses`).get()).docs.map((d) => d.data());
    const before = netBalances(await load());
    await remove('ann');
    const after = netBalances(await load());
    const anon = (await read(`${E}/expenses/annPaid`)).payerId;
    expect(Object.values(after).reduce((a, b) => a + b, 0)).toBeCloseTo(0);
    expect(after[anon]).toBeCloseTo(before.ann);
    expect(after.bob).toBeCloseTo(before.bob);
    expect(after.owner).toBeCloseTo(before.owner);
  });

  test('two deleted people are never merged', async () => {
    await remove('ann');
    await remove('bob');
    const paid = await read(`${E}/expenses/annPaid`);
    expect(paid.payerId).not.toBe(paid.splits[1].userId);
    expect(new Set(paid.splits.map((s: {userId: string}) => s.userId)).size).toBe(3);
  });

  test('the same person gets a different ID in another event', async () => {
    const other = 'events/other';
    await db().doc(other).set({creatorId: 'owner', adminIds: ['owner'], memberIds: ['owner', 'ann']});
    await db().doc(`${other}/messages/m`).set({senderId: 'ann', text: 'hi'});
    await remove('ann');
    const here = (await read(`${E}/messages/said`)).senderId;
    const there = (await read(`${other}/messages/m`)).senderId;
    expect(here).toMatch(/^deleted_/);
    expect(there).toMatch(/^deleted_/);
    expect(here).not.toBe(there);
  });

  test('members cannot read the secret behind anonymous IDs', async () => {
    const {getTestEnv} = require('../setup'); // eslint-disable-line
    const {assertFails} = require('@firebase/rules-unit-testing'); // eslint-disable-line
    const {doc, getDoc} = require('firebase/firestore'); // eslint-disable-line
    const env = await getTestEnv();
    await env.withSecurityRulesDisabled(async (ctx: any) => { // eslint-disable-line
      const {setDoc} = require('firebase/firestore'); // eslint-disable-line
      await setDoc(doc(ctx.firestore(), E), {memberIds: ['owner']});
    });
    await assertFails(
      getDoc(doc(env.authenticatedContext('owner').firestore(), `${E}/anonymisation/secret`))
    );
    await env.cleanup();
  });

  test('a retry after a partial failure uses the same anonymous ID', async () => {
    // First run stops part-way: this expense is left with the real ID.
    const {anonymizeUserInEvent} = require('../../src/account/deleteUserAccount'); // eslint-disable-line
    const event = await read(E);
    await anonymizeUserInEvent(db().doc(E), event, 'ann');
    const anon = (await read(`${E}/expenses/annPaid`)).payerId;
    await db().doc(`${E}/expenses/late`).set({
      payerId: 'ann',
      amount: 1,
      splits: [{userId: 'ann', amount: 1}],
    });
    await anonymizeUserInEvent(db().doc(E), event, 'ann');
    expect((await read(`${E}/expenses/late`)).payerId).toBe(anon);
  });

  test('after a failure part-way, the person stays listed so a retry finds the event', async () => {
    const {anonymizeUserInEvent} = require('../../src/account/deleteUserAccount'); // eslint-disable-line
    const batch = require('../../src/utils/batch'); // eslint-disable-line
    const failure = jest.spyOn(batch, 'commitInChunks').mockRejectedValueOnce(new Error('blip'));
    await expect(anonymizeUserInEvent(db().doc(E), await read(E), 'ann')).rejects.toThrow('blip');
    failure.mockRestore();
    expect((await read(E)).memberIds).toContain('ann');

    await anonymizeUserInEvent(db().doc(E), await read(E), 'ann');
    expect((await read(E)).memberIds).toEqual(['owner', 'bob']);
    expect((await read(E)).memberCount).toBe(2);
  });

  test('an only member takes the whole event with them', async () => {
    const solo = 'events/solo';
    await db().doc(solo).set({creatorId: 'ann', adminIds: ['ann'], memberIds: ['ann']});
    await db().doc(`${solo}/tasks/t`).set({createdBy: 'ann'});
    await db().doc(`${solo}/tasks/t/checklist/c`).set({text: 'x'});
    await db().doc('users/ann/chatReads/solo').set({lastReadAt: 'x'});
    await remove('ann');
    expect(await exists(solo)).toBe(false);
    expect(await exists(`${solo}/tasks/t/checklist/c`)).toBe(false);
  });
});

describe('deleting an event', () => {
  const seedAll = async () => {
    await db().doc(`${E}/tasks/made/checklist/c1`).set({text: 'x'});
    await db().doc(`${E}/anonymisation/secret`).set({value: 'x'});
    await db().doc(`${E}/somethingNew/doc`).set({value: 'x'});
    await db().doc('event_invites/ABC234').set({eventId: 'shared'});
  };

  test('removes checklists and every subcollection', async () => {
    await seedAll();
    await ftest.wrap(deleteEvent)({auth: {uid: 'owner'}, data: {eventId: 'shared'}});
    for (const path of [
      E,
      `${E}/tasks/made`,
      `${E}/tasks/made/checklist/c1`,
      `${E}/expenses/annPaid`,
      `${E}/messages/said`,
      `${E}/urgentRates/ann`,
      `${E}/anonymisation/secret`,
      `${E}/somethingNew/doc`,
      'event_invites/ABC234',
    ]) {
      expect(await exists(path)).toBe(false);
    }
  });

  test("removes members' personal documents for that event only", async () => {
    await seedAll();
    await db().doc('users/ann/chatReads/elsewhere').set({lastReadAt: 'x'});
    await ftest.wrap(deleteEvent)({auth: {uid: 'owner'}, data: {eventId: 'shared'}});
    expect(await exists('users/ann/chatReads/shared')).toBe(false);
    expect(await exists('users/ann/eventMutes/shared')).toBe(false);
    expect(await exists('users/bob/chatReads/shared')).toBe(false);
    expect(await exists('users/ann/chatReads/elsewhere')).toBe(true);
    expect(await exists('users/ann')).toBe(true);
  });
});
