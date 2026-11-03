/* eslint-disable */
// Acceptance tests for the deployed backend code against the emulator. Test
// names start with the scenario ID. A failure is a finding. Push goes through a
// mocked transport, so no real notification can leave this suite (N-00).
import {RulesTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, getDoc, updateDoc, setDoc} from 'firebase/firestore';
import {getAuth} from 'firebase-admin/auth';
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb, getTestEnv} from '../test/setup';

const mockSendEach = jest.fn();
jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({sendEach: mockSendEach}),
}));

const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {sendCategorizedPush} = require('../src/notifications/sendPush');
const {shouldSuppress, isWithinQuietHours} = require('../src/notifications/suppress');
const {loadTemplate} = require('../src/notifications/templates');
const {DIGEST_HOUR} = require('../src/events/onDigestSummary');
const {joinEvent} = require('../src/events/joinEvent');
const {removeEventMember} = require('../src/events/removeEventMember');
const {deleteUserAccount} = require('../src/account/deleteUserAccount');

const call = (fn: unknown, uid: string, data: object) => ftest.wrap(fn)({auth: {uid}, data});
const allOk = (msgs: unknown[]) => ({responses: msgs.map(() => ({success: true}))});
// Minutes from midnight: 9:00pm to 7:00am.
const QUIET = {quietHoursStart: 21 * 60, quietHoursEnd: 7 * 60};

async function user(uid: string, prefs: object = {}, token = `tok-${uid}`) {
  await getAdminDb().doc(`users/${uid}/private/profile`).set({
    fcmTokens: [token],
    notificationPrefs: prefs,
  });
}

function pushArgs(recipientUids: string[], category = 'digest') {
  return {
    recipientUids,
    category,
    eventId: 'derod',
    title: 'Morning summary',
    body: 'Your agenda',
    deepLink: '/dashboard/event/derod',
  };
}

beforeEach(() => {
  mockSendEach.mockReset();
  mockSendEach.mockImplementation(async (m: unknown[]) => allOk(m));
});
afterAll(() => ftest.cleanup());

describe('notifications', () => {
  afterEach(async () => {
    jest.useRealTimers();
    await clearFirestoreEmulator();
  });

  test('N-00 push only reaches the mock transport, on the emulator', async () => {
    expect(process.env.FIRESTORE_EMULATOR_HOST).toBeTruthy();
    await user('a');
    await sendCategorizedPush(pushArgs(['a']));
    expect(mockSendEach).toHaveBeenCalledTimes(1);
  });

  test('N-10 quiet-hours window is right per recipient zone', () => {
    const at = new Date('2027-06-04T01:00:00Z'); // Jun 3, 8:00pm Central
    const q = (timezone: string) => isWithinQuietHours({...QUIET, timezone}, at);
    expect(q('Europe/London')).toBe(true); // 2:00am
    expect(q('America/Toronto')).toBe(true); // 9:00pm, window start
    expect(q('America/New_York')).toBe(true);
    expect(q('America/Chicago')).toBe(false); // 8:00pm
  });

  test('N-10 a quiet-hours message is deferred to 7:00am, not dropped', async () => {
    await user('f5', {...QUIET, timezone: 'Europe/London'});
    const db = getAdminDb();
    const before = (await db.listCollections()).map((c) => c.id);
    jest.useFakeTimers({now: new Date('2027-06-04T01:00:00Z'), doNotFake: [
      'hrtime', 'nextTick', 'performance', 'queueMicrotask', 'setImmediate',
      'clearImmediate', 'setInterval', 'clearInterval', 'setTimeout', 'clearTimeout',
    ]});
    const r = await sendCategorizedPush(pushArgs(['f5']));
    jest.useRealTimers();
    expect(r.skipped).toBe(1);
    expect(mockSendEach).not.toHaveBeenCalled();
    const after = (await db.listCollections()).map((c) => c.id);
    // Something must remember to send it at 7:00am.
    expect(after.filter((c) => !before.includes(c))).not.toEqual([]);
  });

  test('N-09 F5 at the event gets the 6:45pm Central reminder', () => {
    expect(
      shouldSuppress({
        category: 'task_due',
        prefs: {...QUIET, timezone: 'Europe/London'},
        eventMutedUntil: null,
        now: new Date('2027-07-16T23:45:00Z'),
      })
    ).toBe(false);
  });

  test('N-11 live-style urgent push bypasses quiet hours', () => {
    expect(
      shouldSuppress({
        category: 'chat_urgent',
        prefs: {...QUIET, timezone: 'America/Chicago'},
        eventMutedUntil: null,
        now: new Date('2027-07-17T04:00:00Z'), // 11:00pm Central
      })
    ).toBe(false);
  });

  test('N-14 a lost-child alert reaches someone who muted the event', () => {
    expect(
      shouldSuppress({
        category: 'chat_urgent',
        prefs: {quietHoursStart: null, quietHoursEnd: null, timezone: null},
        eventMutedUntil: '2099-01-01T00:00:00Z',
        now: new Date('2027-07-17T17:00:00Z'),
      })
    ).toBe(false);
  });

  test('N-08 morning summary is scheduled for 7:00am', () => {
    expect(DIGEST_HOUR).toBe(7);
  });

  test('N-16 opting out of a category stops only that category', async () => {
    await user('a', {dailyDigest: false});
    const off = await sendCategorizedPush(pushArgs(['a'], 'digest'));
    expect(off.attempted).toBe(0);
    const on = await sendCategorizedPush(pushArgs(['a'], 'chat_urgent'));
    expect(on.attempted).toBe(1);
  });

  test('N-18 a dead push token is removed', async () => {
    await user('a');
    mockSendEach.mockImplementation(async (m: unknown[]) => ({
      responses: m.map(() => ({
        success: false,
        error: {code: 'messaging/registration-token-not-registered'},
      })),
    }));
    await sendCategorizedPush(pushArgs(['a']));
    const d = await getAdminDb().doc('users/a/private/profile').get();
    expect(d.data()!.fcmTokens).toEqual([]);
  });

  test('N-18 a failed push is logged as FAILED for staff to see', async () => {
    await user('a');
    mockSendEach.mockImplementation(async (m: unknown[]) => ({
      responses: m.map(() => ({success: false, error: {code: 'messaging/internal-error'}})),
    }));
    const db = getAdminDb();
    const before = (await db.listCollections()).map((c) => c.id);
    await sendCategorizedPush(pushArgs(['a']));
    const after = (await db.listCollections()).map((c) => c.id);
    expect(after.filter((c) => !before.includes(c))).not.toEqual([]);
  });

  test('N-21 messages exist in Gujarati', () => {
    const en = loadTemplate('chat_urgent', 'title', 'en');
    const gu = loadTemplate('chat_urgent', 'title', 'gu');
    expect(en).toBeTruthy();
    expect(gu).not.toEqual(en);
  });
});

