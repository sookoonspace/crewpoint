/**
 * Stage 2A registration acceptance (#242). Test names start with the
 * scenario ID from docs/testing/CREWPOINT_CONVENTION_TEST_v4.md. Families
 * register through `submitRegistration`; counts come from
 * `recalculateEvent`; "my registration" from `getMyRegistration`. Email goes
 * only to the outbox, never a real provider (N-00).
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../test/setup';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {submitRegistration} = require('../src/registration/submitRegistration');
const {getMyRegistration} = require('../src/registration/myRegistration');
const {updateRegistration} = require('../src/registration/updateRegistration');
const {recalculateEvent} = require('../src/counts/recalculate');
const {saveWaiver, acceptWaivers, sendWaiverReminders} = require('../src/registration/waiverCallables');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'derod';
const SLUG = 'derod-2027';
const DAY = 24 * 60 * 60 * 1000;
const db = () => getAdminDb();
const at = (iso: string) => new Date(iso);

/** The convention, Jul 16–18, 2027 in America/Chicago (CDT, UTC-5). */
async function seed(registration: object = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Derod Gaam Convention 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner'], memberIds: ['owner'], capacity: 200, timeZone: 'America/Chicago',
    startDate: at('2027-07-16T00:00:00Z'), endDate: at('2027-07-18T00:00:00Z'), dateOnly: true,
    settings: {
      attendancePolicy: 'arrivalToDeparture',
      categories: [
        {id: 'child', name: 'Child', maxAge: 17, isChild: true},
        {id: 'adult', name: 'Adult', minAge: 18},
      ],
      registration: {
        mode: 'open', slug: SLUG, deadline: Date.now() + 30 * DAY,
        sections: [
          {id: 'people', name: {en: 'About you'}, fieldIds: ['diet', 'relation', 'shirt', 'kids']},
          {id: 'hotel', name: {en: 'Hotel'}, fieldIds: ['booked', 'confirmation']},
        ],
        blocks: {people: true, ageOnly: false, stay: true, sessionChoices: true, waivers: false, contact: true},
        conditions: {kids: {categoryId: 'child'}, confirmation: {fieldId: 'booked', value: 'yes'}},
        afterNote: {en: 'Book at hotel.example with code DEROD27'},
        laterNote: {en: 'The hotel block has closed. Please call the hotel.'},
        laterNoteFrom: Date.now() + 10 * DAY,
        ...registration,
      },
    },
  });
  await db().doc(`eventSlugs/${SLUG}`).set({eventId: E});
  const field = (id: string, label: string, type: string, extra: object = {}) =>
    db().doc(`events/${E}/fields/${id}`).set({
      label, type, options: [], required: false, scope: 'participant', visibility: 'standard', order: 0, ...extra,
    });
  await field('diet', 'Diet', 'singleChoice', {options: ['V', 'J', 'N'], required: true});
  await field('relation', 'Derod relation', 'text');
  await field('shirt', 'T-shirt size', 'singleChoice', {options: ['S', 'M', 'L', 'XL']});
  await field('kids', 'Kids activities', 'yesNo');
  await field('booked', 'Booked a room?', 'yesNo', {scope: 'group'});
  await field('confirmation', 'Confirmation number', 'text', {scope: 'group', visibility: 'private'});
  const session = (id: string, title: string, start: string, end: string | null, attendance: string | null) =>
    db().doc(`events/${E}/sessions/${id}`).set({
      title, startAt: at(start), endAt: end ? at(end) : null, attendance, hidden: false,
      timeTbc: false, locationTba: false, tags: [], eligibility: {categoryIds: [], filterTags: []},
    });
  await session('M1', 'Welcome Dinner', '2027-07-17T00:00:00Z', null, null);
  await session('P1', 'Karaoke & Garba', '2027-07-17T02:00:00Z', null, null);
  await session('M2', 'Breakfast', '2027-07-17T13:00:00Z', null, null);
  // Saturday: the waterpark, or bhajan and lunch at the hotel (W-01).
  await session('WP', 'Waterpark', '2027-07-17T15:00:00Z', '2027-07-17T22:00:00Z', 'bySession');
  await session('HL', 'Bhajan and hotel lunch', '2027-07-17T16:00:00Z', '2027-07-17T19:00:00Z', 'bySession');
}

