/**
 * Req 32, 35 (WE-08, H-05): the role matrix. Every preset from the Req 26a
 * table, against every restricted path the rules hold today. #72 and later
 * items add rows as their paths land.
 *
 * Vendors and Observers do not contribute (Req 34): they see only tasks
 * assigned to them and expenses they paid or share in (Req 32), and chat
 * needs `chat.send`, which neither holds unless the Owner adds it to their
 * role. Observers therefore see the event and its schedule, and nothing else.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import {getTestEnv} from './setup';
import {PRESET_ROLES, computePermissions, type Permission} from '../src/events/permissions';
import {
  expenseAccessOf, readsAllExpensesUnder, type ExpenseAccess,
} from '../src/events/expenseAccess';

let env: RulesTestEnvironment;
beforeAll(async () => {
  env = await getTestEnv();
});
afterEach(() => env.clearFirestore());
afterAll(() => env.cleanup());

const E = 'events/matrix';
const ROLES = Object.keys(PRESET_ROLES);
const as = (uid: string) => env.authenticatedContext(uid).firestore();
const holds = (role: string, p: Permission) => PRESET_ROLES[role].permissions.includes(p);
/** Everyone except those holding only Observer or Vendor (Req 34). */
const contributes = (role: string) => role !== 'observer' && role !== 'vendor';

async function seed(
  roles: Record<string, {permissions: string[]}> = {},
  access: Partial<ExpenseAccess> | undefined = undefined,
) {
  const expenseAccess = expenseAccessOf({settings: {expenseAccess: access}});
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, E), {
      title: 'Fest',
      status: 'published',
      creatorId: 'owner',
      adminIds: ['owner', 'coOwner', 'admin'],
      memberIds: ROLES,
      skipMemberSync: true,
      ...(access ? {settings: {expenseAccess: access}} : {}),
    });
    for (const role of ROLES) {
      await setDoc(doc(db, `${E}/members/${role}`), {
        uid: role, roleIds: [role], crewIds: [],
        permissions: computePermissions([role], roles, {
          readsAllExpenses: readsAllExpensesUnder(expenseAccess, role, [role]),
        }),
      });
      // One task assigned to each person, and one expense each shares in.
      await setDoc(doc(db, `${E}/tasks/a-${role}`), {
        eventId: 'matrix', title: 'Mine', createdBy: 'owner', assigneeId: role, status: 'todo',
      });
      await setDoc(doc(db, `${E}/tasks/a-${role}/checklist/c`), {text: 'Step', isCompleted: false});
      await setDoc(doc(db, `${E}/expenses/e-${role}`), {
        payerId: 'owner', amount: 10, involvedUids: ['owner', role], splits: [],
      });
      await setDoc(doc(db, `${E}/expenses/p-${role}`), {
        payerId: role, amount: 4, involvedUids: [role], splits: [],
      });
    }
    await setDoc(doc(db, `${E}/tasks/open`), {
      eventId: 'matrix', title: 'Nobody', createdBy: 'owner', status: 'todo',
    });
    await setDoc(doc(db, `${E}/tasks/open/checklist/c`), {text: 'Step', isCompleted: false});
    await setDoc(doc(db, `${E}/expenses/other`), {
      payerId: 'stranger', amount: 99, involvedUids: ['stranger'], splits: [],
    });
    await setDoc(doc(db, `${E}/messages/m`), {senderId: 'owner', text: 'Hi'});
    await setDoc(doc(db, `${E}/taskBudgets/open`), {estimate: 500, updatedBy: 'owner'});
    await setDoc(doc(db, `${E}/profiles/owner`), {uid: 'owner', displayName: 'Olu', venmoHandle: 'olu'});
    await setDoc(doc(db, 'users/owner'), {displayName: 'Olu', venmoHandle: 'olu'});
    for (const role of roles ? Object.keys(roles) : []) {
      await setDoc(doc(db, `${E}/roles/${role}`), roles[role]);
    }
  });
}

