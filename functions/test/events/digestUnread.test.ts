/**
 * Req 32: the daily digest counts unread chat only in events where the
 * person can read chat, so a Vendor or Observer is not nudged about it.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

getAdminApp();
// eslint-disable-next-line @typescript-eslint/no-var-requires
const {computeUserCounters} = require('../../src/events/onDigestSummary');

beforeEach(() => clearFirestoreEmulator());

async function seed(eventId: string, roleIds: string[]) {
  const db = getAdminDb();
  await db.doc(`events/${eventId}`).set({title: eventId, memberIds: ['sam']});
  await db.doc(`events/${eventId}/members/sam`).set({
    uid: 'sam', roleIds, permissions: computePermissions(roleIds, {}),
  });
  await db.doc(`events/${eventId}/messages/m`).set({
    senderId: 'x', text: 'Hi', timestamp: Timestamp.fromMillis(2000),
  });
  await db.doc(`users/sam/chatReads/${eventId}`).set({lastReadAt: Timestamp.fromMillis(1000)});
}

test('unread chat counts only where the person can read chat', async () => {
  await seed('fest', ['participant']);
  await seed('market', ['vendor']);
  const counters = await computeUserCounters(getAdminDb(), 'sam');
  expect(counters.unread).toBe(1);
});