const submit = (uid: string, data: object) => ftest.wrap(submitRegistration)({
  auth: {uid}, data: {slug: SLUG, submissionId: `s-${uid}`, contact: {email: `${uid}@example.com`}, ...data},
});
const stats = async () => {
  await recalculateEvent(db(), E, new Date());
  return (await db().doc(`events/${E}/stats/current`).get()).data()!;
};
const fri3pm = Date.parse('2027-07-16T20:00:00Z');
const mon = Date.parse('2027-07-19T15:00:00Z');

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

test('B-01 a contact registers the whole family with every per-person answer, stay and choice', async () => {
  await seed();
  const result = await submit('raj', {
    groupName: 'Bhakta', groupAnswers: {booked: true, confirmation: 'HP123456'},
    people: [
      {name: 'Raj Bhakta', birthDate: '1989-01-10', arrivalAt: fri3pm, departureAt: mon, signUps: ['WP'],
        answers: {diet: 'V', relation: '[TEST VALUE]', shirt: 'L', kids: true}},
      {name: 'Priya Bhakta', birthDate: '1991-02-02', arrivalAt: fri3pm, departureAt: mon, signUps: ['WP'],
        answers: {diet: 'V', shirt: 'M'}},
      {name: 'Kiaan Bhakta', birthDate: '2024-03-03', arrivalAt: fri3pm, departureAt: mon, signUps: ['WP'],
        answers: {diet: 'V', kids: false}},
    ],
  });
  expect(result.status).toBe('submitted');
  const people = (await db().collection(`events/${E}/participants`).get()).docs.map((d) => d.data());
  expect(people).toHaveLength(3);
  const raj = people.find((p) => p.name === 'Raj Bhakta')!;
  const kiaan = people.find((p) => p.name === 'Kiaan Bhakta')!;
  // Kids activities is asked of under-18s only, so an adult's answer is dropped.
  expect(raj.fields).toEqual({diet: 'V', relation: '[TEST VALUE]', shirt: 'L'});
  expect(kiaan).toEqual(expect.objectContaining({categoryId: 'child', isChild: true, fields: {diet: 'V', kids: false}}));
  expect(raj.signUps).toEqual(['WP']);
  expect(raj.arrivalAt.toMillis()).toBe(fri3pm);
  const group = (await db().collection(`events/${E}/groups`).get()).docs[0];
  expect(group.data().fields).toEqual({booked: true});
  expect((await group.ref.collection('private').doc('details').get()).data())
    .toEqual(expect.objectContaining({fields: {confirmation: 'HP123456'}}));
});

test('B-02 an arrival time keeps a person out of the meals before it', async () => {
  await seed();
  // F4: Savita arrives Saturday 11:00am, after M1, P1 and M2.
  await submit('savita', {
    people: [{name: 'Savita Mistry', birthDate: '1953-01-01', answers: {diet: 'V'},
      arrivalAt: Date.parse('2027-07-17T16:00:00Z'), departureAt: mon}],
  });
  await submit('raj', {
    people: [{name: 'Raj Bhakta', birthDate: '1989-01-10', answers: {diet: 'V'}, arrivalAt: fri3pm, departureAt: mon}],
  });
  const s = await stats();
  for (const meal of ['M1', 'P1', 'M2']) expect(s.sessions[meal].total).toBe(1);
  expect(s.event.total).toBe(2);
});

test('B-07 the hotel booking link is shown only after registering, and the confirmation number only to those who booked', async () => {
  await seed();
  const view = () => ftest.wrap(getMyRegistration)({auth: {uid: 'raj'}, data: {slug: SLUG}});
  expect((await view()).note).toBeNull();
  await submit('raj', {
    groupAnswers: {booked: false, confirmation: 'HP000000'},
    people: [{name: 'Raj Bhakta', birthDate: '1989-01-10', answers: {diet: 'V'}}],
  });
  expect((await view()).note).toEqual({en: 'Book at hotel.example with code DEROD27'});
  // Not booked, so the confirmation number was never asked or kept.
  const group = (await db().collection(`events/${E}/groups`).get()).docs[0];
  expect((await group.ref.collection('private').doc('details').get()).exists).toBe(false);
});

