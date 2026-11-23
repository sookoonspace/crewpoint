/* eslint-disable */
// Acceptance tests for invite links (#79, #238). Test names start with the
// scenario ID. Runs on the emulators only.
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../test/setup';
import {computePermissions} from '../src/events/permissions';

const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {generateInviteCode} = require('../src/events/generateInviteCode');
const {previewInvite} = require('../src/events/previewInvite');
const {joinEvent} = require('../src/events/joinEvent');
const {createInviteLink, updateInviteLink, listInviteLinks} = require('../src/events/inviteLinks');

const E = 'derod';
const DAY = 24 * 60 * 60 * 1000;
const db = () => getAdminDb();
const call = (fn: unknown, uid: string, data: object) => ftest.wrap(fn)({auth: {uid}, data});

beforeEach(async () => {
  await clearFirestoreEmulator();
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status: 'published', templateId: 'convention',
    creatorId: 'admin', adminIds: ['admin'], memberIds: ['admin'], memberCount: 1,
    startDate: Timestamp.fromMillis(Date.now() + 240 * DAY), dateOnly: true, timeZone: 'America/Chicago',
  });
  await db().doc(`events/${E}/members/admin`).set({
    uid: 'admin', roleIds: ['owner'], permissions: computePermissions(['owner'], {}),
  });
});
afterAll(() => ftest.cleanup());

describe('Convention: seating 25+ attendees with one link', () => {
  test('GAP-CON-01 one link and code, carrying a role, open for the whole registration period, seats 30 people', async () => {
    const registrationCloses = Date.now() + 180 * DAY;
    const {code, expiresAt} = await call(generateInviteCode, 'admin', {eventId: E, expiresAt: registrationCloses});
    expect(expiresAt).toBe(registrationCloses);
    for (let i = 1; i <= 30; i++) {
      const uid = `attendee${i}`;
      const seen = await call(previewInvite, uid, {code});
      expect(seen).toEqual(expect.objectContaining({title: 'Convention 2027', roleName: 'Participant', open: true}));
      await call(joinEvent, uid, {joinCode: code});
    }
    const event = (await db().doc(`events/${E}`).get()).data()!;
    expect(event.memberCount).toBe(31);
    const member = (await db().doc(`events/${E}/members/attendee30`).get()).data()!;
    expect(member.roleIds).toEqual(['participant']);
  });

  test('GAP-CON-01 rotating replaces the link, so a leaked one stops working', async () => {
    const first = await call(generateInviteCode, 'admin', {eventId: E});
    const second = await call(generateInviteCode, 'admin', {eventId: E, rotate: true});
    expect(second.code).not.toBe(first.code);
    await expect(call(previewInvite, 'late', {code: first.code})).rejects.toEqual(expect.objectContaining({code: 'not-found'}));
    await expect(call(joinEvent, 'late', {joinCode: first.code})).rejects.toBeTruthy();
  });

  test('GAP-CON-01 a draft link explains it is not open yet', async () => {
    const {code} = await call(generateInviteCode, 'admin', {eventId: E});
    await db().doc(`events/${E}`).update({status: 'draft'});
    expect(await call(previewInvite, 'early', {code})).toEqual(expect.objectContaining({open: false, reason: 'draft'}));
  });
});

describe('Several member invite links (Spec #233 Req 15)', () => {
  const roleOf = async (uid: string) =>
    (await db().doc(`events/${E}/members/${uid}`).get()).data()?.roleIds;

  test('GAP-ANY-02 team captains and sponsors get different links, so the role is set at join', async () => {
    const captains = await call(createInviteLink, 'admin', {eventId: E, roleId: 'crewLead'});
    const sponsors = await call(createInviteLink, 'admin', {eventId: E, roleId: 'vendor', expiresAt: Date.now() + 30 * DAY});
    expect(captains.code).not.toBe(sponsors.code);
    expect((await call(previewInvite, 'captain', {code: captains.code})).roleName).toBe('Crew lead');
    await call(joinEvent, 'captain', {joinCode: captains.code});
    await call(joinEvent, 'sponsor', {joinCode: sponsors.code});
    expect(await roleOf('captain')).toEqual(['crewLead']);
    expect(await roleOf('sponsor')).toEqual(['vendor']);
    const {links} = await call(listInviteLinks, 'admin', {eventId: E});
    expect(links).toHaveLength(2);
  });

  test('GAP-ANY-03 a single-use link shared with one guest cannot spread', async () => {
    const {code} = await call(createInviteLink, 'admin', {eventId: E, singleUse: true});
    await call(joinEvent, 'guest', {joinCode: code});
    await expect(call(previewInvite, 'friend', {code})).rejects.toEqual(
      expect.objectContaining({code: 'not-found', details: {reason: 'used'}}));
    await expect(call(joinEvent, 'friend', {joinCode: code})).rejects.toBeTruthy();
  });

  test('GAP-ANY-03 a link that expires, or is turned off, stops working and says why', async () => {
    const shortLived = await call(createInviteLink, 'admin', {eventId: E, expiresAt: Date.now() + 10 * 60 * 1000});
    await db().doc(`event_invites/${shortLived.code}`).update({expiresAt: Timestamp.fromMillis(Date.now() - 1000)});
    await expect(call(previewInvite, 'late', {code: shortLived.code})).rejects.toEqual(
      expect.objectContaining({details: {reason: 'expired'}}));
    const leaked = await call(createInviteLink, 'admin', {eventId: E});
    await call(updateInviteLink, 'admin', {eventId: E, code: leaked.code, turnOff: true});
    await expect(call(joinEvent, 'stranger', {joinCode: leaked.code})).rejects.toEqual(
      expect.objectContaining({details: {reason: 'off'}}));
  });
});
