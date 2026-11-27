/**
 * Spec #233 Req 32, 32a, 34, 52, TD 11 (#248): waitlist offers that hold
 * places, Accept and No thanks, expiry every 15 minutes, organizer
 * actions, no automatic offers after the deadline, and the nightly recount.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';
import {clock} from '../../src/utils/clock';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {submitRegistration} = require('../../src/registration/submitRegistration');
const {cancelRegistration} = require('../../src/registration/cancelRegistration');
const {respondToOffer, manageOffer, getWaitlist, runOfferExpiry, recountTally, offerOnwardNow,
  onCapacityRaised, nightlyUpkeep, capacityRaised} =
  require('../../src/registration/offers');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const SLUG = 'convention-2027';
const HOUR = 3600_000;
const DAY = 24 * HOUR;
const db = () => getAdminDb();
const rejected = (code: string, reason?: string) =>
  expect.objectContaining({code, ...(reason ? {details: expect.objectContaining({reason})} : {})});
const realNow = clock.now;

async function seed({capacity = 2, deadline = Date.now() + 30 * DAY} = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', status: 'published', templateId: 'convention', creatorId: 'owner',
    adminIds: ['owner'], memberIds: ['owner', 'pia'], memberCount: 2, capacity, timeZone: 'America/Chicago',
    startDate: new Date(Date.UTC(2027, 6, 16)), dateOnly: true,
    settings: {
      categories: [{id: 'adult', name: 'Adult', minAge: 18}],
      registration: {
        mode: 'open', slug: SLUG, deadline, sections: [], offerHours: 72, registrationRoleId: 'participant',
        blocks: {people: true, ageOnly: false, stay: false, sessionChoices: false, waivers: false, contact: true},
      },
    },
  });
  await db().doc(`eventSlugs/${SLUG}`).set({eventId: E});
  for (const [uid, roleIds] of [['owner', ['owner']], ['pia', ['participant']]] as const) {
    await db().doc(`events/${E}/members/${uid}`).set({uid, roleIds, crewIds: [], permissions: computePermissions([...roleIds], {})});
  }
}

const register = (uid: string, n: number) => ftest.wrap(submitRegistration)({auth: {uid}, data: {
  slug: SLUG, submissionId: `s-${uid}`, contact: {email: `${uid}@example.com`},
  people: Array.from({length: n}, (_, i) => ({name: `${uid} ${i + 1}`, birthDate: '1980-01-01'})),
}});
const respond = (uid: string, accept: boolean) =>
  ftest.wrap(respondToOffer)({auth: {uid}, data: {slug: SLUG, accept}});
const manage = (data: object, uid = 'owner') => ftest.wrap(manageOffer)({auth: {uid}, data: {eventId: E, ...data}});
const reg = async (uid: string) =>
  (await db().collection(`events/${E}/registrations`).where('contactUid', '==', uid).get()).docs[0];
const tally = async () => (await db().doc(`events/${E}/registrationTally/current`).get()).data()!;
const mail = async (template: string) =>
  (await db().collection('mailOutbox').where('template', '==', template).get()).docs.map((d) => d.data());

/** Asha (2) fills the event; Big (3) and Ravi (1) wait, in that order. */
async function fullEvent(options = {}) {
  await seed(options);
  await register('asha', 2);
  await register('big', 3);
  await register('ravi', 1);
}

beforeEach(() => clearFirestoreEmulator());
afterEach(() => {
  clock.now = realNow;
});
afterAll(() => ftest.cleanup());

