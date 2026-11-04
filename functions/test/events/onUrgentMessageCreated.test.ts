/**
 * Req 10 (FND-04): urgent sending is limited by permission and by a rate per
 * sender per event. Over the limit, the message stays but sends no urgent push.
 * Push goes through a mocked transport.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

const mockSendEach = jest.fn();
jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({sendEach: mockSendEach}),
}));

getAdminApp();
// eslint-disable-next-line @typescript-eslint/no-var-requires
const {handleUrgentMessage} = require('../../src/events/onUrgentMessageCreated');

const E = 'evt';
const HOUR = 60 * 60 * 1000;
const START = Date.UTC(2027, 0, 1, 12);

let nextId = 0;
async function urgent(sender: string, at: number, eventId = E, data: object = {}) {
  const ref = getAdminDb().doc(`events/${eventId}/messages/m${nextId++}`);
  const message = {senderId: sender, text: 'Fire', isHighPriority: true, ...data};
  await ref.set(message);
  await handleUrgentMessage({eventId, messageId: ref.id, data: message, ref, now: () => at});
  return ref;
}

async function seedEvent(eventId = E, over: object = {}) {
  await getAdminDb().doc(`events/${eventId}`).set({
    title: 'Trip',
    creatorId: 'owner',
    adminIds: ['owner', 'admin'],
    memberIds: ['owner', 'admin', 'member'],
    ...over,
  });
}

beforeEach(async () => {
  await clearFirestoreEmulator();
  mockSendEach.mockReset();
  mockSendEach.mockImplementation(async (m: unknown[]) => ({
    responses: m.map(() => ({success: true})),
  }));
  await seedEvent();
  for (const uid of ['owner', 'admin', 'member']) {
    await getAdminDb().doc(`users/${uid}/private/profile`).set({fcmTokens: [`tok-${uid}`]});
  }
});

describe('urgent push rate limit', () => {
  test('an urgent message pushes to the other members', async () => {
    const ref = await urgent('admin', START);
    expect(mockSendEach).toHaveBeenCalledTimes(1);
    expect((await ref.get()).data()!.urgentPushSkipped).toBeUndefined();
  });

  test('allows 5 in an hour by default', async () => {
    for (let i = 0; i < 5; i++) await urgent('admin', START + i);
    expect(mockSendEach).toHaveBeenCalledTimes(5);
  });

  test('the 6th in an hour is saved, sends no push, and is flagged', async () => {
    for (let i = 0; i < 5; i++) await urgent('admin', START + i);
    const sixth = await urgent('admin', START + 5);
    expect(mockSendEach).toHaveBeenCalledTimes(5);
    const saved = (await sixth.get()).data()!;
    expect(saved.text).toBe('Fire');
    expect(saved.isHighPriority).toBe(true);
    expect(saved.urgentPushSkipped).toBe(true);
  });

  test('the window slides, so a slot frees up after an hour', async () => {
    for (let i = 0; i < 5; i++) await urgent('admin', START + i);
    await urgent('admin', START + HOUR + 1);
    expect(mockSendEach).toHaveBeenCalledTimes(6);
  });

  test('a skipped message does not extend the wait', async () => {
    for (let i = 0; i < 5; i++) await urgent('admin', START + i);
    await urgent('admin', START + HOUR - 1);
    expect(mockSendEach).toHaveBeenCalledTimes(5);
    await urgent('admin', START + HOUR + 1);
    expect(mockSendEach).toHaveBeenCalledTimes(6);
  });

  test('the limit is per sender', async () => {
    for (let i = 0; i < 5; i++) await urgent('admin', START + i);
    await urgent('owner', START + 5);
    expect(mockSendEach).toHaveBeenCalledTimes(6);
  });

  test('the limit is per event', async () => {
    await seedEvent('other');
    for (let i = 0; i < 5; i++) await urgent('admin', START + i);
    await urgent('admin', START + 5, 'other');
    expect(mockSendEach).toHaveBeenCalledTimes(6);
  });

  test('an event setting changes the limit', async () => {
    await seedEvent(E, {settings: {urgentRatePerHour: 1}});
    await urgent('admin', START);
    const second = await urgent('admin', START + 1);
    expect(mockSendEach).toHaveBeenCalledTimes(1);
    expect((await second.get()).data()!.urgentPushSkipped).toBe(true);
  });

  test('an invalid setting falls back to the default', async () => {
    await seedEvent(E, {settings: {urgentRatePerHour: -1}});
    for (let i = 0; i < 5; i++) await urgent('admin', START + i);
    expect(mockSendEach).toHaveBeenCalledTimes(5);
  });

  test('a member without permission sends no push', async () => {
    await urgent('member', START);
    expect(mockSendEach).not.toHaveBeenCalled();
  });

  test('a normal message does nothing', async () => {
    const ref = await urgent('admin', START, E, {isHighPriority: false});
    expect(mockSendEach).not.toHaveBeenCalled();
    expect((await ref.get()).data()!.urgentPushSkipped).toBeUndefined();
  });
});
