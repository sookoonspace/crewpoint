/* eslint-disable */
// Acceptance tests for the Stage 1 foundation fixes. Test names start with the
// scenario ID. Runs on the emulators only.
import {RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {assertFails} from '@firebase/rules-unit-testing';
import {doc, setDoc, updateDoc} from 'firebase/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb, getTestEnv} from '../test/setup';

const mockSendEach = jest.fn();
jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({sendEach: mockSendEach}),
}));

const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {saveExpense} = require('../src/events/saveExpense');
const {recordSettlement} = require('../src/events/recordSettlement');
const {createEvent} = require('../src/events/createEvent');
const {handleUrgentMessage} = require('../src/events/onUrgentMessageCreated');

const E = 'foundation';
const call = (uid: string, data: object) => ftest.wrap(saveExpense)({auth: {uid}, data});
const invalid = expect.objectContaining({code: 'invalid-argument'});

afterAll(() => ftest.cleanup());

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
  afterAll(() => env.cleanup());

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

  test('FND-01 rules deny a direct settlement payment', async () => {
    const db = env.authenticatedContext('member').firestore();
    await assertFails(
      setDoc(doc(db, `events/${E}/expenses/forged`), {
        eventId: E,
        payerId: 'member',
        amount: 1000,
        isPayment: true,
        splits: [{userId: 'owner', amount: 1000}],
      })
    );
  });

  test('FND-01 the settlement callable rejects a forged amount', async () => {
    const settlement = {eventId: E, settlementId: 's', payerId: 'member', payeeId: 'owner'};
    for (const amount of [0, -1, NaN, Infinity, 1e12]) {
      await expect(
        ftest.wrap(recordSettlement)({auth: {uid: 'member'}, data: {...settlement, amount}})
      ).rejects.toEqual(invalid);
    }
  });

  test('FND-02 a member cannot forge a settlement notice', async () => {
    const db = env.authenticatedContext('member').firestore();
    await assertFails(
      setDoc(doc(db, `events/${E}/messages/forged`), {
        senderId: 'member',
        text: 'Settled $1000 with a member',
        kind: 'settlement',
      })
    );
  });

  test('FND-02 a member cannot forge a disputed notice', async () => {
    const db = env.authenticatedContext('member').firestore();
    await assertFails(
      setDoc(doc(db, `events/${E}/messages/forged`), {
        senderId: 'member',
        text: 'Settlement disputed',
        kind: 'settlement_disputed',
      })
    );
  });

  test('FND-02 the server writes the payment and its notice together', async () => {
    await ftest.wrap(recordSettlement)({
      auth: {uid: 'member'},
      data: {eventId: E, settlementId: 's', payerId: 'member', payeeId: 'owner', amount: 12},
    });
    const payment = (await getAdminDb().doc(`events/${E}/expenses/s`).get()).data()!;
    const notice = (await getAdminDb().doc(`events/${E}/messages/s`).get()).data()!;
    expect(payment.isPayment).toBe(true);
    expect(notice.kind).toBe('settlement');
  });

  test('FND-01 rules deny a direct expense edit', async () => {
    const db = env.authenticatedContext('member').firestore();
    await assertFails(updateDoc(doc(db, `events/${E}/expenses/old`), {amount: 9999}));
  });
});

describe('FND-03 strangers', () => {
  let env: RulesTestEnvironment;
  const event = {creatorId: 'owner', adminIds: ['owner'], memberIds: ['owner'], title: 'Trip'};

  beforeAll(async () => {
    env = await getTestEnv();
  });
  beforeEach(async () => {
    await clearFirestoreEmulator();
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'events/mine'), event);
    });
  });
  afterAll(() => env.cleanup());

  const asOwner = () => env.authenticatedContext('owner').firestore();

  test('FND-03 a client cannot create an event listing a stranger', async () => {
    await assertFails(
      setDoc(doc(asOwner(), 'events/new'), {
        ...event,
        memberIds: ['owner', 'stranger'],
      })
    );
  });

  test('FND-03 a client cannot add a stranger to an event', async () => {
    await assertFails(
      updateDoc(doc(asOwner(), 'events/mine'), {memberIds: ['owner', 'stranger']})
    );
  });

  test('FND-03 the callable ignores members sent by the client', async () => {
    await ftest.wrap(createEvent)({
      auth: {uid: 'owner'},
      data: {eventId: 'made', title: 'Trip', memberIds: ['owner', 'stranger']},
    });
    const saved = (await getAdminDb().doc('events/made').get()).data()!;
    expect(saved.memberIds).toEqual(['owner']);
    expect(saved.creatorId).toBe('owner');
  });
});

describe('FND-04 urgent messages', () => {
  let env: RulesTestEnvironment;
  const event = {
    title: 'Trip',
    creatorId: 'owner',
    adminIds: ['owner'],
    memberIds: ['owner', 'member'],
  };
  const NOW = Date.UTC(2027, 0, 1);

  beforeAll(async () => {
    env = await getTestEnv();
  });
  beforeEach(async () => {
    await clearFirestoreEmulator();
    await env.clearFirestore();
    mockSendEach.mockReset();
    mockSendEach.mockImplementation(async (m: unknown[]) => ({
      responses: m.map(() => ({success: true})),
    }));
    await getAdminDb().doc('events/urgent').set(event);
    await getAdminDb().doc('users/member/private/profile').set({fcmTokens: ['tok']});
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'events/urgent'), event);
    });
  });
  afterAll(() => env.cleanup());

  async function urgentFrom(id: string, at: number) {
    const ref = getAdminDb().doc(`events/urgent/messages/${id}`);
    const data = {senderId: 'owner', text: 'Fire', isHighPriority: true};
    await ref.set(data);
    await handleUrgentMessage({eventId: 'urgent', messageId: id, data, ref, now: () => at});
    return ref;
  }

  test('FND-04 sending urgent needs permission', async () => {
    const db = env.authenticatedContext('member').firestore();
    await assertFails(
      setDoc(doc(db, 'events/urgent/messages/m'), {
        senderId: 'member',
        text: 'Fire',
        isHighPriority: true,
      })
    );
  });

  test('FND-04 message text is limited to 4,000 characters', async () => {
    const db = env.authenticatedContext('member').firestore();
    await assertFails(
      setDoc(doc(db, 'events/urgent/messages/m'), {senderId: 'member', text: 'a'.repeat(4001)})
    );
  });

  test('FND-04 over the rate, the message is saved with no push, and flagged', async () => {
    for (let i = 0; i < 5; i++) await urgentFrom(`m${i}`, NOW + i);
    expect(mockSendEach).toHaveBeenCalledTimes(5);

    const sixth = await urgentFrom('m5', NOW + 5);
    expect(mockSendEach).toHaveBeenCalledTimes(5);
    const saved = (await sixth.get()).data()!;
    expect(saved.text).toBe('Fire');
    expect(saved.urgentPushSkipped).toBe(true);
  });
});
