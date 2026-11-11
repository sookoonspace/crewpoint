/* eslint-disable */
// Acceptance tests for counts (#83, Req 52a). F1–F8 are imported from the
// convention fixture, F8 is cancelled through re-import, and F10 is absent
// because merging is Stage 2. Stays and opt-outs are set as an organizer
// would, and the §1 schedule is added. Then the counts must match §4.
import * as fs from 'fs';
import * as path from 'path';
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../test/setup';
import {computePermissions} from '../src/events/permissions';

const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {runImportJob} = require('../src/imports/runImport');
const {cancelImportedGroups} = require('../src/imports/cancelImportedGroups');
const {recalculateEvent} = require('../src/counts/recalculate');
const {exportRoster, freezeCounts} = require('../src/counts/exportAndFreeze');
const {parseCsv} = require('../src/imports/csv');

const E = 'derod';
const db = () => getAdminDb();
const fixture = JSON.parse(fs.readFileSync(
  path.join(__dirname, '..', '..', 'test_acceptance', 'fixtures', 'derod_convention_2027_v3.json'), 'utf8'));

const TARGETS = ['externalId', 'group', 'name', 'age', 'field:diet', 'field:kids', 'field:shirt'];
const DIET: Record<string, string> = {V: 'Veg', J: 'Jain', N: 'Non-veg'};

type Person = {name: string; age: number; diet: string; shirt?: string; kidsAct?: boolean; optOut?: string[]};
type Family = {id: string; surname: string; arrive: string; lastMeal: string; people: Person[]};
const families: Family[] = fixture.families;
// F8 cancelled before the event; only its two adults are known.
const f8 = {id: 'F8', surname: 'Shah', people: [
  {name: 'Adult 1', age: 40, diet: 'V'}, {name: 'Adult 2', age: 38, diet: 'V'},
] as Person[]};

function exportCsv(withF8: boolean): string {
  const lines = ['Registration ID,Family,Full name,Age,Diet,Kids activity,Shirt'];
  for (const f of [...families, ...(withF8 ? [f8] : [])]) {
    f.people.forEach((p, i) => lines.push([
      `${f.id}-${i}`, `${f.id} ${f.surname}`, p.name, p.age, DIET[p.diet], p.kidsAct ? 'yes' : 'no', p.shirt ?? '',
    ].join(',')));
  }
  return lines.join('\n');
}

async function run(id: string, csv: string) {
  await db().doc(`events/${E}/imports/${id}`).set({fileName: 'export.csv', targets: TARGETS, mode: 'apply', status: 'queued', createdBy: 'admin'});
  await runImportJob({eventId: E, jobId: id, readFile: async () => csv, deleteFile: async () => undefined});
  return (await db().doc(`events/${E}/imports/${id}`).get()).data()!;
}

/** A wall-clock time in Chicago, which is UTC-5 in July. */
const chicago = (day: number, hour: number, minute = 0) =>
  Timestamp.fromDate(new Date(Date.UTC(2027, 6, day, hour + 5, minute)));

const SCHEDULE: [string, number, number, number, string?][] = [
  ['M1', 16, 19, 0], ['P1', 16, 21, 0], ['M2', 17, 8, 0], ['M3', 17, 12, 30],
  ['K1', 17, 13, 30, 'bySession'], ['P2', 17, 16, 0], ['M4', 17, 19, 0], ['P3', 17, 21, 0],
  ['M5', 18, 8, 0], ['M6', 18, 12, 30], ['M7', 18, 19, 0], ['M8', 19, 8, 0],
];

let stats: any;

beforeAll(async () => {
  await clearFirestoreEmulator();
  await db().doc(`events/${E}`).set({
    title: 'Convention', status: 'published', creatorId: 'admin', adminIds: ['admin'], memberIds: ['admin'],
    dateOnly: true, startDate: new Date('2027-07-16T00:00:00Z'), timeZone: 'America/Chicago',
    settings: {
      attendancePolicy: 'arrivalToDeparture',
      categories: [{id: 'child', name: 'Child', maxAge: 17, isChild: true}, {id: 'adult', name: 'Adult', minAge: 18}],
    },
  });
  await db().doc(`events/${E}/members/admin`).set({uid: 'admin', roleIds: ['owner'], permissions: computePermissions(['owner'], {})});
  const fields: [string, string, string[]][] = [
    ['diet', 'singleChoice', ['Veg', 'Jain', 'Non-veg']],
    ['kids', 'yesNo', []],
    ['shirt', 'singleChoice', ['2T', 'YS', 'YM', 'S', 'M', 'L']],
  ];
  for (const [id, type, options] of fields) {
    await db().doc(`events/${E}/fields/${id}`).set({label: id, type, options, required: false, scope: 'participant', visibility: 'standard', order: 0});
  }
  for (const [id, day, hour, minute, attendance] of SCHEDULE) {
    await db().doc(`events/${E}/sessions/${id}`).set({
      title: id, startAt: chicago(day, hour, minute), hidden: false, attendance: attendance ?? null,
      eligibility: id === 'K1' ? {categoryIds: ['child'], filterTags: []} : {categoryIds: [], filterTags: []},
    });
  }

  await run('first', exportCsv(true));
  const second = await run('second', exportCsv(false));
  await ftest.wrap(cancelImportedGroups)({
    auth: {uid: 'admin'},
    data: {eventId: E, jobId: 'second', groupIds: second.report.missingGroups.map((m: any) => m.groupId)},
  });

  // Stays, opt-outs and sign-ups, as an organizer records them.
  const start = new Map(SCHEDULE.map(([id, d, h, m]) => [id, chicago(d, h, m)]));
  for (const f of families) {
    const arrive = f.arrive.includes('T') ? chicago(17, Number(f.arrive.slice(11, 13))) : null;
    // They leave after their last meal, before the next one.
    const departure = Timestamp.fromMillis(start.get(f.lastMeal)!.toMillis() + 60_000);
    for (const [i, p] of f.people.entries()) {
      const ref = (await db().collection(`events/${E}/participants`).where('externalId', '==', `${f.id}-${i}`).get()).docs[0].ref;
      await ref.update({
        arrivalAt: arrive, departureAt: departure,
        optOuts: p.optOut ?? [], signUps: p.kidsAct ? ['K1'] : [],
      });
    }
  }
  await recalculateEvent(db(), E, new Date('2027-07-10T12:00:00Z'));
  stats = (await db().doc(`events/${E}/stats/current`).get()).data();
});
afterAll(() => ftest.cleanup());

