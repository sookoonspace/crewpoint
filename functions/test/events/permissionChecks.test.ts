/**
 * #66: every callable and trigger reads permissions from member documents,
 * not `creatorId` or `adminIds`. Each test uses a role that is not Owner or
 * Admin, so it passes only through the named permission.
 */
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from '../setup';
import {computePermissions} from '../../src/events/permissions';

const mockSendEach = jest.fn(async (m: unknown[]) => ({
  responses: m.map(() => ({success: true})), successCount: m.length, failureCount: 0,
}));
jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({sendEach: mockSendEach}),
}));

/* eslint-disable @typescript-eslint/no-var-requires */
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();
getAdminApp();
const {changeEventCurrency} = require('../../src/events/changeEventCurrency');
const {removeEventMember} = require('../../src/events/removeEventMember');
const {promoteToAdmin} = require('../../src/events/promoteToAdmin');
const {demoteAdmin} = require('../../src/events/demoteAdmin');
const {deleteEvent} = require('../../src/events/deleteEvent');
const {generateInviteCode} = require('../../src/events/generateInviteCode');
const {markTaskComplete} = require('../../src/events/markTaskComplete');
const {saveExpense} = require('../../src/events/saveExpense');
const {recordSettlement} = require('../../src/events/recordSettlement');
const {handleUrgentMessage} = require('../../src/events/onUrgentMessageCreated');
const {memberJoinedRecipients} = require('../../src/events/onMemberJoined');
/* eslint-enable @typescript-eslint/no-var-requires */

const E = 'evt';
const eventRef = () => getAdminDb().doc(`events/${E}`);
const rejected = (code: string) => expect.objectContaining({code});
const call = (fn: unknown, uid: string, data: object) =>
  ftest.wrap(fn)({auth: {uid}, data: {eventId: E, ...data}});

// Roles chosen so nobody but `owner` is in adminIds.
const people: Record<string, string[]> = {
  owner: ['owner'],
  coOwner: ['coOwner'],
  manager: ['custom'],
  finance: ['finance'],
  lead: ['crewLead'],
  plain: ['participant'],
  observer: ['observer'],
};
const customRole = {
  permissions: ['event.manage', 'members.manage'],
};

async function seed(over: object = {}) {
  await eventRef().set({
    title: 'Fest',
    status: 'published',
    currency: 'USD',
    creatorId: 'owner',
    adminIds: ['owner', 'coOwner'],
    memberIds: Object.keys(people),
    memberCount: Object.keys(people).length,
    ...over,
  });
  await eventRef().collection('roles').doc('custom').set({name: 'Manager', ...customRole});
  for (const [uid, roleIds] of Object.entries(people)) {
    await eventRef().collection('members').doc(uid).set({
      uid, roleIds, crewIds: [], participantId: null,
      permissions: computePermissions(roleIds, {custom: customRole}),
    });
  }
}

beforeEach(async () => {
  await clearFirestoreEmulator();
  mockSendEach.mockClear();
});
afterAll(() => ftest.cleanup());

