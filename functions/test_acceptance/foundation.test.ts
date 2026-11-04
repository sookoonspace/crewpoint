/* eslint-disable */
// Acceptance tests for the Stage 1 foundation fixes. Test names start with the
// scenario ID. Runs on the emulators only.
import {RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
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
const {markTaskComplete} = require('../src/events/markTaskComplete');
const {joinEvent} = require('../src/events/joinEvent');
const {deleteUserAccount} = require('../src/account/deleteUserAccount');
const {deleteEvent} = require('../src/events/deleteEvent');
const {disputeSettlement} = require('../src/events/disputeSettlement');
const {clock} = require('../src/utils/clock');
const {removeEventMember} = require('../src/events/removeEventMember');

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

describe('FND-05 task permissions', () => {
  let env: RulesTestEnvironment;
  const E = 'events/tasks';
  const T = `${E}/tasks/t`;
  const event = {
    creatorId: 'owner',
    adminIds: ['owner'],
    memberIds: ['owner', 'creator', 'assignee', 'member'],
  };
  const task = {eventId: 'tasks', createdBy: 'creator', assigneeId: 'assignee', status: 'todo', title: 'X'};
  const as = (uid: string) => env.authenticatedContext(uid).firestore();

  beforeAll(async () => {
    env = await getTestEnv();
  });
  beforeEach(async () => {
    await clearFirestoreEmulator();
    await env.clearFirestore();
    await getAdminDb().doc(E).set(event);
    await getAdminDb().doc(T).set(task);
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), E), event);
      await setDoc(doc(ctx.firestore(), T), task);
    });
  });
  afterAll(() => env.cleanup());

  test('FND-05 an assignee may change status, and nothing else', async () => {
    await assertSucceeds(updateDoc(doc(as('assignee'), T), {status: 'in_progress'}));
    await assertFails(updateDoc(doc(as('assignee'), T), {title: 'Changed'}));
  });

  test('FND-05 the creator and managers may edit, and other members may not', async () => {
    await assertSucceeds(updateDoc(doc(as('creator'), T), {title: 'A'}));
    await assertSucceeds(updateDoc(doc(as('owner'), T), {title: 'B'}));
    await assertFails(updateDoc(doc(as('member'), T), {title: 'C'}));
  });

  test('FND-05 clients cannot write completion directly', async () => {
    await assertFails(updateDoc(doc(as('owner'), T), {status: 'done'}));
    await assertFails(updateDoc(doc(as('owner'), T), {completedBy: 'owner'}));
    await assertFails(updateDoc(doc(as('owner'), T), {completedAt: new Date()}));
  });

  test('FND-05 a second completion keeps the first completedBy', async () => {
    const complete = ftest.wrap(markTaskComplete);
    await complete({auth: {uid: 'assignee'}, data: {eventId: 'tasks', taskId: 't'}});
    await complete({auth: {uid: 'owner'}, data: {eventId: 'tasks', taskId: 't'}});
    expect((await getAdminDb().doc(T).get()).data()!.completedBy).toBe('assignee');
  });
});

describe('FND-06 member limit', () => {
  const join = (uid: string) =>
    ftest.wrap(joinEvent)({auth: {uid}, data: {joinCode: 'LIMIT2'}});

  async function seed(over: object) {
    await clearFirestoreEmulator();
    await getAdminDb().doc('events/full').set({
      title: 'Trip',
      creatorId: 'owner',
      adminIds: ['owner'],
      memberIds: ['owner'],
      memberCount: 1,
      ...over,
    });
    await getAdminDb().doc('event_invites/LIMIT2').set({
      eventId: 'full',
      expiresAt: new Date(Date.now() + 86400000),
    });
  }

  test('FND-06 8 simultaneous joins at one place remaining admit exactly 1', async () => {
    await seed({memberLimit: 2});
    const results = await Promise.allSettled(
      Array.from({length: 8}, (_, i) => join(`j${i}`))
    );
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    const saved = (await getAdminDb().doc('events/full').get()).data()!;
    expect(saved.memberIds).toHaveLength(2);
    expect(saved.memberCount).toBe(2);
  });

  test('FND-06 with no memberLimit, joining is not capped', async () => {
    await seed({memberIds: Array.from({length: 60}, (_, i) => `u${i}`), memberCount: 60});
    await join('new');
    expect((await getAdminDb().doc('events/full').get()).data()!.memberCount).toBe(61);
  });
});