test('B-15 after the hotel cutoff, the booking link is replaced by the call-the-hotel note', async () => {
  await seed({laterNoteFrom: Date.now() - DAY});
  await submit('raj', {people: [{name: 'Raj Bhakta', birthDate: '1989-01-10', answers: {diet: 'V'}}]});
  const view = await ftest.wrap(getMyRegistration)({auth: {uid: 'raj'}, data: {slug: SLUG}});
  expect(view.note).toEqual({en: 'The hotel block has closed. Please call the hotel.'});
});

test('W-01 each person chooses the waterpark or the hotel, never both, and each is counted', async () => {
  await seed();
  await submit('raj', {
    people: [
      {name: 'Raj Bhakta', birthDate: '1989-01-10', answers: {diet: 'V'}, arrivalAt: fri3pm, departureAt: mon, signUps: ['WP']},
      {name: 'Priya Bhakta', birthDate: '1991-02-02', answers: {diet: 'V'}, arrivalAt: fri3pm, departureAt: mon, signUps: ['WP']},
    ],
  });
  await submit('hemant', {
    people: [
      {name: 'Hemant Patel', birthDate: '1975-01-01', answers: {diet: 'V'}, arrivalAt: fri3pm, departureAt: mon, signUps: ['HL']},
    ],
  });
  await expect(submit('both', {
    people: [{name: 'Both Ways', birthDate: '1980-01-01', answers: {diet: 'V'}, signUps: ['WP', 'HL']}],
  })).rejects.toEqual(expect.objectContaining({code: 'invalid-argument'}));
  const s = await stats();
  expect(s.sessions.WP.total).toBe(2);
  expect(s.sessions.HL.total).toBe(1);
});

test('N-01 the registration confirmation lists who registered, with a link back, in the outbox', async () => {
  await seed();
  await submit('raj', {
    people: [
      {name: 'Raj Bhakta', birthDate: '1989-01-10', answers: {diet: 'V'}},
      {name: 'Kiaan Bhakta', birthDate: '2024-03-03', answers: {diet: 'V'}},
    ],
  });
  const [mail] = (await db().collection('mailOutbox').get()).docs.map((d) => d.data());
  expect(mail).toEqual(expect.objectContaining({to: 'raj@example.com', template: 'registrationConfirmation', status: 'queued'}));
  expect(mail.data.people).toBe('• Raj Bhakta\n• Kiaan Bhakta');
  expect(mail.data.link).toBe(`https://crewpoint-dev.web.app/e/${SLUG}/registration`);
});

/** Raj's registration as the form sends it back, with participant IDs. */
async function asStored(uid: string) {
  const people = (await db().collection(`events/${E}/participants`).get()).docs
    .filter((d) => d.data().groupId && d.data().registrationId)
    .map((d) => ({id: d.id, ...d.data()} as any));
  return people;
}
const edit = (uid: string, data: object) => ftest.wrap(updateRegistration)({auth: {uid}, data: {slug: SLUG, ...data}});

test('B-03 Jaya opts out of breakfast, and breakfast does not count her', async () => {
  await seed();
  await submit('hemant', {
    groupName: 'Patel', people: [
      {name: 'Hemant Patel', birthDate: '1975-01-01', answers: {diet: 'V'}, arrivalAt: fri3pm, departureAt: mon},
      {name: 'Jaya Patel', birthDate: '1977-01-01', answers: {diet: 'N'}, arrivalAt: fri3pm, departureAt: mon},
    ],
  });
  const [hemant, jaya] = (await asStored('hemant')).sort((a, b) => a.name.localeCompare(b.name));
  await edit('hemant', {
    groupName: 'Patel', contact: {email: 'hemant@example.com'}, people: [
      {id: hemant.id, name: 'Hemant Patel', birthDate: '1975-01-01', answers: {diet: 'V'}, arrivalAt: fri3pm, departureAt: mon},
      {id: jaya.id, name: 'Jaya Patel', birthDate: '1977-01-01', answers: {diet: 'N'}, arrivalAt: fri3pm, departureAt: mon, optOuts: ['M2']},
    ],
  });
  const s = await stats();
  expect(s.sessions.M2.total).toBe(1);
  expect(s.sessions.M1.total).toBe(2);
});

