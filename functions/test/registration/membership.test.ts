/**
 * Spec #233 Req 60-63, TD 10 (#245): a submitted registration makes its
 * contact and linked adults members with the event's registration role;
 * cancelling takes back only what registration gave.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {submitRegistration} = require('../../src/registration/submitRegistration');
const {cancelRegistration} = require('../../src/registration/cancelRegistration');
const {applyRegistrationMembership} = require('../../src/registration/membership');
const {setMemberRoles} = require('../../src/events/roles');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const SLUG = 'convention-2027';
const DAY = 24 * 60 * 60 * 1000;
const db = () => getAdminDb();

async function seed({capacity = 10, roleId = 'participant'} = {}) {
  const people: Array<[string, string[]]> = [['owner', ['owner']], ['ada', ['admin']], ['pia', ['participant']]];
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner', 'ada'], memberIds: people.map(([u]) => u), memberCount: people.length, capacity,
    timeZone: 'America/Chicago', startDate: new Date(Date.UTC(2027, 6, 16)), dateOnly: true,
    settings: {
      categories: [{id: 'adult', name: 'Adult', minAge: 18}],
      registration: {
        mode: 'open', slug: SLUG, deadline: Date.now() + DAY, sections: [],
        blocks: {people: true, ageOnly: false, stay: false, sessionChoices: false, waivers: false, contact: true},
        registrationRoleId: roleId,
      },
    },
  });
  await db().doc(`eventSlugs/${SLUG}`).set({eventId: E});
  for (const [uid, roleIds] of people) {
    await db().doc(`events/${E}/members/${uid}`).set({
      uid, roleIds, crewIds: [], permissions: computePermissions(roleIds, {}),
    });
  }
}

const register = (uid: string) => ftest.wrap(submitRegistration)({auth: {uid}, data: {
  slug: SLUG, submissionId: `s-${uid}`, contact: {email: `${uid}@example.com`},
  people: [{name: `${uid} Patel`, birthDate: '1980-01-01'}],
}});
const cancel = (uid: string, data: object = {}) =>
  ftest.wrap(cancelRegistration)({auth: {uid}, data: {slug: SLUG, ...data}});
const member = async (uid: string) => (await db().doc(`events/${E}/members/${uid}`).get()).data();
const event = async () => (await db().doc(`events/${E}`).get()).data()!;
const registrationOf = async (uid: string) =>
  (await db().collection(`events/${E}/registrations`).where('contactUid', '==', uid).get()).docs[0];

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('membership through the registration role', () => {
  test('Req 60: the contact joins with the registration role, the grant recorded', async () => {
    await seed({roleId: 'player'});
    await db().doc(`events/${E}/roles/player`).set({name: 'Player', permissions: ['chat.send', 'group.readOwn']});
    await register('asha');
    const m = (await member('asha'))!;
    expect(m.roleIds).toEqual(['player']);
    expect(m.permissions).toEqual(expect.arrayContaining(['chat.send']));
    expect(m.registrationGrant).toEqual({roleId: 'player', groupIds: m.groupIds});
    const e = await event();
    expect(e.memberIds).toContain('asha');
    expect(e.memberCount).toBe(4);
    expect(e.adminIds).not.toContain('asha');
  });

  test('an existing Admin who registers keeps Admin and gains the role', async () => {
    await seed();
    await register('ada');
    const m = (await member('ada'))!;
    expect(m.roleIds).toEqual(['admin', 'participant']);
    expect(m.registrationGrant.roleId).toBe('participant');
    expect((await event()).memberCount).toBe(3);
  });

  test('a role edit keeps what registration granted', async () => {
    await seed();
    await register('asha');
    await ftest.wrap(setMemberRoles)({auth: {uid: 'owner'}, data: {eventId: E, targetUserId: 'asha', roleIds: ['participant', 'crewLead']}});
    expect((await member('asha'))!.registrationGrant).toEqual(expect.objectContaining({roleId: 'participant'}));
  });

  test('linked adults of a submitted group join too; waiting groups give no role', async () => {
    await seed();
    await register('asha');
    const reg = await registrationOf('asha');
    await db().doc(`events/${E}/groups/${reg.data().groupId}`).update({adultUids: ['asha', 'ravi']});
    await db().runTransaction(async (tx) => {
      const eventRef = db().doc(`events/${E}`);
      const plan = await applyRegistrationMembership.read(tx, eventRef, reg.ref);
      applyRegistrationMembership.write(tx, plan, 'submitted');
    });
    expect((await member('ravi'))!.roleIds).toEqual(['participant']);
    expect((await event()).memberIds).toEqual(expect.arrayContaining(['asha', 'ravi']));
  });

  test('Req 61: cancelling takes the role back; someone with no other role leaves', async () => {
    await seed();
    await register('asha');
    const result = await cancel('asha');
    expect(result).toEqual({status: 'cancelled'});
    expect(await member('asha')).toBeUndefined();
    const e = await event();
    expect(e.memberIds).not.toContain('asha');
    expect(e.memberCount).toBe(3);
    const reg = await registrationOf('asha');
    expect(reg.data()).toEqual(expect.objectContaining({status: 'cancelled', cancelReason: 'byGroup'}));
    const [person] = (await db().collection(`events/${E}/participants`).get()).docs.map((d) => d.data());
    expect(person.registrationStatus).toBe('cancelled');
    expect((await db().doc(`events/${E}/groups/${reg.data().groupId}`).get()).data()!.registrationStatus).toBe('cancelled');
    expect((await db().doc(`events/${E}/registrationTally/current`).get()).data()!.placesUsed).toBe(0);
    const log = (await reg.ref.collection('changes').get()).docs.map((d) => d.data());
    expect(log).toEqual(expect.arrayContaining([expect.objectContaining({action: 'cancelled', by: 'asha', reason: 'byGroup'})]));
  });

  test('an Admin who cancels stays an Admin, without the group or the role', async () => {
    await seed();
    await register('ada');
    await cancel('ada');
    const m = (await member('ada'))!;
    expect(m.roleIds).toEqual(['admin']);
    expect(m.groupIds ?? []).toEqual([]);
    expect(m.registrationGrant).toBeUndefined();
    expect((await event()).adminIds).toContain('ada');
  });

  test('someone who held the role before registering keeps it after cancelling', async () => {
    await seed();
    await register('pia');
    expect((await member('pia'))!.registrationGrant.roleId).toBeNull();
    await cancel('pia');
    expect((await member('pia'))!.roleIds).toEqual(['participant']);
    expect((await event()).memberIds).toContain('pia');
  });

  test('the committee cancels with registrations.manage; others cannot; a waitlisted group frees nothing', async () => {
    await seed({capacity: 1});
    await register('asha');
    await register('ravi');
    const ravi = await registrationOf('ravi');
    expect(ravi.data().status).toBe('waitlisted');
    await expect(cancel('pia', {registrationId: ravi.id})).rejects.toEqual(expect.objectContaining({code: 'permission-denied'}));
    await cancel('owner', {registrationId: ravi.id});
    expect((await registrationOf('ravi')).data().cancelReason).toBe('byCommittee');
    expect((await db().doc(`events/${E}/registrationTally/current`).get()).data()!.placesUsed).toBe(1);
    await expect(cancel('owner', {registrationId: ravi.id})).rejects.toEqual(
      expect.objectContaining({code: 'failed-precondition'}));
  });
});
