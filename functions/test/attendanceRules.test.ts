/**
 * Req 50 (J-06): attendance exceptions. Organizers with participants.edit
 * set anything; a group's linked adults set their own people's stay,
 * opt-outs and sign-ups, but never invitations. Groups are invited by
 * organizers only. Sessions may override the event's policy.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {Timestamp, doc, serverTimestamp, setDoc, updateDoc} from 'firebase/firestore';
import {getTestEnv} from './setup';
import {computePermissions} from '../src/events/permissions';

let env: RulesTestEnvironment;
beforeAll(async () => {
  env = await getTestEnv();
});
afterEach(() => env.clearFirestore());
afterAll(() => env.cleanup());

const E = 'events/conv';
const as = (uid: string) => env.authenticatedContext(uid).firestore();
const PEOPLE: Record<string, [string[], string[]]> = {
  owner: [['owner'], []],
  lead: [['crewLead'], []],
  parent: [['participant'], ['f1']],
  plain: [['participant'], []],
};
const at = (iso: string) => Timestamp.fromDate(new Date(iso));

beforeEach(async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, E), {
      title: 'Convention', status: 'published', creatorId: 'owner', adminIds: ['owner'],
      memberIds: Object.keys(PEOPLE), skipMemberSync: true,
    });
    for (const [uid, [roleIds, groupIds]] of Object.entries(PEOPLE)) {
      await setDoc(doc(db, `${E}/members/${uid}`), {
        uid, roleIds, crewIds: [], groupIds,
        permissions: computePermissions(roleIds, {}, {editsOwnGroup: groupIds.length > 0}),
      });
    }
    await setDoc(doc(db, `${E}/groups/f1`), {name: 'Desai', sortName: 'desai', adultUids: ['parent']});
    await setDoc(doc(db, `${E}/participants/ramesh`), {
      name: 'Ramesh', sortName: 'ramesh', groupId: 'f1', isChild: false, createdBy: 'owner', status: 'active',
    });
  });
});

const person = (uid: string) => doc(as(uid), `${E}/participants/ramesh`);
const group = (uid: string) => doc(as(uid), `${E}/groups/f1`);

describe('a person\'s stay and exceptions', () => {
  test('a linked adult sets their own people\'s stay, opt-outs and sign-ups', async () => {
    await assertSucceeds(updateDoc(person('parent'), {
      arrivalAt: at('2027-07-17T16:00:00Z'), departureAt: null,
      optOuts: ['m3'], signUps: ['k1'], updatedAt: serverTimestamp(),
    }));
  });

  test('only participants.edit invites someone', async () => {
    await assertFails(updateDoc(person('parent'), {invitedTo: ['gala']}));
    await assertSucceeds(updateDoc(person('lead'), {invitedTo: ['gala']}));
    // The adult may still save the record while an invitation stands.
    await assertSucceeds(updateDoc(person('parent'), {optOuts: ['m2']}));
    await assertFails(updateDoc(person('parent'), {invitedTo: []}));
  });

  test('a linked adult cannot add someone already invited', async () => {
    await assertFails(setDoc(doc(as('parent'), `${E}/participants/new`), {
      name: 'Om', sortName: 'om', groupId: 'f1', isChild: true, createdBy: 'parent', status: 'active',
      invitedTo: ['gala'],
    }));
    await assertSucceeds(setDoc(doc(as('parent'), `${E}/participants/new`), {
      name: 'Om', sortName: 'om', groupId: 'f1', isChild: true, createdBy: 'parent', status: 'active',
      signUps: ['k1'],
    }));
  });

  test('someone outside the group sets nothing', async () => {
    await assertFails(updateDoc(person('plain'), {optOuts: ['m3']}));
  });

  test('times and lists must be well formed', async () => {
    await assertFails(updateDoc(person('owner'), {arrivalAt: 'Saturday'}));
    await assertFails(updateDoc(person('owner'), {optOuts: 'm3'}));
    await assertFails(updateDoc(person('owner'), {signUps: Array.from({length: 201}, (_, i) => `s${i}`)}));
    await assertFails(updateDoc(person('owner'), {
      arrivalAt: at('2027-07-18T00:00:00Z'), departureAt: at('2027-07-17T00:00:00Z'),
    }));
  });
});

describe('group invitations', () => {
  test('only participants.edit invites a group', async () => {
    await assertSucceeds(updateDoc(group('lead'), {invitedTo: ['reception'], updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(group('parent'), {invitedTo: ['reception', 'gala']}));
    await assertFails(updateDoc(group('lead'), {invitedTo: 'reception'}));
    // Invitations are the only change allowed outside the group callables.
    await assertFails(updateDoc(group('lead'), {invitedTo: [], name: 'Other'}));
  });
});

describe('policy', () => {
  test('a session may override the event\'s policy', async () => {
    const session = (attendance: unknown) => setDoc(doc(as('owner'), `${E}/sessions/k1`), {
      title: 'Kids activities', startAt: at('2027-07-17T18:30:00Z'), endAt: null, timeTbc: false,
      venueId: null, locationTba: false, type: null, tags: [], capacity: null,
      eligibility: {categoryIds: ['child'], filterTags: []}, hidden: false,
      attendance, updatedBy: 'owner', updatedAt: serverTimestamp(),
    });
    await assertSucceeds(session('bySession'));
    await assertSucceeds(session(null));
    await assertFails(session('sometimes'));
  });

  test('the event\'s policy is one of the four', async () => {
    await assertSucceeds(updateDoc(doc(as('owner'), E), {settings: {attendancePolicy: 'arrivalToDeparture'}}));
    await assertFails(updateDoc(doc(as('owner'), E), {settings: {attendancePolicy: 'maybe'}}));
  });
});
