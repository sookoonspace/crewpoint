/**
 * Spec #233 Req 26-29, 31, 52, 65 (#246, W-05, W-06, Z-03): waivers with
 * versions, acceptances written only by the server, required ones checked
 * on Submit, the missing list and its email, and contact consent.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {saveWaiver, acceptWaivers, sendWaiverReminders} = require('../../src/registration/waiverCallables');
const {submitRegistration} = require('../../src/registration/submitRegistration');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const SLUG = 'convention-2027';
const DAY = 24 * 60 * 60 * 1000;
const db = () => getAdminDb();
const rejected = (code: string, reason?: string) =>
  expect.objectContaining({code, ...(reason ? {details: expect.objectContaining({reason})} : {})});

async function seed() {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner'], memberIds: ['owner', 'pia'], capacity: 50, timeZone: 'America/Chicago',
    startDate: new Date(Date.UTC(2027, 6, 16)), dateOnly: true,
    settings: {
      categories: [{id: 'child', name: 'Child', maxAge: 17, isChild: true}, {id: 'adult', name: 'Adult', minAge: 18}],
      registration: {
        mode: 'open', slug: SLUG, deadline: Date.now() + DAY, sections: [],
        blocks: {people: true, ageOnly: false, stay: false, sessionChoices: true, waivers: true, contact: true},
      },
    },
  });
  await db().doc(`eventSlugs/${SLUG}`).set({eventId: E});
  for (const [uid, roleIds] of [['owner', ['owner']], ['pia', ['participant']]] as const) {
    await db().doc(`events/${E}/members/${uid}`).set({uid, roleIds, crewIds: [], permissions: computePermissions([...roleIds], {})});
  }
  await db().doc(`events/${E}/sessions/WP`).set({
    title: 'Waterpark', startAt: new Date(Date.UTC(2027, 6, 17, 15)), attendance: 'bySession', hidden: false,
  });
}

const placeholder = {en: '[PLACEHOLDER: the convention\'s waiver text, Z-03]'};
const save = (data: object, uid = 'owner') => ftest.wrap(saveWaiver)({auth: {uid}, data: {eventId: E, ...data}});
const register = (people: object[], extra: object = {}, uid = 'asha') => ftest.wrap(submitRegistration)({auth: {uid}, data: {
  slug: SLUG, submissionId: `s-${uid}`, contact: {email: `${uid}@example.com`}, people, ...extra,
}});
const asha = {name: 'Asha Patel', birthDate: '1980-03-01', signUps: ['WP']};
const dev = {name: 'Dev Patel', birthDate: '2016-05-09', signUps: ['WP']};
const people = async () => (await db().collection(`events/${E}/participants`).get()).docs
  .map((d) => ({id: d.id, ...d.data()} as any));
const acceptances = async (pid: string) =>
  (await db().doc(`events/${E}/participants/${pid}/private/waivers`).get()).data()?.accepted ?? {};

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('waivers', () => {
  test('Req 26, 28: saving a waiver; a new text is a new version, kept with the old', async () => {
    await seed();
    const {waiverId} = await save({
      title: {en: 'Waterpark waiver'}, text: placeholder,
      appliesTo: {kind: 'session', id: 'WP'}, required: true, requireLatest: true,
    });
    await save({waiverId, title: {en: 'Waterpark waiver'}, text: {en: 'Version two'}, appliesTo: {kind: 'session', id: 'WP'}, required: true, requireLatest: true});
    // A setting alone is no new version.
    await save({waiverId, title: {en: 'Waterpark waiver'}, text: {en: 'Version two'}, appliesTo: {kind: 'session', id: 'WP'}, required: false, requireLatest: true});
    const w = (await db().doc(`events/${E}/waivers/${waiverId}`).get()).data()!;
    expect(w).toEqual(expect.objectContaining({version: 2, required: false, text: {en: 'Version two'}}));
    const versions = (await db().collection(`events/${E}/waivers/${waiverId}/versions`).get()).docs.map((d) => d.id).sort();
    expect(versions).toEqual(['1', '2']);
    await expect(save({title: {en: 'x'}, text: placeholder, appliesTo: {kind: 'everyone'}}, 'pia'))
      .rejects.toEqual(rejected('permission-denied'));
    await expect(save({title: {en: 'x'}, text: placeholder, appliesTo: {kind: 'session', id: 'nope'}}))
      .rejects.toEqual(rejected('invalid-argument'));
  });

  test('Req 29: a required waiver blocks Submit until accepted for everyone it applies to', async () => {
    await seed();
    const {waiverId} = await save({title: {en: 'Waterpark waiver'}, text: placeholder,
      appliesTo: {kind: 'session', id: 'WP'}, required: true, requireLatest: true});
    await expect(register([asha, dev])).rejects.toEqual(rejected('invalid-argument', 'invalid'));
    await expect(register([{...asha, acceptWaivers: [waiverId]}, dev])).rejects.toEqual(rejected('invalid-argument', 'invalid'));
    await register([{...asha, acceptWaivers: [waiverId]}, {...dev, acceptWaivers: [waiverId]}]);
    const [a, d] = (await people()).sort((x, y) => x.name.localeCompare(y.name));
    // Req 27: written by the server, who accepted, as whom, which version.
    expect((await acceptances(a.id))[waiverId]).toEqual(expect.objectContaining({version: 1, by: 'asha', as: 'self'}));
    expect((await acceptances(d.id))[waiverId]).toEqual(expect.objectContaining({version: 1, by: 'asha', as: 'guardian'}));
    expect(a.waiversMissing).toBe(false);
  });

  test('W-05, W-06: an optional waiver can wait; the person is on the missing list until accepted, even after the deadline', async () => {
    await seed();
    const {waiverId} = await save({title: {en: 'Photo walk'}, text: placeholder, appliesTo: {kind: 'everyone'}, required: false, requireLatest: true});
    await register([asha]);
    const [a] = await people();
    expect(a).toEqual(expect.objectContaining({waiversMissing: true, missingWaivers: [waiverId]}));
    await db().doc(`events/${E}`).update({'settings.registration.deadline': Date.now() - DAY});
    await ftest.wrap(acceptWaivers)({auth: {uid: 'asha'}, data: {slug: SLUG, acceptances: [{participantId: a.id, waiverId}]}});
    const [after] = await people();
    expect(after.waiversMissing).toBe(false);
    expect((await acceptances(a.id))[waiverId].version).toBe(1);
    // Someone else's person cannot be accepted for.
    await expect(ftest.wrap(acceptWaivers)({auth: {uid: 'stranger'}, data: {slug: SLUG, acceptances: [{participantId: a.id, waiverId}]}}))
      .rejects.toEqual(rejected('permission-denied'));
  });

  test('Req 28: a new version the organizer requires puts people back on the list; one not required does not', async () => {
    await seed();
    const {waiverId} = await save({title: {en: 'Photo walk'}, text: placeholder, appliesTo: {kind: 'everyone'}, required: false, requireLatest: false});
    await register([{...asha, acceptWaivers: [waiverId]}]);
    await save({waiverId, title: {en: 'Photo walk'}, text: {en: 'New words'}, appliesTo: {kind: 'everyone'}, required: false, requireLatest: false});
    expect((await people())[0].waiversMissing).toBe(false);
    await save({waiverId, title: {en: 'Photo walk'}, text: {en: 'Newer words'}, appliesTo: {kind: 'everyone'}, required: false, requireLatest: true});
    expect((await people())[0].waiversMissing).toBe(true);
  });

  test('Req 52, 65: registrations.manage emails each group with someone missing a waiver', async () => {
    await seed();
    await save({title: {en: 'Photo walk'}, text: placeholder, appliesTo: {kind: 'everyone'}, required: false, requireLatest: true});
    await register([asha]);
    const result = await ftest.wrap(sendWaiverReminders)({auth: {uid: 'owner'}, data: {eventId: E}});
    expect(result).toEqual({sent: 1});
    const [mail] = (await db().collection('mailOutbox').where('template', '==', 'waiverMissing').get()).docs.map((d) => d.data());
    expect(mail).toEqual(expect.objectContaining({to: 'asha@example.com', eventId: E}));
    expect(mail.data.people).toContain('Asha Patel');
    await expect(ftest.wrap(sendWaiverReminders)({auth: {uid: 'pia'}, data: {eventId: E}}))
      .rejects.toEqual(rejected('permission-denied'));
  });

  test('Req 31: contact consent for announcements is asked once and stored', async () => {
    await seed();
    await register([asha], {consent: {email: true, sms: false}});
    const [reg] = (await db().collection(`events/${E}/registrations`).get()).docs.map((d) => d.data());
    expect(reg.consent).toEqual(expect.objectContaining({email: true, sms: false}));
  });
});

describe('the form and my registration show waivers', () => {
  test('getRegistrationForm lists waivers; getMyRegistration lists what each person misses', async () => {
    await seed();
    const {waiverId} = await save({title: {en: 'Photo walk'}, text: placeholder, appliesTo: {kind: 'everyone'}, required: false, requireLatest: true});
    /* eslint-disable @typescript-eslint/no-var-requires */
    const {getRegistrationForm} = require('../../src/registration/registrationForm');
    const {getMyRegistration} = require('../../src/registration/myRegistration');
    /* eslint-enable @typescript-eslint/no-var-requires */
    const form = await ftest.wrap(getRegistrationForm)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    expect(form.waivers).toEqual([expect.objectContaining({id: waiverId, version: 1, required: false, text: placeholder})]);
    await register([asha]);
    const view = await ftest.wrap(getMyRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    expect(view.waivers.map((w: {id: string}) => w.id)).toEqual([waiverId]);
    expect(view.registration.people[0]).toEqual(expect.objectContaining({missingWaivers: [waiverId]}));
  });
});