const expectAccess = (allowed: boolean, op: Promise<unknown>) =>
  allowed ? assertSucceeds(op) : assertFails(op);

describe.each(ROLES)('%s', (role) => {
  beforeEach(() => seed());

  test('reads the event', async () => {
    await assertSucceeds(getDoc(doc(as(role), E)));
  });

  test('tasks: all of them only when contributing or holding tasks.manage', async () => {
    const all = contributes(role) || holds(role, 'tasks.manage');
    await expectAccess(all, getDoc(doc(as(role), `${E}/tasks/open`)));
    await expectAccess(all, getDocs(collection(as(role), `${E}/tasks`)));
    await expectAccess(all, getDoc(doc(as(role), `${E}/tasks/open/checklist/c`)));
  });

  test('tasks: always their own, and its checklist', async () => {
    await assertSucceeds(getDoc(doc(as(role), `${E}/tasks/a-${role}`)));
    await assertSucceeds(getDocs(query(collection(as(role), `${E}/tasks`), where('assigneeId', '==', role))));
    await assertSucceeds(getDocs(collection(as(role), `${E}/tasks/a-${role}/checklist`)));
  });

  test('tasks: creating one needs to contribute', async () => {
    await expectAccess(contributes(role), setDoc(doc(as(role), `${E}/tasks/new`), {
      eventId: 'matrix', title: 'New', createdBy: role, status: 'todo',
    }));
  });

  test('expenses: all of them under Everyone, unless Observer or Vendor', async () => {
    const all = contributes(role) || holds(role, 'money.read') || holds(role, 'expenses.readAll');
    await expectAccess(all, getDoc(doc(as(role), `${E}/expenses/other`)));
    await expectAccess(all, getDocs(collection(as(role), `${E}/expenses`)));
  });

  test('expenses: always those they paid or share in', async () => {
    await assertSucceeds(getDoc(doc(as(role), `${E}/expenses/e-${role}`)));
    await assertSucceeds(getDoc(doc(as(role), `${E}/expenses/p-${role}`)));
    await assertSucceeds(getDocs(query(
      collection(as(role), `${E}/expenses`), where('involvedUids', 'array-contains', role))));
  });

  test('expenses: no client writes, and deleting needs the payer or money.record', async () => {
    await assertFails(setDoc(doc(as(role), `${E}/expenses/new`), {payerId: role, amount: 1}));
    await expectAccess(holds(role, 'money.record'), deleteDoc(doc(as(role), `${E}/expenses/other`)));
    await assertSucceeds(deleteDoc(doc(as(role), `${E}/expenses/p-${role}`)));
  });

  test('chat: reading and sending need chat.send, urgent needs chat.urgent', async () => {
    const chat = holds(role, 'chat.send');
    await expectAccess(chat, getDoc(doc(as(role), `${E}/messages/m`)));
    await expectAccess(chat, getDocs(collection(as(role), `${E}/messages`)));
    await expectAccess(chat, setDoc(doc(as(role), `${E}/messages/n`), {senderId: role, text: 'Hi'}));
    await expectAccess(holds(role, 'chat.urgent'), setDoc(doc(as(role), `${E}/messages/u`), {
      senderId: role, text: 'Fire', isHighPriority: true,
    }));
  });

  test('task budget figures: reading needs budget.read, and setting budget.edit (Req 36)', async () => {
    await expectAccess(holds(role, 'budget.read'), getDoc(doc(as(role), `${E}/taskBudgets/open`)));
    await expectAccess(holds(role, 'budget.read'), getDocs(collection(as(role), `${E}/taskBudgets`)));
    await expectAccess(holds(role, 'budget.edit'), setDoc(doc(as(role), `${E}/taskBudgets/open`), {
      estimate: 1, updatedBy: role,
    }));
    // Nobody can put the figure back on a task.
    await assertFails(updateDoc(doc(as(role), `${E}/tasks/a-${role}`), {budgetEstimate: 5}));
  });

  test('names and handles: read in the event, never from users/{uid} (Req 37)', async () => {
    await assertSucceeds(getDoc(doc(as(role), `${E}/profiles/owner`)));
    await expectAccess(role === 'owner', getDoc(doc(as(role), 'users/owner')));
  });

  test('settings need event.manage, and roles, crews and members only the server', async () => {
    await expectAccess(holds(role, 'event.manage'), updateDoc(doc(as(role), E), {title: 'Renamed'}));
    await assertFails(setDoc(doc(as(role), `${E}/roles/x`), {permissions: []}));
    await assertFails(setDoc(doc(as(role), `${E}/crews/x`), {name: 'X'}));
    await assertFails(updateDoc(doc(as(role), `${E}/members/${role}`), {permissions: ['event.manage']}));
  });
});

