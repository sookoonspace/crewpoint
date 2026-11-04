/**
 * Req 9, 63a (FND-03): events are created only through `createEvent`, with the
 * caller as Owner, so nobody can be listed as a member without their own action.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
// eslint-disable-next-line @typescript-eslint/no-var-requires
const {createEvent} = require('../../src/events/createEvent');

const call = (uid: string | null, data: object) =>
  ftest.wrap(createEvent)({auth: uid ? {uid} : undefined, data});
const input = (over: object = {}) => ({
  eventId: 'evt',
  title: 'Trip',
  description: 'A trip',
  eventType: 'trip',
  currency: 'EUR',
  startDate: '2027-03-01T10:00:00.000Z',
  ...over,
});
const eventDoc = () => getAdminDb().doc('events/evt').get();
const rejected = (code: string) => expect.objectContaining({code});

beforeEach(() => clearFirestoreEmulator());
afterAll(() => ftest.cleanup());

describe('createEvent', () => {
  test('creates the event with the caller as Owner', async () => {
    await call('me', input());
    const saved = (await eventDoc()).data()!;
    expect(saved.title).toBe('Trip');
    expect(saved.description).toBe('A trip');
    expect(saved.eventType).toBe('trip');
    expect(saved.currency).toBe('EUR');
    expect(saved.creatorId).toBe('me');
    expect(saved.adminIds).toEqual(['me']);
    expect(saved.memberIds).toEqual(['me']);
    expect(saved.status).toBe('active');
    expect(saved.id).toBe('evt');
    expect(saved.createdAt).toBeDefined();
    expect(saved.updatedAt).toBeDefined();
    expect(saved.startDate.toDate().toISOString()).toBe('2027-03-01T10:00:00.000Z');
    expect(saved.endDate).toBeNull();
  });

  test('a client cannot list anyone else, or choose an owner', async () => {
    await call('me', input({
      memberIds: ['me', 'stranger'],
      adminIds: ['stranger'],
      creatorId: 'stranger',
      status: 'archived',
    }));
    const saved = (await eventDoc()).data()!;
    expect(saved.memberIds).toEqual(['me']);
    expect(saved.adminIds).toEqual(['me']);
    expect(saved.creatorId).toBe('me');
    expect(saved.status).toBe('active');
  });

  test('needs only a title', async () => {
    await call('me', {eventId: 'evt', title: 'Trip'});
    const saved = (await eventDoc()).data()!;
    expect(saved.description).toBeNull();
    expect(saved.eventType).toBe('custom');
    expect(saved.currency).toBe('USD');
    expect(saved.startDate).toBeNull();
  });

  test('a retry after a lost response is safe', async () => {
    await call('me', input());
    await getAdminDb().doc('events/evt').update({memberIds: ['me', 'friend']});
    await call('me', input());
    expect((await eventDoc()).data()!.memberIds).toEqual(['me', 'friend']);
  });

  test("cannot take over someone else's event", async () => {
    await call('owner', input());
    await expect(call('me', input({title: 'Mine now'}))).rejects.toEqual(
      rejected('already-exists')
    );
    const saved = (await eventDoc()).data()!;
    expect(saved.creatorId).toBe('owner');
    expect(saved.title).toBe('Trip');
  });

  test('needs a signed-in caller', async () => {
    await expect(call(null, input())).rejects.toEqual(rejected('unauthenticated'));
  });

  test.each([
    ['a missing title', {title: undefined}],
    ['a blank title', {title: '   '}],
    ['a title that is not text', {title: 5}],
    ['a missing ID', {eventId: undefined}],
    ['an ID with a slash', {eventId: 'a/b'}],
    ['a description that is not text', {description: 5}],
    ['an invalid start date', {startDate: 'soon'}],
    ['an invalid end date', {endDate: 'later'}],
    ['a currency that is not a code', {currency: 'dollars'}],
    ['an event type that is not text', {eventType: 5}],
  ])('rejects %s, and leaves nothing behind', async (_name, over) => {
    await expect(call('me', input(over))).rejects.toEqual(rejected('invalid-argument'));
    expect((await eventDoc()).exists).toBe(false);
  });
});
