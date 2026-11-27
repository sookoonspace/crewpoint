/**
 * Spec #233 Req 4, 4a, 37, 52, 64, 66 (#249): the committee's summary and
 * actions, each with registrations.manage, at any time, with the
 * over-capacity confirm, and the closing reminder and group details.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {submitRegistration} = require('../../src/registration/submitRegistration');
const {cancelRegistration} = require('../../src/registration/cancelRegistration');
const {saveRegistrationDraft} = require('../../src/registration/registrationDraft');
const {
  getRegistrationSummary, manageRegistration, resendConfirmation, sendClosingReminder, getGroupRegistration,
} = require('../../src/registration/committee');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const SLUG = 'convention-2027';
const DAY = 24 * 3600_000;
const db = () => getAdminDb();
const rejected = (code: string, reason?: string) =>
  expect.objectContaining({code, ...(reason ? {details: expect.objectContaining({reason})} : {})});

async function seed({capacity = 3, review = false} = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner'], memberIds: ['owner', 'pia', 'lead'], memberCount: 3, capacity, timeZone: 'America/Chicago',
    startDate: new Date(Date.UTC(2027, 6, 16)), dateOnly: true,
    settings: {
      categories: [{id: 'adult', name: 'Adult', minAge: 18}],
      registration: {
        mode: 'open', slug: SLUG, deadline: Date.now() + 30 * DAY, sections: [], review, registrationRoleId: 'participant',
        blocks: {people: true, ageOnly: false, stay: false, sessionChoices: false, waivers: false, contact: true},
      },
    },
  });
  await db().doc(`eventSlugs/${SLUG}`).set({eventId: E});
  // `lead` manages registrations without reading private details.
  const members: Array<[string, string[], string[]?]> = [
    ['owner', ['owner']], ['pia', ['participant']], ['lead', ['crewLead'], ['registrations.manage']],
  ];
  for (const [uid, roleIds, extra = []] of members) {
    await db().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds, crewIds: [], permissions: [...computePermissions(roleIds, {}), ...extra],
    });
  }
}

const register = (uid: string, n: number) => ftest.wrap(submitRegistration)({auth: {uid}, data: {
  slug: SLUG, submissionId: `s-${uid}`, contact: {email: `${uid}@example.com`},
  people: Array.from({length: n}, (_, i) => ({name: `${uid} ${i + 1}`, birthDate: '1980-01-01'})),
}});
const manage = (registrationId: string, action: string, extra: object = {}, uid = 'owner') =>
  ftest.wrap(manageRegistration)({auth: {uid}, data: {eventId: E, registrationId, action, ...extra}});
const reg = async (uid: string) =>
  (await db().collection(`events/${E}/registrations`).where('contactUid', '==', uid).get()).docs[0];
const tally = async () => (await db().doc(`events/${E}/registrationTally/current`).get()).data()!;
const member = async (uid: string) => (await db().doc(`events/${E}/members/${uid}`).get()).data();
const mail = async (template: string) =>
  (await db().collection('mailOutbox').where('template', '==', template).get()).docs.map((d) => d.data());

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('the committee', () => {
  test('Req 64, 4a: the summary counts groups and people by status, with places and the link', async () => {
    await seed();
    await register('asha', 2);
    await register('ravi', 2);
    await ftest.wrap(saveRegistrationDraft)({auth: {uid: 'mina'}, data: {slug: SLUG, draft: {people: []}, savedAt: Date.now()}});
    const s = await ftest.wrap(getRegistrationSummary)({auth: {uid: 'owner'}, data: {eventId: E}});
    expect(s.byStatus).toEqual({
      submitted: {groups: 1, people: 2}, waitlisted: {groups: 1, people: 2},
      pending: {groups: 0, people: 0}, cancelled: {groups: 0, people: 0}, draft: {groups: 1, people: null},
    });
    expect(s).toEqual(expect.objectContaining({capacity: 3, placesUsed: 2, held: 0, slug: SLUG, review: false}));
    await expect(ftest.wrap(getRegistrationSummary)({auth: {uid: 'pia'}, data: {eventId: E}}))
      .rejects.toEqual(rejected('permission-denied'));
  });

  test('approve: pending to submitted, a member, with the confirmation', async () => {
    await seed({review: true});
    await register('asha', 2);
    expect((await reg('asha')).data().status).toBe('pending');
    expect(await member('asha')).toBeUndefined();
    await expect(manage((await reg('asha')).id, 'approve', {}, 'pia')).rejects.toEqual(rejected('permission-denied'));
    expect(await manage((await reg('asha')).id, 'approve')).toEqual({status: 'submitted'});
    expect((await member('asha'))!.roleIds).toEqual(['participant']);
    expect((await mail('registrationConfirmation')).map((m) => m.to)).toContain('asha@example.com');
    const people = await db().collection(`events/${E}/participants`).where('registrationId', '==', (await reg('asha')).id).get();
    expect(people.docs.every((p) => p.data().registrationStatus === 'submitted')).toBe(true);
    // Only a pending registration can be approved.
    await expect(manage((await reg('asha')).id, 'approve')).rejects.toEqual(rejected('failed-precondition', 'wrongStatus'));
  });

  test('waitlist: frees the places for the next group, at the end of the queue, and takes membership back', async () => {
    await seed();
    await register('asha', 2);
    await register('ravi', 2);
    await manage((await reg('asha')).id, 'waitlist');
    const asha = (await reg('asha')).data();
    expect(asha.status).toBe('waitlisted');
    expect(asha.waitlistPosition).toBeGreaterThan((await reg('ravi')).data().waitlistPosition);
    expect(await member('asha')).toBeUndefined();
    // Ravi (2) now fits the freed places and is offered them.
    expect((await reg('ravi')).data().offer).toBeTruthy();
    expect((await tally()).placesUsed).toBe(0);
  });

  test('Req 37, B-12: reinstating past capacity warns, and goes ahead once confirmed', async () => {
    await seed({capacity: 2});
    await register('asha', 2);
    await register('ravi', 2);
    const ravi = (await reg('ravi')).id;
    await expect(manage(ravi, 'reinstate')).rejects.toEqual(rejected('failed-precondition', 'overCapacity'));
    await expect(manage(ravi, 'reinstate')).rejects.toEqual(expect.objectContaining({details: expect.objectContaining({over: 2})}));
    expect(await manage(ravi, 'reinstate', {confirmOverCapacity: true})).toEqual({status: 'submitted'});
    expect((await tally()).placesUsed).toBe(4);
    expect((await member('ravi'))!.roleIds).toEqual(['participant']);
    const log = (await (await reg('ravi')).ref.collection('changes').get()).docs.map((d) => d.data());
    expect(log).toEqual(expect.arrayContaining([expect.objectContaining({action: 'reinstated', overCapacity: true, by: 'owner'})]));
  });

  test('reinstate a cancelled registration with room, after the deadline too', async () => {
    await seed();
    await register('asha', 2);
    await ftest.wrap(cancelRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    await db().doc(`events/${E}`).update({'settings.registration.deadline': Date.now() - DAY});
    expect(await manage((await reg('asha')).id, 'reinstate')).toEqual({status: 'submitted'});
    expect((await reg('asha')).data()).toEqual(expect.objectContaining({status: 'submitted', cancelReason: null}));
    expect((await tally()).placesUsed).toBe(2);
  });

  test('resend the confirmation; refused for a draft', async () => {
    await seed();
    await register('asha', 1);
    await ftest.wrap(resendConfirmation)({auth: {uid: 'owner'}, data: {eventId: E, registrationId: (await reg('asha')).id}});
    expect(await mail('registrationConfirmation')).toHaveLength(2);
    await ftest.wrap(saveRegistrationDraft)({auth: {uid: 'mina'}, data: {slug: SLUG, draft: {email: 'mina@example.com'}, savedAt: Date.now()}});
    await expect(ftest.wrap(resendConfirmation)({auth: {uid: 'owner'}, data: {eventId: E, registrationId: (await reg('mina')).id}}))
      .rejects.toEqual(rejected('failed-precondition', 'wrongStatus'));
  });

  test('Req 52: the closing reminder goes only to drafts not yet sent', async () => {
    await seed();
    await register('asha', 1);
    await ftest.wrap(saveRegistrationDraft)({auth: {uid: 'mina'}, data: {slug: SLUG, draft: {email: 'mina@example.com'}, savedAt: Date.now()}});
    expect(await ftest.wrap(sendClosingReminder)({auth: {uid: 'owner'}, data: {eventId: E}})).toEqual({sent: 1});
    const [m] = await mail('registrationClosing');
    expect(m.to).toBe('mina@example.com');
    expect(m.data.closes).toMatch(/CST|CDT/);
    expect(m.data.link).toContain(`/e/${SLUG}/register`);
  });

  test('Req 66: a group\'s registration: status, log, contact and adults by name, waivers', async () => {
    await seed();
    await register('asha', 2);
    await db().doc(`events/${E}/profiles/asha`).set({displayName: 'Asha Patel'});
    const groupId = (await reg('asha')).data().groupId;
    const view = await ftest.wrap(getGroupRegistration)({auth: {uid: 'owner'}, data: {eventId: E, groupId}});
    expect(view.registration).toEqual(expect.objectContaining({
      status: 'submitted', contact: expect.objectContaining({name: 'Asha Patel', email: 'asha@example.com'}),
      linkedAdults: [{uid: 'asha', name: 'Asha Patel'}],
    }));
    expect(view.registration.changes[0]).toEqual(expect.objectContaining({action: 'submitted', by: 'Asha Patel'}));
    expect(view.registration.people).toHaveLength(2);
    // Without participants.readPrivate, no email.
    const lead = await ftest.wrap(getGroupRegistration)({auth: {uid: 'lead'}, data: {eventId: E, groupId}});
    expect(lead.registration.contact.email).toBeNull();
    // A group added by hand has no registration.
    await db().doc(`events/${E}/groups/hand`).set({name: 'By hand'});
    expect(await ftest.wrap(getGroupRegistration)({auth: {uid: 'owner'}, data: {eventId: E, groupId: 'hand'}}))
      .toEqual({registration: null});
  });
});
