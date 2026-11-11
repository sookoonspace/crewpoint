/**
 * Req 47, 56 (GAP-CON-01): one shareable link per event, carrying a role,
 * with an expiry the organizer sets. Changing the expiry keeps the link;
 * rotating replaces it and keeps the role and expiry. `/join/:code` first
 * shows what the person is joining, and explains when the event is not open.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {generateInviteCode} = require('../../src/events/generateInviteCode');
const {previewInvite} = require('../../src/events/previewInvite');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const DAY = 24 * 60 * 60 * 1000;
const db = () => getAdminDb();
const rejected = (code: string) => expect.objectContaining({code});
const stored = async (code: string) =>
  (await db().doc(`event_invites/${code}`).get()).data();

async function seed(over: object = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status: 'published', creatorId: 'owner', adminIds: ['owner'],
    memberIds: ['owner'], memberCount: 1, ...over,
  });
  await db().doc(`events/${E}/members/owner`).set({
    uid: 'owner', roleIds: ['owner'], crewIds: [], permissions: computePermissions(['owner'], {}),
  });
}

const invite = (data: object = {}) =>
  ftest.wrap(generateInviteCode)({auth: {uid: 'owner'}, data: {eventId: E, ...data}});
const preview = (uid: string, code: string) =>
  ftest.wrap(previewInvite)({auth: {uid}, data: {code}});
const within = (actual: number, expected: number) =>
  expect(Math.abs(actual - expected)).toBeLessThan(60 * 1000);

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('the expiry (Req 56)', () => {
  test('Blank and Party default to 24 hours', async () => {
    await seed({templateId: 'party'});
    const result = await invite();
    within(result.expiresAt, Date.now() + DAY);
    expect((await stored(result.code))!.expiresAt.toMillis()).toBe(result.expiresAt);
  });

  test('other templates default to the event start', async () => {
    const startsAt = Date.now() + 200 * DAY;
    await seed({templateId: 'convention', startDate: Timestamp.fromMillis(startsAt)});
    expect((await invite()).expiresAt).toBe(startsAt);
  });

  test('GAP-CON-01 an organizer sets it to cover registration, and the link stays the same', async () => {
    await seed();
    const first = await invite();
    const closes = Date.now() + 120 * DAY;
    const changed = await invite({expiresAt: closes});
    expect(changed.code).toBe(first.code);
    expect(changed.expiresAt).toBe(closes);
    expect((await stored(first.code))!.expiresAt.toMillis()).toBe(closes);
    // Opening the invite again keeps it.
    expect((await invite()).expiresAt).toBe(closes);
  });

  test('rotating replaces the link, keeping the role and expiry', async () => {
    await seed();
    const closes = Date.now() + 90 * DAY;
    const first = await invite({roleId: 'volunteer', expiresAt: closes});
    const rotated = await invite({rotate: true});
    expect(rotated.code).not.toBe(first.code);
    expect(rotated).toEqual(expect.objectContaining({roleId: 'volunteer', expiresAt: closes}));
    expect(await stored(first.code)).toBeUndefined();
  });

  test('a new role replaces the link and keeps the expiry', async () => {
    await seed();
    const closes = Date.now() + 30 * DAY;
    const first = await invite({expiresAt: closes});
    const changed = await invite({roleId: 'volunteer'});
    expect(changed.code).not.toBe(first.code);
    expect(changed.expiresAt).toBe(closes);
  });

  test('refuses an expiry in the past or beyond a registration period', async () => {
    await seed();
    await expect(invite({expiresAt: Date.now() - 1000})).rejects.toEqual(rejected('invalid-argument'));
    await expect(invite({expiresAt: Date.now() + 500 * DAY})).rejects.toEqual(rejected('invalid-argument'));
  });
});

describe('previewInvite (/join/:code)', () => {
  test('shows the event, the role and its start, before joining', async () => {
    const startsAt = Date.UTC(2027, 6, 16);
    await seed({startDate: Timestamp.fromMillis(startsAt), dateOnly: true, timeZone: 'America/Chicago'});
    const {code} = await invite({roleId: 'volunteer'});
    await expect(preview('guest', code.toLowerCase())).resolves.toEqual({
      eventId: E, title: 'Convention 2027', roleId: 'volunteer', roleName: 'Volunteer',
      open: true, reason: null, alreadyMember: false, full: false,
      startDate: startsAt, dateOnly: true, timeZone: 'America/Chicago',
      expiresAt: expect.any(Number),
    });
  });

  test('a custom role shows its own name', async () => {
    await seed();
    await db().doc(`events/${E}/roles/greeter`).set({name: 'Greeter', permissions: ['chat.send']});
    const {code} = await invite({roleId: 'greeter'});
    expect((await preview('guest', code)).roleName).toBe('Greeter');
  });

  test('explains a draft, an ended event, a full one, and someone already in it', async () => {
    await seed();
    const {code} = await invite();
    await db().doc(`events/${E}`).update({status: 'draft'});
    expect(await preview('guest', code)).toEqual(expect.objectContaining({open: false, reason: 'draft'}));
    await db().doc(`events/${E}`).update({status: 'ended'});
    expect(await preview('guest', code)).toEqual(expect.objectContaining({open: false, reason: 'ended'}));
    await db().doc(`events/${E}`).update({status: 'live', memberLimit: 1});
    expect(await preview('guest', code)).toEqual(expect.objectContaining({open: true, full: true}));
    expect((await preview('owner', code)).alreadyMember).toBe(true);
  });

  test('an unknown or expired code is not found, and it needs a signed-in person', async () => {
    await seed();
    await expect(preview('guest', 'ZZZZZZ')).rejects.toEqual(rejected('not-found'));
    await db().doc('event_invites/OLD234').set({
      eventId: E, roleId: 'participant', expiresAt: Timestamp.fromMillis(Date.now() - 1000),
    });
    await expect(preview('guest', 'OLD234')).rejects.toEqual(rejected('not-found'));
    await expect(preview('guest', 'abc')).rejects.toEqual(rejected('invalid-argument'));
    await expect(ftest.wrap(previewInvite)({data: {code: 'OLD234'}})).rejects.toEqual(rejected('unauthenticated'));
  });
});
