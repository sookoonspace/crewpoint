/**
 * Req 25, 27: `events/{id}/members/{uid}` documents, written by the server
 * alongside the old arrays until #66 moves reads over.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {PRESET_ROLES, computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {createEvent} = require('../../src/events/createEvent');
const {joinEvent} = require('../../src/events/joinEvent');
const {removeEventMember} = require('../../src/events/removeEventMember');
const {promoteToAdmin} = require('../../src/events/promoteToAdmin');
const {demoteAdmin} = require('../../src/events/demoteAdmin');
const {deleteUserAccount} = require('../../src/account/deleteUserAccount');
const {getAuth} = require('firebase-admin/auth');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const member = async (uid: string) =>
  (await getAdminDb().doc(`events/${E}/members/${uid}`).get()).data();

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('createEvent', () => {
  test("writes the owner's member document", async () => {
    await ftest.wrap(createEvent)({auth: {uid: 'me'}, data: {eventId: E, title: 'Trip'}});
    const doc = await member('me');
    expect(doc).toEqual({
      uid: 'me',
      roleIds: ['owner'],
      crewIds: [],
      permissions: [...PRESET_ROLES.owner.permissions],
      participantId: null,
      joinedAt: expect.any(Timestamp),
    });
  });
});

async function seedEvent(over: object = {}) {
  await getAdminDb().doc(`events/${E}`).set({
    title: 'Trip',
    status: 'published',
    creatorId: 'owner',
    adminIds: ['owner', 'admin'],
    memberIds: ['owner', 'admin', 'plain'],
    memberCount: 3,
    ...over,
  });
}

describe('joinEvent', () => {
  test('writes a Participant member document', async () => {
    await seedEvent();
    await getAdminDb().doc('event_invites/ABC234').set({
      eventId: E,
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 86400000)),
    });
    await ftest.wrap(joinEvent)({auth: {uid: 'new'}, data: {joinCode: 'ABC234'}});
    expect(await member('new')).toEqual(expect.objectContaining({
      uid: 'new',
      roleIds: ['participant'],
      permissions: ['group.readOwn', 'chat.send'],
    }));
  });
});

async function seedMembers() {
  for (const [uid, roleIds] of [['owner', ['owner']], ['admin', ['admin']], ['plain', ['participant']]]) {
    await getAdminDb().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds, permissions: computePermissions(roleIds as string[], {}),
    });
  }
}

describe('removeEventMember', () => {
  test('removing or leaving deletes the member document', async () => {
    await seedEvent();
    await seedMembers();
    const remove = (uid: string, target: string) => ftest.wrap(removeEventMember)({
      auth: {uid}, data: {eventId: E, targetUserId: target},
    });
    await remove('owner', 'plain');
    expect(await member('plain')).toBeUndefined();
    await remove('admin', 'admin');
    expect(await member('admin')).toBeUndefined();
    expect(await member('owner')).toBeDefined();
  });
});

describe('promoteToAdmin and demoteAdmin', () => {
  const promote = (target: string) => ftest.wrap(promoteToAdmin)({
    auth: {uid: 'owner'}, data: {eventId: E, targetUserId: target},
  });
  const demote = (target: string) => ftest.wrap(demoteAdmin)({
    auth: {uid: 'owner'}, data: {eventId: E, targetUserId: target},
  });

  test('promoting swaps Participant for Admin and recalculates permissions', async () => {
    await seedEvent();
    await getAdminDb().doc(`events/${E}/members/plain`).set({
      uid: 'plain', roleIds: ['participant', 'scorer'], crewIds: ['c1'],
      permissions: [], participantId: 'p1', joinedAt: Timestamp.fromMillis(1000),
    });
    await promote('plain');
    expect(await member('plain')).toEqual({
      uid: 'plain',
      roleIds: ['scorer', 'admin'],
      crewIds: ['c1'],
      permissions: [...PRESET_ROLES.admin.permissions],
      participantId: 'p1',
      joinedAt: Timestamp.fromMillis(1000),
    });
  });

  test('demoting removes Admin, leaving Participant when no role is left', async () => {
    await seedEvent();
    await seedMembers();
    await demote('admin');
    expect(await member('admin')).toEqual(expect.objectContaining({
      roleIds: ['participant'],
      permissions: ['group.readOwn', 'chat.send'],
    }));
  });

  test('an event not yet migrated starts from the old arrays', async () => {
    await seedEvent();
    await promote('plain');
    expect((await member('plain'))?.roleIds).toEqual(['admin']);
  });
});

describe('deleteUserAccount', () => {
  const deleteAccount = async (uid: string) => {
    await getAuth().createUser({uid}).catch(() => undefined);
    await ftest.wrap(deleteUserAccount)({auth: {uid}, data: {}});
  };

  test("removes the person's member document", async () => {
    await seedEvent();
    await seedMembers();
    await deleteAccount('plain');
    expect(await member('plain')).toBeUndefined();
  });

  test('when the owner leaves, the next owner gets the Owner role', async () => {
    await seedEvent();
    await seedMembers();
    await deleteAccount('owner');
    expect(await member('owner')).toBeUndefined();
    expect(await member('admin')).toEqual(expect.objectContaining({
      roleIds: ['owner'],
      permissions: [...PRESET_ROLES.owner.permissions],
    }));
  });
});
