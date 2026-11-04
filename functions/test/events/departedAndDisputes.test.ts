/**
 * Req 15-16 (FND-09, FND-10): debts of departed people can still be settled, and
 * disputes are limited by an event setting.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
/* eslint-disable @typescript-eslint/no-var-requires */
const {recordSettlement} = require('../../src/events/recordSettlement');
const {disputeSettlement} = require('../../src/events/disputeSettlement');
const {clock} = require('../../src/utils/clock');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const DAY = 24 * 60 * 60 * 1000;
const db = () => getAdminDb();
const record = (uid: string, payerId: string, payeeId: string, id = 's1') =>
  ftest.wrap(recordSettlement)({
    auth: {uid},
    data: {eventId: E, settlementId: id, payerId, payeeId, amount: 25},
  });
const dispute = (uid: string, id = 's1') =>
  ftest.wrap(disputeSettlement)({auth: {uid}, data: {eventId: E, settlementId: id}});
const rejected = (code: string) => expect.objectContaining({code});

async function seedEvent(over: object = {}) {
  await db().doc(`events/${E}`).set({
    creatorId: 'owner',
    adminIds: ['owner', 'admin'],
    memberIds: ['owner', 'admin', 'member', 'other'],
    currency: 'USD',
    ...over,
  });
}

beforeEach(async () => {
  await clearFirestoreEmulator();
  await seedEvent();
  // `gone` left the event owing `member`. The older record has no involvedUids.
  await db().doc(`events/${E}/expenses/old`).set({
    payerId: 'member',
    amount: 50,
    splits: [
      {userId: 'gone', amount: 25},
      {userId: 'member', amount: 25},
    ],
  });
  await db().doc(`events/${E}/expenses/paidByGone2`).set({
    payerId: 'gone2',
    amount: 10,
    involvedUids: ['gone2', 'member'],
    splits: [{userId: 'member', amount: 10}],
  });
});
afterEach(() => jest.restoreAllMocks());
afterAll(() => ftest.cleanup());

describe('settling for departed people', () => {
  test.each(['owner', 'admin'])('%s can record a payment from a departed person', async (uid) => {
    await record(uid, 'gone', 'member');
    const saved = (await db().doc(`events/${E}/expenses/s1`).get()).data()!;
    expect(saved.payerId).toBe('gone');
    expect(saved.isPayment).toBe(true);
    expect(saved.splits).toEqual([{userId: 'member', amount: 25}]);
    expect(saved.recordedBy).toBe(uid);
    const notice = (await db().doc(`events/${E}/messages/s1`).get()).data()!;
    expect(notice.senderId).toBe(uid);
    expect(notice.kind).toBe('settlement');
    expect(notice.text).toBe('Settled $25.00 on behalf of a former member');
  });

  test('an admin can record a payment to a departed person', async () => {
    await record('admin', 'member', 'gone2');
    const saved = (await db().doc(`events/${E}/expenses/s1`).get()).data()!;
    expect(saved.splits[0].userId).toBe('gone2');
  });

  test('an admin paying a departed person themselves is worded for that', async () => {
    await db().doc(`events/${E}/expenses/adminOwes`).set({
      payerId: 'gone2',
      amount: 5,
      splits: [{userId: 'admin', amount: 5}],
    });
    await record('admin', 'admin', 'gone2');
    const notice = (await db().doc(`events/${E}/messages/s1`).get()).data()!;
    expect(notice.text).toBe('Settled $25.00 with a former member');
  });

  test('an anonymised deleted person counts as departed', async () => {
    await db().doc(`events/${E}/expenses/anon`).set({
      payerId: 'member',
      amount: 5,
      splits: [{userId: 'deleted_abc', amount: 5}],
    });
    await record('admin', 'deleted_abc', 'member');
    expect((await db().doc(`events/${E}/expenses/s1`).get()).exists).toBe(true);
  });

  test('a member without the permission cannot', async () => {
    await expect(record('other', 'gone', 'member')).rejects.toEqual(rejected('permission-denied'));
    await expect(record('member', 'member', 'gone')).rejects.toEqual(rejected('permission-denied'));
    expect((await db().doc(`events/${E}/expenses/s1`).get()).exists).toBe(false);
  });

  test('an admin cannot record for someone still in the event', async () => {
    await expect(record('admin', 'member', 'other')).rejects.toEqual(rejected('permission-denied'));
  });

  test('a stranger with no history in the event cannot be used', async () => {
    await expect(record('admin', 'stranger', 'member')).rejects.toEqual(
      rejected('invalid-argument')
    );
    await expect(record('admin', 'member', 'stranger')).rejects.toEqual(
      rejected('invalid-argument')
    );
  });

  test('someone not in the event cannot record at all', async () => {
    await expect(record('gone', 'gone', 'member')).rejects.toEqual(rejected('permission-denied'));
  });

  test('both sides can be departed', async () => {
    await record('admin', 'gone', 'gone2');
    expect((await db().doc(`events/${E}/expenses/s1`).get()).exists).toBe(true);
  });

  test('whoever recorded it can dispute it', async () => {
    await record('admin', 'gone', 'member');
    await dispute('admin');
    expect((await db().doc(`events/${E}/expenses/s1`).get()).exists).toBe(false);
  });
});

describe('the dispute window', () => {
  async function settledAgo(days: number) {
    await record('member', 'member', 'other');
    const created = (await db().doc(`events/${E}/expenses/s1`).get()).createTime!.toMillis();
    jest.spyOn(clock, 'now').mockReturnValue(created + days * DAY);
  }

  test('a dispute within 30 days works by default', async () => {
    await settledAgo(29);
    await dispute('other');
    expect((await db().doc(`events/${E}/expenses/s1`).get()).exists).toBe(false);
  });

  test('a dispute after 30 days is refused, and keeps the settlement', async () => {
    await settledAgo(31);
    await expect(dispute('other')).rejects.toEqual(rejected('failed-precondition'));
    expect((await db().doc(`events/${E}/expenses/s1`).get()).exists).toBe(true);
    const notice = (await db().doc(`events/${E}/messages/s1`).get()).data()!;
    expect(notice.kind).toBe('settlement');
  });

  test('an event setting changes the window', async () => {
    await seedEvent({settings: {disputeWindowDays: 7}});
    await settledAgo(8);
    await expect(dispute('other')).rejects.toEqual(rejected('failed-precondition'));
  });

  test('a longer setting allows a later dispute', async () => {
    await seedEvent({settings: {disputeWindowDays: 60}});
    await settledAgo(45);
    await dispute('other');
    expect((await db().doc(`events/${E}/expenses/s1`).get()).exists).toBe(false);
  });

  test('an invalid setting falls back to 30 days', async () => {
    await seedEvent({settings: {disputeWindowDays: 'soon'}});
    await settledAgo(31);
    await expect(dispute('other')).rejects.toEqual(rejected('failed-precondition'));
  });
});
