/**
 * Req 19 (GE-08): five statuses control who sees and changes what, and start
 * and end times move events on a schedule.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
/* eslint-disable @typescript-eslint/no-var-requires */
const {
  mapLegacyStatus,
  nextStatus,
  runStatusChanges,
} = require('../../src/events/eventStatus');
const {createEvent} = require('../../src/events/createEvent');
const {saveExpense} = require('../../src/events/saveExpense');
const {recordSettlement} = require('../../src/events/recordSettlement');
const {disputeSettlement} = require('../../src/events/disputeSettlement');
const {markTaskComplete} = require('../../src/events/markTaskComplete');
const {joinEvent} = require('../../src/events/joinEvent');
const {generateInviteCode} = require('../../src/events/generateInviteCode');
const {promoteToAdmin} = require('../../src/events/promoteToAdmin');
const {demoteAdmin} = require('../../src/events/demoteAdmin');
const {removeEventMember} = require('../../src/events/removeEventMember');
const {changeEventCurrency} = require('../../src/events/changeEventCurrency');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const REF = `events/${E}`;
const db = () => getAdminDb();
const at = (iso: string) => new Date(iso);
const ts = (iso: string) => Timestamp.fromDate(at(iso));
const rejected = (code: string) => expect.objectContaining({code});
const call = (fn: unknown, uid: string, data: object) =>
  ftest.wrap(fn)({auth: {uid}, data});

async function seed(status: string | undefined, over: object = {}) {
  await db().doc(REF).set({
    title: 'Convention',
    creatorId: 'owner',
    adminIds: ['owner', 'admin'],
    memberIds: ['owner', 'admin', 'member', 'other'],
    currency: 'USD',
    ...(status ? {status} : {}),
    ...over,
  });
}

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('the mapping for existing events', () => {
  const now = at('2027-06-01T00:00:00Z');

  test('active becomes ended once the end date has passed', () => {
    expect(mapLegacyStatus('active', at('2027-05-01T00:00:00Z'), now)).toBe('ended');
  });

  test('active becomes published otherwise', () => {
    expect(mapLegacyStatus('active', at('2027-07-01T00:00:00Z'), now)).toBe('published');
    expect(mapLegacyStatus('active', null, now)).toBe('published');
    expect(mapLegacyStatus(undefined, null, now)).toBe('published');
  });

  test('archived stays archived', () => {
    expect(mapLegacyStatus('archived', at('2027-05-01T00:00:00Z'), now)).toBe('archived');
  });

  test('a current status is left alone', () => {
    expect(mapLegacyStatus('draft', null, now)).toBe('draft');
    expect(mapLegacyStatus('live', at('2027-05-01T00:00:00Z'), now)).toBe('live');
  });
});