describe('counts', () => {
  test('B-04 headcount: 7 groups, 16 adults, 10 children, 26 people', () => {
    expect(stats.event.total).toBe(26);
    expect(stats.event.groups).toBe(7);
    expect(stats.event.byCategory).toEqual({adult: 16, child: 10});
  });

  test('B-04 diet totals: 18 veg, 2 Jain, 6 non-veg', () => {
    expect(stats.event.byField.diet).toEqual({Veg: 18, Jain: 2, 'Non-veg': 6});
  });

  test('B-04 kids activity: 7 sign-ups', () => {
    expect(stats.sessions.K1.total).toBe(7);
    expect(stats.event.byField.kids.yes).toBe(7);
  });

  test('B-04 the T-shirt report has one count per size, summing to 26', () => {
    const sizes = stats.event.byField.shirt as Record<string, number>;
    expect(Object.values(sizes).reduce((a, b) => a + b, 0)).toBe(26);
    for (const size of Object.keys(sizes)) expect(sizes[size]).toBeGreaterThan(0);
  });

  test('B-05 per-meal counts match §4, by diet', () => {
    const table: Record<string, [number, number, number, number]> = {
      M1: [25, 17, 2, 6], M2: [24, 17, 2, 5], M3: [24, 18, 0, 6], M4: [26, 18, 2, 6],
      M5: [26, 18, 2, 6], M6: [26, 18, 2, 6], M7: [26, 18, 2, 6], M8: [18, 10, 2, 6],
    };
    for (const [meal, [total, veg, jain, nonVeg]] of Object.entries(table)) {
      const s = stats.sessions[meal];
      expect({meal, total: s.total, veg: s.byField.diet.Veg ?? 0, jain: s.byField.diet.Jain ?? 0, nonVeg: s.byField.diet['Non-veg'] ?? 0})
        .toEqual({meal, total, veg, jain, nonVeg});
    }
  });
});

describe('export and freeze', () => {
  const call = (fn: unknown, data: object) => ftest.wrap(fn)({auth: {uid: 'admin'}, data: {eventId: E, ...data}});

  test('B-10 the registrations export for the caterer, one row per person, with diet', async () => {
    const {csv, rows} = await call(exportRoster, {});
    expect(rows).toBe(26);
    const table = parseCsv(csv);
    const diet = table[0].indexOf('diet');
    const byDiet: Record<string, number> = {};
    for (const row of table.slice(1)) byDiet[row[diet]] = (byDiet[row[diet]] ?? 0) + 1;
    expect(byDiet).toEqual({Veg: 18, Jain: 2, 'Non-veg': 6});
    // F8 was cancelled, so nobody from it is exported.
    expect(csv).not.toContain('Adult 1');
  });

  test('B-14 frozen meal counts stay, and later changes show against them', async () => {
    const {freezeId} = await call(freezeCounts, {label: 'Caterer'});
    // After the freeze, Jaya decides to come to Saturday breakfast.
    const jaya = (await db().collection(`events/${E}/participants`).where('name', '==', 'Jaya').get()).docs[0].ref;
    await jaya.update({optOuts: []});
    await recalculateEvent(db(), E, new Date('2027-07-12T12:00:00Z'));
    const frozen = (await db().doc(`events/${E}/countFreezes/${freezeId}`).get()).data()!;
    const live = (await db().doc(`events/${E}/stats/current`).get()).data()!;
    expect(frozen.sessions.M2.total).toBe(24);
    expect(live.sessions.M2.total).toBe(25);
    expect(frozen.sessions.M2.byField.diet['Non-veg']).toBe(5);
    expect(live.sessions.M2.byField.diet['Non-veg']).toBe(6);
  });
});
