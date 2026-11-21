/**
 * Spec #233 Req 51, 51a, 53, 54 and N-00, N-22: the outbox, the send
 * function, the delivery log, the dev allowed list and push alongside email.
 * Every send goes through the mock transport or the refusing default.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {enqueueEmail, MAIL_SETTINGS, normaliseEmail, OUTBOX} from '../../src/mail/outbox';
import {
  DELIVERY_OFF, NO_SENDER, NOT_ON_ALLOWED_LIST, PROD_PROJECT, TEST_ENVIRONMENT,
  blockedReason, defaultTransport, mailSettingsOf, processOutboxMessage,
} from '../../src/mail/send';
import {MockTransport, RefusingTransport, ResendTransport, isTestEnvironment} from '../../src/mail/transport';

getAdminApp();
const db = () => getAdminDb();
const DEV = 'crewpoint-dev';
const FROM = 'CrewPoint <no-reply@mail.example.org>';

async function settings(over: object = {}) {
  await db().doc(MAIL_SETTINGS).set({deliveryEnabled: true, from: FROM, allowedRecipients: ['owner@example.org'], ...over});
}
const log = async (id: string) => (await db().collection(OUTBOX).doc(id).get()).data()!;

beforeEach(async () => {
  await clearFirestoreEmulator();
});

describe('enqueueEmail', () => {
  test('writes a queued message with a normalised address', async () => {
    const id = await enqueueEmail(db(), {to: ' Owner@Example.ORG ', template: 'deliveryCheck', data: {name: 'A'}});
    const msg = await log(id);
    expect(msg).toMatchObject({to: 'owner@example.org', status: 'queued', attempts: 0, template: 'deliveryCheck', push: false});
  });

  test('refuses an address that is not an email', async () => {
    await expect(enqueueEmail(db(), {to: 'nope', template: 'deliveryCheck'})).rejects.toThrow();
    expect(normaliseEmail('a@b')).toBeNull();
  });
});

describe('processOutboxMessage', () => {
  test('sends through the transport in the recipient language and logs it as sent', async () => {
    await settings();
    await db().doc('users/u1').set({language: 'gu'});
    const transport = new MockTransport();
    const id = await enqueueEmail(db(), {to: 'owner@example.org', uid: 'u1', template: 'deliveryCheck', data: {name: 'Savita'}});
    expect(await processOutboxMessage(db(), id, {transport, projectId: DEV})).toBe('sent');
    expect(transport.sent).toHaveLength(1);
    expect(transport.sent[0]).toMatchObject({to: 'owner@example.org', from: FROM, subject: 'CrewPoint ઇમેઇલ તપાસ', messageId: id});
    expect(await log(id)).toMatchObject({status: 'sent', providerId: 'mock-1', attempts: 1});
  });

  test('uses the event words', async () => {
    await settings();
    await db().doc('events/e1').set({title: 'E', labels: {group: {one: 'Family', other: 'Families'}}});
    const transport = new MockTransport();
    const id = await enqueueEmail(db(), {to: 'owner@example.org', eventId: 'e1', template: 'deliveryCheck', data: {name: 'A'}});
    await processOutboxMessage(db(), id, {transport, projectId: DEV});
    expect(transport.sent[0].text).toContain('your family');
  });

  test('outside prod, emails only the allowed list', async () => {
    await settings();
    const transport = new MockTransport();
    const id = await enqueueEmail(db(), {to: 'family@example.org', template: 'deliveryCheck', data: {name: 'A'}});
    expect(await processOutboxMessage(db(), id, {transport, projectId: DEV})).toBe('notSent');
    expect(transport.sent).toHaveLength(0);
    expect(await log(id)).toMatchObject({status: 'notSent', reason: NOT_ON_ALLOWED_LIST});
  });

  test('prod emails everyone, once delivery is on', async () => {
    await settings();
    const transport = new MockTransport();
    const id = await enqueueEmail(db(), {to: 'family@example.org', template: 'deliveryCheck', data: {name: 'A'}});
    expect(await processOutboxMessage(db(), id, {transport, projectId: PROD_PROJECT})).toBe('sent');
  });

  test('sends nothing until delivery is turned on, or without a sending address', async () => {
    const transport = new MockTransport();
    await settings({deliveryEnabled: false});
    const off = await enqueueEmail(db(), {to: 'owner@example.org', template: 'deliveryCheck', data: {name: 'A'}});
    await processOutboxMessage(db(), off, {transport, projectId: PROD_PROJECT});
    expect(await log(off)).toMatchObject({status: 'notSent', reason: DELIVERY_OFF});
    await settings({from: ''});
    const noFrom = await enqueueEmail(db(), {to: 'owner@example.org', template: 'deliveryCheck', data: {name: 'A'}});
    await processOutboxMessage(db(), noFrom, {transport, projectId: PROD_PROJECT});
    expect(await log(noFrom)).toMatchObject({status: 'notSent', reason: NO_SENDER});
    expect(transport.sent).toHaveLength(0);
  });

  test('missing settings mean nothing is sent', () => {
    expect(blockedReason('a@b.co', mailSettingsOf(undefined), PROD_PROJECT)).toBe(DELIVERY_OFF);
  });

  test('a provider failure is logged as failed with its reason', async () => {
    await settings();
    const transport = new MockTransport();
    transport.failWith = new Error('rate limited');
    const id = await enqueueEmail(db(), {to: 'owner@example.org', template: 'deliveryCheck', data: {name: 'A'}});
    expect(await processOutboxMessage(db(), id, {transport, projectId: DEV})).toBe('failed');
    expect(await log(id)).toMatchObject({status: 'failed', reason: 'rate limited'});
  });

  test('a money value fails the message before anything is sent', async () => {
    await settings();
    const transport = new MockTransport();
    const id = await enqueueEmail(db(), {to: 'owner@example.org', template: 'deliveryCheck', data: {name: 'A', amount: '150'}});
    expect(await processOutboxMessage(db(), id, {transport, projectId: DEV})).toBe('failed');
    expect(transport.sent).toHaveLength(0);
  });

  test('a message is handled once, even if the trigger repeats', async () => {
    await settings();
    const transport = new MockTransport();
    const id = await enqueueEmail(db(), {to: 'owner@example.org', template: 'deliveryCheck', data: {name: 'A'}});
    await Promise.all([
      processOutboxMessage(db(), id, {transport, projectId: DEV}),
      processOutboxMessage(db(), id, {transport, projectId: DEV}),
    ]);
    expect(transport.sent).toHaveLength(1);
  });

  test('pushes alongside a sent email to someone with the app', async () => {
    await settings();
    const push = jest.fn().mockResolvedValue({sent: 1});
    const id = await enqueueEmail(db(), {
      to: 'owner@example.org', uid: 'u1', eventId: 'e1', push: true, deepLink: '/e/x',
      template: 'deliveryCheck', data: {name: 'A'},
    });
    await processOutboxMessage(db(), id, {transport: new MockTransport(), projectId: DEV, push});
    expect(push).toHaveBeenCalledWith(expect.objectContaining({
      recipientUids: ['u1'], category: 'registration', eventId: 'e1', title: 'CrewPoint email check',
    }));
  });

  test('N-22: someone without an account or the app still gets the email', async () => {
    await settings();
    const push = jest.fn();
    const transport = new MockTransport();
    const id = await enqueueEmail(db(), {to: 'owner@example.org', eventId: 'e1', push: true, template: 'deliveryCheck', data: {name: 'A'}});
    expect(await processOutboxMessage(db(), id, {transport, projectId: DEV, push})).toBe('sent');
    expect(transport.sent).toHaveLength(1);
    expect(push).not.toHaveBeenCalled();
  });
});

describe('N-00: no real email can be sent from tests', () => {
  test('tests run in a test environment', () => {
    expect(isTestEnvironment()).toBe(true);
    expect(isTestEnvironment({GCLOUD_PROJECT: 'crewpoint-prod'})).toBe(false);
  });

  test('the default transport refuses to send', async () => {
    expect(defaultTransport()).toBeInstanceOf(RefusingTransport);
    await settings();
    const id = await enqueueEmail(db(), {to: 'owner@example.org', template: 'deliveryCheck', data: {name: 'A'}});
    expect(await processOutboxMessage(db(), id, {transport: defaultTransport(), projectId: PROD_PROJECT})).toBe('notSent');
    expect(await log(id)).toMatchObject({status: 'notSent', reason: TEST_ENVIRONMENT});
  });

  test('the Resend transport posts to the provider with an idempotency key', async () => {
    const fetchFn = jest.fn().mockResolvedValue({ok: true, status: 200, json: async () => ({id: 're_1'})});
    const resend = new ResendTransport('key', fetchFn as unknown as typeof fetch);
    const result = await resend.send({from: FROM, to: 'a@b.co', subject: 's', text: 't', html: 'h', messageId: 'm1'});
    expect(result.providerId).toBe('re_1');
    const [url, init] = fetchFn.mock.calls[0];
    expect(url).toBe('https://api.resend.com/emails');
    expect(init.headers).toMatchObject({'Authorization': 'Bearer key', 'Idempotency-Key': 'm1'});
  });

  test('a provider refusal throws with its status', async () => {
    const fetchFn = jest.fn().mockResolvedValue({ok: false, status: 422, json: async () => ({message: 'bad from'})});
    const resend = new ResendTransport('key', fetchFn as unknown as typeof fetch);
    await expect(resend.send({from: FROM, to: 'a@b.co', subject: 's', text: 't', html: 'h', messageId: 'm1'}))
      .rejects.toThrow('422');
  });
});
