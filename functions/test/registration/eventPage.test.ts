/**
 * Spec #233 Req 10, 13a, 14, 69 (#240): the public event page, found only
 * by its slug, for visitors who are not signed in, rate limited by address,
 * and its server-rendered first page.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {getEventPage, eventPageHtml, renderEventPage, PAGE_OPENS_PER_MINUTE} =
  require('../../src/registration/eventPage');
const {claimEventSlug} = require('../../src/registration/registrationSettings');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt-secret-id';
const db = () => getAdminDb();

async function seed(over: object = {}) {
  await db().doc(`events/${E}`).set({
    title: 'Convention 2027', description: 'Three days in Chicago.', status: 'published',
    templateId: 'convention', creatorId: 'owner', adminIds: ['owner'], memberIds: ['owner', 'sam'],
    startDate: Timestamp.fromMillis(Date.UTC(2027, 6, 16)), endDate: Timestamp.fromMillis(Date.UTC(2027, 6, 18)),
    dateOnly: true, timeZone: 'America/Chicago', capacity: 2, currency: 'USD',
    venues: [{id: 'v', name: 'Hall <A>', address: '1 Main St', mapUrl: '', directions: ''}],
    ...over,
  });
  await db().doc(`events/${E}/members/owner`).set({
    uid: 'owner', roleIds: ['owner'], permissions: computePermissions(['owner'], {}),
  });
  await ftest.wrap(claimEventSlug)({auth: {uid: 'owner'}, data: {eventId: E, slug: 'convention-2027'}});
}

let address = 0;
const open = (slug: string, ip = `10.0.0.${++address}`, auth?: object) =>
  ftest.wrap(getEventPage)({
    data: {slug}, ...(auth ? {auth} : {}),
    rawRequest: {headers: {'x-forwarded-for': `${ip}, 130.211.0.1`}, ip},
  });

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('getEventPage', () => {
  test('a visitor who is not signed in sees the public fields, by slug', async () => {
    await seed();
    const page = await open('Convention-2027');
    expect(page).toEqual(expect.objectContaining({
      state: 'open', title: 'Convention 2027', timeZone: 'America/Chicago',
      mode: 'open', placesRemain: true, slug: 'convention-2027',
    }));
    const text = JSON.stringify(page);
    for (const hidden of [E, 'owner', 'sam', 'USD']) expect(text).not.toContain(hidden);
  });

  test('a signed-in visitor sees the same', async () => {
    await seed();
    expect((await open('convention-2027', '10.1.1.1', {uid: 'someone'})).title).toBe('Convention 2027');
  });

  test('a full event says so without a number', async () => {
    await seed();
    await db().doc(`events/${E}/registrationTally/current`).set({placesUsed: 2});
    const page = await open('convention-2027');
    expect(page.placesRemain).toBe(false);
  });

  test('a draft says only that it is not open yet', async () => {
    await seed({status: 'draft'});
    expect(await open('convention-2027')).toEqual({state: 'notOpen'});
  });

  test('an ended or archived event has closed', async () => {
    await seed({status: 'ended'});
    expect((await open('convention-2027')).state).toBe('closed');
    await db().doc(`events/${E}`).update({status: 'archived'});
    expect((await open('convention-2027')).state).toBe('closed');
  });

  test('an unknown name, or one the event gave up, is not found', async () => {
    await seed();
    await expect(open('nobody-here')).rejects.toEqual(expect.objectContaining({code: 'not-found'}));
    await expect(open('a b')).rejects.toEqual(expect.objectContaining({code: 'not-found'}));
    await ftest.wrap(claimEventSlug)({auth: {uid: 'owner'}, data: {eventId: E, slug: 'renamed-event'}});
    await expect(open('convention-2027')).rejects.toEqual(expect.objectContaining({code: 'not-found'}));
    expect((await open('renamed-event')).title).toBe('Convention 2027');
  });

  test('about 60 opens a minute from one address, then "try again in a few minutes"', async () => {
    await seed();
    for (let i = 0; i < PAGE_OPENS_PER_MINUTE; i++) await open('convention-2027', '10.9.9.9');
    await expect(open('convention-2027', '10.9.9.9')).rejects.toEqual(expect.objectContaining({
      code: 'resource-exhausted', message: 'Please try again in a few minutes.', details: {reason: 'rateLimited'},
    }));
    // Another address is not held back.
    expect((await open('convention-2027', '10.9.9.8')).state).toBe('open');
    // No address is stored.
    const counts = await db().collection('rateLimits').get();
    expect(JSON.stringify(counts.docs.map((d) => d.id))).not.toContain('10.9.9.9');
  }, 120000);
});

describe('the server-rendered first page (Req 69)', () => {
  const response = () => {
    const res: any = {headers: {} as Record<string, string>, code: 0, body: ''};
    res.set = (k: string, v: string) => { res.headers[k] = v; return res; };
    res.status = (c: number) => { res.code = c; return res; };
    res.send = (b: unknown) => { res.body = b; return res; };
    return res;
  };
  const get = async (path: string) => {
    const res = response();
    await eventPageHtml({path, headers: {'x-forwarded-host': 'crewpoint-dev.web.app', 'x-forwarded-for': `10.5.0.${++address}`}} as any, res);
    return res;
  };

  test('shows the title, dates, place, Register and link-preview tags, then loads the app', async () => {
    await seed({cover: {path: `events/${E}/cover.jpg`, updatedAt: Timestamp.now()}});
    const res = await get('/e/convention-2027');
    expect(res.code).toBe(200);
    expect(res.headers['Content-Type']).toContain('text/html');
    expect(res.headers['Cache-Control']).toContain('s-maxage=60');
    const html: string = res.body;
    expect(html).toContain('<h1>Convention 2027</h1>');
    expect(html).toContain('Fri, Jul 16, 2027 – Sun, Jul 18, 2027');
    // Escaped, so an organizer's text cannot add markup.
    expect(html).toContain('Hall &lt;A&gt;');
    expect(html).toContain('href="/e/convention-2027/register">Register</a>');
    expect(html).toContain('<meta property="og:title" content="Convention 2027">');
    expect(html).toContain('content="https://crewpoint-dev.web.app/e/convention-2027/cover.jpg"');
    expect(html).toContain('<script src="flutter_bootstrap.js" async></script>');
    expect(html).toContain('id="cp-ssr"');
    expect(html).not.toContain(E);
  });

  test('a draft, or an unknown name, gets the plain app shell and no details', async () => {
    await seed({status: 'draft'});
    for (const path of ['/e/convention-2027', '/e/nobody-here']) {
      const html: string = (await get(path)).body;
      expect(html).not.toContain('Convention 2027');
      expect(html).toContain('noindex');
      expect(html).toContain('flutter_bootstrap.js');
    }
  });

  test('a draft never shows its cover', async () => {
    await seed({status: 'draft', cover: {path: `events/${E}/cover.jpg`, updatedAt: Timestamp.now()}});
    expect((await get('/e/convention-2027/cover.jpg')).code).toBe(404);
  });

  test('an invited event has no Register on its first page', () => {
    const html: string = renderEventPage({
      view: {
        state: 'open', slug: 's', title: 'Shah wedding', description: '', startDate: null, endDate: null,
        dateOnly: true, timeZone: 'UTC', venues: [], included: null, deadline: null, mode: 'invited',
        placesRemain: true, hasCover: false, labels: {},
      },
      slug: 's', origin: 'https://x',
    });
    expect(html).toContain('Shah wedding');
    expect(html).not.toContain('Register');
  });
});
