/**
 * Spec #233 Req 16-18, 20 (#242): what the registration form needs, for a
 * signed-in visitor who is not yet a member, by the event's link name.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {getRegistrationForm} = require('../../src/registration/registrationForm');
const {submitRegistration} = require('../../src/registration/submitRegistration');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const SLUG = 'convention-2027';
const db = () => getAdminDb();
const DAY = 24 * 60 * 60 * 1000;
const rejected = (code: string, reason?: string) =>
  expect.objectContaining({code, ...(reason ? {details: expect.objectContaining({reason})} : {})});

async function seed(registration: object = {}, status = 'published') {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status, templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner'], memberIds: ['owner'], capacity: 10, timeZone: 'America/Chicago',
    startDate: new Date(Date.UTC(2027, 6, 16)), endDate: new Date(Date.UTC(2027, 6, 18)), dateOnly: true,
    labels: {group: {one: 'Family', other: 'Families'}},
    settings: {
      categories: [{id: 'child', name: 'Child', maxAge: 17, isChild: true}, {id: 'adult', name: 'Adult', minAge: 18}],
      registration: {
        mode: 'open', slug: SLUG, deadline: Date.now() + DAY,
        sections: [{id: 'food', name: {en: 'Food', gu: 'ભોજન'}, fieldIds: ['diet', 'hotel']}],
        blocks: {people: true, ageOnly: false, stay: true, sessionChoices: true, waivers: false, contact: true},
        conditions: {hotel: {fieldId: 'diet', value: 'Jain'}},
        ...registration,
      },
    },
  });
  await db().doc(`eventSlugs/${SLUG}`).set({eventId: E});
  const field = {options: [], required: false, scope: 'participant', visibility: 'standard'};
  await db().doc(`events/${E}/fields/diet`).set(
    {...field, label: 'Diet', type: 'singleChoice', options: ['Veg', 'Jain'], required: true, order: 0});
  await db().doc(`events/${E}/fields/hotel`).set({...field, label: 'Hotel', type: 'text', scope: 'group', order: 1});
  await db().doc(`events/${E}/fields/secret`).set({...field, label: 'Not on the form', type: 'text', order: 2});
  await db().doc(`events/${E}/sessions/park`).set({
    title: 'Park meal', hidden: false, attendance: 'bySession',
    startAt: new Date(Date.UTC(2027, 6, 17, 17)), endAt: new Date(Date.UTC(2027, 6, 17, 19)),
  });
  await db().doc(`events/${E}/sessions/hotel`).set({
    title: 'Hotel lunch', hidden: false, attendance: 'bySession',
    startAt: new Date(Date.UTC(2027, 6, 17, 17, 30)), endAt: null,
  });
  await db().doc(`events/${E}/sessions/opening`).set({
    title: 'Opening', hidden: false, attendance: null, startAt: new Date(Date.UTC(2027, 6, 16, 14)),
  });
}

const get = (uid: string | null = 'asha', slug = SLUG) =>
  ftest.wrap(getRegistrationForm)({...(uid ? {auth: {uid}} : {}), data: {slug}});

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('getRegistrationForm', () => {
  test('returns the form: sections with their questions, blocks, categories and session choices', async () => {
    await seed();
    const form = await get();
    expect(form).toEqual(expect.objectContaining({
      slug: SLUG, title: 'Convention 2027', timeZone: 'America/Chicago', dateOnly: true,
      startDate: Date.UTC(2027, 6, 16), endDate: Date.UTC(2027, 6, 18), review: false,
      blocks: expect.objectContaining({people: true, stay: true, contact: true}),
      sections: [{id: 'food', name: {en: 'Food', gu: 'ભોજન'}, fieldIds: ['diet', 'hotel']}],
      conditions: {hotel: {fieldId: 'diet', value: 'Jain'}},
      categories: [
        {id: 'child', name: 'Child', maxAge: 17, isChild: true},
        {id: 'adult', name: 'Adult', minAge: 18},
      ],
      labels: expect.objectContaining({group: {one: 'Family', other: 'Families'}}),
      registration: null,
    }));
    // Only questions in a section are asked.
    expect(form.fields.map((f: {id: string}) => f.id)).toEqual(['diet', 'hotel']);
    expect(form.fields[0]).toEqual({
      id: 'diet', label: 'Diet', type: 'singleChoice', options: ['Veg', 'Jain'], required: true,
      scope: 'participant', visibility: 'standard',
    });
    expect(form.choices).toEqual([[
      {id: 'park', title: 'Park meal', startAt: Date.UTC(2027, 6, 17, 17), endAt: Date.UTC(2027, 6, 17, 19)},
      {id: 'hotel', title: 'Hotel lunch', startAt: Date.UTC(2027, 6, 17, 17, 30), endAt: null},
    ]]);
    expect(JSON.stringify(form)).not.toContain(E);
  });

  test('says when the caller has already registered', async () => {
    await seed();
    await ftest.wrap(submitRegistration)({auth: {uid: 'asha'}, data: {
      slug: SLUG, submissionId: 's1', contact: {email: 'a@b.co'},
      people: [{name: 'Asha', birthDate: '1980-01-01', answers: {diet: 'Veg'}}],
    }});
    expect((await get()).registration).toEqual({status: 'submitted', waitlistPosition: null});
  });

  test('#244: someone registered gets their registration to edit, private answers included', async () => {
    await seed();
    await db().doc(`events/${E}/fields/allergies`).set({
      label: 'Allergies', type: 'text', options: [], required: false, scope: 'participant',
      visibility: 'private', order: 3,
    });
    await db().doc(`events/${E}`).update({
      'settings.registration.sections': [{id: 'food', name: {en: 'Food'}, fieldIds: ['diet', 'hotel', 'allergies']}],
      'settings.registration.conditions': {},
    });
    await ftest.wrap(submitRegistration)({auth: {uid: 'asha'}, data: {
      slug: SLUG, submissionId: 's1', groupName: 'Patel family', contact: {email: 'a@b.co', phone: '312 555 0100'},
      groupAnswers: {hotel: 'Hilton'},
      people: [{name: 'Asha', birthDate: '1980-01-01', answers: {diet: 'Jain', allergies: 'Peanuts'},
        arrivalAt: Date.UTC(2027, 6, 17, 16), signUps: ['park']}],
    }});
    const form = await get();
    expect(form.editable).toBe('all');
    // Opening is everyone's, so it can be opted out of; the meals are by sign-up.
    expect(form.attending.map((x: {id: string}) => x.id)).toEqual(['opening']);
    expect(form.current).toEqual({
      groupName: 'Patel family', email: 'a@b.co', phone: '+13125550100',
      groupAnswers: {hotel: 'Hilton'},
      people: [{
        id: expect.any(String), name: 'Asha', birthDate: '1980-01-01', age: null,
        answers: {diet: 'Jain', allergies: 'Peanuts'}, arrivalAt: Date.UTC(2027, 6, 17, 16),
        departureAt: null, signUps: ['park'], optOuts: [], waiverVersions: {},
      }],
    });
    // After the deadline, only contact details: the form still opens for them.
    await db().doc(`events/${E}`).update({'settings.registration.deadline': Date.now() - DAY});
    expect((await get()).editable).toBe('contact');
    await expect(get('someone-new')).rejects.toEqual(rejected('failed-precondition', 'closed'));
  });

  test('refusals match the submit', async () => {
    await seed();
    await expect(get(null)).rejects.toEqual(rejected('unauthenticated'));
    await expect(get('asha', 'nobody')).rejects.toEqual(rejected('not-found'));
    await seed({}, 'draft');
    await expect(get()).rejects.toEqual(rejected('failed-precondition', 'notOpen'));
    await seed({deadline: Date.now() - DAY});
    await expect(get()).rejects.toEqual(rejected('failed-precondition', 'closed'));
    await seed({mode: 'invited'});
    await expect(get()).rejects.toEqual(rejected('permission-denied', 'invitedOnly'));
  });
});
