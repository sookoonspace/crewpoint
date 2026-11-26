/**
 * Spec #233 Req 9, 19, 35 (#242, B-07, B-15): "my registration" for the
 * contact or a linked adult, with the after-registration note shown only
 * to submitted groups and replaced from its date.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {getMyRegistration} = require('../../src/registration/myRegistration');
const {submitRegistration} = require('../../src/registration/submitRegistration');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const SLUG = 'convention-2027';
const db = () => getAdminDb();
const DAY = 24 * 60 * 60 * 1000;

async function seed({capacity = 10, registration = {} as object} = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner'], memberIds: ['owner'], capacity, timeZone: 'America/Chicago',
    startDate: new Date(Date.UTC(2027, 6, 16)), dateOnly: true,
    settings: {
      categories: [{id: 'child', name: 'Child', maxAge: 17, isChild: true}, {id: 'adult', name: 'Adult', minAge: 18}],
      registration: {
        mode: 'open', slug: SLUG, deadline: Date.now() + DAY, sections: [],
        blocks: {people: true, ageOnly: false, stay: false, sessionChoices: false, waivers: false, contact: true},
        afterNote: {en: 'Book at hotel.example with code CONV27', gu: 'કોડ CONV27'},
        laterNote: {en: 'The hotel block has closed'}, laterNoteFrom: Date.now() + 10 * DAY,
        ...registration,
      },
    },
  });
  await db().doc(`eventSlugs/${SLUG}`).set({eventId: E});
}

const people = [
  {name: 'Asha Patel', birthDate: '1980-03-01'},
  {name: 'Dev Patel', birthDate: '2016-05-09'},
];
const register = (uid: string, id = uid) => ftest.wrap(submitRegistration)({
  auth: {uid}, data: {slug: SLUG, submissionId: id, groupName: 'Patel family', contact: {email: 'a@b.co'}, people},
});
const mine = (uid: string | null) =>
  ftest.wrap(getMyRegistration)({...(uid ? {auth: {uid}} : {}), data: {slug: SLUG}});

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('getMyRegistration', () => {
  test('the contact sees their group, its people and status, and the note for submitted groups', async () => {
    await seed();
    await register('asha');
    const view = await mine('asha');
    expect(view).toEqual(expect.objectContaining({
      title: 'Convention 2027', timeZone: 'America/Chicago',
      registration: expect.objectContaining({
        status: 'submitted', waitlistPosition: null, groupName: 'Patel family',
        submittedAt: expect.any(Number),
        people: [
          {name: 'Asha Patel', categoryId: 'adult'},
          {name: 'Dev Patel', categoryId: 'child'},
        ],
      }),
      note: {en: 'Book at hotel.example with code CONV27', gu: 'કોડ CONV27'},
    }));
    expect(JSON.stringify(view)).not.toContain(E);
  });

  test('from its date, the replacement note shows instead (B-15)', async () => {
    await seed({registration: {laterNoteFrom: Date.now() - DAY}});
    await register('asha');
    expect((await mine('asha')).note).toEqual({en: 'The hotel block has closed'});
  });

  test('a waitlisted group sees its number and no note (Req 19)', async () => {
    await seed({capacity: 3});
    await register('first');
    await register('asha');
    const view = await mine('asha');
    expect(view.registration).toEqual(expect.objectContaining({status: 'waitlisted', waitlistPosition: 1}));
    expect(view.note).toBeNull();
  });

  test('a linked adult of the group sees it too; anyone else sees none', async () => {
    await seed();
    await register('asha');
    const groupId = (await db().collection(`events/${E}/groups`).get()).docs[0].id;
    await db().doc(`events/${E}/members/spouse`).set({uid: 'spouse', roleIds: ['participant'], groupIds: [groupId]});
    expect((await mine('spouse')).registration.groupName).toBe('Patel family');
    expect((await mine('stranger')).registration).toBeNull();
    expect((await mine('stranger')).note).toBeNull();
  });

  test('still shown after the deadline (Req 35); signed out or an unknown name is refused', async () => {
    await seed();
    await register('asha');
    await db().doc(`events/${E}`).update({'settings.registration.deadline': Date.now() - DAY});
    expect((await mine('asha')).registration.status).toBe('submitted');
    await expect(mine(null)).rejects.toEqual(expect.objectContaining({code: 'unauthenticated'}));
    await expect(ftest.wrap(getMyRegistration)({auth: {uid: 'asha'}, data: {slug: 'nobody'}}))
      .rejects.toEqual(expect.objectContaining({code: 'not-found'}));
  });
});
