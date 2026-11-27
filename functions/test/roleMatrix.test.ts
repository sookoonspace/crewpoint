/**
 * Req 32, 35 (WE-08, H-05): the role matrix. Every preset from the Req 26a
 * table, against every restricted path in an event: tasks, expenses, chat
 * and its summary, budgets, profiles, the roster and its private details,
 * fields, settings and their log, roles, crews, members, ownership offers,
 * the schedule, counts and freezes, imports, link requests and match keys,
 * registration settings, event link names and rate-limit counts.
 *
 * Vendors and Observers do not contribute (Req 34): they see only tasks
 * assigned to them and expenses they paid or share in (Req 32), and chat
 * needs `chat.send`, which neither holds unless the Owner adds it to their
 * role. Observers therefore see the event and its schedule, and nothing else.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
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
      settings: {
        ...(access ? {expenseAccess: access} : {}),
        registration: {mode: 'open', offerHours: 72, slug: 'fest-2027'},
      },
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
    await setDoc(doc(db, `${E}/groups/g1`), {name: 'Shahs', sortName: 'shahs', adultUids: []});
    await setDoc(doc(db, `${E}/participants/kid`), {
      name: 'Ana', sortName: 'ana', groupId: 'g1', isChild: true, createdBy: 'owner', status: 'active',
    });
    await setDoc(doc(db, `${E}/participants/kid/private/details`), {birthDate: '2020-05-01'});
    await setDoc(doc(db, `${E}/profiles/owner`), {uid: 'owner', displayName: 'Olu', venmoHandle: 'olu'});
    await setDoc(doc(db, 'users/owner'), {displayName: 'Olu', venmoHandle: 'olu'});
    for (const role of roles ? Object.keys(roles) : []) {
      await setDoc(doc(db, `${E}/roles/${role}`), roles[role]);
    }
    // Paths from #77 to #86, written only by the server or by organizers.
    await setDoc(doc(db, `${E}/sessions/open`), session());
    await setDoc(doc(db, `${E}/sessions/draft`), session({title: 'Gala', hidden: true}));
    await setDoc(doc(db, `${E}/stats/current`), {event: {total: 1}});
    await setDoc(doc(db, `${E}/countFreezes/f1`), {event: {total: 1}, note: 'Caterer'});
    await setDoc(doc(db, `${E}/imports/j1`), {fileName: 'r.csv', status: 'checked', createdBy: 'owner'});
    await setDoc(doc(db, `${E}/linkRequests/stranger`), {email: 'a@b.c', status: 'open'});
    await setDoc(doc(db, `${E}/participantKeys/kid`), {emailKey: 'k'});
    await setDoc(doc(db, `${E}/chatSummary/current`), {count: 1});
    await setDoc(doc(db, `${E}/settingsLog/l1`), {setting: 'expenseAccess', by: 'owner'});
    await setDoc(doc(db, `${E}/ownership/offer`), {toUid: 'coOwner', fromUid: 'owner'});
    // Spec #233: the email outbox and server-only settings.
    await setDoc(doc(db, 'mailOutbox/m1'), {to: 'a@b.co', status: 'sent'});
    await setDoc(doc(db, 'serverConfig/mail'), {deliveryEnabled: true, allowedRecipients: []});
    // #239: event link names.
    await setDoc(doc(db, 'eventSlugs/fest-2027'), {eventId: 'matrix'});
    // #240: rate-limit counts for public calls.
    await setDoc(doc(db, 'rateLimits/eventPage_x_1'), {count: 1});
    // #242: registrations, their change log and the tally of places.
    await setDoc(doc(db, `${E}/registrations/r1`), {groupId: 'g1', contactUid: 'stranger', status: 'submitted'});
    await setDoc(doc(db, `${E}/registrations/r1/changes/c1`), {by: 'stranger', action: 'submitted'});
    await setDoc(doc(db, `${E}/registrationTally/current`), {placesUsed: 1});
    await setDoc(doc(db, `${E}/participants/registered`), {
      name: 'Rani', sortName: 'rani', groupId: 'g1', isChild: false, createdBy: 'owner', status: 'active',
      registrationId: 'r1', registrationStatus: 'submitted',
    });
    // #246: waivers, their versions and a person's acceptances.
    await setDoc(doc(db, `${E}/waivers/w1`), {title: {en: 'Waiver'}, version: 1, appliesTo: {kind: 'everyone'}});
    await setDoc(doc(db, `${E}/waivers/w1/versions/1`), {text: {en: 'Text'}});
    await setDoc(doc(db, `${E}/participants/registered/private/waivers`), {accepted: {w1: {version: 1, by: 'stranger'}}});
  });
}

/** A schedule session the rules accept (Req 47). */
const session = (over: object = {}) => ({
  title: 'Welcome dinner',
  startAt: Timestamp.fromDate(new Date('2027-07-17T00:00:00Z')),
  endAt: Timestamp.fromDate(new Date('2027-07-17T02:00:00Z')),
  timeTbc: false, venueId: null, locationTba: true, type: 'Dinner', tags: [], capacity: null,
  eligibility: {categoryIds: [], filterTags: []}, hidden: false, updatedBy: 'owner',
  updatedAt: serverTimestamp(), ...over,
});

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

  test('participants: the roster, adding people and private details (Req 40, 43)', async () => {
    await expectAccess(holds(role, 'participants.read'), getDocs(collection(as(role), `${E}/participants`)));
    await expectAccess(holds(role, 'participants.read'), getDoc(doc(as(role), `${E}/groups/g1`)));
    await expectAccess(holds(role, 'participants.edit'), setDoc(doc(as(role), `${E}/participants/new`), {
      name: 'Ravi', sortName: 'ravi', groupId: 'g1', isChild: true, createdBy: role, status: 'active',
    }));
    await expectAccess(holds(role, 'participants.readPrivate'),
      getDoc(doc(as(role), `${E}/participants/kid/private/details`)));
    await assertFails(setDoc(doc(as(role), `${E}/groups/g2`), {name: 'X', sortName: 'x', adultUids: []}));
  });

  test('custom fields: read by everyone, defined with event.manage (Req 41)', async () => {
    await assertSucceeds(getDocs(collection(as(role), `${E}/fields`)));
    await expectAccess(holds(role, 'event.manage'), setDoc(doc(as(role), `${E}/fields/diet`), {
      label: 'Diet', type: 'singleChoice', options: ['Veg'], required: false,
      scope: 'participant', visibility: 'standard', order: 0,
    }));
  });

  test('settings need event.manage, and roles, crews and members only the server', async () => {
    await expectAccess(holds(role, 'event.manage'), updateDoc(doc(as(role), E), {title: 'Renamed'}));
    await assertFails(setDoc(doc(as(role), `${E}/roles/x`), {permissions: []}));
    await assertFails(setDoc(doc(as(role), `${E}/crews/x`), {name: 'X'}));
    await assertFails(updateDoc(doc(as(role), `${E}/members/${role}`), {permissions: ['event.manage']}));
  });

  test('registration settings and link names: only the server (#239)', async () => {
    await assertFails(updateDoc(doc(as(role), E), {'settings.registration.mode': 'invited'}));
    await assertFails(updateDoc(doc(as(role), E), {'settings.registration.slug': 'mine'}));
    await assertFails(getDoc(doc(as(role), 'eventSlugs/fest-2027')));
    await assertFails(setDoc(doc(as(role), 'eventSlugs/mine'), {eventId: 'matrix'}));
    await assertFails(deleteDoc(doc(as(role), 'eventSlugs/fest-2027')));
  });

  test('rate-limit counts: no client access (#240)', async () => {
    await assertFails(getDoc(doc(as(role), 'rateLimits/eventPage_x_1')));
    await assertFails(setDoc(doc(as(role), 'rateLimits/eventPage_x_1'), {count: 0}));
    await assertFails(deleteDoc(doc(as(role), 'rateLimits/eventPage_x_1')));
  });

  test('settings log: read with event.manage, written only by the server', async () => {
    await expectAccess(holds(role, 'event.manage'), getDoc(doc(as(role), `${E}/settingsLog/l1`)));
    await assertFails(setDoc(doc(as(role), `${E}/settingsLog/l2`), {setting: 'x', by: role}));
  });

  test('ownership offer: read by everyone in the event, written only by the server', async () => {
    await assertSucceeds(getDoc(doc(as(role), `${E}/ownership/offer`)));
    await assertFails(setDoc(doc(as(role), `${E}/ownership/offer`), {toUid: role, fromUid: 'owner'}));
  });

  test('schedule: drafts and changes need schedule.edit (Req 47)', async () => {
    const edits = holds(role, 'schedule.edit');
    await assertSucceeds(getDoc(doc(as(role), `${E}/sessions/open`)));
    await assertSucceeds(getDocs(query(collection(as(role), `${E}/sessions`), where('hidden', '==', false))));
    await expectAccess(edits, getDoc(doc(as(role), `${E}/sessions/draft`)));
    await expectAccess(edits, getDocs(collection(as(role), `${E}/sessions`)));
    await expectAccess(edits, setDoc(doc(as(role), `${E}/sessions/new`), session({updatedBy: role})));
    await expectAccess(edits, deleteDoc(doc(as(role), `${E}/sessions/open`)));
  });

  test('counts and freezes: read with counts.read, written only by the server (Req 52, 54)', async () => {
    await expectAccess(holds(role, 'counts.read'), getDoc(doc(as(role), `${E}/stats/current`)));
    await expectAccess(holds(role, 'counts.read'), getDocs(collection(as(role), `${E}/countFreezes`)));
    await assertFails(setDoc(doc(as(role), `${E}/stats/current`), {event: {total: 9}}));
    await assertFails(setDoc(doc(as(role), `${E}/countFreezes/f2`), {event: {total: 9}}));
  });

  test('imports: read and queued with participants.import (Req 44a)', async () => {
    const imports = holds(role, 'participants.import');
    await expectAccess(imports, getDoc(doc(as(role), `${E}/imports/j1`)));
    await expectAccess(imports, setDoc(doc(as(role), `${E}/imports/j2`), {
      fileName: 'r.csv', targets: [], header: [], mode: 'dryRun', status: 'queued',
      createdBy: role, createdAt: serverTimestamp(),
    }));
  });

  test('link requests: read with participants.readPrivate, match keys by nobody (Req 46, 14a)', async () => {
    await expectAccess(holds(role, 'participants.readPrivate'),
      getDoc(doc(as(role), `${E}/linkRequests/stranger`)));
    await assertFails(setDoc(doc(as(role), `${E}/linkRequests/${role}`), {email: 'x@y.z', status: 'open'}));
    await assertFails(getDoc(doc(as(role), `${E}/participantKeys/kid`)));
  });

  test('registrations: read with registrations.manage, written only by the server (Spec #233 TD 1, #242)', async () => {
    const manages = holds(role, 'registrations.manage');
    await expectAccess(manages, getDoc(doc(as(role), `${E}/registrations/r1`)));
    await expectAccess(manages, getDoc(doc(as(role), `${E}/registrations/r1/changes/c1`)));
    await assertFails(setDoc(doc(as(role), `${E}/registrations/r2`), {groupId: 'g1', contactUid: role, status: 'submitted'}));
    await assertFails(updateDoc(doc(as(role), `${E}/registrations/r1`), {status: 'cancelled'}));
    await assertFails(setDoc(doc(as(role), `${E}/registrations/r1/changes/c2`), {by: role}));
    await assertFails(getDoc(doc(as(role), `${E}/registrationTally/current`)));
    await assertFails(setDoc(doc(as(role), `${E}/registrationTally/current`), {placesUsed: 0}));
    // The mirrored status is the server's alone, and a registered person
    // leaves only through registrations.manage.
    await assertFails(updateDoc(doc(as(role), `${E}/participants/registered`), {registrationStatus: 'cancelled'}));
    await expectAccess(manages && holds(role, 'participants.edit'),
      deleteDoc(doc(as(role), `${E}/participants/registered`)));
  });

  test('waivers: read by everyone in the event, written and accepted only by the server (Spec #233 Req 26-28, #246)', async () => {
    await assertSucceeds(getDoc(doc(as(role), `${E}/waivers/w1`)));
    await assertSucceeds(getDoc(doc(as(role), `${E}/waivers/w1/versions/1`)));
    await assertFails(setDoc(doc(as(role), `${E}/waivers/w2`), {title: {en: 'x'}, version: 1}));
    await assertFails(updateDoc(doc(as(role), `${E}/waivers/w1`), {version: 2}));
    await assertFails(setDoc(doc(as(role), `${E}/waivers/w1/versions/2`), {text: {en: 'x'}}));
    await assertFails(setDoc(doc(as(role), `${E}/participants/registered/private/waivers`), {accepted: {}}));
    await assertFails(deleteDoc(doc(as(role), `${E}/participants/registered/private/waivers`)));
    await assertFails(updateDoc(doc(as(role), `${E}/participants/registered`), {waiversMissing: false}));
    await assertFails(updateDoc(doc(as(role), `${E}/participants/registered`), {waiverVersions: {w1: 9}}));
  });

  test('email outbox and mail settings: no client access (Spec #233 Req 51, 51a)', async () => {
    await assertFails(getDoc(doc(as(role), 'mailOutbox/m1')));
    await assertFails(setDoc(doc(as(role), 'mailOutbox/m2'), {to: 'x@y.z', template: 'deliveryCheck', status: 'queued'}));
    await assertFails(updateDoc(doc(as(role), 'mailOutbox/m1'), {status: 'queued'}));
    await assertFails(getDoc(doc(as(role), 'serverConfig/mail')));
    await assertFails(setDoc(doc(as(role), 'serverConfig/mail'), {allowedRecipients: [`${role}@x.y`]}));
  });

  test('chat summary: read with chat.send, written only by the server (Req 57a)', async () => {
    await expectAccess(holds(role, 'chat.send'), getDoc(doc(as(role), `${E}/chatSummary/current`)));
    await assertFails(setDoc(doc(as(role), `${E}/chatSummary/current`), {count: 99}));
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