describe('callables read permissions (#66)', () => {
  test('changeEventCurrency needs event.manage', async () => {
    await seed();
    await call(changeEventCurrency, 'manager', {currency: 'EUR'});
    expect((await eventRef().get()).data()!.currency).toBe('EUR');
    await expect(call(changeEventCurrency, 'lead', {currency: 'GBP'}))
      .rejects.toEqual(rejected('permission-denied'));
  });

  test('removeEventMember needs members.manage, and roles.manage to remove a manager', async () => {
    await seed();
    await expect(call(removeEventMember, 'lead', {targetUserId: 'plain'}))
      .rejects.toEqual(rejected('permission-denied'));
    await call(removeEventMember, 'manager', {targetUserId: 'plain'});
    expect((await eventRef().get()).data()!.memberIds).not.toContain('plain');
    await expect(call(removeEventMember, 'manager', {targetUserId: 'coOwner'}))
      .rejects.toEqual(rejected('permission-denied'));
    await call(removeEventMember, 'coOwner', {targetUserId: 'manager'});
    expect((await eventRef().get()).data()!.memberIds).not.toContain('manager');
  });

  test('promoting and demoting need roles.manage, which a Co-owner holds', async () => {
    await seed();
    await call(promoteToAdmin, 'coOwner', {targetUserId: 'plain'});
    expect((await eventRef().get()).data()!.adminIds).toContain('plain');
    await call(demoteAdmin, 'coOwner', {targetUserId: 'plain'});
    expect((await eventRef().get()).data()!.adminIds).not.toContain('plain');
    await expect(call(promoteToAdmin, 'manager', {targetUserId: 'plain'}))
      .rejects.toEqual(rejected('permission-denied'));
  });

  test('deleteEvent needs event.transfer, which only the Owner holds', async () => {
    await seed();
    await expect(call(deleteEvent, 'coOwner', {})).rejects.toEqual(rejected('permission-denied'));
    expect((await eventRef().get()).exists).toBe(true);
  });

  test('generateInviteCode needs members.manage', async () => {
    await seed();
    await expect(call(generateInviteCode, 'lead', {})).rejects.toEqual(rejected('permission-denied'));
    const result = await call(generateInviteCode, 'manager', {});
    expect(result.code).toHaveLength(6);
  });

  test('markTaskComplete: tasks.manage completes anyone\'s task', async () => {
    await seed();
    await eventRef().collection('tasks').doc('t').set({title: 'T', createdBy: 'plain', status: 'todo'});
    await call(markTaskComplete, 'lead', {taskId: 't'});
    expect((await eventRef().collection('tasks').doc('t').get()).data()!.status).toBe('done');
    await eventRef().collection('tasks').doc('t2').set({title: 'T', createdBy: 'lead', status: 'todo'});
    await expect(call(markTaskComplete, 'finance', {taskId: 't2'}))
      .rejects.toEqual(rejected('permission-denied'));
  });

  test('after an event ends, event.manage can still change tasks', async () => {
    await seed({status: 'ended'});
    await eventRef().collection('tasks').doc('t').set({title: 'T', createdBy: 'plain', status: 'todo'});
    await expect(call(markTaskComplete, 'plain', {taskId: 't'})).rejects.toEqual(rejected('failed-precondition'));
    await eventRef().collection('members').doc('manager').update({
      permissions: computePermissions(['custom'], {custom: {permissions: ['event.manage', 'tasks.manage']}}),
    });
    await call(markTaskComplete, 'manager', {taskId: 't'});
  });

  const expense = (over: object = {}) => ({
    expenseId: 'x', payerId: 'plain', amount: 10, description: 'Lunch', isDonation: false,
    splits: [{userId: 'plain', amount: 5}, {userId: 'lead', amount: 5}], ...over,
  });

  test('saveExpense: money.record edits anyone\'s expense, and Observer cannot add one', async () => {
    await seed();
    await call(saveExpense, 'plain', expense());
    await call(saveExpense, 'finance', expense({description: 'Fixed'}));
    expect((await eventRef().collection('expenses').doc('x').get()).data()!.description).toBe('Fixed');
    await expect(call(saveExpense, 'lead', expense({description: 'No'})))
      .rejects.toEqual(rejected('permission-denied'));
    await expect(call(saveExpense, 'observer', expense({
      expenseId: 'y', payerId: 'observer', splits: [{userId: 'observer', amount: 10}],
    }))).rejects.toEqual(rejected('permission-denied'));
  });

  test('recordSettlement: money.record records for someone who has left', async () => {
    await seed();
    await eventRef().collection('expenses').doc('old').set({
      payerId: 'gone', amount: 10, splits: [{userId: 'plain', amount: 10}], involvedUids: ['gone', 'plain'],
    });
    await call(recordSettlement, 'finance', {settlementId: 's1', payerId: 'plain', payeeId: 'gone', amount: 10});
    await expect(call(recordSettlement, 'lead', {settlementId: 's2', payerId: 'plain', payeeId: 'gone', amount: 1}))
      .rejects.toEqual(rejected('permission-denied'));
  });
});

describe('triggers read permissions (#66)', () => {
  test('an urgent message pushes only when the sender holds chat.urgent', async () => {
    await seed();
    await getAdminDb().doc('users/plain/private/profile').set({fcmTokens: ['tok-plain']});
    const send = async (senderId: string) => {
      const ref = eventRef().collection('messages').doc(senderId);
      const data = {senderId, text: 'Now', isHighPriority: true, timestamp: Timestamp.now()};
      await ref.set(data);
      await handleUrgentMessage({eventId: E, messageId: ref.id, data, ref});
    };
    await send('finance');
    expect(mockSendEach).not.toHaveBeenCalled();
    await send('lead');
    expect(mockSendEach).toHaveBeenCalled();
  });

  test('a new member is announced to members.manage holders', async () => {
    await seed();
    const recipients = await memberJoinedRecipients(eventRef(), 'plain');
    expect(recipients.sort()).toEqual(['coOwner', 'manager', 'owner']);
  });
});