/**
 * Req 38: every expense access option against every role. Whatever the
 * option, the payer and people in a split read that expense, and roles
 * holding money.read or expenses.readAll read all of them. Only reading
 * changes: writes stay as they were.
 */
const OPTIONS: [string, Partial<ExpenseAccess>, (role: string) => boolean][] = [
  ['Everyone', {mode: 'everyone'}, (r) => contributes(r)],
  ['Everyone, with Observers and Vendors', {mode: 'everyone', includeNonContributors: true}, () => true],
  ['Only people involved', {mode: 'involved'}, () => false],
  ['Selected: Crew lead, Observer and the Scorer', {mode: 'selected', roleIds: ['crewLead', 'observer'], uids: ['scorer']},
    (r) => ['crewLead', 'observer', 'scorer'].includes(r)],
  ['Selected: nobody', {mode: 'selected'}, () => false],
];

describe.each(OPTIONS)('expense access: %s', (_name, access, chosen) => {
  beforeEach(() => seed({}, access));

  test.each(ROLES)('%s', async (role) => {
    const all = chosen(role) || holds(role, 'money.read') || holds(role, 'expenses.readAll');
    await expectAccess(all, getDoc(doc(as(role), `${E}/expenses/other`)));
    await expectAccess(all, getDocs(collection(as(role), `${E}/expenses`)));
    // Their own, always, by document and by the involvedUids query.
    await assertSucceeds(getDoc(doc(as(role), `${E}/expenses/e-${role}`)));
    await assertSucceeds(getDoc(doc(as(role), `${E}/expenses/p-${role}`)));
    await assertSucceeds(getDocs(query(
      collection(as(role), `${E}/expenses`), where('involvedUids', 'array-contains', role))));
    // Reading all of them grants no writes.
    await assertFails(setDoc(doc(as(role), `${E}/expenses/new`), {payerId: role, amount: 1}));
    await expectAccess(holds(role, 'money.record'), deleteDoc(doc(as(role), `${E}/expenses/other`)));
  });
});

describe('the Owner can widen a Vendor or Observer role', () => {
  test('adding chat.send to Observer opens chat', async () => {
    await seed({observer: {permissions: ['group.readOwn', 'chat.send']}});
    await assertSucceeds(getDocs(collection(as('observer'), `${E}/messages`)));
    await assertFails(getDocs(collection(as('observer'), `${E}/tasks`)));
  });

  test('adding tasks.manage to Vendor shows every task, and money.read every expense', async () => {
    await seed({vendor: {permissions: ['group.readOwn', 'tasks.manage', 'money.read']}});
    await assertSucceeds(getDocs(collection(as('vendor'), `${E}/tasks`)));
    await assertSucceeds(getDocs(collection(as('vendor'), `${E}/expenses`)));
    // Still not a contributor, so adding a task stays closed.
    await assertFails(setDoc(doc(as('vendor'), `${E}/tasks/new`), {
      eventId: 'matrix', title: 'New', createdBy: 'vendor', status: 'todo',
    }));
  });
});
