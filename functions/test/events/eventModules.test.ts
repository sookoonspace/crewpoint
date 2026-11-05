/**
 * Req 22 (GE-02): turning a module off blocks its server paths, and keeps its
 * data for when it comes back on.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
/* eslint-disable @typescript-eslint/no-var-requires */
const {saveExpense} = require('../../src/events/saveExpense');
const {recordSettlement} = require('../../src/events/recordSettlement');
const {disputeSettlement} = require('../../src/events/disputeSettlement');
const {markTaskComplete} = require('../../src/events/markTaskComplete');
const {isModuleOn} = require('../../src/events/eventModules');
/* eslint-enable @typescript-eslint/no-var-requires */

const REF = 'events/evt';
const db = () => getAdminDb();
const refused = expect.objectContaining({code: 'failed-precondition'});
const call = (fn: unknown, uid: string, data: object) =>
  ftest.wrap(fn)({auth: {uid}, data});

const seed = (modules?: object) =>
  db().doc(REF).set({
    creatorId: 'owner',
    adminIds: ['owner'],
    memberIds: ['owner', 'member', 'other'],
    currency: 'USD',
    status: 'published',
    ...(modules ? {modules} : {}),
  });
const expense = {
  eventId: 'evt',
  expenseId: 'x',
  payerId: 'member',
  amount: 10,
  description: 'Lunch',
  isDonation: false,
  splits: [{userId: 'member', amount: 5}, {userId: 'other', amount: 5}],
};
const settlement = {
  eventId: 'evt',
  settlementId: 's',
  payerId: 'member',
  payeeId: 'other',
  amount: 5,
};

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('isModuleOn', () => {
  test('a module is on unless turned off', () => {
    expect(isModuleOn({}, 'tasks')).toBe(true);
    expect(isModuleOn({modules: {budget: false}}, 'tasks')).toBe(true);
    expect(isModuleOn({modules: {tasks: true}}, 'tasks')).toBe(true);
    expect(isModuleOn({modules: {tasks: false}}, 'tasks')).toBe(false);
  });
});

describe('budget off', () => {
  test('refuses expenses and settlements', async () => {
    await seed({budget: false});
    await expect(call(saveExpense, 'member', expense)).rejects.toEqual(refused);
    await expect(call(recordSettlement, 'member', settlement)).rejects.toEqual(refused);
  });

  test('refuses disputes', async () => {
    await seed();
    await call(recordSettlement, 'member', settlement);
    await db().doc(REF).update({modules: {budget: false}});
    await expect(call(disputeSettlement, 'other', {eventId: 'evt', settlementId: 's'}))
      .rejects.toEqual(refused);
  });

  test('keeps the data, and it works again when turned back on', async () => {
    await seed();
    await call(saveExpense, 'member', expense);
    await db().doc(REF).update({modules: {budget: false}});
    expect((await db().doc(`${REF}/expenses/x`).get()).exists).toBe(true);
    await db().doc(REF).update({modules: {budget: true}});
    await call(saveExpense, 'member', {...expense, expenseId: 'y'});
    expect((await db().doc(`${REF}/expenses/y`).get()).exists).toBe(true);
  });
});

describe('tasks off', () => {
  test('refuses completing a task, which stays as it was', async () => {
    await seed({tasks: false});
    await db().doc(`${REF}/tasks/t`).set({
      eventId: 'evt',
      assigneeId: 'member',
      createdBy: 'member',
      status: 'todo',
    });
    await expect(call(markTaskComplete, 'member', {eventId: 'evt', taskId: 't'}))
      .rejects.toEqual(refused);
    expect((await db().doc(`${REF}/tasks/t`).get()).data()!.status).toBe('todo');
  });
});
