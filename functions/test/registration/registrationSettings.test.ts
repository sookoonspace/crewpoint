/**
 * Spec #233 Req 8, 11, 16-19, 60, 67 (#239): `event.manage` saves the
 * event's registration settings and claims its link name, both checked on
 * the server.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {saveRegistrationSettings, claimEventSlug} = require('../../src/registration/registrationSettings');
const {registrationOf} = require('../../src/registration/registrationSettings');
const {deleteEvent} = require('../../src/events/deleteEvent');
const {createEvent} = require('../../src/events/createEvent');
const {saveAsTemplate} = require('../../src/events/saveAsTemplate');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const db = () => getAdminDb();
const rejected = (code: string, message?: RegExp) =>
  expect.objectContaining({code, ...(message ? {message: expect.stringMatching(message)} : {})});

async function seed(id = E, over: object = {}) {
  const people = [['owner', ['owner']], ['admin', ['admin']], ['lead', ['crewLead']], ['sam', ['participant']]] as const;
  await db().doc(`events/${id}`).set({
    title: 'Convention 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner', 'admin'], memberIds: people.map(([uid]) => uid), memberCount: people.length,
    capacity: null,
    settings: {categories: [{id: 'child', name: 'Child', maxAge: 17}, {id: 'adult', name: 'Adult', minAge: 18}]},
    ...over,
  });
  for (const [uid, roleIds] of people) {
    await db().doc(`events/${id}/members/${uid}`).set({
      uid, roleIds, crewIds: [], permissions: computePermissions(roleIds, {}),
    });
  }
  const field = {options: [], required: false, scope: 'participant', visibility: 'standard', order: 0};
  await db().doc(`events/${id}/fields/booked`).set({...field, label: 'Booked a room?', type: 'yesNo'});
  await db().doc(`events/${id}/fields/confirmation`).set({...field, label: 'Confirmation number', type: 'text'});
  await db().doc(`events/${id}/roles/player`).set({name: 'Player', permissions: ['chat.send', 'group.readOwn']});
}

const call = (fn: unknown, uid: string, data: object) => ftest.wrap(fn)({auth: {uid}, data});
const save = (registration: object, uid = 'admin', extra: object = {}) =>
  call(saveRegistrationSettings, uid, {eventId: E, registration, ...extra});
const claim = (slug: string | null, uid = 'admin', eventId = E) =>
  call(claimEventSlug, uid, {eventId, slug});
const event = async (id = E) => (await db().doc(`events/${id}`).get()).data()!;
const log = async () => (await db().collection(`events/${E}/settingsLog`).get()).docs.map((d) => d.data());

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('saveRegistrationSettings', () => {
  const deadline = Date.UTC(2027, 5, 30, 4, 59);
  const full = {
    mode: 'open', deadline, review: true, extraGuests: 1,
    sections: [{id: 'stay', name: {en: 'Your stay'}, fieldIds: ['booked', 'confirmation']}],
    blocks: {people: true, ageOnly: false, stay: true, sessionChoices: true, waivers: true, contact: true},
    conditions: {confirmation: {fieldId: 'booked', value: 'yes'}},
    afterNote: {en: 'Book with code CONV27'}, laterNote: {en: 'The hotel block has closed'},
    laterNoteFrom: Date.UTC(2027, 4, 1),
    registrationRoleId: 'player', offerHours: 48,
  };

  test('saves every setting and the capacity, and logs who changed them', async () => {
    await seed();
    await save(full, 'admin', {capacity: 400});
    const saved = await event();
    expect(saved.capacity).toBe(400);
    expect(saved.settings.registration).toEqual(expect.objectContaining({
      mode: 'open', review: true, extraGuests: 1, registrationRoleId: 'player', offerHours: 48,
      conditions: {confirmation: {fieldId: 'booked', value: 'yes'}},
    }));
    expect(saved.settings.registration.deadline).toBe(deadline);
    // The rest of the settings stay as they were.
    expect(saved.settings.categories).toHaveLength(2);
    const entries = await log();
    expect(entries).toHaveLength(1);
    expect(entries[0]).toEqual(expect.objectContaining({setting: 'registration', changedBy: 'admin'}));
    expect(entries[0].to.capacity).toBe(400);
  });

  test('saving the same settings again records nothing', async () => {
    await seed();
    await save(full, 'admin', {capacity: 400});
    await save(full, 'admin', {capacity: 400});
    expect(await log()).toHaveLength(1);
  });

  test('keeps the slug, which only claimEventSlug sets', async () => {
    await seed();
    await claim('convention-2027');
    await save({...full, slug: 'stolen'});
    expect((await event()).settings.registration.slug).toBe('convention-2027');
  });

  test('refuses a condition on a question that itself has a condition', async () => {
    await seed();
    await db().doc(`events/${E}/fields/room`).set({label: 'Room type', type: 'singleChoice', options: ['King', 'Two beds']});
    await expect(save({
      ...full,
      conditions: {
        room: {fieldId: 'booked', value: 'yes'},
        booked: {categoryId: 'adult'},
      },
    })).rejects.toEqual(rejected('invalid-argument', /itself has a condition/));
    expect((await event()).settings.registration).toBeUndefined();
  });

  test('refuses sections listing questions the event does not have', async () => {
    await seed();
    await expect(save({...full, sections: [{id: 'a', name: {en: 'A'}, fieldIds: ['ghost']}]}))
      .rejects.toEqual(rejected('invalid-argument', /does not exist/));
  });

  test('refuses a registration role that manages anything, or Owner', async () => {
    await seed();
    await expect(save({...full, registrationRoleId: 'crewLead'}))
      .rejects.toEqual(rejected('invalid-argument', /organizer permissions/));
    await expect(save({...full, registrationRoleId: 'owner'}))
      .rejects.toEqual(rejected('invalid-argument'));
  });

  test('refuses a bad capacity', async () => {
    await seed();
    await expect(save(full, 'admin', {capacity: 0})).rejects.toEqual(rejected('invalid-argument'));
  });

  test('needs event.manage', async () => {
    await seed();
    await expect(save(full, 'lead')).rejects.toEqual(rejected('permission-denied'));
    await expect(save(full, 'sam')).rejects.toEqual(rejected('permission-denied'));
    await expect(save(full, 'stranger')).rejects.toEqual(rejected('permission-denied'));
  });

  test('refuses an archived event', async () => {
    await seed(E, {status: 'archived'});
    await expect(save(full)).rejects.toEqual(rejected('failed-precondition'));
  });
});

describe('registrationOf', () => {
  test("an event with no settings reads its template's defaults", () => {
    expect(registrationOf({templateId: 'convention'}).mode).toBe('open');
    expect(registrationOf({templateId: 'wedding'}).mode).toBe('invited');
    expect(registrationOf({templateId: 'cricket_tournament'}).registrationRoleId).toBe('player');
    expect(registrationOf({}).offerHours).toBe(72);
    expect(registrationOf({}).slug).toBeNull();
  });
});

describe('claimEventSlug', () => {
  test('claims a name, kept lower-case, and maps it to the event', async () => {
    await seed();
    expect(await claim('Convention-2027')).toEqual({slug: 'convention-2027'});
    expect((await db().doc('eventSlugs/convention-2027').get()).data()).toEqual(
      expect.objectContaining({eventId: E, claimedBy: 'admin'}));
    expect((await event()).settings.registration.slug).toBe('convention-2027');
    expect((await log()).map((e) => e.setting)).toEqual(['slug']);
  });

  test('a name another event holds is refused with a reason, whatever its case', async () => {
    await seed();
    await seed('other');
    await claim('shah-wedding', 'owner', 'other');
    await expect(claim('Shah-Wedding')).rejects.toEqual(
      expect.objectContaining({code: 'already-exists', details: {reason: 'taken'}}));
    expect((await db().doc('eventSlugs/shah-wedding').get()).data()!.eventId).toBe('other');
  });

  test('changing the name releases the old one, and null releases it', async () => {
    await seed();
    await claim('first-name');
    await claim('second-name');
    expect((await db().doc('eventSlugs/first-name').get()).exists).toBe(false);
    expect((await db().doc('eventSlugs/second-name').get()).exists).toBe(true);
    await claim(null);
    expect((await db().doc('eventSlugs/second-name').get()).exists).toBe(false);
    expect((await event()).settings.registration.slug).toBeNull();
  });

  test('claiming its own name again changes nothing', async () => {
    await seed();
    await claim('same-name');
    await claim('same-name');
    expect(await log()).toHaveLength(1);
  });

  test('refuses names that are not letters, numbers and hyphens', async () => {
    await seed();
    for (const bad of ['a b', 'ab', 'join', '-x-']) {
      await expect(claim(bad)).rejects.toEqual(
        expect.objectContaining({code: 'invalid-argument', details: {reason: 'invalid'}}));
    }
  });

  test('needs event.manage', async () => {
    await seed();
    await expect(claim('mine', 'lead')).rejects.toEqual(rejected('permission-denied'));
    expect((await db().doc('eventSlugs/mine').get()).exists).toBe(false);
  });

  test('deleting the event releases its name', async () => {
    await seed();
    await claim('gone-soon', 'owner');
    await call(deleteEvent, 'owner', {eventId: E});
    expect((await db().doc('eventSlugs/gone-soon').get()).exists).toBe(false);
  });
});

describe('templates (Spec #233 Req 8, 60)', () => {
  const created = async (templateId: string) => {
    const eventId = `t-${templateId}`;
    await call(createEvent, 'maker', {eventId, title: 'New', templateId});
    return (await event(eventId)).settings.registration;
  };

  test('open for Convention, Cricket tournament and Golf outing', async () => {
    for (const t of ['convention', 'cricket_tournament', 'golf_outing']) {
      expect((await created(t)).mode).toBe('open');
    }
  });

  test('invited for Wedding, Party and Blank', async () => {
    for (const t of ['wedding', 'party', 'blank']) {
      expect((await created(t)).mode).toBe('invited');
    }
  });

  test('a cricket entry registers people as Players, called a Team entry', async () => {
    expect((await created('cricket_tournament')).registrationRoleId).toBe('player');
    const e = await event('t-cricket_tournament');
    expect(e.labels.registration.one).toBe('Team entry');
    expect((await db().doc('events/t-cricket_tournament/roles/player').get()).data()!.name).toBe('Player');
  });

  test('a saved template keeps the registration settings, without dates or the link name', async () => {
    await seed();
    await save({
      mode: 'open', deadline: Date.UTC(2027, 5, 30), review: true, extraGuests: 2,
      sections: [{id: 'stay', name: {en: 'Your stay'}, fieldIds: ['booked']}],
      conditions: {confirmation: {fieldId: 'booked', value: 'yes'}},
      laterNote: {en: 'Later'}, laterNoteFrom: Date.UTC(2027, 4, 1),
      registrationRoleId: 'player', offerHours: 24,
    }, 'owner');
    await claim('my-convention', 'owner');
    const {templateId: id} = await call(saveAsTemplate, 'owner', {eventId: E, name: 'Our convention'});
    const saved = (await db().doc(`users/owner/templates/${id}`).get()).data()!;
    expect(saved.settings.registration).toEqual(expect.objectContaining({
      mode: 'open', review: true, extraGuests: 2, registrationRoleId: 'player', offerHours: 24,
      conditions: {confirmation: {fieldId: 'booked', value: 'yes'}},
    }));
    for (const gone of ['deadline', 'laterNote', 'laterNoteFrom', 'slug']) {
      expect(saved.settings.registration).not.toHaveProperty(gone);
    }
    // An event made from it registers the same way.
    await call(createEvent, 'owner', {eventId: 'again', title: 'Again', savedTemplateId: id});
    expect((await event('again')).settings.registration.registrationRoleId).toBe('player');
  });
});