describe('waitlist offers', () => {
  test('Req 32, 34: freed places go to the first group that fits; a larger one keeps its number', async () => {
    await fullEvent();
    expect((await reg('big')).data()).toEqual(expect.objectContaining({status: 'waitlisted', waitlistPosition: 1}));
    await ftest.wrap(cancelRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    const ravi = (await reg('ravi')).data();
    expect(ravi.status).toBe('waitlisted');
    expect(ravi.offer.expiresAt - ravi.offer.offeredAt).toBe(72 * HOUR);
    expect((await reg('big')).data().waitlistPosition).toBe(1);
    expect((await reg('big')).data().offer).toBeUndefined();
    const t = await tally();
    expect(t.placesUsed).toBe(0);
    expect(t.offers).toEqual([expect.objectContaining({registrationId: (await reg('ravi')).id, size: 1})]);
    const [offerMail] = await mail('registrationOffer');
    expect(offerMail).toEqual(expect.objectContaining({to: 'ravi@example.com', push: true}));
    expect(offerMail.data.until).toMatch(/CST|CDT/);
    expect((await db().doc(`offerQueue/${E}`).get()).data()!.nextExpiry).toBe(ravi.offer.expiresAt);
  });

  test('accepting makes the registration submitted, a member, and sends the confirmation', async () => {
    await fullEvent();
    await ftest.wrap(cancelRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    expect(await respond('ravi', true)).toEqual({status: 'submitted'});
    const r = (await reg('ravi')).data();
    expect(r).toEqual(expect.objectContaining({status: 'submitted', offer: null, waitlistPosition: null}));
    expect((await tally())).toEqual(expect.objectContaining({placesUsed: 1, offers: []}));
    expect((await db().doc(`events/${E}/members/ravi`).get()).data()!.roleIds).toEqual(['participant']);
    expect((await mail('registrationConfirmation')).map((m) => m.to)).toContain('ravi@example.com');
    expect((await db().doc(`offerQueue/${E}`).get()).exists).toBe(false);
    // Nothing left to accept.
    await expect(respond('ravi', true)).rejects.toEqual(rejected('failed-precondition', 'noOffer'));
  });

  test('No thanks takes the group off the waitlist and offers the places onward at once', async () => {
    await seed({capacity: 2});
    await register('asha', 2);
    await register('ravi', 1);
    await register('mina', 1);
    await ftest.wrap(cancelRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    // Both fit in the two freed places: two offers open at once.
    expect((await tally()).offers).toHaveLength(2);
    await respond('ravi', false);
    expect((await reg('ravi')).data()).toEqual(expect.objectContaining({status: 'cancelled', cancelReason: 'declinedOffer'}));
    const people = (await db().collection(`events/${E}/participants`).where('registrationId', '==', (await reg('ravi')).id).get());
    expect(people.docs.every((d) => d.data().registrationStatus === 'cancelled')).toBe(true);
    expect((await tally()).offers.map((o: {registrationId: string}) => o.registrationId)).toEqual([(await reg('mina')).id]);
  });

  test('an offer that runs out sends the group to the end of the queue, emails it, and offers onward', async () => {
    await fullEvent({capacity: 2});
    await register('zed', 1);
    await ftest.wrap(cancelRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    // Ravi and Zed (1 each) are offered the 2 places; Big (3) waits.
    const raviOffer = (await reg('ravi')).data().offer;
    expect(await runOfferExpiry(db(), raviOffer.expiresAt - 1)).toBe(0);
    expect(await runOfferExpiry(db(), raviOffer.expiresAt + 1)).toBe(2);
    const ravi = (await reg('ravi')).data();
    expect(ravi.status).toBe('waitlisted');
    expect(ravi.waitlistPosition).toBeGreaterThan((await reg('big')).data().waitlistPosition);
    // Offered again, from the end of the queue, at the time of the expiry.
    expect(ravi.offer.offeredAt).toBe(raviOffer.expiresAt + 1);
    expect((await mail('registrationOfferExpired')).map((m) => m.to).sort())
      .toEqual(['ravi@example.com', 'zed@example.com']);
    // The places went onward: Big still doesn't fit, so Ravi and Zed are offered again from the end.
    expect((await tally()).offers).toHaveLength(2);
    await expect(respond('ravi', true)).resolves.toEqual({status: 'submitted'});
  });

  test('a late Accept is refused as expired', async () => {
    await fullEvent();
    await ftest.wrap(cancelRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    const offer = (await reg('ravi')).data().offer;
    clock.now = () => offer.expiresAt + 1;
    await expect(respond('ravi', true)).rejects.toEqual(rejected('failed-precondition', 'expired'));
  });

  test('accepting racing the expiry leaves one outcome and a true tally', async () => {
    await fullEvent();
    await ftest.wrap(cancelRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    const offer = (await reg('ravi')).data().offer;
    clock.now = () => offer.expiresAt - 1;
    const [accepted] = await Promise.allSettled([respond('ravi', true), runOfferExpiry(db(), offer.expiresAt + 1)]);
    const r = (await reg('ravi')).data();
    const counted = (await db().collection(`events/${E}/participants`)
      .where('registrationStatus', 'in', ['submitted', 'pending']).get()).size;
    expect((await tally()).placesUsed).toBe(counted);
    if (accepted.status === 'fulfilled') {
      expect(r.status).toBe('submitted');
    } else {
      expect(r.status).toBe('waitlisted');
      expect(counted).toBe(0);
    }
  });

  test('organizers withdraw, extend and offer by hand, with registrations.manage', async () => {
    await fullEvent({capacity: 3});
    // With 3 places, Asha (2) and Ravi (1) are in and Big (3) waits.
    const big = await reg('big');
    await expect(manage({registrationId: big.id, action: 'offer'})).rejects.toEqual(rejected('failed-precondition', 'noRoom'));
    await ftest.wrap(cancelRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    await ftest.wrap(cancelRegistration)({auth: {uid: 'ravi'}, data: {slug: SLUG}});
    const offered = (await reg('big')).data().offer;
    expect(offered).toBeTruthy();
    await expect(manage({registrationId: big.id, action: 'withdraw'}, 'pia')).rejects.toEqual(rejected('permission-denied'));
    await manage({registrationId: big.id, action: 'extend', hours: 24});
    expect((await reg('big')).data().offer.expiresAt).toBe(offered.expiresAt + 24 * HOUR);
    await manage({registrationId: big.id, action: 'withdraw'});
    expect((await reg('big')).data()).toEqual(expect.objectContaining({offer: null, waitlistPosition: 1}));
    expect((await tally()).offers).toEqual([]);
    await manage({registrationId: big.id, action: 'offer'});
    expect((await tally()).offers).toHaveLength(1);
    const log = (await big.ref.collection('changes').get()).docs.map((d) => d.data().action);
    expect(log).toEqual(expect.arrayContaining(['offerExtended', 'offerWithdrawn', 'offerMade']));
  });

  test('no automatic offers after the deadline; an organizer may still offer by hand', async () => {
    await fullEvent();
    await db().doc(`events/${E}`).update({'settings.registration.deadline': Date.now() - DAY});
    await db().doc(`events/${E}/registrationTally/current`).update({placesUsed: 0});
    expect(await offerOnwardNow(db(), E)).toEqual([]);
    await manage({registrationId: (await reg('ravi')).id, action: 'offer'});
    expect((await tally()).offers).toHaveLength(1);
  });

  test('a lower capacity removes nobody, and offers nothing while over', async () => {
    await fullEvent();
    await db().doc(`events/${E}`).update({capacity: 1});
    expect(await offerOnwardNow(db(), E)).toEqual([]);
    expect((await reg('asha')).data().status).toBe('submitted');
    expect((await tally()).placesUsed).toBe(2);
  });

  test('TD 11: the nightly recount corrects drift and logs it', async () => {
    await fullEvent();
    await db().doc(`events/${E}/registrationTally/current`).update({
      placesUsed: 9, offers: [{registrationId: 'gone', size: 1, offeredAt: 0, expiresAt: 1}],
    });
    expect(await recountTally(db(), E)).toBe(true);
    expect(await tally()).toEqual(expect.objectContaining({placesUsed: 2, offers: []}));
    const [fix] = (await db().collection(`events/${E}/registrationTally/current/corrections`).get()).docs.map((d) => d.data());
    expect(fix).toEqual(expect.objectContaining({placesUsed: {from: 9, to: 2}, offersDropped: ['gone']}));
    expect(await recountTally(db(), E)).toBe(false);
  });

  test('getWaitlist lists the queue with open offers and the places, for registrations.manage', async () => {
    await fullEvent();
    await db().doc(`events/${E}`).update({capacity: 1});
    const view = await ftest.wrap(getWaitlist)({auth: {uid: 'owner'}, data: {eventId: E}});
    expect(view).toEqual(expect.objectContaining({capacity: 1, placesUsed: 2, held: 0, timeZone: 'America/Chicago'}));
    expect(view.waiting.map((w: {groupName: string; size: number; position: number}) => [w.size, w.position]))
      .toEqual([[3, 1], [1, 2]]);
    await expect(ftest.wrap(getWaitlist)({auth: {uid: 'pia'}, data: {eventId: E}}))
      .rejects.toEqual(rejected('permission-denied'));
    // my registration shows an open offer's expiry.
    await db().doc(`events/${E}`).update({capacity: 2});
    await ftest.wrap(cancelRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    /* eslint-disable-next-line @typescript-eslint/no-var-requires */
    const {getMyRegistration} = require('../../src/registration/myRegistration');
    const mine = await ftest.wrap(getMyRegistration)({auth: {uid: 'ravi'}, data: {slug: SLUG}});
    expect(mine.registration.offerExpiresAt).toBe((await reg('ravi')).data().offer.expiresAt);
    const after = await ftest.wrap(getWaitlist)({auth: {uid: 'owner'}, data: {eventId: E}});
    expect(after.waiting.find((w: {size: number}) => w.size === 1).offerExpiresAt).toEqual(expect.any(Number));
    expect(after.held).toBe(1);
  });

  test('capacityRaised: up or removed frees places; down, same or newly set does not', () => {
    expect(capacityRaised(1, 5)).toBe(true);
    expect(capacityRaised(5, null)).toBe(true);
    expect(capacityRaised(5, 5)).toBe(false);
    expect(capacityRaised(5, 3)).toBe(false);
    expect(capacityRaised(null, 5)).toBe(false);
  });

  test('raising capacity outside Registration settings offers the places at once', async () => {
    // As on dev: a limit of 1, a family of 2 waitlisted, then 5 set from Event settings.
    await seed({capacity: 1});
    await register('asha', 2);
    expect((await reg('asha')).data().status).toBe('waitlisted');
    const ref = db().doc(`events/${E}`);
    const before = await ref.get();
    await ref.update({capacity: 5});
    const after = await ref.get();
    await ftest.wrap(onCapacityRaised)({data: ftest.makeChange(before, after), params: {eventId: E}});
    expect((await reg('asha')).data().offer).toEqual(expect.objectContaining({expiresAt: expect.any(Number)}));
    expect((await tally()).offers).toHaveLength(1);
    await expect(respond('asha', true)).resolves.toEqual({status: 'submitted'});
    expect((await db().doc(`events/${E}/members/asha`).get()).exists).toBe(true);
  });

  test('the nightly upkeep offers places that every other path missed', async () => {
    await seed({capacity: 1});
    await register('asha', 2);
    await db().doc(`events/${E}`).update({capacity: 5});
    expect((await tally()).offers ?? []).toEqual([]);
    await nightlyUpkeep(db(), E);
    expect((await tally()).offers).toHaveLength(1);
  });

  test('#292 getMyWaitingRegistrations lists my waitlisted and pending registrations for home', async () => {
    /* eslint-disable-next-line @typescript-eslint/no-var-requires */
    const {getMyWaitingRegistrations} = require('../../src/registration/myRegistration');
    const mine = (uid: string) => ftest.wrap(getMyWaitingRegistrations)({auth: {uid}, data: {}});
    await fullEvent();
    expect((await mine('asha')).registrations).toEqual([]);
    const [ravi] = (await mine('ravi')).registrations;
    expect(ravi).toEqual(expect.objectContaining({
      eventId: E, slug: SLUG, title: 'Convention 2027', status: 'waitlisted', waitlistPosition: 2,
      offerExpiresAt: null, timeZone: 'America/Chicago', dateOnly: true,
    }));
    await ftest.wrap(cancelRegistration)({auth: {uid: 'asha'}, data: {slug: SLUG}});
    expect((await mine('ravi')).registrations[0].offerExpiresAt).toEqual(expect.any(Number));
    await respond('ravi', true);
    expect((await mine('ravi')).registrations).toEqual([]);
    await db().doc(`events/${E}`).update({status: 'ended'});
    expect((await mine('big')).registrations).toEqual([]);
  });
});
