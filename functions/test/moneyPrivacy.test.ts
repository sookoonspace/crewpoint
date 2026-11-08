/**
 * Req 36, 37 (H-05): task budget figures live in `taskBudgets/{taskId}`, which
 * needs `budget.read`, because rules cannot hide one field of a task
 * (Technical Decision 4). Payment handles leave the public profile: names and
 * handles are copied into `profiles/{uid}` in each event, which only people in
 * that event can read, and `users/{uid}` is readable only by its owner.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc, writeBatch,
} from 'firebase/firestore';
import {getTestEnv} from './setup';
import {computePermissions} from '../src/events/permissions';

let env: RulesTestEnvironment;
beforeAll(async () => {
  env = await getTestEnv();
});
afterEach(() => env.clearFirestore());
afterAll(() => env.cleanup());

const E = 'events/fest';
const as = (uid: string) => env.authenticatedContext(uid).firestore();
const PEOPLE: Record<string, string[]> = {
  owner: ['owner'],
  finance: ['finance'],
  lead: ['crewLead'],
  plain: ['participant'],
};

beforeEach(async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, E), {
      title: 'Fest', status: 'published', creatorId: 'owner',
      adminIds: ['owner'], memberIds: Object.keys(PEOPLE),
    });
    for (const [uid, roleIds] of Object.entries(PEOPLE)) {
      await setDoc(doc(db, `${E}/members/${uid}`), {
        uid, roleIds, crewIds: [], permissions: computePermissions(roleIds, {}),
      });
    }
    await setDoc(doc(db, `${E}/tasks/t1`), {
      eventId: 'fest', title: 'Caterer', createdBy: 'plain', status: 'todo',
    });
    await setDoc(doc(db, `${E}/taskBudgets/t1`), {estimate: 28000, updatedBy: 'owner'});
    await setDoc(doc(db, `${E}/profiles/plain`), {uid: 'plain', displayName: 'Pat', venmoHandle: 'pat'});
    await setDoc(doc(db, 'users/plain'), {displayName: 'Pat', venmoHandle: 'pat'});
    await setDoc(doc(db, 'events/other'), {title: 'Other', creatorId: 'outsider', memberIds: ['outsider']});
    await setDoc(doc(db, 'events/other/members/outsider'), {
      uid: 'outsider', roleIds: ['owner'], crewIds: [], permissions: computePermissions(['owner'], {}),
    });
  });
});

describe('task budget figures (Req 36)', () => {
  test('reading needs budget.read', async () => {
    await assertSucceeds(getDoc(doc(as('owner'), `${E}/taskBudgets/t1`)));
    await assertSucceeds(getDocs(collection(as('finance'), `${E}/taskBudgets`)));
    await assertFails(getDoc(doc(as('plain'), `${E}/taskBudgets/t1`)));
    await assertFails(getDoc(doc(as('lead'), `${E}/taskBudgets/t1`)));
    await assertFails(getDocs(collection(as('plain'), `${E}/taskBudgets`)));
  });

  test('setting one needs budget.edit, and a task that exists', async () => {
    const write = (uid: string, taskId = 't1', data: object = {estimate: 500, updatedBy: uid}) =>
      setDoc(doc(as(uid), `${E}/taskBudgets/${taskId}`), data);
    await assertSucceeds(write('finance'));
    await assertFails(write('plain'));
    await assertFails(write('owner', 'missing'));
  });

  test('a new task and its figure can be saved together', async () => {
    const db = as('finance');
    const batch = writeBatch(db);
    batch.set(doc(db, `${E}/tasks/t9`), {eventId: 'fest', title: 'Stage', createdBy: 'finance', status: 'todo'});
    batch.set(doc(db, `${E}/taskBudgets/t9`), {estimate: 900, updatedBy: 'finance'});
    await assertSucceeds(batch.commit());
  });

  test('a figure is a number of zero or more, written by the person setting it', async () => {
    const write = (data: object) => setDoc(doc(as('finance'), `${E}/taskBudgets/t1`), data);
    await assertSucceeds(write({estimate: 0, updatedBy: 'finance'}));
    await assertFails(write({estimate: -1, updatedBy: 'finance'}));
    await assertFails(write({estimate: '5', updatedBy: 'finance'}));
    await assertFails(write({estimate: 5, updatedBy: 'owner'}));
    await assertFails(write({estimate: 5, updatedBy: 'finance', note: 'x'}));
  });

  test('clearing one needs budget.edit', async () => {
    await assertFails(deleteDoc(doc(as('plain'), `${E}/taskBudgets/t1`)));
    await assertSucceeds(deleteDoc(doc(as('finance'), `${E}/taskBudgets/t1`)));
  });

  test('the figure can no longer be written onto a task', async () => {
    await assertFails(setDoc(doc(as('plain'), `${E}/tasks/t2`), {
      eventId: 'fest', title: 'New', createdBy: 'plain', status: 'todo', budgetEstimate: 50,
    }));
    await assertFails(updateDoc(doc(as('plain'), `${E}/tasks/t1`), {budgetEstimate: 50}));
  });

  test('an older app sending an empty figure can still save tasks', async () => {
    await assertSucceeds(setDoc(doc(as('plain'), `${E}/tasks/t2`), {
      eventId: 'fest', title: 'New', createdBy: 'plain', status: 'todo', budgetEstimate: null,
    }));
    await assertSucceeds(updateDoc(doc(as('plain'), `${E}/tasks/t1`), {title: 'Food', budgetEstimate: null}));
  });
});

describe('names and payment handles (Req 37)', () => {
  test('everyone in the event reads profiles there, including handles', async () => {
    await assertSucceeds(getDoc(doc(as('lead'), `${E}/profiles/plain`)));
    await assertSucceeds(getDocs(collection(as('owner'), `${E}/profiles`)));
  });

  test('someone sharing no event cannot read them', async () => {
    await assertFails(getDoc(doc(as('outsider'), `${E}/profiles/plain`)));
    await assertFails(getDocs(collection(as('outsider'), `${E}/profiles`)));
  });

  test('only the server writes profiles', async () => {
    await assertFails(setDoc(doc(as('plain'), `${E}/profiles/plain`), {displayName: 'X'}));
  });

  test('users/{uid} is readable only by its owner', async () => {
    await assertSucceeds(getDoc(doc(as('plain'), 'users/plain')));
    await assertFails(getDoc(doc(as('owner'), 'users/plain')));
    await assertFails(getDoc(doc(as('outsider'), 'users/plain')));
  });
});

describe('expense access setting (Req 38b)', () => {
  test('only setExpenseAccess changes it, so member documents stay in step', async () => {
    await assertFails(updateDoc(doc(as('owner'), E), {'settings.expenseAccess': {mode: 'involved'}}));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), E), {'settings.expenseAccess': {mode: 'involved'}});
    });
    // Removing a stored setting would widen access the same way.
    await assertFails(updateDoc(doc(as('owner'), E), {settings: {}}));
    // Other settings still save.
    await assertSucceeds(updateDoc(doc(as('owner'), E), {'settings.other': true}));
  });

  test('the change log is read by event.manage and written only by the server', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `${E}/settingsLog/1`), {setting: 'expenseAccess', changedBy: 'owner'});
    });
    await assertSucceeds(getDoc(doc(as('owner'), `${E}/settingsLog/1`)));
    await assertFails(getDoc(doc(as('finance'), `${E}/settingsLog/1`)));
    await assertFails(setDoc(doc(as('owner'), `${E}/settingsLog/2`), {setting: 'x'}));
  });
});
