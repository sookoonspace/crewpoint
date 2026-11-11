/**
 * Req 34 (script): an idempotent admin script, with a dry run, converts each
 * event to member documents while keeping everyone's access and old data.
 * Runs on a seeded old-shape fixture in the emulators only.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {migrateToMembers} from '../../scripts/migrateToMembers';
import {computePermissions} from '../../src/events/permissions';

getAdminApp();

const db = () => getAdminDb();
const NOW = new Date('2026-11-06T12:00:00Z');
const member = async (e: string, uid: string) =>
  (await db().doc(`events/${e}/members/${uid}`).get()).data();
const event = async (e: string) => (await db().doc(`events/${e}`).get()).data()!;
const run = (dryRun = false) => migrateToMembers(db(), {dryRun, now: NOW});

/** An event as the app wrote it before Stage 1. */
async function seedOld(id: string, over: object = {}) {
  await db().doc(`events/${id}`).set({
    title: 'Old trip',
    eventType: 'trip',
    status: 'active',
    creatorId: 'c',
    adminIds: ['c', 'a'],
    memberIds: ['c', 'a', 'm'],
    createdAt: Timestamp.fromDate(new Date('2025-01-01T00:00:00Z')),
    ...over,
  });
}

beforeEach(() => clearFirestoreEmulator());

