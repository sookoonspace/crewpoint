/**
 * Spec #233 Req 15 (#238; GAP-ANY-02, GAP-ANY-03): an event has several
 * member invite links, each with its own role, expiry and optional single
 * use, each turned off on its own. Invites from before keep working.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {createInviteLink, updateInviteLink, listInviteLinks} = require('../../src/events/inviteLinks');
const {joinEvent} = require('../../src/events/joinEvent');
const {previewInvite} = require('../../src/events/previewInvite');
const {generateInviteCode} = require('../../src/events/generateInviteCode');
const {removeEventMember} = require('../../src/events/removeEventMember');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const DAY = 24 * 60 * 60 * 1000;
const db = () => getAdminDb();
const rejected = (code: string) => expect.objectContaining({code});
const unusable = (reason: string) =>
  expect.objectContaining({code: 'not-found', details: {reason}});

async function seed(over: object = {}) {
  const people = [['owner', ['owner']], ['admin', ['admin']], ['helper', ['participant']]] as const;
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner', 'admin'], memberIds: people.map(([uid]) => uid), memberCount: people.length,
    startDate: Timestamp.fromMillis(Date.now() + 200 * DAY), ...over,
  });
  for (const [uid, roleIds] of people) {
    await db().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds, crewIds: [], permissions: computePermissions(roleIds, {}),
    });
  }
}

const call = (fn: unknown, uid: string, data: object) => ftest.wrap(fn)({auth: {uid}, data});
const create = (data: object = {}, uid = 'owner') => call(createInviteLink, uid, {eventId: E, ...data});
const update = (data: object, uid = 'owner') => call(updateInviteLink, uid, {eventId: E, ...data});
const list = async (uid = 'owner') => (await call(listInviteLinks, uid, {eventId: E})).links;
const join = (uid: string, code: string) => call(joinEvent, uid, {joinCode: code});
const preview = (uid: string, code: string) => call(previewInvite, uid, {code});
const roleOf = async (uid: string) =>
  (await db().doc(`events/${E}/members/${uid}`).get()).data()?.roleIds;

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('createInviteLink', () => {
  test('makes a Participant link lasting until the event starts, by default', async () => {
    await seed();
    const link = await create();
    expect(link).toEqual(expect.objectContaining({
      roleId: 'participant', singleUse: false, uses: 0, state: 'active', turnedOffAt: null,
    }));
    expect(link.code).toMatch(/^[A-Z2-9]{6}$/);
    const startsAt = (await db().doc(`events/${E}`).get()).data()!.startDate.toMillis();
    expect(link.expiresAt).toBe(startsAt);
  });

  test('GAP-ANY-02 makes several links, each with its own role, and lists them newest first', async () => {
    await seed();
    const first = await create();
    const second = await create({roleId: 'volunteer', expiresAt: Date.now() + 30 * DAY});
    expect(second.code).not.toBe(first.code);
    const links = await list();
    expect(links.map((l: {code: string}) => l.code)).toEqual([second.code, first.code]);
    expect(links.map((l: {roleId: string}) => l.roleId)).toEqual(['volunteer', 'participant']);
    await join('ravi', first.code);
    await join('mira', second.code);
    expect(await roleOf('ravi')).toEqual(['participant']);
    expect(await roleOf('mira')).toEqual(['volunteer']);
  });

  test('keeps the same rules as before for who may hand out which role', async () => {
    await seed();
    expect((await create({}, 'admin')).roleId).toBe('participant');
    await expect(create({roleId: 'finance'}, 'admin')).rejects.toEqual(rejected('permission-denied'));
    await expect(create({}, 'helper')).rejects.toEqual(rejected('permission-denied'));
    await expect(create({roleId: 'owner'})).rejects.toEqual(rejected('failed-precondition'));
    await expect(create({roleId: 'nope'})).rejects.toEqual(rejected('invalid-argument'));
  });

  test('takes the same expiry limits as before: 5 minutes to 400 days', async () => {
    await seed();
    await expect(create({expiresAt: Date.now() + 60 * 1000})).rejects.toEqual(rejected('invalid-argument'));
    await expect(create({expiresAt: Date.now() + 401 * DAY})).rejects.toEqual(rejected('invalid-argument'));
    expect((await create({expiresAt: Date.now() + 400 * DAY - 60 * 1000})).state).toBe('active');
  });

  test('refuses a draft event and a bad single-use value', async () => {
    await seed({status: 'draft'});
    await expect(create()).rejects.toEqual(rejected('failed-precondition'));
    await db().doc(`events/${E}`).update({status: 'published'});
    await expect(create({singleUse: 'yes'})).rejects.toEqual(rejected('invalid-argument'));
  });

  test('needs a signed-in caller and an event that exists', async () => {
    await seed();
    await expect(ftest.wrap(createInviteLink)({data: {eventId: E}})).rejects.toEqual(rejected('unauthenticated'));
    await expect(call(createInviteLink, 'owner', {eventId: 'gone'})).rejects.toEqual(rejected('not-found'));
  });
});

describe('single use (GAP-ANY-03)', () => {
  test('GAP-ANY-03 a single-use link stops working after one join, and says why', async () => {
    await seed();
    const {code} = await create({singleUse: true});
    await join('ravi', code);
    const [link] = await list();
    expect(link).toEqual(expect.objectContaining({state: 'used', uses: 1, usedAt: expect.any(Number)}));
    await expect(preview('mira', code)).rejects.toEqual(unusable('used'));
    await expect(join('mira', code)).rejects.toEqual(unusable('used'));
    expect(await roleOf('mira')).toBeUndefined();
  });

  test('a refused join does not use it up', async () => {
    await seed();
    const {code} = await create({singleUse: true});
    await expect(join('owner', code)).rejects.toEqual(rejected('already-exists'));
    expect((await list())[0].state).toBe('active');
    await join('ravi', code);
  });

  test('two people racing for one single-use link: only one joins', async () => {
    await seed();
    const {code} = await create({singleUse: true});
    const results = await Promise.allSettled([join('ravi', code), join('mira', code)]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    const event = (await db().doc(`events/${E}`).get()).data()!;
    expect(event.memberCount).toBe(4);
  });

  test('a link for many joins counts each one', async () => {
    await seed();
    const {code} = await create();
    for (const uid of ['a', 'b', 'c']) await join(uid, code);
    expect((await list())[0]).toEqual(expect.objectContaining({uses: 3, state: 'active', usedAt: null}));
  });
});

describe('updateInviteLink', () => {
  test('GAP-ANY-03 turning one link off leaves the others working', async () => {
    await seed();
    const kept = await create();
    const off = await create({roleId: 'volunteer'});
    const result = await update({code: off.code, turnOff: true});
    expect(result).toEqual(expect.objectContaining({state: 'off', turnedOffAt: expect.any(Number)}));
    await expect(preview('mira', off.code)).rejects.toEqual(unusable('off'));
    await expect(join('mira', off.code)).rejects.toEqual(unusable('off'));
    await join('ravi', kept.code);
    expect(await roleOf('ravi')).toEqual(['participant']);
  });

  test('an Admin may turn off a link into a role, but not extend it', async () => {
    await seed();
    const {code} = await create({roleId: 'volunteer'});
    await expect(update({code, expiresAt: Date.now() + 10 * DAY}, 'admin')).rejects.toEqual(rejected('permission-denied'));
    expect((await update({code, turnOff: true}, 'admin')).state).toBe('off');
  });

  test('changes the expiry and keeps the code', async () => {
    await seed();
    const {code} = await create();
    const closes = Date.now() + 120 * DAY;
    const result = await update({code, expiresAt: closes});
    expect(result).toEqual(expect.objectContaining({code, expiresAt: closes}));
    expect((await list())[0].expiresAt).toBe(closes);
  });

  test('an expired link can be given a new expiry, and works again', async () => {
    await seed();
    const {code} = await create();
    await db().doc(`event_invites/${code}`).update({expiresAt: Timestamp.fromMillis(Date.now() - 1000)});
    await expect(preview('ravi', code)).rejects.toEqual(unusable('expired'));
    await update({code, expiresAt: Date.now() + DAY});
    await join('ravi', code);
  });

  test('a turned-off or used link cannot be extended', async () => {
    await seed();
    const off = await create();
    await update({code: off.code, turnOff: true});
    await expect(update({code: off.code, expiresAt: Date.now() + DAY})).rejects.toEqual(rejected('failed-precondition'));
    const used = await create({singleUse: true});
    await join('ravi', used.code);
    await expect(update({code: used.code, expiresAt: Date.now() + DAY})).rejects.toEqual(rejected('failed-precondition'));
  });

  test("refuses another event's link, both changes at once, and people who do not manage members", async () => {
    await seed();
    const {code} = await create();
    await db().doc('event_invites/OTH234').set({eventId: 'other', expiresAt: Timestamp.fromMillis(Date.now() + DAY)});
    await expect(update({code: 'OTH234', turnOff: true})).rejects.toEqual(rejected('not-found'));
    await expect(update({code, turnOff: true, expiresAt: Date.now() + DAY})).rejects.toEqual(rejected('invalid-argument'));
    await expect(update({code})).rejects.toEqual(rejected('invalid-argument'));
    await expect(update({code, turnOff: true}, 'helper')).rejects.toEqual(rejected('permission-denied'));
  });
});

describe('listInviteLinks', () => {
  test('needs members.manage', async () => {
    await seed();
    await create();
    await expect(list('helper')).rejects.toEqual(rejected('permission-denied'));
    expect(await list('admin')).toHaveLength(1);
  });
});

describe('existing invites keep working (Req 15)', () => {
  test('a code from before #238 is listed, previewed and joined as before', async () => {
    await seed();
    await db().doc('event_invites/OLD234').set({
      eventId: E, roleId: 'volunteer', createdBy: 'owner',
      createdAt: Timestamp.fromMillis(Date.now() - DAY), expiresAt: Timestamp.fromMillis(Date.now() + DAY),
    });
    expect(await list()).toEqual([expect.objectContaining({
      code: 'OLD234', roleId: 'volunteer', singleUse: false, uses: 0, state: 'active',
    })]);
    expect((await preview('ravi', 'OLD234')).roleName).toBe('Volunteer');
    await join('ravi', 'OLD234');
    await join('mira', 'OLD234');
    expect(await roleOf('mira')).toEqual(['volunteer']);
  });

  test('an expired old code explains it has expired, and is kept', async () => {
    await seed();
    await db().doc('event_invites/OLD234').set({eventId: E, expiresAt: Timestamp.fromMillis(Date.now() - 1000)});
    await expect(join('ravi', 'OLD234')).rejects.toEqual(unusable('expired'));
    expect((await db().doc('event_invites/OLD234').get()).exists).toBe(true);
  });

  test('the older one-invite call leaves the new links alone', async () => {
    await seed();
    const single = await create({singleUse: true});
    const volunteers = await create({roleId: 'volunteer'});
    const legacy = await call(generateInviteCode, 'owner', {eventId: E});
    // It returns the newest usable link that allows many joins.
    expect(legacy.code).toBe(volunteers.code);
    const rotated = await call(generateInviteCode, 'owner', {eventId: E, rotate: true});
    const states = Object.fromEntries((await list()).map((l: {code: string; state: string}) => [l.code, l.state]));
    expect(states).toEqual({[rotated.code]: 'active', [volunteers.code]: 'off', [single.code]: 'active'});
  });

  test('removing someone turns the usable links off, so they stay listed', async () => {
    await seed();
    const a = await create();
    const b = await create({roleId: 'volunteer'});
    await call(removeEventMember, 'owner', {eventId: E, targetUserId: 'helper'});
    const links = await list();
    expect(links.map((l: {code: string}) => l.code).sort()).toEqual([a.code, b.code].sort());
    expect(links.every((l: {state: string}) => l.state === 'off')).toBe(true);
  });
});
