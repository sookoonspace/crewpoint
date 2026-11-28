/**
 * Spec #233 Req 5, 66 (#249): a "complete your registration" link for a
 * group the organizer added, opened by whoever signs in with the email it
 * was sent to, attaching a registration to the existing group and people.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {sendCompletionLink} = require('../../src/registration/completion');
const {getRegistrationForm} = require('../../src/registration/registrationForm');
const {submitRegistration} = require('../../src/registration/submitRegistration');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const SLUG = 'convention-2027';
const DAY = 24 * 3600_000;
const db = () => getAdminDb();
const rejected = (code: string, reason?: string) =>
  expect.objectContaining({code, ...(reason ? {details: expect.objectContaining({reason})} : {})});

async function seed({capacity = 10} = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner'], memberIds: ['owner', 'pia'], memberCount: 2, capacity, timeZone: 'America/Chicago',
    startDate: new Date(Date.UTC(2027, 6, 16)), dateOnly: true,
    settings: {
      categories: [{id: 'child', name: 'Child', maxAge: 17, isChild: true}, {id: 'adult', name: 'Adult', minAge: 18}],
      registration: {
        mode: 'open', slug: SLUG, deadline: Date.now() + 30 * DAY, sections: [], registrationRoleId: 'participant',
        blocks: {people: true, ageOnly: false, stay: false, sessionChoices: false, waivers: false, contact: true},
      },
    },
  });
  await db().doc(`eventSlugs/${SLUG}`).set({eventId: E});
  for (const [uid, roleIds] of [['owner', ['owner']], ['pia', ['participant']]] as const) {
    await db().doc(`events/${E}/members/${uid}`).set({uid, roleIds, crewIds: [], permissions: computePermissions([...roleIds], {})});
  }
  // The organizer added the Shahs by hand: two people, no registration.
  await db().doc(`events/${E}/groups/g1`).set({name: 'Shah family', sortName: 'shah family', adultUids: []});
  const person = (id: string, name: string, isChild = false) => db().doc(`events/${E}/participants/${id}`).set({
    name, sortName: name.toLowerCase(), groupId: 'g1', isChild, status: 'active', createdBy: 'owner',
  });
  await person('nita', 'Nita Shah');
  await person('rohan', 'Rohan Shah', true);
}

const send = (data: object, uid = 'owner') =>
  ftest.wrap(sendCompletionLink)({auth: {uid}, data: {eventId: E, groupId: 'g1', ...data}});
const asNita = {uid: 'nita-account', token: {email: 'nita@example.com', email_verified: true}};
const form = (complete: string, auth: object = asNita) =>
  ftest.wrap(getRegistrationForm)({auth, data: {slug: SLUG, complete}});
const submit = (complete: string, people: object[], auth: object = asNita, submissionId = 's1') =>
  ftest.wrap(submitRegistration)({auth, data: {
    slug: SLUG, submissionId, completeRegistrationId: complete, contact: {email: 'nita@example.com'}, people,
  }});
const all = async (path: string) => (await db().collection(path).get()).docs.map((d) => ({id: d.id, ...d.data()} as any));

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('complete your registration', () => {
  test('registrations.manage sends the link; nobody else, and not to a registered group', async () => {
    await seed();
    await expect(send({email: 'nita@example.com'}, 'pia')).rejects.toEqual(rejected('permission-denied'));
    await expect(send({email: 'not an email'})).rejects.toEqual(rejected('invalid-argument', 'invalidEmail'));
    const {registrationId} = await send({email: 'Nita@Example.com'});
    const reg = (await db().doc(`events/${E}/registrations/${registrationId}`).get()).data()!;
    expect(reg).toEqual(expect.objectContaining({
      groupId: 'g1', contactUid: null, status: 'draft', completion: expect.objectContaining({email: 'nita@example.com'}),
    }));
    const [mail] = (await all('mailOutbox')).filter((m) => m.template === 'registrationComplete');
    expect(mail.to).toBe('nita@example.com');
    expect(mail.data.link).toContain(`/e/${SLUG}/register?complete=${registrationId}`);
    // Sending again keeps one link for the group.
    expect((await send({email: 'nita@example.com'})).registrationId).toBe(registrationId);
    await db().doc(`events/${E}/groups/g1`).update({registrationId: 'other'});
    await expect(send({email: 'nita@example.com'})).rejects.toEqual(rejected('failed-precondition', 'alreadyRegistered'));
  });

  test('the form opens only for the verified email it was sent to, with the group\'s people', async () => {
    await seed();
    const {registrationId} = await send({email: 'nita@example.com'});
    await expect(form(registrationId, {uid: 'x', token: {email: 'someone@example.com', email_verified: true}}))
      .rejects.toEqual(rejected('permission-denied', 'completionEmail'));
    await expect(form(registrationId, {uid: 'x', token: {email: 'nita@example.com', email_verified: false}}))
      .rejects.toEqual(rejected('permission-denied', 'completionEmail'));
    await expect(form('nope')).rejects.toEqual(rejected('not-found', 'completionNotFound'));
    const f = await form(registrationId);
    expect(f.completing).toBe(true);
    expect(f.current.people.map((p: {id: string; name: string}) => [p.id, p.name]).sort())
      .toEqual([['nita', 'Nita Shah'], ['rohan', 'Rohan Shah']]);
  });

  test('submitting attaches the registration to the existing group and people, adding new ones', async () => {
    await seed();
    const {registrationId} = await send({email: 'nita@example.com'});
    const result = await submit(registrationId, [
      {id: 'nita', name: 'Nita Shah', birthDate: '1978-04-04'},
      {name: 'Jaya Shah', birthDate: '1950-02-02'},
    ]);
    expect(result).toEqual({registrationId, status: 'submitted', waitlistPosition: null});
    const people = await all(`events/${E}/participants`);
    expect(people).toHaveLength(3);
    // Rohan was not on the form but stays in the group and the registration.
    expect(people.every((p) => p.registrationId === registrationId && p.registrationStatus === 'submitted')).toBe(true);
    expect(people.find((p) => p.id === 'nita')).toEqual(expect.objectContaining({uid: 'nita-account', categoryId: 'adult'}));
    const group = (await db().doc(`events/${E}/groups/g1`).get()).data()!;
    expect(group).toEqual(expect.objectContaining({registrationId, registrationStatus: 'submitted', adultUids: ['nita-account']}));
    const reg = (await db().doc(`events/${E}/registrations/${registrationId}`).get()).data()!;
    expect(reg).toEqual(expect.objectContaining({contactUid: 'nita-account', status: 'submitted', size: 3}));
    expect((await db().doc(`events/${E}/registrationTally/current`).get()).data()!.placesUsed).toBe(3);
    expect((await db().doc(`events/${E}/members/nita-account`).get()).data()!.roleIds).toEqual(['participant']);
    expect((await all('mailOutbox')).filter((m) => m.template === 'registrationConfirmation').map((m) => m.to))
      .toEqual(['nita@example.com']);
    // A repeat is the same submission; another use of the link is refused.
    expect(await submit(registrationId, [{id: 'nita', name: 'Nita Shah', birthDate: '1978-04-04'}]))
      .toEqual({registrationId, status: 'submitted', waitlistPosition: null});
    await expect(submit(registrationId, [{name: 'X', birthDate: '1980-01-01'}],
      {uid: 'other', token: {email: 'nita@example.com', email_verified: true}}, 's2'))
      .rejects.toEqual(rejected('failed-precondition', 'completionUsed'));
  });

  test('a full event puts the completed group on the waitlist; a stranger\'s ID is refused', async () => {
    await seed({capacity: 1});
    const {registrationId} = await send({email: 'nita@example.com'});
    await expect(submit(registrationId, [{id: 'someone-else', name: 'X', birthDate: '1980-01-01'}]))
      .rejects.toEqual(rejected('invalid-argument', 'invalid'));
    const result = await submit(registrationId, [{id: 'nita', name: 'Nita Shah', birthDate: '1978-04-04'}], asNita, 's3');
    expect(result).toEqual({registrationId, status: 'waitlisted', waitlistPosition: 1});
    expect((await db().doc(`events/${E}/members/nita-account`).get()).exists).toBe(false);
  });
});