describe('migrateToMembers', () => {
  test('writes member documents from the arrays, and keeps the arrays', async () => {
    await seedOld('e1');
    await run();
    expect(await member('e1', 'c')).toEqual({
      uid: 'c',
      roleIds: ['owner'],
      crewIds: [],
      permissions: computePermissions(['owner'], {}),
      participantId: null,
      joinedAt: Timestamp.fromDate(new Date('2025-01-01T00:00:00Z')),
    });
    expect((await member('e1', 'a'))?.roleIds).toEqual(['admin']);
    expect((await member('e1', 'm'))?.roleIds).toEqual(['participant']);
    const saved = await event('e1');
    expect(saved.memberIds).toEqual(['c', 'a', 'm']);
    expect(saved.adminIds).toEqual(['c', 'a']);
  });

  test('a dry run reports what would change, and writes nothing', async () => {
    await seedOld('e1');
    const result = await run(true);
    expect(result).toEqual(expect.objectContaining({events: 1, memberDocs: 3}));
    expect(await member('e1', 'c')).toBeUndefined();
    expect((await event('e1')).status).toBe('active');
  });

  test('status maps from active, and memberCount comes from the arrays', async () => {
    const day = (iso: string) => Timestamp.fromDate(new Date(iso));
    await seedOld('past', {endDate: day('2026-10-01T00:00:00Z')});
    await seedOld('future', {endDate: day('2027-01-01T00:00:00Z')});
    await seedOld('noEnd');
    await seedOld('draft', {status: 'draft', memberIds: ['c', 'a']});
    const result = await run();
    expect((await event('past')).status).toBe('ended');
    expect((await event('future')).status).toBe('published');
    expect((await event('noEnd')).status).toBe('published');
    expect((await event('draft')).status).toBe('draft');
    expect((await event('past')).memberCount).toBe(3);
    expect((await event('draft')).memberCount).toBe(2);
    expect(result.statuses).toBe(3);
  });

  test('an event ending today is not ended until its end date is over', async () => {
    // Before #63, dates were midnight on the creator's device.
    await seedOld('today', {endDate: Timestamp.fromDate(new Date('2026-11-06T05:00:00Z'))});
    await run();
    expect((await event('today')).status).toBe('published');
  });

  test('older expenses get involvedUids, and newer ones are left alone', async () => {
    await seedOld('e1');
    const expenses = db().collection('events/e1/expenses');
    await expenses.doc('old').set({
      payerId: 'a', amount: 30, splits: [{userId: 'a', amount: 10}, {userId: 'm', amount: 20}],
    });
    await expenses.doc('payment').set({
      payerId: 'm', amount: 5, isPayment: true, splits: [{userId: 'a', amount: 5}],
    });
    await expenses.doc('new').set({payerId: 'c', splits: [], involvedUids: ['c', 'kept']});
    const result = await run();
    expect((await expenses.doc('old').get()).data()!.involvedUids).toEqual(['a', 'm']);
    expect((await expenses.doc('payment').get()).data()!.involvedUids).toEqual(['m', 'a']);
    expect((await expenses.doc('new').get()).data()!.involvedUids).toEqual(['c', 'kept']);
    expect(result.involvedUids).toBe(2);
  });

  describe('dates', () => {
    const at = (iso: string) => Timestamp.fromDate(new Date(iso));
    const iso = async (e: string, field: string) =>
      ((await event(e))[field] as Timestamp).toDate().toISOString();
    const creatorZone = (zone: string) =>
      db().doc('users/c/private/profile').set({notificationPrefs: {timezone: zone}});

    test("take the creator's zone, and become the day they showed there", async () => {
      await creatorZone('America/New_York');
      // Midnight in New York, either side of the clocks changing on 8 March.
      await seedOld('ny', {startDate: at('2026-03-07T05:00:00Z'), endDate: at('2026-03-12T04:00:00Z')});
      await run();
      const saved = await event('ny');
      expect(saved.timeZone).toBe('America/New_York');
      expect(saved.dateOnly).toBe(true);
      expect(await iso('ny', 'startDate')).toBe('2026-03-07T00:00:00.000Z');
      expect(await iso('ny', 'endDate')).toBe('2026-03-12T00:00:00.000Z');
    });

    test("an event's own zone wins over the creator's", async () => {
      await creatorZone('America/New_York');
      await seedOld('in', {timeZone: 'Asia/Kolkata', startDate: at('2026-03-09T18:30:00Z')});
      await run();
      expect((await event('in')).timeZone).toBe('Asia/Kolkata');
      expect(await iso('in', 'startDate')).toBe('2026-03-10T00:00:00.000Z');
    });

    test('with no zone known, dates are left alone and counted', async () => {
      await seedOld('unknown', {startDate: at('2026-03-09T18:30:00Z')});
      const result = await run();
      const saved = await event('unknown');
      expect(saved.timeZone).toBeUndefined();
      expect(saved.dateOnly).toBeUndefined();
      expect(await iso('unknown', 'startDate')).toBe('2026-03-09T18:30:00.000Z');
      expect(result.unknownZones).toBe(1);
    });

    test('date-only events are left alone', async () => {
      await creatorZone('America/New_York');
      await seedOld('done', {timeZone: 'UTC', dateOnly: true, startDate: at('2026-03-10T00:00:00Z')});
      const result = await run();
      expect(await iso('done', 'startDate')).toBe('2026-03-10T00:00:00.000Z');
      expect(result.dates).toBe(0);
    });
  });

  describe('expense access (Req 38)', () => {
    test('new member documents follow the setting', async () => {
      await seedOld('e1', {settings: {expenseAccess: {mode: 'involved'}}});
      await run();
      expect((await member('e1', 'm'))?.permissions).not.toContain('expenses.readAll');
      // The Owner role holds it, whatever the setting.
      expect((await member('e1', 'c'))?.permissions).toContain('expenses.readAll');
    });

    test('existing member documents get expenses.readAll, keeping their roles', async () => {
      await seedOld('e1');
      await db().doc('events/e1/members/m').set({
        uid: 'm', roleIds: ['crewLead'], crewIds: ['food'],
        permissions: computePermissions(['crewLead'], {}), participantId: null,
      });
      const result = await run();
      const m = await member('e1', 'm');
      expect(m?.roleIds).toEqual(['crewLead']);
      expect(m?.crewIds).toEqual(['food']);
      expect(m?.permissions).toEqual(
        computePermissions(['crewLead'], {}, {readsAllExpenses: true}));
      expect(result.permissions).toBe(1);
    });

    test('an edited role is kept when recalculating', async () => {
      await seedOld('e1', {settings: {expenseAccess: {mode: 'involved'}}});
      await db().doc('events/e1/roles/participant').set({permissions: ['chat.send', 'money.read']});
      await db().doc('events/e1/members/m').set({
        uid: 'm', roleIds: ['participant'], crewIds: [], permissions: ['chat.send'], participantId: null,
      });
      await run();
      expect((await member('e1', 'm'))?.permissions).toEqual(['money.read', 'chat.send']);
    });
  });

  describe('task budget figures (Req 36)', () => {
    test('move to taskBudgets, and leave the task', async () => {
      await seedOld('e1');
      await db().doc('events/e1/tasks/t1').set({title: 'Food', budgetEstimate: 280});
      await db().doc('events/e1/tasks/t2').set({title: 'Zero', budgetEstimate: 0});
      await db().doc('events/e1/tasks/t3').set({title: 'Empty', budgetEstimate: null});
      await db().doc('events/e1/tasks/t4').set({title: 'None'});
      const result = await run();
      expect((await db().doc('events/e1/taskBudgets/t1').get()).data()).toEqual({estimate: 280});
      expect((await db().doc('events/e1/taskBudgets/t2').get()).data()).toEqual({estimate: 0});
      expect((await db().doc('events/e1/taskBudgets/t3').get()).exists).toBe(false);
      for (const t of ['t1', 't2', 't3', 't4']) {
        const task = (await db().doc(`events/e1/tasks/${t}`).get()).data()!;
        expect(task).not.toHaveProperty('budgetEstimate');
        expect(task.title).toBeDefined();
      }
      expect(result.taskBudgets).toBe(2);
    });

    test('a dry run leaves them on the task', async () => {
      await seedOld('e1');
      await db().doc('events/e1/tasks/t1').set({title: 'Food', budgetEstimate: 280});
      expect((await run(true)).taskBudgets).toBe(1);
      expect((await db().doc('events/e1/tasks/t1').get()).data()?.budgetEstimate).toBe(280);
      expect((await db().doc('events/e1/taskBudgets/t1').get()).exists).toBe(false);
    });
  });

  describe('names and payment handles (Req 37)', () => {
    const profile = async (uid: string) =>
      (await db().doc(`events/e1/profiles/${uid}`).get()).data();

    test('every member gets a profile in the event', async () => {
      await seedOld('e1');
      await db().doc('users/m').set({displayName: 'Mo', venmoHandle: 'mo', currency: 'USD'});
      const result = await run();
      expect(await profile('m')).toEqual({
        uid: 'm', displayName: 'Mo', photoUrl: null, paymentMethod: null,
        paymentHandle: null, venmoHandle: 'mo', cashappHandle: null,
        sortName: 'mo', inEvent: true,
      });
      expect((await profile('c'))?.displayName).toBeNull();
      expect(result.profiles).toBe(3);
    });

    test('people who left keep their name on old records, without handles', async () => {
      await seedOld('e1');
      await db().doc('users/gone').set({displayName: 'Gil', venmoHandle: 'gil', photoUrl: 'g.jpg'});
      await db().doc('users/paid').set({displayName: 'Pia', venmoHandle: 'pia'});
      await db().doc('users/did').set({displayName: 'Dee'});
      await db().doc('events/e1/messages/x').set({senderId: 'gone', text: 'Hi'});
      await db().doc('events/e1/expenses/x').set({payerId: 'paid', splits: [{userId: 'm', amount: 1}]});
      await db().doc('events/e1/tasks/x').set({title: 'T', createdBy: 'did', assigneeId: 'm'});
      await run();
      const left = {inEvent: false};
      expect(await profile('gone')).toEqual({uid: 'gone', displayName: 'Gil', photoUrl: 'g.jpg', sortName: 'gil', ...left});
      expect(await profile('paid')).toEqual({uid: 'paid', displayName: 'Pia', photoUrl: null, sortName: 'pia', ...left});
      expect(await profile('did')).toEqual({uid: 'did', displayName: 'Dee', photoUrl: null, sortName: 'dee', ...left});
    });

    test('a profile that is already right is left alone', async () => {
      await seedOld('e1');
      await db().doc('users/m').set({displayName: 'Mo'});
      await run();
      await db().doc('users/m').set({displayName: 'Maureen'});
      const again = await run();
      expect(again.profiles).toBe(1);
      expect((await profile('m'))?.displayName).toBe('Maureen');
    });

    // Req 43a: profiles written before the member picker gain a sort name
    // and whether the person is still in the event.
    test('profiles from before the picker gain a sort name and inEvent', async () => {
      await seedOld('e1');
      await db().doc('users/m').set({displayName: 'Mo'});
      await db().doc('users/gone').set({displayName: 'Gil'});
      await db().doc('events/e1/messages/x').set({senderId: 'gone', text: 'Hi'});
      await db().doc('events/e1/profiles/m').set(
        {uid: 'm', displayName: 'Mo', photoUrl: null, paymentMethod: null,
          paymentHandle: null, venmoHandle: null, cashappHandle: null});
      await db().doc('events/e1/profiles/gone').set({uid: 'gone', displayName: 'Gil', photoUrl: null});
      await run();
      expect(await profile('m')).toMatchObject({sortName: 'mo', inEvent: true});
      expect(await profile('gone')).toMatchObject({sortName: 'gil', inEvent: false});
    });
  });

  test('builds each event\'s chat summary from its messages (Req 57a)', async () => {
    await seedOld('e1');
    const at = (m: number) => Timestamp.fromDate(new Date(Date.UTC(2026, 5, 1, 12, m)));
    await db().doc('events/e1/messages/m1').set({senderId: 'a', text: 'Hi', timestamp: at(1), isHighPriority: true});
    await db().doc('events/e1/messages/m2').set({senderId: 'c', text: 'Hello', timestamp: at(2)});
    const result = await run();
    expect(result.chatSummaries).toBe(1);
    const s = (await db().doc('events/e1/chatSummary/current').get()).data()!;
    expect(s.count).toBe(2);
    expect(s.latest.id).toBe('m2');
    expect(s.lastUrgentSenderId).toBe('a');
    // An event with no messages needs none.
    await seedOld('e2');
    expect((await run()).chatSummaries).toBe(0);
  });

  test('running it again changes nothing, and keeps later role changes', async () => {
    await db().doc('events/e1/tasks/t1').set({title: 'Food', budgetEstimate: 280});
    await db().doc('events/e1/messages/x').set({senderId: 'gone', text: 'Hi'});
    await db().doc('users/c/private/profile').set({notificationPrefs: {timezone: 'Europe/London'}});
    await seedOld('e1', {startDate: Timestamp.fromDate(new Date('2026-07-01T23:00:00Z'))});
    await db().doc('events/e1/expenses/x').set({payerId: 'a', splits: [{userId: 'm', amount: 1}]});
    await run();
    await db().doc('events/e1/members/m').update({
      roleIds: ['finance'],
      permissions: computePermissions(['finance'], {}, {readsAllExpenses: true}),
    });
    const again = await run();
    expect(again).toEqual({
      events: 1, memberDocs: 0, statuses: 0, memberCounts: 0,
      involvedUids: 0, dates: 0, unknownZones: 0, taskBudgets: 0, profiles: 0,
      permissions: 0, chatSummaries: 0,
    });
    expect((await member('e1', 'm'))?.roleIds).toEqual(['finance']);
  });
});