test('B-06 Meera, a linked adult, edits the registration; counts update and the log shows who changed what', async () => {
  await seed();
  await submit('raj', {
    groupName: 'Bhakta', people: [{name: 'Raj Bhakta', birthDate: '1989-01-10', answers: {diet: 'V'}}],
  });
  const groupId = (await db().collection(`events/${E}/groups`).get()).docs[0].id;
  await db().doc(`events/${E}/members/meera`).set({uid: 'meera', roleIds: ['participant'], groupIds: [groupId]});
  const [raj] = await asStored('raj');
  await edit('meera', {
    groupName: 'Bhakta', contact: {email: 'raj@example.com'}, people: [
      {id: raj.id, name: 'Raj Bhakta', birthDate: '1989-01-10', answers: {diet: 'J'}},
      {name: 'Meera Bhakta', birthDate: '1990-02-02', answers: {diet: 'V'}},
    ],
  });
  const s = await stats();
  expect(s.event.total).toBe(2);
  expect(s.event.byField.diet).toEqual({J: 1, V: 1});
  const [reg] = (await db().collection(`events/${E}/registrations`).get()).docs;
  const [entry] = (await reg.ref.collection('changes').where('action', '==', 'edited').get()).docs.map((d) => d.data());
  expect(entry.by).toBe('meera');
  expect(entry.changes).toEqual(expect.arrayContaining([
    expect.objectContaining({person: 'Raj Bhakta', before: 'V', after: 'J'}),
    expect.objectContaining({person: 'Meera Bhakta', before: null, after: 'Meera Bhakta'}),
  ]));
});

test('B-13 after the deadline, registering and changes need the committee; contact details still change', async () => {
  await seed();
  await submit('raj', {people: [{name: 'Raj Bhakta', birthDate: '1989-01-10', answers: {diet: 'V'}}]});
  await db().doc(`events/${E}`).update({'settings.registration.deadline': Date.now() - DAY});
  await expect(submit('late', {people: [{name: 'Late Comer', birthDate: '1980-01-01', answers: {diet: 'V'}}]}))
    .rejects.toEqual(expect.objectContaining({code: 'failed-precondition', details: {reason: 'closed'}}));
  const [raj] = await asStored('raj');
  const form = {groupName: 'Raj Bhakta', people: [{id: raj.id, name: 'Raj Bhakta', birthDate: '1989-01-10', answers: {diet: 'V'}}]};
  await expect(edit('raj', {...form, contact: {email: 'raj@example.com'}, people: [{...form.people[0], answers: {diet: 'J'}}]}))
    .rejects.toEqual(expect.objectContaining({code: 'failed-precondition', details: {reason: 'closed'}}));
  expect((await edit('raj', {...form, contact: {email: 'raj.b@example.com'}})).changed).toBe(1);
});

// Waivers (#246). The convention's waiver text is the owner's to give, so
// these use placeholder text (Z-03).
const WAIVER_BLOCKS = {people: true, ageOnly: false, stay: true, sessionChoices: true, waivers: true, contact: true};
const PLACEHOLDER = {en: '[PLACEHOLDER: waiver text from the committee]'};
const saveWaiverAs = (data: object) =>
  ftest.wrap(saveWaiver)({auth: {uid: 'owner'}, data: {eventId: E, text: PLACEHOLDER, requireLatest: true, ...data}});
const personByName = async (name: string) =>
  (await db().collection(`events/${E}/participants`).where('name', '==', name).get()).docs[0];
const acceptedFor = async (name: string) =>
  ((await (await personByName(name)).ref.collection('private').doc('waivers').get()).data() ?? {}).accepted ?? {};