describe('FND-08 deletion', () => {
  const E = 'events/gone';
  const db = () => getAdminDb();
  const exists = async (path: string) => (await db().doc(path).get()).exists;

  beforeEach(async () => {
    await clearFirestoreEmulator();
    await db().doc(E).set({title: 'T', creatorId: 'owner', adminIds: ['owner'], memberIds: ['owner', 'fnd8']});
    await db().doc(`${E}/expenses/e`).set({
      payerId: 'owner',
      amount: 10,
      involvedUids: ['owner', 'fnd8'],
      splits: [
        {userId: 'owner', amount: 5},
        {userId: 'fnd8', amount: 5},
      ],
    });
    await db().doc(`${E}/tasks/t`).set({createdBy: 'fnd8', completedBy: 'fnd8'});
    await db().doc(`${E}/tasks/t/checklist/c`).set({text: 'x'});
    await db().doc('users/fnd8/chatReads/gone').set({lastReadAt: 'x'});
    await db().doc('users/fnd8/eventMutes/gone').set({mutedUntil: 'x'});
    const {getAuth} = require('firebase-admin/auth');
    await getAuth().deleteUser('fnd8').catch(() => undefined);
    await getAuth().createUser({uid: 'fnd8'});
  });

  test('FND-08 account deletion leaves no user ID, and removes personal documents', async () => {
    await ftest.wrap(deleteUserAccount)({auth: {uid: 'fnd8'}, data: {}});
    const shared = JSON.stringify([
      (await db().doc(`${E}/expenses/e`).get()).data(),
      (await db().doc(`${E}/tasks/t`).get()).data(),
    ]);
    expect(shared).not.toContain('fnd8');
    expect(await exists('users/fnd8/chatReads/gone')).toBe(false);
    expect(await exists('users/fnd8/eventMutes/gone')).toBe(false);
  });

  test('FND-08 event deletion removes checklists and personal documents', async () => {
    await ftest.wrap(deleteEvent)({auth: {uid: 'owner'}, data: {eventId: 'gone'}});
    expect(await exists(`${E}/tasks/t/checklist/c`)).toBe(false);
    expect(await exists('users/fnd8/chatReads/gone')).toBe(false);
    expect(await exists('users/fnd8/eventMutes/gone')).toBe(false);
  });
});

describe('departed members and disputes', () => {
  const E = 'events/left';
  const db = () => getAdminDb();
  const settle = (uid: string, payerId: string, payeeId: string) =>
    ftest.wrap(recordSettlement)({
      auth: {uid},
      data: {eventId: 'left', settlementId: 's', payerId, payeeId, amount: 10},
    });

  beforeEach(async () => {
    await clearFirestoreEmulator();
    await db().doc(E).set({creatorId: 'owner', adminIds: ['owner'], memberIds: ['owner', 'member']});
    await db().doc(`${E}/expenses/e`).set({
      payerId: 'member',
      amount: 20,
      splits: [
        {userId: 'departed', amount: 10},
        {userId: 'member', amount: 10},
      ],
    });
  });
  afterEach(() => jest.restoreAllMocks());

  test('FND-09 a settlement can be recorded for a departed person', async () => {
    await settle('owner', 'departed', 'member');
    const saved = (await db().doc(`${E}/expenses/s`).get()).data()!;
    expect(saved.payerId).toBe('departed');
    expect(saved.recordedBy).toBe('owner');
  });

  test('FND-09 a member without permission cannot record for them', async () => {
    await expect(settle('member', 'departed', 'member')).rejects.toEqual(
      expect.objectContaining({code: 'permission-denied'})
    );
  });

  test('FND-10 a dispute after the window is refused', async () => {
    await settle('member', 'member', 'owner');
    const created = (await db().doc(`${E}/expenses/s`).get()).createTime!.toMillis();
    jest.spyOn(clock, 'now').mockReturnValue(created + 31 * 24 * 60 * 60 * 1000);
    await expect(
      ftest.wrap(disputeSettlement)({auth: {uid: 'owner'}, data: {eventId: 'left', settlementId: 's'}})
    ).rejects.toEqual(expect.objectContaining({code: 'failed-precondition'}));
  });

  test('FND-10 a setting changes the dispute window', async () => {
    await db().doc(E).update({settings: {disputeWindowDays: 60}});
    await settle('member', 'member', 'owner');
    const created = (await db().doc(`${E}/expenses/s`).get()).createTime!.toMillis();
    jest.spyOn(clock, 'now').mockReturnValue(created + 31 * 24 * 60 * 60 * 1000);
    await ftest.wrap(disputeSettlement)({auth: {uid: 'owner'}, data: {eventId: 'left', settlementId: 's'}});
    expect((await db().doc(`${E}/expenses/s`).get()).exists).toBe(false);
  });
});