describe('nextStatus', () => {
  const event = (over: object) => ({timeZone: 'UTC', ...over});
  const start = ts('2027-06-01T15:00:00Z');
  const end = ts('2027-06-03T18:00:00Z');

  test('published stays until the start time, then goes live', () => {
    const data = event({status: 'published', startDate: start, endDate: end});
    expect(nextStatus(data, at('2027-06-01T14:59:00Z'))).toBeNull();
    expect(nextStatus(data, at('2027-06-01T15:00:00Z'))).toBe('live');
  });

  test('live ends after the end time', () => {
    const data = event({status: 'live', startDate: start, endDate: end});
    expect(nextStatus(data, at('2027-06-03T17:59:00Z'))).toBeNull();
    expect(nextStatus(data, at('2027-06-03T18:00:00Z'))).toBe('ended');
  });

  test('published past both times goes straight to ended', () => {
    const data = event({status: 'published', startDate: start, endDate: end});
    expect(nextStatus(data, at('2027-07-01T00:00:00Z'))).toBe('ended');
  });

  test.each(['draft', 'ended', 'archived'])('%s never changes by itself', (status) => {
    const data = event({status, startDate: start, endDate: end});
    expect(nextStatus(data, at('2027-07-01T00:00:00Z'))).toBeNull();
  });

  test('an event without dates stays until changed by hand', () => {
    expect(nextStatus(event({status: 'published'}), at('2030-01-01T00:00:00Z'))).toBeNull();
    expect(nextStatus(event({status: 'live'}), at('2030-01-01T00:00:00Z'))).toBeNull();
  });

  test('an end given as a date runs to the end of that day in the event zone', () => {
    // Midnight in Chicago on June 3 is 05:00 UTC, in daylight time.
    const data = {
      status: 'live',
      timeZone: 'America/Chicago',
      endDate: ts('2027-06-03T05:00:00Z'),
    };
    expect(nextStatus(data, at('2027-06-03T23:00:00Z'))).toBeNull();
    expect(nextStatus(data, at('2027-06-04T05:00:00Z'))).toBe('ended');
  });

  test('an unknown zone does not stop the change', () => {
    const data = {status: 'live', timeZone: 'Mars/Base', endDate: end};
    expect(nextStatus(data, at('2027-06-03T18:00:00Z'))).toBe('ended');
  });

  describe('date-only events (Req 23)', () => {
    // Stored as midnight UTC on the chosen date.
    const data = (timeZone: string) => ({
      status: 'published',
      timeZone,
      dateOnly: true,
      startDate: ts('2027-06-01T00:00:00Z'),
      endDate: ts('2027-06-03T00:00:00Z'),
    });

    test('go live at the start of the day in the event zone', () => {
      // Midnight on June 1 in Chicago, in daylight time, is 05:00 UTC.
      expect(nextStatus(data('America/Chicago'), at('2027-06-01T04:59:00Z'))).toBeNull();
      expect(nextStatus(data('America/Chicago'), at('2027-06-01T05:00:00Z'))).toBe('live');
      // Midnight on June 1 in Tokyo is 15:00 UTC the day before.
      expect(nextStatus(data('Asia/Tokyo'), at('2027-05-31T15:00:00Z'))).toBe('live');
    });

    test('end after the last day in the event zone', () => {
      const live = {...data('America/Chicago'), status: 'live'};
      expect(nextStatus(live, at('2027-06-04T04:59:00Z'))).toBeNull();
      expect(nextStatus(live, at('2027-06-04T05:00:00Z'))).toBe('ended');
    });

    test('use the right offset across daylight saving', () => {
      // Chicago's clocks moved on 14 March 2027, from UTC-6 to UTC-5.
      const across = {
        status: 'published',
        timeZone: 'America/Chicago',
        dateOnly: true,
        startDate: ts('2027-03-15T00:00:00Z'),
      };
      expect(nextStatus(across, at('2027-03-15T04:59:00Z'))).toBeNull();
      expect(nextStatus(across, at('2027-03-15T05:00:00Z'))).toBe('live');
    });

    test('fall back to UTC for an unknown zone', () => {
      expect(nextStatus(data('Mars/Base'), at('2027-06-01T00:00:00Z'))).toBe('live');
    });
  });

  describe('a change by hand is respected', () => {
    test('published by hand after the start stays published', () => {
      const data = event({
        status: 'published',
        startDate: start,
        statusSetAt: ts('2027-06-02T00:00:00Z'),
      });
      expect(nextStatus(data, at('2027-06-02T01:00:00Z'))).toBeNull();
    });

    test('live by hand after the end stays live', () => {
      const data = event({
        status: 'live',
        endDate: end,
        statusSetAt: ts('2027-06-04T00:00:00Z'),
      });
      expect(nextStatus(data, at('2027-06-05T00:00:00Z'))).toBeNull();
    });

    test('live by hand before the start still ends on time', () => {
      const data = event({
        status: 'live',
        startDate: start,
        endDate: end,
        statusSetAt: ts('2027-05-01T00:00:00Z'),
      });
      expect(nextStatus(data, at('2027-06-03T18:00:00Z'))).toBe('ended');
    });
  });
});

describe('runStatusChanges', () => {
  test('changes only the events that are due', async () => {
    const now = at('2027-06-02T00:00:00Z');
    const seedDoc = (id: string, data: object) =>
      db().doc(`events/${id}`).set({timeZone: 'UTC', ...data});
    await seedDoc('toLive', {status: 'published', startDate: ts('2027-06-01T00:00:00Z')});
    await seedDoc('toEnded', {status: 'live', endDate: ts('2027-06-01T00:00:00Z')});
    await seedDoc('waiting', {status: 'published', startDate: ts('2027-07-01T00:00:00Z')});
    await seedDoc('drafted', {status: 'draft', startDate: ts('2027-06-01T00:00:00Z')});
    await seedDoc('undated', {status: 'published'});

    expect(await runStatusChanges(db(), now)).toBe(2);

    const status = async (id: string) => (await db().doc(`events/${id}`).get()).data()!.status;
    expect(await status('toLive')).toBe('live');
    expect(await status('toEnded')).toBe('ended');
    expect(await status('waiting')).toBe('published');
    expect(await status('drafted')).toBe('draft');
    expect(await status('undated')).toBe('published');
  });

  test('a second run changes nothing', async () => {
    const now = at('2027-06-02T00:00:00Z');
    await db().doc('events/a').set({
      timeZone: 'UTC',
      status: 'published',
      startDate: ts('2027-06-01T00:00:00Z'),
    });
    await runStatusChanges(db(), now);
    expect(await runStatusChanges(db(), now)).toBe(0);
  });
});

