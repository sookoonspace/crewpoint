/**
 * Spec #233 Req 30 (#247): the server's list of who said no to photos or
 * has not answered, with only name, group name and age band, kept up to
 * date as answers change, and the totals Counts show.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {photoEntry, refreshPhotoConsent, rebuildPhotoConsent} from '../../src/participants/photoConsent';
import {recalculateEvent} from '../../src/counts/recalculate';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {onPhotoConsentAnswerWritten} = require('../../src/participants/photoConsent');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const db = () => getAdminDb();
const categories = [{id: 'child', name: 'Child'}, {id: 'adult', name: 'Adult'}];

async function seed() {
  await db().doc(`events/${E}`).set({title: 'Convention', status: 'published', settings: {categories}});
  await db().doc(`events/${E}/groups/g1`).set({name: 'Shah family'});
  const person = (id: string, name: string, categoryId: string, extra: object = {}) =>
    db().doc(`events/${E}/participants/${id}`).set({name, groupId: 'g1', categoryId, status: 'active', ...extra});
  await person('nita', 'Nita Shah', 'adult');
  await person('rohan', 'Rohan Shah', 'child');
  await person('jaya', 'Jaya Shah', 'adult');
  await person('gone', 'Gone Shah', 'adult', {registrationStatus: 'cancelled'});
  await db().doc(`events/${E}/participants/nita/private/details`).set({photoConsent: true, birthDate: '1978-04-04'});
  await db().doc(`events/${E}/participants/rohan/private/details`).set({photoConsent: false, birthDate: '2014-06-06'});
}
const list = async () => (await db().doc(`events/${E}/photoConsent/current`).get()).data()?.people ?? {};

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('photoEntry', () => {
  test('yes is not listed; no and unanswered are, with only name, group and age band', () => {
    const p = {name: 'Rohan', categoryId: 'child', status: 'active'};
    expect(photoEntry(p, {photoConsent: true}, 'Shahs', categories)).toBeNull();
    expect(photoEntry(p, {photoConsent: false, birthDate: '2014-06-06'}, 'Shahs', categories))
      .toEqual({name: 'Rohan', groupName: 'Shahs', ageBand: 'Child', answer: 'no'});
    expect(photoEntry(p, undefined, 'Shahs', categories)?.answer).toBe('unanswered');
    expect(photoEntry({...p, registrationStatus: 'waitlisted'}, undefined, '', categories)).toBeNull();
  });
});

describe('the list', () => {
  test('is built with everyone who said no or has not answered, confirmed people only', async () => {
    await seed();
    await rebuildPhotoConsent(db(), E);
    expect(await list()).toEqual({
      rohan: {name: 'Rohan Shah', groupName: 'Shah family', ageBand: 'Child', answer: 'no'},
      jaya: {name: 'Jaya Shah', groupName: 'Shah family', ageBand: 'Adult', answer: 'unanswered'},
    });
  });

  test('a first change builds the whole list, so people who never answered are on it', async () => {
    await seed();
    await refreshPhotoConsent(db(), E, ['nita']);
    expect(Object.keys(await list()).sort()).toEqual(['jaya', 'rohan']);
  });

  test('updates when a guardian changes an answer', async () => {
    await seed();
    await rebuildPhotoConsent(db(), E);
    const ref = db().doc(`events/${E}/participants/rohan/private/details`);
    const before = await ref.get();
    await ref.set({photoConsent: true, birthDate: '2014-06-06'});
    const after = await ref.get();
    await ftest.wrap(onPhotoConsentAnswerWritten)({
      data: ftest.makeChange(before, after), params: {eventId: E, participantId: 'rohan'},
    });
    expect(Object.keys(await list())).toEqual(['jaya']);
    // And back to no: listed again.
    await ref.set({photoConsent: false});
    await refreshPhotoConsent(db(), E, ['rohan']);
    expect((await list()).rohan.answer).toBe('no');
  });

  test('Counts show Yes, No and Not answered, from the list without private details', async () => {
    await seed();
    await recalculateEvent(db(), E, new Date());
    // No list yet: no totals, rather than reading everyone's details.
    expect((await db().doc(`events/${E}/stats/current`).get()).data()!.photoConsent).toBeUndefined();
    await rebuildPhotoConsent(db(), E);
    await recalculateEvent(db(), E, new Date());
    const stats = (await db().doc(`events/${E}/stats/current`).get()).data()!;
    expect(stats.photoConsent).toEqual({yes: 1, no: 1, unanswered: 1});
  });
});
