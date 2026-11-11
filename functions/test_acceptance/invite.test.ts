/* eslint-disable */
// Acceptance tests for the invite link (#79). Test names start with the
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
