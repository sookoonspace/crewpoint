/**
 * Req 44, 44a, 45, 75 (X-01, X-02, X-03, X-06): the import job. A dry run
 * writes a report; applying writes people and groups in chunks with
 * progress, keeps unmapped data, and deletes the file. Missing groups are
 * cancelled only when confirmed, keeping the records.
 */
import {FieldValue} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {runImportJob} = require('../../src/imports/runImport');
const {cancelImportedGroups} = require('../../src/imports/cancelImportedGroups');
const {importFileExpired} = require('../../src/imports/cleanupImports');
const {externalIdMatchKey} = require('../../src/participants/matchKeys');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'conv';
const db = () => getAdminDb();
const job = async (id = 'j1') => (await db().doc(`events/${E}/imports/${id}`).get()).data()!;
const people = async () => {
  const snap = await db().collection(`events/${E}/participants`).orderBy('sortName').get();
  return snap.docs.map((d) => ({id: d.id, ...d.data()} as Record<string, unknown>));
};
const header = 'Family,ID,Name,Age,Diet,Allergy,Hotel';
const TARGETS = ['group', 'externalId', 'name', 'age', 'field:diet', 'field:allergy', 'field:hotel'];
const deleted: string[] = [];

async function queue(text: string, {id = 'j1', mode = 'dryRun', targets = TARGETS} = {}) {
  await db().doc(`events/${E}/imports/${id}`).set({
    fileName: 'roster.csv', targets, mode, status: 'queued', createdBy: 'owner',
  });
  await runImportJob({
    eventId: E, jobId: id,
    readFile: async () => text,
    deleteFile: async (path: string) => {
      deleted.push(path);
    },
  });
}

beforeEach(async () => {
  await clearFirestoreEmulator();
  deleted.length = 0;
  await db().doc(`events/${E}`).set({
    title: 'Convention', status: 'published', creatorId: 'owner', adminIds: ['owner'],
    memberIds: ['owner'], dateOnly: true,
    startDate: new Date('2027-07-16T00:00:00Z'),
    settings: {categories: [
      {id: 'child', name: 'Child', maxAge: 17, isChild: true},
      {id: 'adult', name: 'Adult', minAge: 18},
    ]},
  });
  await db().doc(`events/${E}/members/owner`).set({
    uid: 'owner', roleIds: ['owner'], permissions: computePermissions(['owner'], {}),
  });
  const field = (id: string, over: object) => db().doc(`events/${E}/fields/${id}`).set({
    label: id, options: [], required: false, scope: 'participant', visibility: 'standard', order: 0, ...over,
  });
  await field('diet', {type: 'singleChoice', options: ['Jain', 'Veg'], required: true});
  await field('allergy', {type: 'text', visibility: 'private'});
  await field('hotel', {type: 'text', scope: 'group'});
});
afterAll(() => ftest.cleanup());

const first = [
  header,
  'Patel,P1,Ravi Patel,42,Jain,,Inn',
  'Patel,P2,Asha Patel,9,Veg,Nuts,',
  'Shah,S1,Dev Shah,unknown,Veg,,',
  'Shah,S2,Ana Shah,30,,,',
  'Joshi,J1,Ila Joshi,35,Veg,,',
].join('\n');

describe('a dry run (X-06)', () => {
  test('reports what would happen, and writes nobody', async () => {
    await queue(first);
    const j = await job();
    expect(j.status).toBe('checked');
    expect(j.report).toEqual(expect.objectContaining({
      total: 5, valid: 3, creates: 3, updates: 0, newGroups: 2, errorCount: 2,
    }));
    expect(j.report.errors).toEqual([
      {row: 4, column: 'Age', problem: 'unknownAge'},
      {row: 5, column: 'Diet', problem: 'required'},
    ]);
    expect(await people()).toEqual([]);
    expect(deleted).toEqual([]);
  });

  test('an unreadable file fails the job and says why', async () => {
    await queue('Name\n"open');
    const j = await job();
    expect(j.status).toBe('failed');
    expect(j.error).toBe('unreadable');
  });

  test('a job that is not queued is left alone', async () => {
    await db().doc(`events/${E}/imports/j2`).set({status: 'done', targets: TARGETS, mode: 'apply', createdBy: 'owner'});
    await runImportJob({eventId: E, jobId: 'j2', readFile: async () => first, deleteFile: async () => undefined});
    expect((await job('j2')).status).toBe('done');
  });
});

describe('applying (X-01)', () => {
  test('writes good rows with groups, answers and age bands, then deletes the file', async () => {
    await queue(first, {mode: 'apply'});
    const j = await job();
    expect(j.status).toBe('done');
    expect(j.progress).toEqual({processed: 3, total: 3});
    expect(deleted).toEqual([`events/${E}/imports/j1.csv`]);
    const all = await people();
    expect(all.map((p) => p.name)).toEqual(['Asha Patel', 'Ila Joshi', 'Ravi Patel']);
    const asha = all.find((p) => p.name === 'Asha Patel')!;
    expect(asha).toEqual(expect.objectContaining({
      externalId: 'P2', categoryId: 'child', isChild: true, imported: true, status: 'active',
      fields: {diet: 'Veg'}, filterTags: ['diet=Veg'], createdBy: 'owner',
    }));
    const ashaPrivate = (await db().doc(`events/${E}/participants/${asha.id}/private/details`).get()).data();
    expect(ashaPrivate?.fields).toEqual({allergy: 'Nuts'});
    const groups = await db().collection(`events/${E}/groups`).orderBy('sortName').get();
    expect(groups.docs.map((g) => g.data().name)).toEqual(['Joshi', 'Patel']);
    const patel = groups.docs.find((g) => g.data().name === 'Patel')!;
    expect(patel.data()).toEqual(expect.objectContaining({imported: true, fields: {hotel: 'Inn'}, adultUids: []}));
    expect(asha.groupId).toBe(patel.id);
  });
});

