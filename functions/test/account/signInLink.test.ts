/**
 * Spec #233 Req 12, 13a (#241): Register's email sign-in link, made by
 * Firebase and sent in CrewPoint's own words through the outbox, returning
 * only to the paths the app allows, and rate limited.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {sendSignInLink, safeReturn, linkDomainFor, LINKS_PER_EMAIL_PER_HOUR, LINKS_PER_ADDRESS_PER_HOUR} =
  require('../../src/account/signInLink');
/* eslint-enable @typescript-eslint/no-var-requires */

const db = () => getAdminDb();
let address = 0;
const send = (data: object, ip = `10.2.0.${++address}`) =>
  ftest.wrap(sendSignInLink)({data, rawRequest: {headers: {'x-forwarded-for': ip}, ip}});
const outbox = async () => (await db().collection('mailOutbox').get()).docs.map((d) => d.data());

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('sendSignInLink', () => {
  test('queues our own email with Firebase\'s link, which returns to the form', async () => {
    expect(await send({email: ' Asha@Example.com ', returnTo: '/e/convention-2027/register', language: 'gu'}))
      .toEqual({sent: true});
    const [mail] = await outbox();
    expect(mail).toEqual(expect.objectContaining({
      to: 'asha@example.com', template: 'signInLink', language: 'gu', status: 'queued',
    }));
    const link = new URL(mail.data.link);
    expect(link.searchParams.get('mode')).toBe('signIn');
    expect(link.searchParams.get('oobCode')).toBeTruthy();
    const next = new URL(link.searchParams.get('continueUrl')!);
    expect(next.host).toBe('crewpoint-dev.web.app');
    expect(next.pathname).toBe('/auth/link');
    expect(next.searchParams.get('to')).toBe('/e/convention-2027/register');
  });

  test('a visitor needs no account to ask', async () => {
    await send({email: 'new@example.com'});
    expect(await outbox()).toHaveLength(1);
  });

  test('refuses something that is not an email address', async () => {
    await expect(send({email: 'not-an-email'})).rejects.toEqual(
      expect.objectContaining({code: 'invalid-argument'}));
  });

  test('returns only to invite links, event pages and personal links', () => {
    expect(safeReturn('/e/x/register')).toBe('/e/x/register');
    expect(safeReturn('/r/abc')).toBe('/r/abc');
    expect(safeReturn('/join/ABC234')).toBe('/join/ABC234');
    for (const bad of ['/profile', 'https://evil.example/e/x', '//evil.example', '/e//evil', 42]) {
      expect(safeReturn(bad)).toBe('/');
    }
  });

  test('names a link domain only for a custom domain; dev and stg use the default one', () => {
    // Firebase refuses web.app and firebaseapp.com as a link domain, so dev
    // and stg links come on <project>.firebaseapp.com/__/auth/links.
    expect(linkDomainFor('crewpoint-dev')).toBeUndefined();
    expect(linkDomainFor('crewpoint-stg')).toBeUndefined();
    expect(linkDomainFor('demo-crewpoint')).toBeUndefined();
    expect(linkDomainFor('crewpoint-prod')).toBe('crewpoint.sookoon.space');
  });

  test('about 5 links an hour to one email, whatever the address', async () => {
    for (let i = 0; i < LINKS_PER_EMAIL_PER_HOUR; i++) await send({email: 'asha@example.com'});
    await expect(send({email: 'asha@example.com'})).rejects.toEqual(expect.objectContaining({
      code: 'resource-exhausted', details: {reason: 'rateLimited'},
    }));
    expect(await outbox()).toHaveLength(LINKS_PER_EMAIL_PER_HOUR);
  });

  test('about 10 links an hour from one address', async () => {
    for (let i = 0; i < LINKS_PER_ADDRESS_PER_HOUR; i++) await send({email: `p${i}@example.com`}, '10.7.7.7');
    await expect(send({email: 'another@example.com'}, '10.7.7.7')).rejects.toEqual(
      expect.objectContaining({code: 'resource-exhausted'}));
  });
});
