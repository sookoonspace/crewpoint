/**
 * Req 46 (X-05, L-01, L-02): a signed-in person is linked to their own
 * participant record when their **verified** email matches it, never on a
 * name. Linking makes them a member with the Participant role, unless they
 * are one already, and a linked adult of that person's group only. An
 * ambiguous match goes to an organizer, who links them or says it is not a
 * match.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {linkMyParticipants, resolveLinkRequest} = require('../../src/participants/linkParticipants');
const {emailMatchKey} = require('../../src/participants/matchKeys');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'conv';
const db = () => getAdminDb();
const get = async (path: string) => (await db().doc(path).get()).data();
const rejected = (code: string) => expect.objectContaining({code});

async function seedEvent(over: object = {}, members: [string, string[]][] = [['owner', ['owner']], ['lead', ['crewLead']]]) {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2026', status: 'published', creatorId: 'owner', adminIds: ['owner'],
    memberIds: members.map(([u]) => u), memberCount: members.length, ...over,
  });
  for (const [uid, roleIds] of members) {
    await db().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds, crewIds: [], participantId: null,
      permissions: computePermissions(roleIds, {}, {readsAllExpenses: true}),
    });
  }
  await db().doc(`events/${E}/groups/f1`).set({name: 'Patel', sortName: 'patel', adultUids: []});
  await db().doc(`events/${E}/groups/f2`).set({name: 'Shah', sortName: 'shah', adultUids: []});
}

async function person(id: string, name: string, email: string | null, over: object = {}) {
  await db().doc(`events/${E}/participants/${id}`).set({
    name, sortName: name.toLowerCase(), groupId: 'f1', isChild: false, status: 'active',
    createdBy: 'owner', ...over,
  });
  if (email) await db().doc(`events/${E}/participants/${id}/private/details`).set({email});
}

const signIn = (uid: string, email: string, verified = true, name?: string) =>
  ftest.wrap(linkMyParticipants)({
    auth: {uid, token: {email, email_verified: verified, ...(name ? {name} : {})}},
    data: {},
  });
const resolve = (uid: string, data: object) =>
  ftest.wrap(resolveLinkRequest)({auth: {uid}, data: {eventId: E, ...data}});

beforeEach(async () => {
  await clearFirestoreEmulator();
  await seedEvent();
});
afterAll(() => ftest.cleanup());

describe('linkMyParticipants', () => {
  test('X-05 a verified email links the person to their record and makes them a Participant', async () => {
    await person('ravi', 'Ravi Patel', 'ravi@x.test');
    await expect(signIn('u1', 'Ravi@X.test ')).resolves.toEqual({linked: [E], asked: []});
    expect((await get(`events/${E}/participants/ravi`))!.uid).toBe('u1');
    const member = (await get(`events/${E}/members/u1`))!;
    expect(member).toEqual(expect.objectContaining({
      uid: 'u1', roleIds: ['participant'], participantId: 'ravi', groupIds: ['f1'],
    }));
    expect(member.permissions).toEqual(expect.arrayContaining(['group.readOwn', 'group.editOwn']));
    expect(member.permissions).not.toContain('participants.read');
    expect((await get(`events/${E}/groups/f1`))!.adultUids).toEqual(['u1']);
    expect((await get(`events/${E}/groups/f2`))!.adultUids).toEqual([]);
    const event = (await get(`events/${E}`))!;
    expect(event.memberIds).toContain('u1');
    expect(event.memberCount).toBe(3);
  });

  test('an unverified email never links', async () => {
    await person('ravi', 'Ravi Patel', 'ravi@x.test');
    await expect(signIn('u1', 'ravi@x.test', false)).resolves.toEqual({linked: [], asked: [], unverified: true});
    expect((await get(`events/${E}/participants/ravi`))!.uid).toBeUndefined();
    expect(await get(`events/${E}/members/u1`)).toBeUndefined();
  });

  test('never on a name alone', async () => {
    await person('ravi', 'Ravi Patel', null);
    await expect(signIn('u1', 'ravi@x.test', true, 'Ravi Patel')).resolves.toEqual({linked: [], asked: []});
    expect(await get(`events/${E}/members/u1`)).toBeUndefined();
  });

  test('someone already in the event keeps their roles', async () => {
    await seedEvent({}, [['owner', ['owner']], ['u1', ['volunteer']]]);
    await person('ravi', 'Ravi Patel', 'ravi@x.test');
    await signIn('u1', 'ravi@x.test');
    const member = (await get(`events/${E}/members/u1`))!;
    expect(member.roleIds).toEqual(['volunteer']);
    expect(member.participantId).toBe('ravi');
    expect(member.groupIds).toEqual(['f1']);
    expect((await get(`events/${E}`))!.memberCount).toBe(2);
  });

  test('a person without a group is linked to their own record only', async () => {
    await person('ravi', 'Ravi Patel', 'ravi@x.test', {groupId: null});
    await signIn('u1', 'ravi@x.test');
    const member = (await get(`events/${E}/members/u1`))!;
    expect(member.participantId).toBe('ravi');
    expect(member.groupIds).toEqual([]);
    expect(member.permissions).not.toContain('group.editOwn');
  });

  test('signing in again changes nothing', async () => {
    await person('ravi', 'Ravi Patel', 'ravi@x.test');
    await signIn('u1', 'ravi@x.test');
    await expect(signIn('u1', 'ravi@x.test')).resolves.toEqual({linked: [], asked: []});
    expect((await get(`events/${E}`))!.memberCount).toBe(3);
  });

  test('a record linked to another account is never taken', async () => {
    await person('ravi', 'Ravi Patel', 'ravi@x.test', {uid: 'someoneElse'});
    await expect(signIn('u1', 'ravi@x.test')).resolves.toEqual({linked: [], asked: []});
  });

  test('a draft waits: plain members are never in a draft', async () => {
    await seedEvent({status: 'draft'});
    await person('ravi', 'Ravi Patel', 'ravi@x.test');
    await expect(signIn('u1', 'ravi@x.test')).resolves.toEqual({linked: [], asked: []});
    await db().doc(`events/${E}`).update({status: 'published'});
    await expect(signIn('u1', 'ravi@x.test')).resolves.toEqual({linked: [E], asked: []});
  });

  test('an ended event, or one that is full, is left alone', async () => {
    await seedEvent({status: 'ended'});
    await person('ravi', 'Ravi Patel', 'ravi@x.test');
    await expect(signIn('u1', 'ravi@x.test')).resolves.toEqual({linked: [], asked: []});
    await db().doc(`events/${E}`).update({status: 'published', memberLimit: 2});
    await expect(signIn('u1', 'ravi@x.test')).resolves.toEqual({linked: [], asked: []});
    expect((await get(`events/${E}/participants/ravi`))!.uid).toBeUndefined();
  });

  test('X-05 a shared family email links the one adult, never a child', async () => {
    await person('ravi', 'Ravi Patel', 'ravi@x.test');
    await person('kid', 'Asha Patel', 'ravi@x.test', {isChild: true});
    await signIn('u1', 'ravi@x.test');
    expect((await get(`events/${E}/participants/ravi`))!.uid).toBe('u1');
    expect((await get(`events/${E}/participants/kid`))!.uid).toBeUndefined();
  });

  test('X-05 two adults with one email go to an organizer, with nothing linked', async () => {
    await person('ravi', 'Ravi Patel', 'home@x.test');
    await person('mira', 'Mira Patel', 'home@x.test');
    await db().doc('users/u1').set({displayName: 'Ravi P'});
    await expect(signIn('u1', 'home@x.test')).resolves.toEqual({linked: [], asked: [E]});
    expect(await get(`events/${E}/members/u1`)).toBeUndefined();
    expect(await get(`events/${E}/linkRequests/u1`)).toEqual(expect.objectContaining({
      uid: 'u1', name: 'Ravi P', email: 'home@x.test', status: 'open',
      participantIds: ['mira', 'ravi'], groupIds: ['f1'],
    }));
  });

  test('a match key from a deleted account links a new account back to its unnamed entry', async () => {
    await person('anon', '', null, {anonymised: true, sortName: '', imported: true});
    await db().doc(`events/${E}/participantKeys/anon`).set({emailKey: await emailMatchKey('ravi@x.test')});
    await db().doc('users/u2').set({displayName: 'Ravi Patel'});
    await expect(signIn('u2', 'ravi@x.test')).resolves.toEqual({linked: [E], asked: []});
    const back = (await get(`events/${E}/participants/anon`))!;
    expect(back).toEqual(expect.objectContaining({uid: 'u2', name: 'Ravi Patel', sortName: 'ravi patel'}));
    expect(back.anonymised).toBeUndefined();
    expect((await get(`events/${E}/participants/anon/private/details`))!.email).toBe('ravi@x.test');
    expect(await get(`events/${E}/participantKeys/anon`)).toBeUndefined();
  });

  test('needs a signed-in caller', async () => {
    await expect(ftest.wrap(linkMyParticipants)({data: {}})).rejects.toEqual(rejected('unauthenticated'));
  });
});

describe('resolveLinkRequest', () => {
  beforeEach(async () => {
    await person('ravi', 'Ravi Patel', 'home@x.test');
    await person('mira', 'Mira Patel', 'home@x.test');
    await person('kid', 'Dev Shah', 'shah@x.test', {groupId: 'f2', isChild: true});
    await signIn('u1', 'home@x.test');
    await signIn('u2', 'shah@x.test');
  });

  test('an organizer links the person to the record they pick', async () => {
    await resolve('owner', {uid: 'u1', participantId: 'mira'});
    expect((await get(`events/${E}/participants/mira`))!.uid).toBe('u1');
    expect((await get(`events/${E}/members/u1`))!.participantId).toBe('mira');
    expect(await get(`events/${E}/linkRequests/u1`)).toBeUndefined();
  });

  test('with only children matching, the person becomes an adult of the group', async () => {
    await resolve('owner', {uid: 'u2', groupId: 'f2'});
    const member = (await get(`events/${E}/members/u2`))!;
    expect(member.participantId).toBeNull();
    expect(member.groupIds).toEqual(['f2']);
    expect((await get(`events/${E}/groups/f2`))!.adultUids).toEqual(['u2']);
    expect((await get(`events/${E}/participants/kid`))!.uid).toBeUndefined();
  });

  test('not a match: nothing is linked, and signing in again does not ask again', async () => {
    await resolve('owner', {uid: 'u1', dismiss: true});
    expect((await get(`events/${E}/linkRequests/u1`))!.status).toBe('dismissed');
    await expect(signIn('u1', 'home@x.test')).resolves.toEqual({linked: [], asked: []});
    expect((await get(`events/${E}/linkRequests/u1`))!.status).toBe('dismissed');
  });

  test('only a pick from the request, a child never, and only organizers', async () => {
    await expect(resolve('owner', {uid: 'u1', participantId: 'kid'})).rejects.toEqual(rejected('invalid-argument'));
    await expect(resolve('owner', {uid: 'u2', participantId: 'kid'})).rejects.toEqual(rejected('invalid-argument'));
    await expect(resolve('owner', {uid: 'u1', groupId: 'f2'})).rejects.toEqual(rejected('invalid-argument'));
    await expect(resolve('owner', {uid: 'nobody', dismiss: true})).rejects.toEqual(rejected('not-found'));
    // A crew lead edits people but cannot read emails.
    await expect(resolve('lead', {uid: 'u1', participantId: 'mira'})).rejects.toEqual(rejected('permission-denied'));
  });
});
