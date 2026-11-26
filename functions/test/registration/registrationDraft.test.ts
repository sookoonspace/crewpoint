/**
 * Spec #233 Req 23-25, TD 8 (#243): a server copy of the form, saved while
 * the family types, restored on reopening and turned into the registration
 * on Submit.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {saveRegistrationDraft} = require('../../src/registration/registrationDraft');
const {getRegistrationForm} = require('../../src/registration/registrationForm');
const {submitRegistration} = require('../../src/registration/submitRegistration');
const {getMyRegistration} = require('../../src/registration/myRegistration');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const SLUG = 'convention-2027';
const DAY = 24 * 60 * 60 * 1000;
const db = () => getAdminDb();

async function seed(over: object = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner'], memberIds: ['owner'], capacity: 10, timeZone: 'America/Chicago',
    startDate: new Date(Date.UTC(2027, 6, 16)), dateOnly: true,
    settings: {
      categories: [{id: 'adult', name: 'Adult', minAge: 18}],
      registration: {
        mode: 'open', slug: SLUG, deadline: Date.now() + DAY, sections: [],
        blocks: {people: true, ageOnly: false, stay: false, sessionChoices: false, waivers: false, contact: true},
      },
    },
    ...over,
  });
  await db().doc(`eventSlugs/${SLUG}`).set({eventId: E});
}

const draft = {
  submissionId: 'sub-1', groupName: '', email: 'asha@example.com', phone: '', groupAnswers: {},
  people: [{name: 'Asha Pat', birthDate: null, answers: {}, signUps: []}],
};
const save = (data: object, uid = 'asha') => ftest.wrap(saveRegistrationDraft)({auth: {uid}, data: {slug: SLUG, ...data}});
const form = (uid = 'asha') => ftest.wrap(getRegistrationForm)({auth: {uid}, data: {slug: SLUG}});
const registrations = async () => (await db().collection(`events/${E}/registrations`).get()).docs;

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('saveRegistrationDraft', () => {
  test('keeps one draft per person, uncounted, and saving again replaces it', async () => {
    await seed();
    const first = await save({draft, savedAt: 1000});
    expect(first).toEqual({savedAt: 1000});
    await save({draft: {...draft, people: [{...draft.people[0], name: 'Asha Patel'}]}, savedAt: 2000});
    const docs = await registrations();
    expect(docs).toHaveLength(1);
    expect(docs[0].data()).toEqual(expect.objectContaining({
      contactUid: 'asha', status: 'draft', draftSavedAt: 2000,
    }));
    expect(docs[0].data().draft.people[0].name).toBe('Asha Patel');
    expect((await db().doc(`events/${E}/registrationTally/current`).get()).exists).toBe(false);
    expect((await db().collection(`events/${E}/participants`).get()).empty).toBe(true);
  });

  test('an older copy never replaces a newer one', async () => {
    await seed();
    await save({draft, savedAt: 5000});
    expect(await save({draft: {...draft, email: 'old@example.com'}, savedAt: 4000})).toEqual({savedAt: 5000});
    expect((await registrations())[0].data().draft.email).toBe('asha@example.com');
  });

  test('the form returns the draft to restore, and a draft is not "already registered"', async () => {
    await seed();
    await save({draft, savedAt: 3000});
    const f = await form();
    expect(f.registration).toBeNull();
    expect(f.draft).toEqual({data: draft, savedAt: 3000});
    expect((await form('someone-else')).draft).toBeNull();
  });

  test('"my registration" offers Register while there is only a draft', async () => {
    await seed();
    await save({draft, savedAt: 3000});
    const view = await ftest.wrap(getMyRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    expect(view.registration).toBeNull();
  });

  test('Submit turns the draft into the registration, on the same document', async () => {
    await seed();
    await save({draft, savedAt: 3000});
    const [before] = await registrations();
    const result = await ftest.wrap(submitRegistration)({auth: {uid: 'asha'}, data: {
      slug: SLUG, submissionId: 'sub-1', contact: {email: 'asha@example.com'},
      people: [{name: 'Asha Patel', birthDate: '1980-03-01'}],
    }});
    expect(result).toEqual(expect.objectContaining({registrationId: before.id, status: 'submitted'}));
    const [after] = await registrations();
    expect(after.data().status).toBe('submitted');
    expect(after.data().draft).toBeUndefined();
    expect(after.data().draftSavedAt).toBeUndefined();
    // Once submitted, drafts are no longer taken.
    await expect(save({draft, savedAt: 9000})).rejects.toEqual(
      expect.objectContaining({code: 'already-exists', details: {reason: 'alreadyRegistered'}}));
  });

  test('refusals: signed out, not open, too large', async () => {
    await seed();
    await expect(ftest.wrap(saveRegistrationDraft)({data: {slug: SLUG, draft, savedAt: 1}}))
      .rejects.toEqual(expect.objectContaining({code: 'unauthenticated'}));
    await expect(save({draft: 'nope', savedAt: 1})).rejects.toEqual(expect.objectContaining({code: 'invalid-argument'}));
    await expect(save({draft: {...draft, groupName: 'x'.repeat(200000)}, savedAt: 1}))
      .rejects.toEqual(expect.objectContaining({code: 'invalid-argument'}));
    await seed({status: 'ended'});
    await expect(save({draft, savedAt: 1})).rejects.toEqual(
      expect.objectContaining({code: 'failed-precondition', details: {reason: 'closed'}}));
  });
});
