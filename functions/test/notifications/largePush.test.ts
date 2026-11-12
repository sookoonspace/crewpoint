/**
 * Req 61a (GE-09): a large push reads recipients in batches, not one read
 * per person, and fits the trigger's 30-second limit at 2,000 recipients,
 * measured on the emulator with a mocked transport. 5,000 is measured and
 * recorded for Stage 3's message queue.
 */
import {DocumentReference, Firestore} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {commitInChunks, BatchOperation} from '../../src/utils/batch';

const sent: number[] = [];
jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({
    sendEach: async (messages: unknown[]) => {
      sent.push(messages.length);
      return {responses: messages.map(() => ({success: true}))};
    },
  }),
}));

getAdminApp();
// eslint-disable-next-line @typescript-eslint/no-var-requires
const {sendCategorizedPush} = require('../../src/notifications/sendPush');

const db = () => getAdminDb();
const TRIGGER_LIMIT_MS = 30_000;

async function seedRecipients(count: number): Promise<string[]> {
  const uids = Array.from({length: count}, (_, i) => `u${i}`);
  const ops: BatchOperation[] = [];
  for (const [i, uid] of uids.entries()) {
    ops.push({
      type: 'set',
      ref: db().doc(`users/${uid}/private/profile`),
      data: {
        fcmTokens: [`token-${uid}`],
        // Every tenth person turned this kind of push off.
        notificationPrefs: i % 10 === 0 ? {eventUpdates: false} : {},
      },
    });
    // Every twentieth muted the event.
    if (i % 20 === 1) {
      ops.push({
        type: 'set',
        ref: db().doc(`users/${uid}/eventMutes/e1`),
        data: {mutedUntil: '2999-01-01T00:00:00Z'},
      });
    }
  }
  await commitInChunks(ops);
  return uids;
}

async function measure(count: number) {
  await clearFirestoreEmulator();
  sent.length = 0;
  const uids = await seedRecipients(count);
  const singleReads = jest.spyOn(DocumentReference.prototype, 'get');
  const batchReads = jest.spyOn(Firestore.prototype, 'getAll');
  const started = Date.now();
  const result = await sendCategorizedPush({
    category: 'member_joined',
    recipientUids: uids,
    eventId: 'e1',
    title: 'New member',
    body: 'Someone joined',
    deepLink: '/dashboard/event/e1',
  });
  const ms = Date.now() - started;
  const reads = {single: singleReads.mock.calls.length, batches: batchReads.mock.calls.length};
  singleReads.mockRestore();
  batchReads.mockRestore();
  // eslint-disable-next-line no-console
  console.log(`GE-09 push to ${count}: ${ms} ms, ${reads.batches} batched reads, ` +
    `${reads.single} single reads, ${result.attempted} sent, ${result.skipped} skipped`);
  return {ms, reads, result};
}

describe('large pushes', () => {
  test('GE-09 2,000 recipients are read in batches and fit the time limit', async () => {
    const {ms, reads, result} = await measure(2000);
    expect(reads.single).toBe(0);
    // Preferences and mutes, a few hundred people at a time.
    expect(reads.batches).toBeLessThanOrEqual(2 * Math.ceil(2000 / 300));
    expect(result.skipped).toBe(200 + 100);
    expect(result.attempted).toBe(1700);
    expect(sent.reduce((a, b) => a + b, 0)).toBe(1700);
    expect(ms).toBeLessThan(TRIGGER_LIMIT_MS);
  }, 120_000);

  test('GE-09 5,000 recipients are measured for the record', async () => {
    const {ms, reads} = await measure(5000);
    expect(reads.single).toBe(0);
    // Recorded rather than required: Stage 3's queue takes over beyond this.
    expect(ms).toBeGreaterThan(0);
  }, 300_000);
});