describe('a new event', () => {
  test('starts as a draft', async () => {
    await call(createEvent, 'me', {eventId: E, title: 'T'});
    expect((await db().doc(REF).get()).data()!.status).toBe('draft');
  });
});

describe('joining', () => {
  const invite = () => db().doc('event_invites/ABC123').set({
    eventId: E,
    createdBy: 'owner',
    expiresAt: Timestamp.fromMillis(Date.now() + 86400000),
  });

  test.each(['draft', 'ended', 'archived'])('nobody can join when %s', async (status) => {
    await seed(status);
    await invite();
    await expect(call(joinEvent, 'new', {joinCode: 'ABC123'}))
      .rejects.toEqual(rejected('failed-precondition'));
    expect((await db().doc(REF).get()).data()!.memberIds).not.toContain('new');
  });

  test.each(['published', 'live', 'active', undefined])('joining works when %s', async (status) => {
    await seed(status);
    await invite();
    await call(joinEvent, 'new', {joinCode: 'ABC123'});
    expect((await db().doc(REF).get()).data()!.memberIds).toContain('new');
  });

  test.each(['draft', 'ended', 'archived'])('no invite code is made when %s', async (status) => {
    await seed(status);
    await expect(call(generateInviteCode, 'owner', {eventId: E}))
      .rejects.toEqual(rejected('failed-precondition'));
  });

  test('an invite code is made when published', async () => {
    await seed('published');
    await expect(call(generateInviteCode, 'owner', {eventId: E})).resolves.toBeDefined();
  });
});

describe('money', () => {
  const expense = {
    eventId: E,
    expenseId: 'x1',
    payerId: 'member',
    amount: 30,
    description: 'Dinner',
    isDonation: false,
    splits: [{userId: 'member', amount: 15}, {userId: 'other', amount: 15}],
  };
  const settlement = {
    eventId: E,
    settlementId: 's1',
    payerId: 'member',
    payeeId: 'other',
    amount: 25,
  };

  test('expenses and settlements stay open after an event ends', async () => {
    await seed('ended');
    await call(saveExpense, 'member', expense);
    await call(recordSettlement, 'member', settlement);
    await call(disputeSettlement, 'other', {eventId: E, settlementId: 's1'});
    expect((await db().doc(`${REF}/expenses/x1`).get()).exists).toBe(true);
    expect((await db().doc(`${REF}/expenses/s1`).get()).exists).toBe(false);
  });

  test('archived refuses all of them', async () => {
    await seed('published');
    await call(recordSettlement, 'member', settlement);
    await db().doc(REF).update({status: 'archived'});
    const refused = rejected('failed-precondition');
    await expect(call(saveExpense, 'member', expense)).rejects.toEqual(refused);
    await expect(call(recordSettlement, 'member', {...settlement, settlementId: 's2'}))
      .rejects.toEqual(refused);
    await expect(call(disputeSettlement, 'other', {eventId: E, settlementId: 's1'}))
      .rejects.toEqual(refused);
    await expect(call(changeEventCurrency, 'owner', {eventId: E, currency: 'EUR'}))
      .rejects.toEqual(refused);
  });
});

describe('tasks', () => {
  const seedTask = () => db().doc(`${REF}/tasks/t1`).set({
    eventId: E,
    title: 'Task',
    assigneeId: 'member',
    createdBy: 'member',
    status: 'todo',
  });
  const complete = (uid: string) =>
    call(markTaskComplete, uid, {eventId: E, taskId: 't1'});

  test('after an event ends only an organizer can complete a task', async () => {
    await seed('ended');
    await seedTask();
    await expect(complete('member')).rejects.toEqual(rejected('failed-precondition'));
    await complete('admin');
    expect((await db().doc(`${REF}/tasks/t1`).get()).data()!.status).toBe('done');
  });

  test('when archived nobody can', async () => {
    await seed('archived');
    await seedTask();
    await expect(complete('owner')).rejects.toEqual(rejected('failed-precondition'));
  });
});

describe('members', () => {
  test('archived refuses membership changes', async () => {
    await seed('archived');
    const refused = rejected('failed-precondition');
    await expect(call(promoteToAdmin, 'owner', {eventId: E, targetUserId: 'member'}))
      .rejects.toEqual(refused);
    await expect(call(demoteAdmin, 'owner', {eventId: E, targetUserId: 'admin'}))
      .rejects.toEqual(refused);
    await expect(call(removeEventMember, 'owner', {eventId: E, targetUserId: 'member'}))
      .rejects.toEqual(refused);
  });

  test('a draft keeps its members as organizers, so demoting is refused', async () => {
    await seed('draft', {memberIds: ['owner', 'admin']});
    await expect(call(demoteAdmin, 'owner', {eventId: E, targetUserId: 'admin'}))
      .rejects.toEqual(rejected('failed-precondition'));
  });
});
