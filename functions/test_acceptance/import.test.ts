/* eslint-disable */
// Acceptance tests for roster import (#77). Test names start with the
// scenario ID. Runs on the emulators only; the file is handed to the job
// directly, as Storage would.
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../test/setup';
import {computePermissions} from '../src/events/permissions';

const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {runImportJob} = require('../src/imports/runImport');
const {cancelImportedGroups} = require('../src/imports/cancelImportedGroups');

const E = 'derod';
const db = () => getAdminDb();
const TARGETS = ['externalId', 'group', 'name', 'age', 'field:diet', 'field:kids', 'email'];
const HEADER = 'Registration ID,Family,Full name,Age,Diet,Kids activity,Email';

/** A tool's export: [families] families of 3 or 4, 400 people at 108. */
function exportCsv(families: number, {cancel = [] as number[], change = [] as number[]} = {}) {
  const lines = [HEADER];
  let person = 0;
  for (let f = 1; f <= families; f++) {
    if (cancel.includes(f)) continue;
    const size = f <= 76 ? 4 : 3;
    for (let i = 1; i <= size; i++) {
      person++;
      const child = i > 2;
      const diet = change.includes(f) ? 'Jain' : ['Veg', 'Jain', 'Non-veg'][person % 3];
      lines.push([`R${f}-${i}`, `Family ${f}`, `Person ${f}-${i}`, child ? 8 : 40, diet, child ? 'yes' : 'no', child ? '' : `p${f}-${i}@x.test`].join(','));
    }
  }
  return lines.join('\n');
}

async function run(id: string, csv: string, mode: 'dryRun' | 'apply') {
  await db().doc(`events/${E}/imports/${id}`).set({fileName: 'export.csv', targets: TARGETS, mode, status: 'queued', createdBy: 'admin'});
  await runImportJob({eventId: E, jobId: id, readFile: async () => csv, deleteFile: async () => undefined});
  return (await db().doc(`events/${E}/imports/${id}`).get()).data()!;
}
const active = async () =>
  (await db().collection(`events/${E}/participants`).where('status', '==', 'active').count().get()).data().count;

beforeEach(async () => {
  await clearFirestoreEmulator();
  await db().doc(`events/${E}`).set({
    title: 'Convention', status: 'published', creatorId: 'admin', adminIds: ['admin'], memberIds: ['admin'],
    dateOnly: true, startDate: new Date('2027-07-16T00:00:00Z'),
    settings: {categories: [{id: 'child', name: 'Child', maxAge: 17, isChild: true}, {id: 'adult', name: 'Adult', minAge: 18}]},
  });
  await db().doc(`events/${E}/members/admin`).set({uid: 'admin', roleIds: ['owner'], permissions: computePermissions(['owner'], {})});
  for (const [id, type, options, required] of [['diet', 'singleChoice', ['Veg', 'Jain', 'Non-veg'], true], ['kids', 'yesNo', [], false]] as const) {
    await db().doc(`events/${E}/fields/${id}`).set({label: id, type, options, required, scope: 'participant', visibility: 'standard', order: 0});
  }
});
afterAll(() => ftest.cleanup());

describe('roster import', () => {
  test('X-01 a roster of 400 people imports with every per-person field and a validation report', async () => {
    const check = await run('check', exportCsv(108), 'dryRun');
    expect(check.report).toEqual(expect.objectContaining({total: 400, valid: 400, errorCount: 0, creates: 400, newGroups: 108}));
    const done = await run('apply', exportCsv(108), 'apply');
    expect(done.status).toBe('done');
    expect(await active()).toBe(400);
    const children = await db().collection(`events/${E}/participants`).where('categoryId', '==', 'child').count().get();
    expect(children.data().count).toBe(76 * 2 + 32);
    const one = (await db().collection(`events/${E}/participants`).where('externalId', '==', 'R1-3').get()).docs[0].data();
    expect(one.fields).toEqual(expect.objectContaining({kids: true}));
    expect(one.filterTags).toContain('kids=yes');
  });

  test('X-02 re-import adds new families, updates changes, duplicates nobody and keeps manual data', async () => {
    await run('first', exportCsv(100), 'apply');
    const ref = (await db().collection(`events/${E}/participants`).where('externalId', '==', 'R1-1').get()).docs[0].ref;
    await ref.update({'fields.tshirt': 'M'});
    const second = await run('second', exportCsv(108, {change: [1]}), 'apply');
    // Families 1-100 hold 376 people; the 8 new families of 3 add 24.
    expect(second.report).toEqual(expect.objectContaining({creates: 24, updates: 376, newGroups: 8}));
    expect(await active()).toBe(400);
    const total = await db().collection(`events/${E}/participants`).count().get();
    expect(total.data().count).toBe(400);
    const updated = (await ref.get()).data()!;
    expect(updated.fields).toEqual({diet: 'Jain', kids: false, tshirt: 'M'});
  });

  test('X-03 a family cancelled in the tool is listed, and confirming removes it from counts', async () => {
    await run('first', exportCsv(108), 'apply');
    const second = await run('second', exportCsv(108, {cancel: [8]}), 'apply');
    expect(second.report.missingGroups).toEqual([expect.objectContaining({name: 'Family 8'})]);
    // Listed for review, still counted until confirmed.
    expect(await active()).toBe(400);
    await ftest.wrap(cancelImportedGroups)({
      auth: {uid: 'admin'}, data: {eventId: E, jobId: 'second', groupIds: [second.report.missingGroups[0].groupId]},
    });
    expect(await active()).toBe(396);
    const kept = await db().collection(`events/${E}/participants`).where('status', '==', 'cancelled').count().get();
    expect(kept.data().count).toBe(4);
  });

  test('X-06 missing diet, unknown age and a duplicate email are listed, and the good rows still import', async () => {
    const csv = [
      HEADER,
      'R1-1,Patel,Ravi,40,Veg,no,dup@x.test',
      'R1-2,Patel,Mira,38,,no,',
      'R2-1,Shah,Dev,unknown,Veg,no,',
      'R2-2,Shah,Ana,35,Veg,no,DUP@x.test',
      'R3-1,Joshi,Ila,35,Jain,no,',
    ].join('\n');
    const done = await run('apply', csv, 'apply');
    expect(done.report.errors.map((e: {problem: string}) => e.problem)).toEqual(['required', 'unknownAge', 'duplicateEmail']);
    expect(done.report.errors.map((e: {row: number}) => e.row)).toEqual([3, 4, 5]);
    expect(await active()).toBe(2);
  });

  test('S-02 importing 108 families finishes within 2 minutes', async () => {
    const started = Date.now();
    await run('apply', exportCsv(108), 'apply');
    expect(Date.now() - started).toBeLessThan(120000);
    expect(await active()).toBe(400);
  });
});
