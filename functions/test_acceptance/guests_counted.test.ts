/**
 * PA-05 (#75, #83): people with no account are counted like everyone else.
 * Counts read participants, never member documents or accounts.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../test/setup';

getAdminApp();
// eslint-disable-next-line @typescript-eslint/no-var-requires
const {recalculateEvent} = require('../src/counts/recalculate');

const E = 'guests';

afterEach(clearFirestoreEmulator);

test('PA-05 guests with no account appear in counts', async () => {
  const db = getAdminDb();
  await db.doc(`events/${E}`).set({
    title: 'Gathering', status: 'published', creatorId: 'owner', adminIds: ['owner'],
    memberIds: ['owner'], settings: {attendancePolicy: 'everyone'},
  });
  const person = (id: string, over: object) => db.doc(`events/${E}/participants/${id}`).set({
    name: id, status: 'active', groupId: null, categoryId: 'adult', fields: {}, ...over,
  });
  await person('linked', {uid: 'owner'});
  await person('guest', {});
  await person('child', {categoryId: 'child', isChild: true});

  await recalculateEvent(db, E, new Date('2027-07-10T12:00:00Z'));

  const stats = (await db.doc(`events/${E}/stats/current`).get()).data()!;
  expect(stats.event.total).toBe(3);
  expect(stats.event.byCategory).toEqual({adult: 2, child: 1});
});
