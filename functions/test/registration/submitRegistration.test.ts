/**
 * Spec #233 Req 1, 2, 4, 4a, 17, 18, 21, 22, 25, 32, 32a, 33, 52, 60
 * (#242): a family submits its registration. One callable, idempotent by
 * `submissionId`, decides in one transaction with `registrationTally/current`
 * whether the whole group takes places or waits.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {submitRegistration} = require('../../src/registration/submitRegistration');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const SLUG = 'convention-2027';
const db = () => getAdminDb();
const rejected = (code: string, reason?: string) =>
  expect.objectContaining({code, ...(reason ? {details: expect.objectContaining({reason})} : {})});

const DAY = 24 * 60 * 60 * 1000;

async function seed({
  capacity = 10 as number | null,
  status = 'published',
  registration = {} as object,
} = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status, templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner'], memberIds: ['owner'], memberCount: 1, capacity,
    timeZone: 'America/Chicago', startDate: new Date(Date.UTC(2027, 6, 16)), dateOnly: true,
    settings: {
      categories: [
        {id: 'child', name: 'Child', maxAge: 17, isChild: true},
        {id: 'adult', name: 'Adult', minAge: 18},
      ],
      registration: {
        mode: 'open', slug: SLUG, deadline: Date.now() + 30 * DAY, review: false,
        sections: [{id: 'food', name: {en: 'Food'}, fieldIds: ['diet', 'allergies', 'kids']}],
        blocks: {people: true, ageOnly: false, stay: true, sessionChoices: true, waivers: false, contact: true},
        conditions: {kids: {categoryId: 'child'}},
        registrationRoleId: 'participant',
        ...registration,
      },
    },
  });
  await db().doc(`eventSlugs/${SLUG}`).set({eventId: E});
  await db().doc(`events/${E}/members/owner`).set({
    uid: 'owner', roleIds: ['owner'], crewIds: [], permissions: computePermissions(['owner'], {}),
  });
  const field = {options: [], required: false, scope: 'participant', visibility: 'standard', order: 0};
  await db().doc(`events/${E}/fields/diet`).set(
    {...field, label: 'Diet', type: 'singleChoice', options: ['Veg', 'Jain'], required: true});
  await db().doc(`events/${E}/fields/allergies`).set(
    {...field, label: 'Allergies', type: 'text', visibility: 'private'});
  await db().doc(`events/${E}/fields/kids`).set({...field, label: 'Kids activities', type: 'yesNo'});
  const session = {title: 'Meal', hidden: false, attendance: 'bySession'};
  await db().doc(`events/${E}/sessions/park`).set(
    {...session, startAt: new Date(Date.UTC(2027, 6, 17, 17)), endAt: new Date(Date.UTC(2027, 6, 17, 19))});
  await db().doc(`events/${E}/sessions/hotel`).set(
    {...session, startAt: new Date(Date.UTC(2027, 6, 17, 17, 30)), endAt: new Date(Date.UTC(2027, 6, 17, 18, 30))});
}

const asha = {
  name: 'Asha Patel', birthDate: '1980-03-01',
  answers: {diet: 'Jain', allergies: 'Peanuts', kids: true},
  arrivalAt: Date.UTC(2027, 6, 16, 15), departureAt: Date.UTC(2027, 6, 18, 18),
  signUps: ['park'],
};
const dev = {name: 'Dev Patel', birthDate: '2016-05-09', answers: {diet: 'Veg', kids: true}, signUps: ['hotel']};
const family = (over: object = {}) => ({
  slug: SLUG, submissionId: 'sub-1', groupName: 'Patel family',
  contact: {email: 'Asha@Example.com', phone: '(312) 555-0100'},
  people: [asha, dev],
  ...over,
});

const submit = (data: object, uid = 'asha') =>
  ftest.wrap(submitRegistration)({auth: {uid, token: {email: 'asha@example.com'}}, data});
const all = async (path: string) => (await db().collection(path).get()).docs.map((d) => ({id: d.id, ...d.data()}));
const tally = async () => (await db().doc(`events/${E}/registrationTally/current`).get()).data();

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('submitRegistration', () => {
  test('a family registers: one group, its people as Participants, places taken, the contact a member', async () => {
    await seed();
    const result = await submit(family());
    expect(result).toEqual({registrationId: expect.any(String), status: 'submitted', waitlistPosition: null});

    const [registration] = await all(`events/${E}/registrations`) as any[];
    expect(registration).toEqual(expect.objectContaining({
      id: result.registrationId, contactUid: 'asha', status: 'submitted', size: 2,
      lastSubmissionId: 'sub-1', waitlistPosition: null, extraGuestsAllowed: 0,
    }));
    const [group] = await all(`events/${E}/groups`) as any[];
    expect(group).toEqual(expect.objectContaining({
      id: registration.groupId, name: 'Patel family', sortName: 'patel family',
      adultUids: ['asha'], registrationId: registration.id, registrationStatus: 'submitted',
    }));

    const people = await all(`events/${E}/participants`) as any[];
    const a = people.find((p) => p.name === 'Asha Patel');
    const d = people.find((p) => p.name === 'Dev Patel');
    expect(a).toEqual(expect.objectContaining({
      groupId: group.id, uid: 'asha', isChild: false, categoryId: 'adult', status: 'active',
      registrationStatus: 'submitted', fields: {diet: 'Jain'}, filterTags: ['diet=Jain'],
      signUps: ['park'],
    }));
    // A question shown only to children is not saved for an adult (Req 18).
    expect(a.fields.kids).toBeUndefined();
    expect(a.arrivalAt.toMillis()).toBe(asha.arrivalAt);
    expect(d).toEqual(expect.objectContaining({
      isChild: true, categoryId: 'child', fields: {diet: 'Veg', kids: true},
      filterTags: expect.arrayContaining(['diet=Veg', 'kids=yes']), signUps: ['hotel'],
    }));
    expect(d.uid).toBeUndefined();
    // Private answers, birth dates and the contact's details stay private (Req 22).
    const aPrivate = (await db().doc(`events/${E}/participants/${a.id}/private/details`).get()).data();
    expect(aPrivate).toEqual(expect.objectContaining({
      birthDate: '1980-03-01', allergies: 'Peanuts', email: 'asha@example.com', phone: '+13125550100',
    }));
    expect(JSON.stringify(a)).not.toContain('Peanuts');

    expect(await tally()).toEqual(expect.objectContaining({placesUsed: 2}));
    const member = (await db().doc(`events/${E}/members/asha`).get()).data()!;
    expect(member.roleIds).toEqual(['participant']);
    expect(member.groupIds).toEqual([group.id]);
    expect(member.participantId).toBe(a.id);
    expect((await db().doc(`events/${E}`).get()).data()!.memberIds).toEqual(['owner', 'asha']);

    const changes = await all(`events/${E}/registrations/${registration.id}/changes`) as any[];
    expect(changes).toEqual([expect.objectContaining({by: 'asha', action: 'submitted', status: 'submitted'})]);
    const [mail] = await all('mailOutbox') as any[];
    expect(mail).toEqual(expect.objectContaining({
      to: 'asha@example.com', uid: 'asha', template: 'registrationConfirmation', eventId: E,
    }));
    expect(mail.data.people).toContain('Asha Patel');
    expect(mail.data.people).toContain('Dev Patel');
    expect(mail.data.link).toBe(`https://crewpoint-dev.web.app/e/${SLUG}/registration`);
  });

  test('a repeat with the same submission ID returns the first result and changes nothing', async () => {
    await seed();
    const first = await submit(family());
    const again = await submit(family());
    expect(again).toEqual(first);
    expect(await all(`events/${E}/registrations`)).toHaveLength(1);
    expect(await all(`events/${E}/participants`)).toHaveLength(2);
    expect((await tally())!.placesUsed).toBe(2);
    expect(await all('mailOutbox')).toHaveLength(1);
  });

  test('a group that would go over capacity waits whole, numbered in turn (Req 33)', async () => {
    await seed({capacity: 3});
    await submit(family({submissionId: 'a'}), 'one');
    const second = await submit(family({submissionId: 'b'}), 'two');
    const third = await submit(family({submissionId: 'c'}), 'three');
    expect(second).toEqual(expect.objectContaining({status: 'waitlisted', waitlistPosition: 1}));
    expect(third).toEqual(expect.objectContaining({status: 'waitlisted', waitlistPosition: 2}));
    expect((await tally())!.placesUsed).toBe(2);
    const waiting = (await all(`events/${E}/participants`) as any[]).filter((p) => p.registrationStatus === 'waitlisted');
    expect(waiting).toHaveLength(4);
    // Waiting is not joining: no registration role yet (Req 60).
    expect((await db().doc(`events/${E}/members/two`).get()).exists).toBe(false);
    const mails = await all('mailOutbox') as any[];
    expect(mails.filter((m) => m.template === 'registrationWaitlisted')).toHaveLength(2);
  });

  test('two families racing for the last places get them in turn; the one that no longer fits waits', async () => {
    await seed({capacity: 3});
    const results = await Promise.all([
      submit(family({submissionId: 'x'}), 'x'),
      submit(family({submissionId: 'y'}), 'y'),
    ]);
    expect(results.map((r) => r.status).sort()).toEqual(['submitted', 'waitlisted']);
    expect((await tally())!.placesUsed).toBe(2);
  });

  test('with review on, the group is pending and holds its places (Req 4)', async () => {
    await seed({registration: {review: true}});
    expect((await submit(family())).status).toBe('pending');
    expect((await tally())!.placesUsed).toBe(2);
  });

  test('refusals', async () => {
    await seed();
    await expect(ftest.wrap(submitRegistration)({data: family()})).rejects.toEqual(rejected('unauthenticated'));
    await expect(submit(family({slug: 'nobody'}))).rejects.toEqual(rejected('not-found'));
    await expect(submit(family({submissionId: ''}))).rejects.toEqual(rejected('invalid-argument'));
    await expect(submit(family({people: []}))).rejects.toEqual(rejected('invalid-argument', 'noPeople'));
    await expect(submit(family({people: [{...asha, name: ' '}]})))
      .rejects.toEqual(rejected('invalid-argument', 'invalid'));
    // A required question, unanswered (Req 21).
    await expect(submit(family({people: [{...asha, answers: {}}]})))
      .rejects.toEqual(rejected('invalid-argument', 'invalid'));
    // Both sides of an either/or (W-01).
    await expect(submit(family({people: [{...asha, signUps: ['park', 'hotel']}]})))
      .rejects.toEqual(rejected('invalid-argument', 'invalid'));
    await expect(submit(family({contact: {email: 'not-an-email'}})))
      .rejects.toEqual(rejected('invalid-argument', 'invalid'));
    expect(await all(`events/${E}/registrations`)).toHaveLength(0);

    await submit(family());
    await expect(submit(family({submissionId: 'sub-2'})))
      .rejects.toEqual(rejected('already-exists', 'alreadyRegistered'));
  });

  test('closed or not open events refuse (Req 14, 35), and invited events need a personal link', async () => {
    await seed({status: 'draft'});
    await expect(submit(family())).rejects.toEqual(rejected('failed-precondition', 'notOpen'));
    await seed({registration: {deadline: Date.now() - DAY}});
    await expect(submit(family())).rejects.toEqual(rejected('failed-precondition', 'closed'));
    await seed({status: 'ended'});
    await expect(submit(family())).rejects.toEqual(rejected('failed-precondition', 'closed'));
    await seed({registration: {mode: 'invited'}});
    await expect(submit(family())).rejects.toEqual(rejected('permission-denied', 'invitedOnly'));
  });
});
