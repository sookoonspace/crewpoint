/**
 * Spec #233 Req 32a, 35, 36 (#244, B-02, B-03, B-06, B-13): a family edits
 * its registration before the deadline, every change logged; after it,
 * only contact details; adding people needs room.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {submitRegistration} = require('../../src/registration/submitRegistration');
const {updateRegistration} = require('../../src/registration/updateRegistration');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const SLUG = 'convention-2027';
const DAY = 24 * 60 * 60 * 1000;
const db = () => getAdminDb();
const rejected = (code: string, reason?: string) =>
  expect.objectContaining({code, ...(reason ? {details: expect.objectContaining({reason})} : {})});

async function seed({capacity = 10 as number | null, deadline = Date.now() + DAY} = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner'], memberIds: ['owner'], capacity, timeZone: 'America/Chicago',
    startDate: new Date(Date.UTC(2027, 6, 16)), dateOnly: true,
    settings: {
      attendancePolicy: 'arrivalToDeparture',
      categories: [{id: 'child', name: 'Child', maxAge: 17, isChild: true}, {id: 'adult', name: 'Adult', minAge: 18}],
      registration: {
        mode: 'open', slug: SLUG, deadline,
        sections: [{id: 'food', name: {en: 'Food'}, fieldIds: ['diet', 'allergies']}],
        blocks: {people: true, ageOnly: false, stay: true, sessionChoices: true, waivers: false, contact: true},
      },
    },
  });
  await db().doc(`eventSlugs/${SLUG}`).set({eventId: E});
  const field = {options: [], required: false, scope: 'participant', visibility: 'standard', order: 0};
  await db().doc(`events/${E}/fields/diet`).set({...field, label: 'Diet', type: 'singleChoice', options: ['V', 'J', 'N'], required: true});
  await db().doc(`events/${E}/fields/allergies`).set({...field, label: 'Allergies', type: 'text', visibility: 'private'});
  await db().doc(`events/${E}/sessions/M2`).set({title: 'Breakfast', startAt: new Date(Date.UTC(2027, 6, 17, 13)), attendance: null, hidden: false});
  await db().doc(`events/${E}/sessions/WP`).set({title: 'Waterpark', startAt: new Date(Date.UTC(2027, 6, 17, 15)), attendance: 'bySession', hidden: false});
}

const asha = {name: 'Asha Patel', birthDate: '1980-03-01', answers: {diet: 'J', allergies: 'Peanuts'}};
const dev = {name: 'Dev Patel', birthDate: '2016-05-09', answers: {diet: 'V'}};
const register = (uid = 'asha', people: object[] = [asha, dev]) => ftest.wrap(submitRegistration)({
  auth: {uid}, data: {slug: SLUG, submissionId: `s-${uid}`, groupName: 'Patel family', contact: {email: `${uid}@example.com`}, people},
});
const update = (data: object, uid = 'asha') =>
  ftest.wrap(updateRegistration)({auth: {uid}, data: {slug: SLUG, ...data}});
const people = async () => (await db().collection(`events/${E}/participants`).get()).docs
  .map((d) => ({id: d.id, ...d.data()} as any));
const tally = async () => (await db().doc(`events/${E}/registrationTally/current`).get()).data()!;
const changes = async () => {
  const [reg] = (await db().collection(`events/${E}/registrations`).get()).docs;
  return (await reg.ref.collection('changes').get()).docs.map((d) => d.data()).filter((c) => c.action === 'edited');
};

/** The registration as the form would send it back, with participant IDs. */
async function current() {
  const all = await people();
  const byName = (n: string) => all.find((p) => p.name === n)!;
  return {
    groupName: 'Patel family', contact: {email: 'asha@example.com'}, groupAnswers: {},
    people: [{...asha, id: byName('Asha Patel').id}, {...dev, id: byName('Dev Patel').id}],
  };
}

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('updateRegistration', () => {
  test('B-06: before the deadline the contact changes answers and people; every change is logged', async () => {
    await seed();
    await register();
    const form = await current();
    const result = await update({
      ...form,
      people: [
        {...form.people[0], answers: {diet: 'N', allergies: 'Peanuts'}},
        {name: 'Meera Patel', birthDate: '1982-06-06', answers: {diet: 'V'}},
      ],
    });
    expect(result).toEqual(expect.objectContaining({status: 'submitted', changed: 3}));
    const after = await people();
    expect(after.map((p) => p.name).sort()).toEqual(['Asha Patel', 'Meera Patel']);
    expect(after.find((p) => p.name === 'Asha Patel').fields).toEqual({diet: 'N'});
    expect(after.find((p) => p.name === 'Meera Patel')).toEqual(expect.objectContaining({
      registrationStatus: 'submitted', categoryId: 'adult', groupId: expect.any(String),
    }));
    // Dev's place is freed and Meera's taken: still 2.
    expect((await tally()).placesUsed).toBe(2);
    const [entry] = await changes();
    expect(entry).toEqual(expect.objectContaining({by: 'asha', action: 'edited'}));
    expect(entry.changes).toEqual(expect.arrayContaining([
      expect.objectContaining({person: 'Asha Patel', before: 'J', after: 'N'}),
      expect.objectContaining({person: 'Dev Patel', before: 'Dev Patel', after: null}),
      expect.objectContaining({person: 'Meera Patel', before: null, after: 'Meera Patel'}),
    ]));
    // Private answers stay private on the person, and are logged without the value.
    expect(JSON.stringify(entry)).not.toContain('Peanuts');
  });

  test('B-02, B-03: arrival times and meal opt-outs are kept; a by-sign-up session cannot be opted out of', async () => {
    await seed();
    await register();
    const form = await current();
    const sat11am = Date.UTC(2027, 6, 17, 16);
    await update({...form, people: [{...form.people[0], arrivalAt: sat11am, optOuts: ['M2']}, form.people[1]]});
    const a = (await people()).find((p) => p.name === 'Asha Patel');
    expect(a.arrivalAt.toMillis()).toBe(sat11am);
    expect(a.optOuts).toEqual(['M2']);
    await expect(update({...form, people: [{...form.people[0], optOuts: ['WP']}, form.people[1]]}))
      .rejects.toEqual(rejected('invalid-argument', 'invalid'));
  });

  test('a linked adult edits too; another family cannot', async () => {
    await seed();
    await register();
    const groupId = (await db().collection(`events/${E}/groups`).get()).docs[0].id;
    await db().doc(`events/${E}/members/meera`).set({uid: 'meera', roleIds: ['participant'], groupIds: [groupId]});
    const form = await current();
    await update({...form, people: [{...form.people[0], name: 'Asha M. Patel'}, form.people[1]]}, 'meera');
    expect((await people()).some((p) => p.name === 'Asha M. Patel')).toBe(true);
    expect((await changes())[0].by).toBe('meera');
    await expect(update(form, 'stranger')).rejects.toEqual(rejected('not-found'));
  });

  test('Req 32a: adding people with no room is refused, and the group keeps its places', async () => {
    await seed({capacity: 2});
    await register();
    const form = await current();
    await expect(update({...form, people: [...form.people, {name: 'Meera Patel', birthDate: '1982-06-06', answers: {diet: 'V'}}]}))
      .rejects.toEqual(expect.objectContaining({
        code: 'failed-precondition',
        message: "There's no room to add more people. Please contact the organizer.",
        details: {reason: 'noRoom'},
      }));
    expect((await people())).toHaveLength(2);
    expect((await tally()).placesUsed).toBe(2);
  });

  test('a waitlisted group can grow; it holds no places', async () => {
    await seed({capacity: 1});
    await register();
    const form = await current();
    await update({...form, people: [...form.people, {name: 'Meera Patel', birthDate: '1982-06-06', answers: {diet: 'V'}}]});
    expect((await people())).toHaveLength(3);
    expect((await tally()).placesUsed).toBe(0);
    const [reg] = (await db().collection(`events/${E}/registrations`).get()).docs;
    expect(reg.data().size).toBe(3);
  });

  test('B-13: after the deadline only contact details change; anything else needs the committee', async () => {
    await seed();
    await register();
    const form = await current();
    await db().doc(`events/${E}`).update({'settings.registration.deadline': Date.now() - DAY});
    await update({...form, contact: {email: 'asha.p@example.com', phone: '312 555 0100'}});
    const a = (await people()).find((p) => p.name === 'Asha Patel');
    const details = (await db().doc(`events/${E}/participants/${a.id}/private/details`).get()).data();
    expect(details).toEqual(expect.objectContaining({email: 'asha.p@example.com', phone: '+13125550100'}));
    await expect(update({...form, people: [{...form.people[0], answers: {diet: 'N'}}, form.people[1]]}))
      .rejects.toEqual(rejected('failed-precondition', 'closed'));
  });

  test('nothing changed, nothing logged; signed out, unknown or ended events refuse', async () => {
    await seed();
    await register();
    const form = await current();
    expect((await update(form)).changed).toBe(0);
    expect(await changes()).toEqual([]);
    await expect(ftest.wrap(updateRegistration)({data: {slug: SLUG}})).rejects.toEqual(rejected('unauthenticated'));
    await expect(update({...form, people: [{...form.people[0], id: 'someone-else'}]}))
      .rejects.toEqual(rejected('invalid-argument', 'invalid'));
    await db().doc(`events/${E}`).update({status: 'ended'});
    await expect(update(form)).rejects.toEqual(rejected('failed-precondition', 'closed'));
  });
});