describe('FND-12 administration', () => {
  let env: RulesTestEnvironment;
  const E = 'events/admin';
  const event = {
    title: 'T',
    creatorId: 'owner',
    adminIds: ['owner', 'a1', 'a2'],
    memberIds: ['owner', 'a1', 'a2', 'm'],
    currency: 'USD',
  };
  const remove = (uid: string, targetUserId: string) =>
    ftest.wrap(removeEventMember)({auth: {uid}, data: {eventId: 'admin', targetUserId}});

  beforeAll(async () => {
    env = await getTestEnv();
  });
  beforeEach(async () => {
    await clearFirestoreEmulator();
    await env.clearFirestore();
    await getAdminDb().doc(E).set(event);
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), E), event);
    });
  });
  afterAll(() => env.cleanup());

  test('FND-12 an admin cannot remove another admin, and the owner can', async () => {
    await expect(remove('a1', 'a2')).rejects.toEqual(
      expect.objectContaining({code: 'permission-denied'})
    );
    await remove('owner', 'a2');
    expect((await getAdminDb().doc(E).get()).data()!.memberIds).not.toContain('a2');
  });

  test('FND-12 an owner cannot leave without transferring ownership', async () => {
    await expect(remove('owner', 'owner')).rejects.toEqual(
      expect.objectContaining({code: 'failed-precondition'})
    );
  });

  test('FND-12 currency cannot be changed directly', async () => {
    const db = env.authenticatedContext('owner').firestore();
    await assertFails(updateDoc(doc(db, E), {currency: 'EUR'}));
  });
});

describe('GE-08 event status', () => {
  /* eslint-disable @typescript-eslint/no-var-requires */
  const {createEvent} = require('../src/events/createEvent');
  const {joinEvent} = require('../src/events/joinEvent');
  const {saveExpense} = require('../src/events/saveExpense');
  const {markTaskComplete} = require('../src/events/markTaskComplete');
  const {runStatusChanges} = require('../src/events/eventStatus');
  const {Timestamp} = require('firebase-admin/firestore');
  /* eslint-enable @typescript-eslint/no-var-requires */
  const store = () => getAdminDb();
  const ref = () => store().doc('events/status');
  const invoke = (fn: unknown, uid: string, data: object) =>
    ftest.wrap(fn)({auth: {uid}, data});
  const refused = expect.objectContaining({code: 'failed-precondition'});

  beforeEach(() => clearFirestoreEmulator());

  const seedEvent = async (status: string) => {
    await ref().set({
      title: 'Status',
      creatorId: 'owner',
      adminIds: ['owner'],
      memberIds: ['owner', 'member', 'other'],
      currency: 'USD',
      timeZone: 'UTC',
      status,
    });
    await store().doc('event_invites/STATUS').set({
      eventId: 'status',
      expiresAt: Timestamp.fromMillis(Date.now() + 86400000),
    });
    await ref().collection('tasks').doc('t').set({
      eventId: 'status',
      title: 'T',
      assigneeId: 'member',
      createdBy: 'member',
      status: 'todo',
    });
  };
  const expense = {
    eventId: 'status',
    expenseId: 'x',
    payerId: 'member',
    amount: 10,
    description: 'Lunch',
    isDonation: false,
    splits: [{userId: 'member', amount: 5}, {userId: 'other', amount: 5}],
  };

  test('GE-08 a new event is a draft that nobody can join', async () => {
    await invoke(createEvent, 'owner', {eventId: 'status', title: 'New'});
    expect((await ref().get()).data()!.status).toBe('draft');
    await store().doc('event_invites/STATUS').set({eventId: 'status'});
    await expect(invoke(joinEvent, 'new', {joinCode: 'STATUS'})).rejects.toEqual(refused);
  });

  test('GE-08 a published event is open to joining', async () => {
    await seedEvent('published');
    await invoke(joinEvent, 'new', {joinCode: 'STATUS'});
    expect((await ref().get()).data()!.memberIds).toContain('new');
  });

  test('GE-08 start and end times move an event on a schedule', async () => {
    await seedEvent('published');
    await ref().update({
      startDate: Timestamp.fromDate(new Date('2027-06-01T15:00:00Z')),
      endDate: Timestamp.fromDate(new Date('2027-06-03T18:00:00Z')),
    });
    await runStatusChanges(store(), new Date('2027-06-02T00:00:00Z'));
    expect((await ref().get()).data()!.status).toBe('live');
    await runStatusChanges(store(), new Date('2027-06-04T00:00:00Z'));
    expect((await ref().get()).data()!.status).toBe('ended');
  });

  test('GE-08 after an event ends, expenses stay open and tasks close', async () => {
    await seedEvent('ended');
    await invoke(saveExpense, 'member', expense);
    expect((await ref().collection('expenses').doc('x').get()).exists).toBe(true);
    await expect(invoke(markTaskComplete, 'member', {eventId: 'status', taskId: 't'}))
      .rejects.toEqual(refused);
    await invoke(markTaskComplete, 'owner', {eventId: 'status', taskId: 't'});
    expect((await ref().collection('tasks').doc('t').get()).data()!.status).toBe('done');
  });

  test('GE-08 an archived event is read-only for everyone', async () => {
    await seedEvent('archived');
    await expect(invoke(saveExpense, 'owner', {...expense, payerId: 'owner'})).rejects.toEqual(refused);
    await expect(invoke(markTaskComplete, 'owner', {eventId: 'status', taskId: 't'}))
      .rejects.toEqual(refused);
    await expect(invoke(joinEvent, 'new', {joinCode: 'STATUS'})).rejects.toEqual(refused);
  });
});