describe('scale', () => {
  afterEach(clearFirestoreEmulator);

  test('S-01 400 people can join the event', async () => {
    const db = getAdminDb();
    const members = Array.from({length: 399}, (_, i) => `u${i}`);
    await db.doc('events/derod').set({creatorId: 'u0', memberIds: members, adminIds: ['u0'], title: 'T'});
    await db.doc('event_invites/ABC234').set({
      eventId: 'derod',
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 86400000)),
    });
    await call(joinEvent, 'u400', {joinCode: 'ABC234'});
    const d = await db.doc('events/derod').get();
    expect(d.data()!.memberIds.length).toBe(400);
  });

  test('S-01 invite codes last long enough for a months-long registration', () => {
    const src = require('fs').readFileSync(
      require('path').join(__dirname, '../src/events/generateInviteCode.ts'), 'utf8');
    const m = src.match(/EXPIRY_MS = (.+);/);
    // eslint-disable-next-line no-eval
    expect(eval(m[1])).toBeGreaterThan(30 * 24 * 60 * 60 * 1000);
  });

  async function fanout() {
    const db = getAdminDb();
    const ids = Array.from({length: 400}, (_, i) => `p${i}`);
    const batch = db.batch();
    ids.forEach((id) =>
      batch.set(db.doc(`users/${id}/private/profile`), {fcmTokens: [`t-${id}`], notificationPrefs: {}})
    );
    await batch.commit();
    const t = Date.now();
    const r = await sendCategorizedPush(pushArgs(ids, 'chat_urgent'));
    return {ms: Date.now() - t, r, sent: mockSendEach.mock.calls.flatMap((c) => c[0]).length};
  }

  test('S-04 live update to 400 is handed over within 60 s', async () => {
    const {ms, sent} = await fanout();
    console.log(`S-04 measured: ${ms}ms on local emulator, ${sent} messages`);
    expect(sent).toBe(400);
    expect(ms).toBeLessThan(60000);
  });

  test('S-03 the 400-person send fits the function time limit (30 s)', async () => {
    const {ms} = await fanout();
    console.log(`S-03 measured: ${ms}ms on local emulator; 2 reads per recipient`);
    expect(ms).toBeLessThan(30000);
  });

  test('S-03 each recipient can receive a personal message', () => {
    const src = require('fs').readFileSync(
      require('path').join(__dirname, '../src/notifications/sendPush.ts'), 'utf8');
    expect(src).toMatch(/perRecipient|bodyFor|agendaFor/);
  });
});

