/* eslint-disable */
// Acceptance tests for the Stage 1 foundation fixes. Test names start with the
// scenario ID. Runs on the emulators only.
import {RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {assertFails} from '@firebase/rules-unit-testing';
import {doc, setDoc, updateDoc} from 'firebase/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb, getTestEnv} from '../test/setup';

const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {saveExpense} = require('../src/events/saveExpense');

const E = 'foundation';
const call = (uid: string, data: object) => ftest.wrap(saveExpense)({auth: {uid}, data});
const invalid = expect.objectContaining({code: 'invalid-argument'});

describe('FND-01 money writes', () => {
  let env: RulesTestEnvironment;
  const event = {
    creatorId: 'owner',
    adminIds: ['owner'],
    memberIds: ['owner', 'member'],
    title: 'Trip',
  };
  const expense = {
    eventId: E,
    expenseId: 'exp',
    payerId: 'member',
    amount: 20,
    splits: [
      {userId: 'owner', amount: 10},
      {userId: 'member', amount: 10},
    ],
  };

  beforeAll(async () => {
    env = await getTestEnv();
  });
  beforeEach(async () => {
    await clearFirestoreEmulator();
    await env.clearFirestore();
    await getAdminDb().doc(`events/${E}`).set(event);
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `events/${E}`), event);
      await setDoc(doc(ctx.firestore(), `events/${E}/expenses/old`), {
        eventId: E,
        payerId: 'member',
        amount: 5,
      });
    });
  });
  afterAll(async () => {
    await env.cleanup();
    ftest.cleanup();
  });

  test('FND-01 the callable rejects forged amounts', async () => {
    for (const amount of [0, -1, NaN, Infinity, 1e12]) {
      await expect(call('member', {...expense, amount})).rejects.toEqual(invalid);
    }
  });

  test('FND-01 the callable rejects splits that do not add up', async () => {
    const splits = [{userId: 'owner', amount: 1}];
    await expect(call('member', {...expense, splits})).rejects.toEqual(invalid);
  });

  test('FND-01 the callable rejects non-member split users', async () => {
    const splits = [{userId: 'stranger', amount: 20}];
    await expect(call('member', {...expense, splits})).rejects.toEqual(invalid);
  });

  test('FND-01 a valid expense is saved with involvedUids', async () => {
    await call('member', expense);
    const saved = (await getAdminDb().doc(`events/${E}/expenses/exp`).get()).data()!;
    expect([...saved.involvedUids].sort()).toEqual(['member', 'owner']);
  });

  test('FND-01 rules deny a direct expense write', async () => {
    const db = env.authenticatedContext('member').firestore();
    await assertFails(
      setDoc(doc(db, `events/${E}/expenses/forged`), {
        eventId: E,
        payerId: 'member',
        amount: -1000,
        isPayment: false,
      })
    );
  });

  test('FND-01 rules deny a direct expense edit', async () => {
    const db = env.authenticatedContext('member').firestore();
    await assertFails(updateDoc(doc(db, `events/${E}/expenses/old`), {amount: 9999}));
  });
});