test('W-05 the contact accepts the waterpark waiver for each person going, as guardian for a child; version, time and signer kept', async () => {
  await seed({blocks: WAIVER_BLOCKS});
  const {waiverId} = await saveWaiverAs({title: {en: 'Waterpark waiver'}, appliesTo: {kind: 'session', id: 'WP'}, required: true});
  const going = (name: string, birthDate: string, accept: boolean) => ({
    name, birthDate, answers: {diet: 'V'}, signUps: ['WP'], ...(accept ? {acceptWaivers: [waiverId]} : {}),
  });
  const jaya = {name: 'Jaya Shah', birthDate: '1950-02-02', answers: {diet: 'V'}, signUps: ['HL']};
  // Submit waits until everyone going has it accepted.
  await expect(submit('nita', {groupName: 'Shah family', people: [going('Nita Shah', '1978-04-04', true), going('Rohan Shah', '2014-06-06', false), jaya]}))
    .rejects.toEqual(expect.objectContaining({code: 'invalid-argument', details: expect.objectContaining({problems: ['people[1].waivers']})}));
  await submit('nita', {groupName: 'Shah family', people: [going('Nita Shah', '1978-04-04', true), going('Rohan Shah', '2014-06-06', true), jaya]});
  expect((await acceptedFor('Nita Shah'))[waiverId]).toEqual(expect.objectContaining({version: 1, by: 'nita', as: 'self', at: expect.anything()}));
  expect((await acceptedFor('Rohan Shah'))[waiverId]).toEqual(expect.objectContaining({version: 1, by: 'nita', as: 'guardian'}));
  expect(await acceptedFor('Jaya Shah')).toEqual({});
  expect((await personByName('Jaya Shah')).data().waiversMissing).toBe(false);
  // A new text is a new version; the earlier one is kept and shows as earlier.
  await saveWaiverAs({waiverId, title: {en: 'Waterpark waiver'}, text: {en: '[PLACEHOLDER: version 2]'}, appliesTo: {kind: 'session', id: 'WP'}, required: true});
  const versions = (await db().collection(`events/${E}/waivers/${waiverId}/versions`).get()).docs.map((d) => d.id).sort();
  expect(versions).toEqual(['1', '2']);
  expect((await personByName('Nita Shah')).data()).toEqual(expect.objectContaining({waiverVersions: {[waiverId]: 1}, waiversMissing: true}));
});

test('W-06 F5 is on the missing-waiver list, gets the email, and leaves the list once accepted after the deadline', async () => {
  await seed({blocks: WAIVER_BLOCKS});
  const {waiverId} = await saveWaiverAs({title: {en: 'Waterpark waiver'}, appliesTo: {kind: 'session', id: 'WP'}, required: false});
  await submit('f5', {groupName: 'Family 5', people: [{name: 'Kiran Desai', birthDate: '1985-01-01', answers: {diet: 'J'}, signUps: ['WP']}]});
  const missing = async () => (await db().collection(`events/${E}/participants`).where('waiversMissing', '==', true).get()).docs.map((d) => d.data().name);
  expect(await missing()).toEqual(['Kiran Desai']);
  expect(await ftest.wrap(sendWaiverReminders)({auth: {uid: 'owner'}, data: {eventId: E}})).toEqual({sent: 1});
  const [mail] = (await db().collection('mailOutbox').where('template', '==', 'waiverMissing').get()).docs.map((d) => d.data());
  expect(mail).toEqual(expect.objectContaining({to: 'f5@example.com', eventId: E}));
  expect(mail.data.people).toContain('Kiran Desai');
  await db().doc(`events/${E}`).update({'settings.registration.deadline': Date.now() - DAY});
  const kiran = await personByName('Kiran Desai');
  await ftest.wrap(acceptWaivers)({auth: {uid: 'f5'}, data: {slug: SLUG, acceptances: [{participantId: kiran.id, waiverId}]}});
  expect(await missing()).toEqual([]);
});

