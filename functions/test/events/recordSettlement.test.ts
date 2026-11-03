/**
 * Req 7-8 (FND-01, FND-02): a settlement and its chat notice are written
 * together by the server, so neither can be forged.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
// eslint-disable-next-line @typescript-eslint/no-var-requires
const {recordSettlement} = require('../../src/events/recordSettlement');

const E = 'evt';
const call = (uid: string | null, data: object) =>
  ftest.wrap(recordSettlement)({auth: uid ? {uid} : undefined, data});
const input = (over: object = {}) => ({
  eventId: E,
  settlementId: 's1',
  payerId: 'payer',
  payeeId: 'payee',
  amount: 25,
  ...over,
});
const expense = () => getAdminDb().doc(`events/${E}/expenses/s1`).get();
const notice = () => getAdminDb().doc(`events/${E}/messages/s1`).get();
const rejected = (code: string) => expect.objectContaining({code});

async function seedEvent(over: object = {}) {
  await getAdminDb().doc(`events/${E}`).set({
    creatorId: 'owner',
    adminIds: ['owner'],
    memberIds: ['owner', 'payer', 'payee'],
    currency: 'USD',
    ...over,
  });
}

beforeEach(async () => {
  await clearFirestoreEmulator();
  await seedEvent();
});
afterAll(() => ftest.cleanup());

describe('recordSettlement', () => {
  test('writes the payment', async () => {
    await call('payer', input());
    const saved = (await expense()).data()!;
    expect(saved.isPayment).toBe(true);
    expect(saved.payerId).toBe('payer');
    expect(saved.amount).toBe(25);
    expect(saved.eventId).toBe(E);
    expect(saved.splits).toEqual([{userId: 'payee', amount: 25}]);
    expect([...saved.involvedUids].sort()).toEqual(['payee', 'payer']);
  });

  test('writes the notice under the same ID', async () => {
    await call('payer', input());
    const saved = (await notice()).data()!;
    expect(saved.kind).toBe('settlement');
    expect(saved.senderId).toBe('payer');
    expect(saved.text).toBe('Settled $25.00 with a member');
    expect(saved.isHighPriority).toBe(false);
    expect(saved.timestamp).toBeDefined();
  });

  test.each([
    ['EUR', '€'],
    ['GBP', '£'],
    ['INR', '₹'],
    ['JPY', '¥'],
    ['CAD', '$'],
  ])('uses the symbol for %s', async (currency, symbol) => {
    await seedEvent({currency});
    await call('payer', input());
    expect((await notice()).data()!.text).toBe(`Settled ${symbol}25.00 with a member`);
  });

  test('ignores text and other fields sent by the client', async () => {
    await call('payer', input({text: 'Settled $9999', kind: 'forged', isPayment: false}));
    expect((await notice()).data()!.text).toBe('Settled $25.00 with a member');
    expect((await notice()).data()!.kind).toBe('settlement');
    expect((await expense()).data()!.isPayment).toBe(true);
  });

  test('a retry is safe and writes one of each', async () => {
    await call('payer', input());
    await call('payer', input());
    const expenses = await getAdminDb().collection(`events/${E}/expenses`).get();
    const messages = await getAdminDb().collection(`events/${E}/messages`).get();
    expect(expenses.size).toBe(1);
    expect(messages.size).toBe(1);
  });

  test('cannot reuse an ID for a different settlement', async () => {
    await call('payer', input());
    await expect(call('payer', input({amount: 99}))).rejects.toEqual(rejected('already-exists'));
    expect((await expense()).data()!.amount).toBe(25);
  });

  test('cannot overwrite an ordinary expense', async () => {
    await getAdminDb().doc(`events/${E}/expenses/s1`).set({payerId: 'payer', amount: 5});
    await expect(call('payer', input())).rejects.toEqual(rejected('already-exists'));
    expect((await expense()).data()!.amount).toBe(5);
  });

  test('needs a signed-in caller', async () => {
    await expect(call(null, input())).rejects.toEqual(rejected('unauthenticated'));
  });

  test('needs the event to exist', async () => {
    await expect(call('payer', input({eventId: 'nope'}))).rejects.toEqual(rejected('not-found'));
  });

  test('the caller must be the payer', async () => {
    await expect(call('owner', input())).rejects.toEqual(rejected('permission-denied'));
    expect((await expense()).exists).toBe(false);
    expect((await notice()).exists).toBe(false);
  });

  test('the caller must be a member', async () => {
    await expect(call('stranger', input({payerId: 'stranger'}))).rejects.toEqual(
      rejected('permission-denied')
    );
  });

  test('a removed payer cannot record', async () => {
    await seedEvent({memberIds: ['owner', 'payee']});
    await expect(call('payer', input())).rejects.toEqual(rejected('permission-denied'));
  });

  test('the payee must be a member', async () => {
    await expect(call('payer', input({payeeId: 'stranger'}))).rejects.toEqual(
      rejected('invalid-argument')
    );
  });

  test('you cannot pay yourself', async () => {
    await expect(call('payer', input({payeeId: 'payer'}))).rejects.toEqual(
      rejected('invalid-argument')
    );
  });

  test.each([
    ['zero', 0],
    ['negative', -5],
    ['a string', '25'],
    ['NaN', NaN],
    ['infinite', Infinity],
    ['over the maximum', 10000000.01],
  ])('rejects an amount that is %s', async (_name, amount) => {
    await expect(call('payer', input({amount}))).rejects.toEqual(rejected('invalid-argument'));
    expect((await expense()).exists).toBe(false);
    expect((await notice()).exists).toBe(false);
  });
});
