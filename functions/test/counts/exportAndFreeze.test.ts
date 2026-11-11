/**
 * Req 53, 54 (B-10, B-14): the roster exports to CSV with private fields
 * left out unless asked for by someone who reads them, and counts are frozen
 * with a date, kept alongside later counts. Both need `reports.export`.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';
import {parseCsv} from '../../src/imports/csv';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const ftest = require('firebase-functions-test')();
getAdminApp();
/* eslint-disable @typescript-eslint/no-var-requires */
const {exportRoster, freezeCounts} = require('../../src/counts/exportAndFreeze');
const {clock} = require('../../src/utils/clock');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'conv';
const db = () => getAdminDb();
const ROLES: Record<string, string[]> = {
  owner: ['owner'], finance: ['finance'], lead: ['crewLead'], plain: ['participant'],
};

beforeEach(async () => {
  await clearFirestoreEmulator();
  await db().doc(`events/${E}`).set({
    title: 'Convention', status: 'published', creatorId: 'owner', adminIds: ['owner'],
    memberIds: Object.keys(ROLES), timeZone: 'America/Chicago',
    settings: {attendancePolicy: 'everyone', categories: [{id: 'child', name: 'Child'}, {id: 'adult', name: 'Adult'}]},
  });
  for (const [uid, roleIds] of Object.entries(ROLES)) {
    await db().doc(`events/${E}/members/${uid}`).set({uid, roleIds, permissions: computePermissions(roleIds, {})});
  }
  await db().doc(`events/${E}/fields/diet`).set({label: 'Diet', type: 'singleChoice', options: ['Veg', 'Jain'], scope: 'participant', visibility: 'standard', order: 0});
  await db().doc(`events/${E}/fields/allergy`).set({label: 'Allergy', type: 'text', options: [], scope: 'participant', visibility: 'private', order: 1});
  await db().doc(`events/${E}/groups/g1`).set({name: 'Desai'});
  const person = (id: string, over: object) => db().doc(`events/${E}/participants/${id}`).set({
    name: id, sortName: id.toLowerCase(), status: 'active', groupId: 'g1', categoryId: 'adult', fields: {}, ...over,
  });
  await person('Kunal', {fields: {diet: 'Veg'}, arrivalAt: Timestamp.fromDate(new Date('2027-07-17T16:00:00Z'))});
  await person('=HYPERLINK("x")', {fields: {diet: 'Jain'}, categoryId: 'child'});
  await person('Gone', {status: 'cancelled'});
  await db().doc(`events/${E}/participants/Kunal/private/details`).set({birthDate: '1983-01-02', fields: {allergy: 'Peanuts'}});
  await db().doc(`events/${E}/sessions/m1`).set({title: 'Dinner', startAt: Timestamp.fromDate(new Date('2027-07-17T00:00:00Z'))});
});
afterAll(() => ftest.cleanup());

const call = (fn: unknown, uid: string, data: object) => ftest.wrap(fn)({auth: {uid}, data: {eventId: E, ...data}});
const refused = expect.objectContaining({code: 'permission-denied'});

describe('exportRoster', () => {
  test('exports active people with standard answers, and no private ones by default', async () => {
    const {csv, rows} = await call(exportRoster, 'finance', {});
    expect(rows).toBe(2);
    const table = parseCsv(csv);
    expect(table[0]).toEqual(['Name', 'Group', 'Category', 'Arrives', 'Leaves', 'Diet']);
    expect(table.slice(1).map((r) => r[0])).toEqual(["'=HYPERLINK(\"x\")", 'Kunal']);
    expect(table[2]).toEqual(['Kunal', 'Desai', 'Adult', '2027-07-17 11:00', '', 'Veg']);
    expect(csv).not.toContain('Peanuts');
    expect(csv).not.toContain('1983');
  });

  test('includes private fields and birth dates only when asked, with readPrivate', async () => {
    const {csv} = await call(exportRoster, 'owner', {includePrivate: true});
    const table = parseCsv(csv);
    expect(table[0]).toEqual(['Name', 'Group', 'Category', 'Arrives', 'Leaves', 'Diet', 'Birth date', 'Allergy']);
    expect(table[2].slice(6)).toEqual(['1983-01-02', 'Peanuts']);
    await expect(call(exportRoster, 'finance', {includePrivate: true})).rejects.toEqual(refused);
  });

  test('needs reports.export', async () => {
    await expect(call(exportRoster, 'lead', {})).rejects.toEqual(refused);
    await expect(call(exportRoster, 'plain', {})).rejects.toEqual(refused);
  });
});

describe('freezeCounts', () => {
  test('counts now and keeps the numbers with the date, who froze them and a label', async () => {
    clock.now = () => new Date('2027-07-09T15:00:00Z').getTime();
    const {freezeId} = await call(freezeCounts, 'owner', {label: 'Caterer final'});
    const frozen = (await db().doc(`events/${E}/countFreezes/${freezeId}`).get()).data()!;
    expect((frozen.frozenAt as Timestamp).toDate()).toEqual(new Date('2027-07-09T15:00:00Z'));
    expect(frozen.frozenBy).toBe('owner');
    expect(frozen.label).toBe('Caterer final');
    expect(frozen.event.total).toBe(2);
    expect(frozen.sessions.m1.byField.diet).toEqual({Veg: 1, Jain: 1});
    // The live counts were refreshed too.
    expect((await db().doc(`events/${E}/stats/current`).get()).data()!.event.total).toBe(2);
  });

  test('a later freeze keeps the earlier one', async () => {
    await call(freezeCounts, 'owner', {});
    await db().doc(`events/${E}/participants/Gone`).update({status: 'active'});
    await call(freezeCounts, 'finance', {});
    const all = await db().collection(`events/${E}/countFreezes`).get();
    expect(all.docs.map((d) => d.data().event.total).sort()).toEqual([2, 3]);
  });

  test('needs reports.export, and a short label', async () => {
    await expect(call(freezeCounts, 'lead', {})).rejects.toEqual(refused);
    await expect(call(freezeCounts, 'owner', {label: 'x'.repeat(81)}))
      .rejects.toEqual(expect.objectContaining({code: 'invalid-argument'}));
  });
});
