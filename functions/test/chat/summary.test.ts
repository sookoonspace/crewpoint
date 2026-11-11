/**
 * Req 57a: each event keeps a chat summary with the latest message, a
 * message count and when the last urgent message came, so the inbox never
 * loads every event's messages. The sender's own read marker moves with
 * their message, so it never shows as unread to them.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {summaryAfterCreate, summaryAfterDelete, ChatSummary} from '../../src/chat/summary';

getAdminApp();
// eslint-disable-next-line @typescript-eslint/no-var-requires
const {applyMessageCreated, applyMessageDeleted, applyMessageUpdated} = require('../../src/chat/summary');

const at = (minute: number) => Timestamp.fromDate(new Date(Date.UTC(2027, 6, 17, 12, minute)));
const msg = (id: string, minute: number, over: object = {}) => ({
  id, senderId: 'ana', text: id, timestamp: at(minute), isHighPriority: false, kind: null, ...over,
});

describe('summaryAfterCreate', () => {
  test('counts the message and keeps the newest as latest', () => {
    let s: ChatSummary = summaryAfterCreate(null, msg('m2', 2));
    s = summaryAfterCreate(s, msg('m1', 1));
    expect(s.count).toBe(2);
    expect(s.latest?.id).toBe('m2');
  });

  test('records the latest urgent message and who sent it', () => {
    const s = summaryAfterCreate(summaryAfterCreate(null, msg('m1', 1, {isHighPriority: true})), msg('m2', 2));
    expect(s.lastUrgentAt).toEqual(at(1));
    expect(s.lastUrgentSenderId).toBe('ana');
    expect(s.lastUrgentId).toBe('m1');
  });

  test('copies the text as written, so no amount appears that the message hides', () => {
    const s = summaryAfterCreate(null, msg('paid', 1, {kind: 'settlement', text: 'Ana paid Bo'}));
    expect(s.latest?.text).toBe('Ana paid Bo');
    expect(s.latest?.kind).toBe('settlement');
  });
});

describe('summaryAfterDelete', () => {
  test('uncounts it and takes the next newest as latest', () => {
    const s = summaryAfterCreate(summaryAfterCreate(null, msg('m1', 1)), msg('m2', 2));
    const after = summaryAfterDelete(s, 'm2', msg('m1', 1));
    expect(after.count).toBe(1);
    expect(after.latest?.id).toBe('m1');
  });

  test('clears the urgent mark when that message goes', () => {
    const s = summaryAfterCreate(null, msg('u', 1, {isHighPriority: true}));
    const after = summaryAfterDelete(s, 'u', null);
    expect(after).toEqual(expect.objectContaining({count: 0, latest: null, lastUrgentAt: null}));
  });
});

describe('on the emulator', () => {
  const db = () => getAdminDb();
  const E = 'events/e1';
  beforeEach(async () => {
    await clearFirestoreEmulator();
    await db().doc(E).set({title: 'Trip'});
  });
  const summary = async () => (await db().doc(`${E}/chatSummary/current`).get()).data();

  test('a new message updates the summary and the sender\'s read marker', async () => {
    await applyMessageCreated(db(), 'e1', msg('m1', 1));
    await applyMessageCreated(db(), 'e1', msg('m2', 2, {senderId: 'bo'}));
    const s = (await summary())!;
    expect(s.count).toBe(2);
    expect(s.latest.id).toBe('m2');
    const boRead = (await db().doc('users/bo/chatReads/e1').get()).data()!;
    expect(boRead.readCount).toBe(2);
    expect((boRead.lastReadAt as Timestamp).toMillis()).toBe(at(2).toMillis());
    const anaRead = (await db().doc('users/ana/chatReads/e1').get()).data()!;
    expect(anaRead.readCount).toBe(1);
  });

  test('a change to the latest message shows in the summary', async () => {
    await applyMessageCreated(db(), 'e1', msg('m1', 1));
    await applyMessageUpdated(db(), 'e1', msg('m1', 1, {text: 'edited'}));
    expect((await summary())!.latest.text).toBe('edited');
  });

  test('deleting the latest message falls back to the one before', async () => {
    await db().doc(`${E}/messages/m1`).set(msg('m1', 1));
    await applyMessageCreated(db(), 'e1', msg('m1', 1));
    await applyMessageCreated(db(), 'e1', msg('m2', 2));
    await applyMessageDeleted(db(), 'e1', 'm2');
    const s = (await summary())!;
    expect(s.count).toBe(1);
    expect(s.latest.id).toBe('m1');
  });
});
