/**
 * Req 35 (H-05, WE-08): the server half of the role matrix. Every preset
 * from the Req 26a table, against the callables a plain member can reach.
 * Rules are covered by `test/roleMatrix.test.ts`.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {PRESET_ROLES, computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {saveExpense} = require('../../src/events/saveExpense');
const {markTaskComplete} = require('../../src/events/markTaskComplete');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'matrix';
const ROLES = Object.keys(PRESET_ROLES);
const contributes = (role: string) => role !== 'observer' && role !== 'vendor';

beforeEach(async () => {
  await clearFirestoreEmulator();
  const db = getAdminDb();
  await db.doc(`events/${E}`).set({
    title: 'Fest', status: 'published', creatorId: 'owner',
    adminIds: ['owner', 'coOwner', 'admin'], memberIds: ROLES,
  });
  for (const role of ROLES) {
    await db.doc(`events/${E}/members/${role}`).set({
      uid: role, roleIds: [role], crewIds: [], permissions: computePermissions([role], {}),
    });
    await db.doc(`events/${E}/tasks/a-${role}`).set({
      eventId: E, title: 'Mine', createdBy: 'owner', assigneeId: role, status: 'todo',
    });
  }
});
afterAll(() => ftest.cleanup());

describe.each(ROLES)('%s', (role) => {
  test(contributes(role) ? 'can add their own expense' : 'cannot add an expense', async () => {
    const save = ftest.wrap(saveExpense)({
      auth: {uid: role},
      data: {
        eventId: E, expenseId: `x-${role}`, payerId: role, amount: 10, description: 'Ice',
        isDonation: false,
        splits: [{userId: role, amount: 5}, {userId: role === 'owner' ? 'admin' : 'owner', amount: 5}],
      },
    });
    if (contributes(role)) {
      await save;
      expect((await getAdminDb().doc(`events/${E}/expenses/x-${role}`).get()).exists).toBe(true);
    } else {
      await expect(save).rejects.toMatchObject({code: 'permission-denied'});
    }
  });

  test('can complete a task assigned to them', async () => {
    await ftest.wrap(markTaskComplete)({auth: {uid: role}, data: {eventId: E, taskId: `a-${role}`}});
    expect((await getAdminDb().doc(`events/${E}/tasks/a-${role}`).get()).data()!.status).toBe('done');
  });
});
