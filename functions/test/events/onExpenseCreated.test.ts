/**
 * Req 32 (WE-08): an expense push goes only to people who may read that
 * expense, so a Vendor or Observer hears only about their own. Push goes
 * through a mocked transport.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';
import {expenseAccessOf, readsAllExpensesUnder} from '../../src/events/expenseAccess';

const mockSendEach = jest.fn();
jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({sendEach: mockSendEach}),
}));

getAdminApp();
// eslint-disable-next-line @typescript-eslint/no-var-requires
const {handleExpenseCreated} = require('../../src/events/onExpenseCreated');

const E = 'evt';
const people: [string, string[]][] = [
  ['owner', ['owner']], ['plain', ['participant']], ['vendor', ['vendor']],
  ['observer', ['observer']], ['books', ['vendor', 'finance']],
];

beforeEach(async () => {
  await clearFirestoreEmulator();
  mockSendEach.mockReset();
  mockSendEach.mockImplementation(async (m: unknown[]) => ({
    responses: m.map(() => ({success: true})),
  }));
  await getAdminDb().doc(`events/${E}`).set({
    title: 'Fest', creatorId: 'owner', adminIds: ['owner'], memberIds: people.map(([u]) => u),
  });
  for (const [uid, roleIds] of people) {
    await getAdminDb().doc(`events/${E}/members/${uid}`).set({
      // As the server writes them under Everyone, the default.
      uid, roleIds, permissions: computePermissions(roleIds, {}, {
        readsAllExpenses: readsAllExpensesUnder(expenseAccessOf({}), uid, roleIds),
      }),
    });
    await getAdminDb().doc(`users/${uid}/private/profile`).set({fcmTokens: [`tok-${uid}`]});
  }
});

const pushedTo = () =>
  (mockSendEach.mock.calls[0]?.[0] ?? []).map((m: {token: string}) => m.token).sort();

test('an expense the Vendor shares in reaches them, and never an Observer', async () => {
  await handleExpenseCreated({
    eventId: E, expenseId: 'x',
    data: {payerId: 'owner', amount: 10, description: 'Stage', involvedUids: ['owner', 'vendor']},
  });
  expect(pushedTo()).toEqual(['tok-books', 'tok-plain', 'tok-vendor']);
});

test('an expense the Vendor is not part of does not reach them', async () => {
  await handleExpenseCreated({
    eventId: E, expenseId: 'y',
    data: {payerId: 'owner', amount: 10, description: 'Food', involvedUids: ['owner', 'plain']},
  });
  expect(pushedTo()).toEqual(['tok-books', 'tok-plain']);
});

test('an event not yet migrated still reaches everyone but the payer', async () => {
  for (const [uid] of people) await getAdminDb().doc(`events/${E}/members/${uid}`).delete();
  await handleExpenseCreated({
    eventId: E, expenseId: 'z',
    data: {payerId: 'owner', amount: 1, description: 'Ice', involvedUids: ['owner']},
  });
  expect(pushedTo()).toEqual(['tok-books', 'tok-observer', 'tok-plain', 'tok-vendor']);
});
