/**
 * Req 52: counts are stored in `stats/current` with an update time, private
 * answers included, and recalculated once per queued event.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const ftest = require('firebase-functions-test')();
getAdminApp();
/* eslint-disable @typescript-eslint/no-var-requires */
const {recalculateEvent, queueCounts, runQueuedCounts, COUNT_INPUTS} = require('../../src/counts/recalculate');
const {recalculateCounts} = require('../../src/counts/functions');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'conv';
const db = () => getAdminDb();
const now = new Date('2027-07-10T12:00:00Z');

beforeEach(async () => {
  await clearFirestoreEmulator();
  await db().doc(`events/${E}`).set({
    title: 'Convention', status: 'published', creatorId: 'owner', adminIds: ['owner'],
    memberIds: ['owner', 'plain'], settings: {attendancePolicy: 'everyone'},
  });
  for (const [uid, roles] of [['owner', ['owner']], ['plain', ['participant']]] as const) {
    await db().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds: roles, permissions: computePermissions([...roles], {}),
    });
  }
  await db().doc(`events/${E}/fields/diet`).set({label: 'Diet', type: 'singleChoice', options: ['Veg', 'Jain'], scope: 'participant', visibility: 'standard'});
  await db().doc(`events/${E}/fields/meal`).set({label: 'Meal', type: 'singleChoice', options: ['Fish', 'Veg'], scope: 'participant', visibility: 'private'});
  const person = (id: string, over: object) => db().doc(`events/${E}/participants/${id}`).set({
    name: id, status: 'active', groupId: 'g1', categoryId: 'adult', fields: {}, ...over,
  });
  await person('a', {fields: {diet: 'Veg'}});
  await person('b', {fields: {diet: 'Jain'}, categoryId: 'child'});
  await person('c', {status: 'cancelled', fields: {diet: 'Veg'}});
  await db().doc(`events/${E}/participants/a/private/details`).set({fields: {meal: 'Fish'}});
  await db().doc(`events/${E}/groups/g1`).set({name: 'Desai'});
  await db().doc(`events/${E}/sessions/m1`).set({title: 'Dinner', startAt: Timestamp.fromDate(new Date('2027-07-17T00:00:00Z'))});
});
afterAll(() => ftest.cleanup());

const stats = async () => (await db().doc(`events/${E}/stats/current`).get()).data();

test('stores counts with when they were updated', async () => {
  await recalculateEvent(db(), E, now);
  const s = (await stats())!;
  expect((s.updatedAt as Timestamp).toDate()).toEqual(now);
  expect(s.event).toEqual({
    total: 2, groups: 1, byCategory: {adult: 1, child: 1},
    byField: {diet: {Veg: 1, Jain: 1}, meal: {Fish: 1, _none: 1}},
  });
  expect(s.sessions.m1.total).toBe(2);
});

test('queued events are counted once, then leave the queue', async () => {
  await queueCounts(db(), E, now);
  expect(await runQueuedCounts(db(), now)).toBe(1);
  expect(await stats()).toBeDefined();
  expect((await db().doc(`countsQueue/${E}`).get()).exists).toBe(false);
  expect(await runQueuedCounts(db(), now)).toBe(0);
});

test('only participants, groups, sessions and fields queue counts', () => {
  expect([...COUNT_INPUTS].sort()).toEqual(['fields', 'groups', 'participants', 'sessions']);
});

describe('recalculateCounts', () => {
  const call = (uid: string) => ftest.wrap(recalculateCounts)({auth: {uid}, data: {eventId: E}});

  test('counts now for counts.read', async () => {
    const result = await call('owner');
    expect(result.updatedAt).toBeDefined();
    expect((await stats())!.event.total).toBe(2);
  });

  test('is refused without counts.read', async () => {
    await expect(call('plain')).rejects.toEqual(expect.objectContaining({code: 'permission-denied'}));
    expect(await stats()).toBeUndefined();
  });
});
