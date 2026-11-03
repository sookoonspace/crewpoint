/**
 * Req 6 (FND-01): expense create and edit go through `saveExpense`, because
 * Firestore rules cannot loop over splits.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
// eslint-disable-next-line @typescript-eslint/no-var-requires
const {saveExpense} = require('../../src/events/saveExpense');

const E = 'evt';
const call = (uid: string | null, data: object) =>
  ftest.wrap(saveExpense)({auth: uid ? {uid} : undefined, data});

const input = (over: object = {}) => ({
  eventId: E,
  expenseId: 'exp1',
  payerId: 'payer',
  amount: 30,
  description: 'Dinner',
  isDonation: false,
  splits: [
    {userId: 'payer', amount: 15},
    {userId: 'other', amount: 15},
  ],
  ...over,
});

const expenseDoc = (id = 'exp1') => getAdminDb().doc(`events/${E}/expenses/${id}`);

async function seedEvent(over: object = {}) {
  await getAdminDb().doc(`events/${E}`).set({
    creatorId: 'owner',
    adminIds: ['owner', 'admin'],
    memberIds: ['owner', 'admin', 'payer', 'other'],
    title: 'Trip',
    ...over,
  });
}

async function seedExpense(over: object = {}) {
  await expenseDoc().set({
    eventId: E,
    payerId: 'payer',
    amount: 30,
    description: 'Dinner',
    isDonation: false,
    isPayment: false,
    splits: [
      {userId: 'payer', amount: 15},
      {userId: 'other', amount: 15},
    ],
    ...over,
  });
}

const rejected = (code: string) => expect.objectContaining({code});

beforeEach(async () => {
  await clearFirestoreEmulator();
  await seedEvent();
});
afterAll(() => ftest.cleanup());

describe('saveExpense: creating', () => {
  test('saves the expense with involvedUids', async () => {
    await call('payer', input());
    const saved = (await expenseDoc().get()).data()!;
    expect(saved.amount).toBe(30);
    expect(saved.eventId).toBe(E);
    expect(saved.payerId).toBe('payer');
    expect(saved.description).toBe('Dinner');
    expect(saved.isPayment).toBe(false);
    expect(saved.splits).toHaveLength(2);
    expect(saved.updatedAt).toBeDefined();
    expect([...saved.involvedUids].sort()).toEqual(['other', 'payer']);
  });

  test('involvedUids includes a payer who is not in the splits', async () => {
    await call('payer', input({isDonation: true, splits: [{userId: 'other', amount: 30}]}));
    const saved = (await expenseDoc().get()).data()!;
    expect([...saved.involvedUids].sort()).toEqual(['other', 'payer']);
  });

  test('always saves as a non-payment, whatever the client sends', async () => {
    await call('payer', input({isPayment: true}));
    expect((await expenseDoc().get()).data()!.isPayment).toBe(false);
  });

  test('a retry after a lost response is safe', async () => {
    await call('payer', input());
    await call('payer', input());
    expect((await expenseDoc().get()).data()!.amount).toBe(30);
  });

  test('needs a signed-in caller', async () => {
    await expect(call(null, input())).rejects.toEqual(rejected('unauthenticated'));
  });

  test('needs the event to exist', async () => {
    await expect(call('payer', input({eventId: 'nope'}))).rejects.toEqual(rejected('not-found'));
  });

  test('a non-member cannot add an expense', async () => {
    await expect(call('stranger', input({payerId: 'stranger'}))).rejects.toEqual(
      rejected('permission-denied')
    );
    expect((await expenseDoc().get()).exists).toBe(false);
  });

  test('a member can only add an expense as its payer', async () => {
    await expect(call('other', input())).rejects.toEqual(rejected('permission-denied'));
    await expect(call('owner', input())).rejects.toEqual(rejected('permission-denied'));
  });
});

describe('saveExpense: validating money', () => {
  test.each([
    ['zero', 0],
    ['negative', -5],
    ['a string', '30'],
    ['missing', undefined],
    ['NaN', NaN],
    ['infinite', Infinity],
  ])('rejects an amount that is %s', async (_name, amount) => {
    await expect(call('payer', input({amount}))).rejects.toEqual(rejected('invalid-argument'));
    expect((await expenseDoc().get()).exists).toBe(false);
  });

  test('rejects an amount over the default maximum', async () => {
    const splits = [{userId: 'payer', amount: 10000000.01}];
    await expect(call('payer', input({amount: 10000000.01, splits}))).rejects.toEqual(
      rejected('invalid-argument')
    );
  });

  test('accepts an amount at the default maximum', async () => {
    const splits = [{userId: 'payer', amount: 10000000}];
    await call('payer', input({amount: 10000000, splits}));
    expect((await expenseDoc().get()).exists).toBe(true);
  });

  test('an event setting can lower the maximum', async () => {
    await seedEvent({settings: {maxExpenseAmount: 20}});
    await expect(call('payer', input())).rejects.toEqual(rejected('invalid-argument'));
  });

  test('accepts a total within 0.01 per split', async () => {
    const splits = [
      {userId: 'payer', amount: 15.01},
      {userId: 'other', amount: 15.01},
    ];
    await call('payer', input({splits}));
    expect((await expenseDoc().get()).exists).toBe(true);
  });

  test('accepts equal thirds that do not add up exactly', async () => {
    const third = 10 / 3;
    const splits = ['payer', 'other', 'admin'].map((userId) => ({userId, amount: third}));
    await call('payer', input({amount: 10, splits}));
    expect((await expenseDoc().get()).exists).toBe(true);
  });

  test('rejects a total more than 0.01 per split away', async () => {
    const splits = [
      {userId: 'payer', amount: 15.02},
      {userId: 'other', amount: 15.02},
    ];
    await expect(call('payer', input({splits}))).rejects.toEqual(rejected('invalid-argument'));
  });

  test('rejects a negative split that balances the total', async () => {
    const splits = [
      {userId: 'payer', amount: 130},
      {userId: 'other', amount: -100},
    ];
    await expect(call('payer', input({splits}))).rejects.toEqual(rejected('invalid-argument'));
  });

  test('rejects a non-finite split', async () => {
    const splits = [{userId: 'payer', amount: Infinity}];
    await expect(call('payer', input({splits}))).rejects.toEqual(rejected('invalid-argument'));
  });

  test('rejects the same person twice in the splits', async () => {
    const splits = [
      {userId: 'other', amount: 15},
      {userId: 'other', amount: 15},
    ];
    await expect(call('payer', input({splits}))).rejects.toEqual(rejected('invalid-argument'));
  });

  test('rejects a split user who is not a member', async () => {
    const splits = [
      {userId: 'payer', amount: 15},
      {userId: 'stranger', amount: 15},
    ];
    await expect(call('payer', input({splits}))).rejects.toEqual(rejected('invalid-argument'));
  });

  test('rejects no splits', async () => {
    await expect(call('payer', input({splits: []}))).rejects.toEqual(rejected('invalid-argument'));
  });

  test('rejects no splits on a donation when others could share it', async () => {
    await expect(call('payer', input({isDonation: true, splits: []}))).rejects.toEqual(
      rejected('invalid-argument')
    );
  });

  test('an only member can record a donation with no splits', async () => {
    await seedEvent({memberIds: ['payer'], adminIds: [], creatorId: 'payer'});
    await call('payer', input({isDonation: true, splits: []}));
    const saved = (await expenseDoc().get()).data()!;
    expect(saved.involvedUids).toEqual(['payer']);
  });

  test('rejects text fields of the wrong type', async () => {
    await expect(call('payer', input({description: 5}))).rejects.toEqual(
      rejected('invalid-argument')
    );
    await expect(call('payer', input({receiptPath: 5}))).rejects.toEqual(
      rejected('invalid-argument')
    );
  });

  test('rejects an expense ID that is not a single path segment', async () => {
    await expect(call('payer', input({expenseId: 'a/b'}))).rejects.toEqual(
      rejected('invalid-argument')
    );
  });
});

describe('saveExpense: editing', () => {
  beforeEach(() => seedExpense());

  test.each(['payer', 'owner', 'admin'])('%s may edit', async (uid) => {
    await call(uid, input({amount: 40, description: 'Edited', splits: [{userId: 'other', amount: 40}]}));
    const saved = (await expenseDoc().get()).data()!;
    expect(saved.amount).toBe(40);
    expect(saved.description).toBe('Edited');
    expect([...saved.involvedUids].sort()).toEqual(['other', 'payer']);
  });

  test('another member may not edit', async () => {
    await expect(call('other', input({amount: 40}))).rejects.toEqual(rejected('permission-denied'));
    expect((await expenseDoc().get()).data()!.amount).toBe(30);
  });

  test('a removed payer may not edit', async () => {
    await seedEvent({memberIds: ['owner', 'admin', 'other']});
    await expect(call('payer', input())).rejects.toEqual(rejected('permission-denied'));
  });

  test('the payer cannot change', async () => {
    await expect(call('admin', input({payerId: 'other'}))).rejects.toEqual(
      rejected('invalid-argument')
    );
  });

  test('a settlement payment cannot be edited', async () => {
    await seedExpense({isPayment: true});
    await expect(call('payer', input())).rejects.toEqual(rejected('failed-precondition'));
  });

  test('keeps a departed person already on the expense', async () => {
    await seedEvent({memberIds: ['owner', 'admin', 'payer']});
    await call('payer', input({description: 'Kept'}));
    const saved = (await expenseDoc().get()).data()!;
    expect(saved.description).toBe('Kept');
    expect([...saved.involvedUids].sort()).toEqual(['other', 'payer']);
  });

  test('an admin can edit an expense whose payer has departed', async () => {
    await seedEvent({memberIds: ['owner', 'admin', 'other']});
    await call('admin', input({description: 'Kept'}));
    expect((await expenseDoc().get()).data()!.description).toBe('Kept');
  });

  test('cannot add a new non-member', async () => {
    const splits = [
      {userId: 'payer', amount: 15},
      {userId: 'stranger', amount: 15},
    ];
    await expect(call('payer', input({splits}))).rejects.toEqual(rejected('invalid-argument'));
  });

  test('saves and clears a receipt', async () => {
    await call('payer', input({receiptPath: 'https://x.test/r.jpg'}));
    expect((await expenseDoc().get()).data()!.receiptPath).toBe('https://x.test/r.jpg');
    await call('payer', input({receiptPath: null}));
    expect((await expenseDoc().get()).data()!.receiptPath).toBeNull();
  });
});

describe('saveExpense: existing records', () => {
  test('a stored negative payment split stays readable', async () => {
    await seedExpense({isPayment: true, splits: [{userId: 'other', amount: -30}]});
    const saved = (await expenseDoc().get()).data()!;
    expect(saved.splits[0].amount).toBe(-30);
  });
});