describe('re-import (X-02, X-03)', () => {
  beforeEach(async () => {
    await queue(first, {mode: 'apply'});
  });

  test('updates matches, adds new people, keeps manual data, and never duplicates', async () => {
    const ravi = (await people()).find((p) => p.name === 'Ravi Patel')!;
    // Edited by hand: an unmapped field, and a manual note on the record.
    await db().doc(`events/${E}/participants/${ravi.id}`).update({'fields.tshirt': 'L', isChild: false});
    const second = [
      header,
      'Patel,P1,Ravi K Patel,42,Veg,,Inn',
      'Patel,P2,Asha Patel,9,Veg,Nuts,',
      'Mehta,M1,Neel Mehta,50,Jain,,',
    ].join('\n');
    await queue(second, {id: 'j2', mode: 'dryRun'});
    const report = (await job('j2')).report;
    expect(report).toEqual(expect.objectContaining({creates: 1, updates: 2}));
    expect(report.missingGroups).toEqual([
      expect.objectContaining({name: 'Joshi', participantIds: [expect.any(String)]}),
    ]);
    await queue(second, {id: 'j3', mode: 'apply'});
    const all = await people();
    expect(all.map((p) => p.name)).toEqual(['Asha Patel', 'Ila Joshi', 'Neel Mehta', 'Ravi K Patel']);
    const updated = all.find((p) => p.id === ravi.id)!;
    expect(updated.fields).toEqual({diet: 'Veg', tshirt: 'L'});
    expect(updated.filterTags).toEqual(['diet=Veg']);
    // Ila is listed, not removed, until someone confirms.
    expect(all.find((p) => p.name === 'Ila Joshi')!.status).toBe('active');
  });

  test('an unnamed entry left by a deleted account is refilled, not added again (Req 14a)', async () => {
    const ravi = (await people()).find((p) => p.name === 'Ravi Patel')!;
    // What deleting Ravi's linked account leaves behind.
    await db().doc(`events/${E}/participants/${ravi.id}`).update({
      name: '', sortName: '\uf8ff', anonymised: true, externalId: FieldValue.delete(),
    });
    await db().doc(`events/${E}/participantKeys/${ravi.id}`).set({
      externalIdKey: await externalIdMatchKey(E, 'P1'),
    });
    await queue(first, {id: 'j2', mode: 'apply'});
    expect((await job('j2')).report).toEqual(expect.objectContaining({creates: 0}));
    const back = (await people()).find((p) => p.id === ravi.id)!;
    expect(back).toEqual(expect.objectContaining({name: 'Ravi Patel', externalId: 'P1'}));
    expect(back.anonymised).toBeUndefined();
    expect((await db().doc(`events/${E}/participantKeys/${ravi.id}`).get()).exists).toBe(false);
  });

  test('X-03 confirming cancels the missing groups and keeps their records', async () => {
    await queue([header, 'Patel,P1,Ravi Patel,42,Jain,,'].join('\n'), {id: 'j2', mode: 'apply'});
    const missing = (await job('j2')).report.missingGroups as {groupId: string}[];
    // Patel still has Ravi, and Shah never imported, so only Joshi is missing.
    expect(missing.map((m) => m.groupId)).toHaveLength(1);
    await ftest.wrap(cancelImportedGroups)({
      auth: {uid: 'owner'},
      data: {eventId: E, jobId: 'j2', groupIds: [missing[0].groupId]},
    });
    const all = await people();
    const cancelled = all.filter((p) => p.status === 'cancelled');
    expect(cancelled.length).toBeGreaterThan(0);
    expect(cancelled.every((p) => p.groupId === missing[0].groupId)).toBe(true);
    expect((await db().doc(`events/${E}/groups/${missing[0].groupId}`).get()).data()?.status).toBe('cancelled');
    expect((await job('j2')).cancelledGroupIds).toEqual([missing[0].groupId]);
  });

  test('confirming needs participants.import, and only groups the job listed', async () => {
    await db().doc(`events/${E}/members/plain`).set({uid: 'plain', roleIds: ['participant'], permissions: ['chat.send']});
    await db().doc(`events/${E}`).update({memberIds: ['owner', 'plain']});
    await queue([header, 'Patel,P1,Ravi Patel,42,Jain,,'].join('\n'), {id: 'j2', mode: 'apply'});
    const call = (uid: string, groupIds: string[]) => ftest.wrap(cancelImportedGroups)({
      auth: {uid}, data: {eventId: E, jobId: 'j2', groupIds},
    });
    const missing = (await job('j2')).report.missingGroups as {groupId: string}[];
    await expect(call('plain', [missing[0].groupId])).rejects.toEqual(expect.objectContaining({code: 'permission-denied'}));
    await expect(call('owner', ['not-listed'])).rejects.toEqual(expect.objectContaining({code: 'invalid-argument'}));
  });
});

describe('the file is kept for 7 days at most (Req 44a)', () => {
  const now = new Date('2027-07-20T00:00:00Z');
  test('older than 7 days goes', () => {
    expect(importFileExpired(new Date('2027-07-12T23:59:00Z'), now)).toBe(true);
    expect(importFileExpired(new Date('2027-07-13T01:00:00Z'), now)).toBe(false);
  });
});
