/* eslint-disable */
// Load baselines (Req 60, 61, 83; S-02, S-08, GE-09). The deterministic
// fixture is imported at 400 and 2,000 people on the emulators, then a
// roster page and the counts are timed, and the reads and writes each step
// costs are counted for the cost estimate in docs/testing/load-baselines.md.
// Timings are emulator baselines, not production promises.
import {Firestore, Query, Timestamp, WriteBatch} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../test/setup';
import {computePermissions} from '../src/events/permissions';
import {LOAD_TARGETS, groupSizes, loadCsv, loadTier} from './loadFixture';

const ftest = require('firebase-functions-test')();
getAdminApp();
const {runImportJob} = require('../src/imports/runImport');
const {recalculateEvent} = require('../src/counts/recalculate');

const E = 'load';
const db = () => getAdminDb();

/** Reads (documents returned) and writes made while [fn] runs. */
async function counted<T>(fn: () => Promise<T>) {
  let reads = 0;
  let writes = 0;
  const query = Query.prototype.get;
  const getAll = Firestore.prototype.getAll;
  const commit = WriteBatch.prototype.commit;
  const q = jest.spyOn(Query.prototype, 'get').mockImplementation(async function (this: Query) {
    const snap = await query.call(this);
    reads += Math.max(1, snap.size);
    return snap;
  });
  const g = jest.spyOn(Firestore.prototype, 'getAll').mockImplementation(async function (this: Firestore, ...refs: any[]) {
    const snaps = await (getAll as any).apply(this, refs);
    reads += snaps.length;
    return snaps;
  } as any);
  const c = jest.spyOn(WriteBatch.prototype, 'commit').mockImplementation(async function (this: WriteBatch) {
    writes += ((this as any)._ops ?? (this as any)._writes ?? []).length;
    return commit.call(this);
  });
  const started = Date.now();
  try {
    const value = await fn();
    return {value, ms: Date.now() - started, reads, writes};
  } finally {
    q.mockRestore();
    g.mockRestore();
    c.mockRestore();
  }
}

async function seedEvent() {
  await clearFirestoreEmulator();
  await db().doc(`events/${E}`).set({
    title: 'Load', status: 'published', creatorId: 'admin', adminIds: ['admin'], memberIds: ['admin'],
    dateOnly: true, startDate: new Date('2027-07-16T00:00:00Z'), timeZone: 'America/Chicago',
    settings: {
      attendancePolicy: 'arrivalToDeparture',
      categories: [{id: 'child', name: 'Child', maxAge: 17, isChild: true}, {id: 'adult', name: 'Adult', minAge: 18}],
    },
  });
  await db().doc(`events/${E}/members/admin`).set({uid: 'admin', roleIds: ['owner'], permissions: computePermissions(['owner'], {})});
  for (const [id, type, options] of [['diet', 'singleChoice', ['Veg', 'Jain', 'Non-veg']], ['kids', 'yesNo', []]] as const) {
    await db().doc(`events/${E}/fields/${id}`).set({label: id, type, options, required: false, scope: 'participant', visibility: 'standard', order: 0});
  }
  // Twelve sessions over four days, as the convention's schedule.
  for (let i = 0; i < 12; i++) {
    await db().doc(`events/${E}/sessions/s${i}`).set({
      title: `Session ${i}`, hidden: false,
      startAt: Timestamp.fromDate(new Date(Date.UTC(2027, 6, 16 + Math.floor(i / 3), 13 + (i % 3) * 5))),
      eligibility: {categoryIds: [], filterTags: []},
    });
  }
}

async function importTier(people: number) {
  const tier = loadTier(people);
  await db().doc(`events/${E}/imports/apply`).set({fileName: 'load.csv', targets: LOAD_TARGETS, mode: 'apply', status: 'queued', createdBy: 'admin'});
  return counted(() => runImportJob({eventId: E, jobId: 'apply', readFile: async () => loadCsv(tier), deleteFile: async () => undefined}));
}

const rosterPage = () => counted(() =>
  db().collection(`events/${E}/participants`).orderBy('sortName').limit(51).get());

const count = () => counted(() => recalculateEvent(db(), E, new Date('2027-07-10T12:00:00Z')));

afterAll(() => ftest.cleanup());

const log = (line: string) => console.log(`LOAD ${line}`);

describe('load fixture', () => {
  test('S-02 the fixture is 108 groups and 400 people, and the same every time', () => {
    const tier = loadTier(400);
    expect(tier.groups).toHaveLength(108);
    expect(tier.people).toHaveLength(400);
    expect(loadCsv(loadTier(400))).toBe(loadCsv(tier));
  });

  test('GE-09 the 2,000 tier follows the same pattern', () => {
    expect(groupSizes(2000).reduce((a, b) => a + b, 0)).toBe(2000);
    expect(loadTier(2000).groups).toHaveLength(539);
  });
});

describe('baselines at 400', () => {
  let imported: Awaited<ReturnType<typeof importTier>>;
  beforeAll(async () => {
    await seedEvent();
    imported = await importTier(400);
  }, 180000);

  test('S-02 importing 108 groups finishes within 2 minutes and the headcount matches', async () => {
    log(`400 import: ${imported.ms} ms, ${imported.reads} reads, ${imported.writes} writes`);
    expect(imported.ms).toBeLessThan(120000);
    await count();
    const stats = (await db().doc(`events/${E}/stats/current`).get()).data()!;
    expect(stats.event.total).toBe(400);
    expect(stats.event.groups).toBe(108);
  });

  test('GE-09 a roster page loads within a second', async () => {
    const page = await rosterPage();
    log(`400 roster page: ${page.ms} ms, ${page.reads} reads`);
    expect(page.value.size).toBe(51);
    expect(page.ms).toBeLessThan(1000);
  });

  test('S-08 counting costs one read per person, group, session and field, and one write', async () => {
    const c = await count();
    log(`400 counts: ${c.ms} ms, ${c.reads} reads, ${c.writes} writes`);
    // Event + fields + people + groups + sessions.
    expect(c.reads).toBe(1 + 2 + 400 + 108 + 12);
    expect(c.ms).toBeLessThan(2000);
  });
});

describe('baselines at 2,000', () => {
  let imported: Awaited<ReturnType<typeof importTier>>;
  beforeAll(async () => {
    await seedEvent();
    imported = await importTier(2000);
  }, 600000);

  test('GE-09 2,000 people import, and the time is recorded', async () => {
    log(`2000 import: ${imported.ms} ms, ${imported.reads} reads, ${imported.writes} writes`);
    const total = await db().collection(`events/${E}/participants`).count().get();
    expect(total.data().count).toBe(2000);
  });

  test('GE-09 a roster page loads within a second at 2,000', async () => {
    const page = await rosterPage();
    log(`2000 roster page: ${page.ms} ms, ${page.reads} reads`);
    expect(page.ms).toBeLessThan(1000);
  });

  test('GE-09 counts finish within 2 seconds at 2,000', async () => {
    const c = await count();
    log(`2000 counts: ${c.ms} ms, ${c.reads} reads, ${c.writes} writes`);
    expect(c.reads).toBe(1 + 2 + 2000 + 539 + 12);
    expect(c.ms).toBeLessThan(2000);
  });
});