test('Z-03 the liability waiver is accepted at registration and recorded (placeholder text)', async () => {
  await seed({blocks: WAIVER_BLOCKS});
  const {waiverId} = await saveWaiverAs({title: {en: 'Liability waiver'}, appliesTo: {kind: 'everyone'}, required: true});
  const person = {name: 'Mira Patel', birthDate: '1990-09-09', answers: {diet: 'N'}, signUps: ['HL']};
  await expect(submit('mira', {people: [person]})).rejects.toEqual(expect.objectContaining({code: 'invalid-argument'}));
  await submit('mira', {people: [{...person, acceptWaivers: [waiverId]}], consent: {email: true, sms: false}});
  expect((await acceptedFor('Mira Patel'))[waiverId]).toEqual(expect.objectContaining({version: 1, by: 'mira', as: 'self'}));
  const [reg] = (await db().collection(`events/${E}/registrations`).get()).docs.map((d) => d.data());
  // Req 31: consent to announcements is kept apart, for Stage 3.
  expect(reg.consent).toEqual(expect.objectContaining({email: true, sms: false}));
});

test('Z-02 photo and video consent per person, children by their guardian, is kept for the photographer', async () => {
  /* eslint-disable @typescript-eslint/no-var-requires */
  const {rebuildPhotoConsent, refreshPhotoConsent} = require('../src/participants/photoConsent');
  /* eslint-enable @typescript-eslint/no-var-requires */
  await seed();
  const person = (name: string, birthDate: string, photoConsent?: boolean) => ({
    name, birthDate, answers: {diet: 'V'}, ...(photoConsent === undefined ? {} : {photoConsent}),
  });
  await submit('nita', {groupName: 'Shah family', people: [
    person('Nita Shah', '1978-04-04', true),
    person('Rohan Shah', '2014-06-06', false),
    person('Jaya Shah', '1950-02-02'),
  ]});
  // The answer sits in private details, never on the person.
  const rohan = (await db().collection(`events/${E}/participants`).where('name', '==', 'Rohan Shah').get()).docs[0];
  expect(rohan.data().photoConsent).toBeUndefined();
  expect((await rohan.ref.collection('private').doc('details').get()).data()!.photoConsent).toBe(false);

  await rebuildPhotoConsent(db(), E);
  const list = async () => (await db().doc(`events/${E}/photoConsent/current`).get()).data()!.people;
  expect(Object.values(await list())).toEqual(expect.arrayContaining([
    {name: 'Rohan Shah', groupName: 'Shah family', ageBand: 'Child', answer: 'no'},
    {name: 'Jaya Shah', groupName: 'Shah family', ageBand: 'Adult', answer: 'unanswered'},
  ]));
  expect(Object.values(await list())).toHaveLength(2);
  // The guardian changes Rohan's answer; the list follows.
  await rohan.ref.collection('private').doc('details').set({photoConsent: true}, {merge: true});
  await refreshPhotoConsent(db(), E, [rohan.id]);
  expect(Object.values(await list()).map((p: any) => p.name)).toEqual(['Jaya Shah']);
});

test('B-12 past capacity a family is waitlisted; a cancellation offers the place, and the family accepts', async () => {
  /* eslint-disable @typescript-eslint/no-var-requires */
  const {cancelRegistration} = require('../src/registration/cancelRegistration');
  const {respondToOffer} = require('../src/registration/offers');
  /* eslint-enable @typescript-eslint/no-var-requires */
  await seed();
  await db().doc(`events/${E}`).update({capacity: 3});
  const family = (uid: string, n: number) => submit(uid, {groupName: `${uid} family`, people: Array.from({length: n}, (_, i) => ({
    name: `${uid} ${i + 1}`, birthDate: '1980-01-01', answers: {diet: 'V'},
  }))});
  expect((await family('f1', 3)).status).toBe('submitted');
  expect(await family('f5', 2)).toEqual(expect.objectContaining({status: 'waitlisted', waitlistPosition: 1}));
  await ftest.wrap(cancelRegistration)({auth: {uid: 'f1'}, data: {slug: SLUG}});
  const offered = (await db().collection(`events/${E}/registrations`).where('contactUid', '==', 'f5').get()).docs[0];
  expect(offered.data().offer.expiresAt).toBeGreaterThan(Date.now());
  const [offerMail] = (await db().collection('mailOutbox').where('template', '==', 'registrationOffer').get()).docs.map((d) => d.data());
  expect(offerMail.to).toBe('f5@example.com');
  expect(await ftest.wrap(respondToOffer)({auth: {uid: 'f5'}, data: {slug: SLUG, accept: true}})).toEqual({status: 'submitted'});
  expect((await stats()).event.total).toBe(2);
});
