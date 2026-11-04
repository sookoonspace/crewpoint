/**
 * Req 17 (FND-12): currency can change only until the event holds money, which
 * rules cannot check, so it changes only through this callable.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
// eslint-disable-next-line @typescript-eslint/no-var-requires
const {changeEventCurrency} = require('../../src/events/changeEventCurrency');

const E = 'events/evt';
const call = (uid: string | null, data: object = {eventId: 'evt', currency: 'EUR'}) =>
  ftest.wrap(changeEventCurrency)({auth: uid ? {uid} : undefined, data});
const currency = async () => (await getAdminDb().doc(E).get()).data()!.currency;
const rejected = (code: string) => expect.objectContaining({code});

beforeEach(async () => {
  await clearFirestoreEmulator();
  await getAdminDb().doc(E).set({
    creatorId: 'owner',
    adminIds: ['owner', 'admin'],
    memberIds: ['owner', 'admin', 'member'],
    currency: 'USD',
  });
});
afterAll(() => ftest.cleanup());

describe('changeEventCurrency', () => {
  test.each(['owner', 'admin'])('%s can change it while the event holds no money', async (uid) => {
    await call(uid);
    expect(await currency()).toBe('EUR');
  });

  test.each(['expenses', 'charges'])('it is refused once the event has any of %s', async (sub) => {
    await getAdminDb().doc(`${E}/${sub}/x`).set({amount: 1});
    await expect(call('owner')).rejects.toEqual(rejected('failed-precondition'));
    expect(await currency()).toBe('USD');
  });

  test.each(['member', 'stranger'])('%s is refused', async (uid) => {
    await expect(call(uid)).rejects.toEqual(rejected('permission-denied'));
    expect(await currency()).toBe('USD');
  });

  test('signing in is required', async () => {
    await expect(call(null)).rejects.toEqual(rejected('unauthenticated'));
  });

  test('a missing event is reported', async () => {
    await expect(call('owner', {eventId: 'nope', currency: 'EUR'}))
      .rejects.toEqual(rejected('not-found'));
  });

  test.each(['euro', 'eur', '', 5])('%p is not a currency code', async (value) => {
    await expect(call('owner', {eventId: 'evt', currency: value}))
      .rejects.toEqual(rejected('invalid-argument'));
    expect(await currency()).toBe('USD');
  });

  test('setting the same currency again succeeds, so a retry is safe', async () => {
    await getAdminDb().doc(`${E}/expenses/x`).set({amount: 1});
    await call('owner', {eventId: 'evt', currency: 'USD'});
    expect(await currency()).toBe('USD');
  });
});