describe('permissions', () => {
  let env: RulesTestEnvironment;
  const E = 'events/derod';
  beforeAll(async () => {
    env = await getTestEnv();
  });
  afterAll(async () => {
    await env.cleanup();
  });
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, E), {
        creatorId: 'admin',
        adminIds: ['admin'],
        memberIds: ['admin', 'committee', 'volunteer', 'familyA', 'familyB'],
        title: 'Derod',
      });
      await setDoc(doc(db, `${E}/expenses/caterer`), {eventId: 'derod', payerId: 'admin', amount: 27400, splits: []});
      await setDoc(doc(db, `${E}/expenses/removedOwn`), {eventId: 'derod', payerId: 'gone', amount: 10, splits: []});
      await setDoc(doc(db, `${E}/tasks/t1`), {eventId: 'derod', createdBy: 'admin', assigneeId: 'gone', title: 'x', budgetEstimate: 28000});
      await setDoc(doc(db, 'users/familyB'), {displayName: 'B', venmoHandle: 'b-handle'});
      await setDoc(doc(db, 'users/familyB/private/profile'), {email: 'b@example.com'});
    });
  });
  afterEach(async () => {
    await env.clearFirestore();
  });
  const as = (uid: string) => env.authenticatedContext(uid).firestore();

  test('H-05 non-member cannot read the event or its money', async () => {
    await expect(getDoc(doc(as('stranger'), E))).rejects.toBeTruthy();
    await expect(getDoc(doc(as('stranger'), `${E}/expenses/caterer`))).rejects.toBeTruthy();
  });

  test('H-05 a member cannot change event settings', async () => {
    await expect(updateDoc(doc(as('volunteer'), E), {title: 'x'})).rejects.toBeTruthy();
  });

  test('H-05 private profile is private', async () => {
    await expect(getDoc(doc(as('familyA'), 'users/familyB/private/profile'))).rejects.toBeTruthy();
  });

  test('H-05 committee member cannot read vendor amounts', async () => {
    await expect(getDoc(doc(as('committee'), `${E}/expenses/caterer`))).rejects.toBeTruthy();
  });

  test('H-05 committee member cannot read a task budget figure', async () => {
    await expect(getDoc(doc(as('committee'), `${E}/tasks/t1`))).rejects.toBeTruthy();
  });

  test('H-05 volunteer cannot read money', async () => {
    await expect(getDoc(doc(as('volunteer'), `${E}/expenses/caterer`))).rejects.toBeTruthy();
  });

  test('H-05 family cannot read another family profile or handles', async () => {
    await expect(getDoc(doc(as('familyA'), 'users/familyB'))).rejects.toBeTruthy();
  });

  test('H-07 removed member cannot edit their old expense', async () => {
    await expect(updateDoc(doc(as('gone'), `${E}/expenses/removedOwn`), {amount: 1})).rejects.toBeTruthy();
  });

  test('H-07 removed member cannot edit a task assigned to them', async () => {
    await expect(updateDoc(doc(as('gone'), `${E}/tasks/t1`), {title: 'y'})).rejects.toBeTruthy();
  });
});

describe('membership and deletion', () => {
  afterEach(clearFirestoreEmulator);

  test('H-07 removed member cannot rejoin with the same code', async () => {
    const db = getAdminDb();
    await db.doc('events/derod').set({creatorId: 'admin', memberIds: ['admin', 'bad'], adminIds: ['admin'], title: 'T'});
    await db.doc('event_invites/ABC234').set({
      eventId: 'derod',
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 86400000)),
    });
    await call(removeEventMember, 'admin', {eventId: 'derod', targetUserId: 'bad'});
    await expect(call(joinEvent, 'bad', {joinCode: 'ABC234'})).rejects.toBeTruthy();
  });

  test('Z-04 account deletion removes the user from shared records', async () => {
    const uid = `conv${Date.now()}`;
    await getAuth().createUser({uid, email: `${uid}@example.com`});
    const db = getAdminDb();
    await db.doc('events/derod').set({creatorId: 'admin', memberIds: ['admin', uid], adminIds: ['admin'], title: 'T'});
    await db.doc(`users/${uid}`).set({displayName: 'Del'});
    await db.doc(`users/${uid}/private/profile`).set({email: 'x@example.com'});
    await db.doc('events/derod/expenses/e1').set({eventId: 'derod', payerId: 'admin', amount: 100, splits: [{userId: uid, amount: 50}]});
    await db.doc('events/derod/tasks/t1').set({eventId: 'derod', createdBy: uid, completedBy: uid});
    await call(deleteUserAccount, uid, {});
    expect((await getAuth().getUser(uid).then(() => 'still', () => 'gone'))).toBe('gone');
    expect((await db.doc(`users/${uid}/private/profile`).get()).exists).toBe(false);
    const shared = JSON.stringify([
      (await db.doc('events/derod/expenses/e1').get()).data(),
      (await db.doc('events/derod/tasks/t1').get()).data(),
    ]);
    expect(shared).not.toContain(uid);
  }, 60000);

  test('Z-04 account deletion removes personal subcollections', async () => {
    const uid = `conv2${Date.now()}`;
    await getAuth().createUser({uid, email: `${uid}@example.com`});
    const db = getAdminDb();
    await db.doc(`users/${uid}`).set({displayName: 'Del'});
    await db.doc(`users/${uid}/chatReads/derod`).set({lastReadAt: 'x'});
    await db.doc(`users/${uid}/eventMutes/derod`).set({mutedUntil: 'x'});
    await call(deleteUserAccount, uid, {});
    expect((await db.doc(`users/${uid}/chatReads/derod`).get()).exists).toBe(false);
    expect((await db.doc(`users/${uid}/eventMutes/derod`).get()).exists).toBe(false);
  }, 60000);
});
