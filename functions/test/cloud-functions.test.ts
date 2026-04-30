/**
 * Cloud Function integration tests.
 *
 * Strategy: import the production callable from `functions/src/`, wrap
 * it with `firebase-functions-test` v3 (online mode — no init args), and
 * invoke it against the local Firestore emulator. Seed state via the
 * Admin SDK (also pointed at the emulator). Each test isolates state
 * via `clearFirestoreEmulator()` in `afterEach`.
 *
 * Prerequisites: `firebase emulators:exec --only firestore,auth`.
 */
import * as admin from 'firebase-admin';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from './setup';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();

// Eager-init the Admin SDK before importing CFs (which call
// admin.initializeApp() at module load).
getAdminApp();

// Imports must come AFTER getAdminApp() to avoid double-init.
/* eslint-disable @typescript-eslint/no-var-requires */
const {demoteAdmin} = require('../src/events/demoteAdmin');
const {promoteToAdmin} = require('../src/events/promoteToAdmin');
const {removeEventMember} = require('../src/events/removeEventMember');
const {joinEvent} = require('../src/events/joinEvent');
const {markTaskComplete} = require('../src/events/markTaskComplete');
const {generateInviteCode} = require('../src/events/generateInviteCode');
const {disputeSettlement} = require('../src/events/disputeSettlement');
const {deleteEvent} = require('../src/events/deleteEvent');
/* eslint-enable @typescript-eslint/no-var-requires */

afterEach(async () => {
  await clearFirestoreEmulator();
});

afterAll(() => {
  ftest.cleanup();
});

interface SeedEventOptions {
  eventId: string;
  creatorUid: string;
  memberUids?: string[];
  adminUids?: string[];
  title?: string;
}

async function seedEvent(opts: SeedEventOptions): Promise<void> {
  const memberIds = opts.memberUids ?? [opts.creatorUid];
  const adminIds = opts.adminUids ?? [opts.creatorUid];
  await getAdminDb()
    .collection('events')
    .doc(opts.eventId)
    .set({
      creatorId: opts.creatorUid,
      memberIds,
      adminIds,
      title: opts.title ?? 'Test Event',
    });
}

describe('callables — auth-failure case (no auth → unauthenticated)', () => {
  const cases: Array<[string, unknown, Record<string, unknown>]> = [
    ['demoteAdmin', demoteAdmin, {eventId: 'e', targetUserId: 'u'}],
    ['promoteToAdmin', promoteToAdmin, {eventId: 'e', targetUserId: 'u'}],
    ['removeEventMember', removeEventMember, {eventId: 'e', targetUserId: 'u'}],
    ['joinEvent', joinEvent, {joinCode: 'ABCDEF'}],
    ['markTaskComplete', markTaskComplete, {eventId: 'e', taskId: 't'}],
    ['generateInviteCode', generateInviteCode, {eventId: 'e'}],
    ['disputeSettlement', disputeSettlement, {eventId: 'e', settlementId: 's'}],
    ['deleteEvent', deleteEvent, {eventId: 'e'}],
  ];

  test.each(cases)(
    '%s rejects unauthenticated callers with "unauthenticated"',
    async (_name, fn, data) => {
      const wrapped = ftest.wrap(fn);
      await expect(wrapped({data})).rejects.toMatchObject({
        code: 'unauthenticated',
      });
    }
  );
});

describe('callables — invalid-argument when required fields are missing', () => {
  const cases: Array<[string, unknown, Record<string, unknown>]> = [
    ['demoteAdmin', demoteAdmin, {}],
    ['promoteToAdmin', promoteToAdmin, {eventId: 'e'}],
    ['removeEventMember', removeEventMember, {eventId: 'e'}],
    ['joinEvent', joinEvent, {}],
    ['markTaskComplete', markTaskComplete, {eventId: 'e'}],
    ['generateInviteCode', generateInviteCode, {}],
    ['disputeSettlement', disputeSettlement, {eventId: 'e'}],
    ['deleteEvent', deleteEvent, {}],
  ];

  test.each(cases)(
    '%s rejects missing-input requests with "invalid-argument"',
    async (_name, fn, data) => {
      const wrapped = ftest.wrap(fn);
      await expect(
        wrapped({auth: {uid: 'caller'}, data})
      ).rejects.toMatchObject({code: 'invalid-argument'});
    }
  );
});

describe('promoteToAdmin', () => {
  test('non-creator caller is rejected with permission-denied', async () => {
    await seedEvent({
      eventId: 'evtP1',
      creatorUid: 'creatorP1',
      memberUids: ['creatorP1', 'caller', 'target'],
      adminUids: ['creatorP1'],
    });

    const wrapped = ftest.wrap(promoteToAdmin);
    await expect(
      wrapped({
        auth: {uid: 'caller'},
        data: {eventId: 'evtP1', targetUserId: 'target'},
      })
    ).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('happy path: creator promotes a member to admin', async () => {
    await seedEvent({
      eventId: 'evtP2',
      creatorUid: 'creatorP2',
      memberUids: ['creatorP2', 'newAdmin'],
      adminUids: ['creatorP2'],
    });

    const wrapped = ftest.wrap(promoteToAdmin);
    const result = await wrapped({
      auth: {uid: 'creatorP2'},
      data: {eventId: 'evtP2', targetUserId: 'newAdmin'},
    });
    expect(result).toEqual({success: true});

    const after = await getAdminDb()
      .collection('events')
      .doc('evtP2')
      .get();
    expect(after.data()!.adminIds).toEqual(
      expect.arrayContaining(['creatorP2', 'newAdmin'])
    );
  });
});

describe('demoteAdmin', () => {
  test(
    'refuses to demote the last remaining admin with failed-precondition',
    async () => {
      await seedEvent({
        eventId: 'evtD1',
        creatorUid: 'creatorD1',
        memberUids: ['creatorD1', 'adminD1'],
        // Creator is NOT in adminIds — demoting adminD1 leaves zero admins.
        adminUids: ['adminD1'],
      });

      const wrapped = ftest.wrap(demoteAdmin);
      await expect(
        wrapped({
          auth: {uid: 'creatorD1'},
          data: {eventId: 'evtD1', targetUserId: 'adminD1'},
        })
      ).rejects.toMatchObject({code: 'failed-precondition'});
    }
  );

  test('non-creator caller rejected with permission-denied', async () => {
    await seedEvent({
      eventId: 'evtD2',
      creatorUid: 'creatorD2',
      memberUids: ['creatorD2', 'admin1', 'admin2'],
      adminUids: ['creatorD2', 'admin1', 'admin2'],
    });

    const wrapped = ftest.wrap(demoteAdmin);
    await expect(
      wrapped({
        auth: {uid: 'admin1'},
        data: {eventId: 'evtD2', targetUserId: 'admin2'},
      })
    ).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('happy path: creator demotes a non-creator admin', async () => {
    await seedEvent({
      eventId: 'evtD3',
      creatorUid: 'creatorD3',
      memberUids: ['creatorD3', 'admin1'],
      adminUids: ['creatorD3', 'admin1'],
    });

    const wrapped = ftest.wrap(demoteAdmin);
    const result = await wrapped({
      auth: {uid: 'creatorD3'},
      data: {eventId: 'evtD3', targetUserId: 'admin1'},
    });
    expect(result).toEqual({success: true});

    const after = await getAdminDb()
      .collection('events')
      .doc('evtD3')
      .get();
    expect(after.data()!.adminIds).toEqual(['creatorD3']);
  });
});

describe('joinEvent', () => {
  test('rejects missing code with not-found', async () => {
    const wrapped = ftest.wrap(joinEvent);
    await expect(
      wrapped({
        auth: {uid: 'caller'},
        data: {joinCode: 'NOEXIS'},
      })
    ).rejects.toMatchObject({code: 'not-found'});
  });

  test('rejects expired code with not-found and deletes the code', async () => {
    const code = 'EXP123';
    await getAdminDb().collection('event_invites').doc(code).set({
      eventId: 'someEvent',
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1000)),
    });

    const wrapped = ftest.wrap(joinEvent);
    await expect(
      wrapped({
        auth: {uid: 'caller'},
        data: {joinCode: code},
      })
    ).rejects.toMatchObject({code: 'not-found'});

    // Code should be deleted as a cleanup side effect.
    const after = await getAdminDb()
      .collection('event_invites')
      .doc(code)
      .get();
    expect(after.exists).toBe(false);
  });

  test('rejects missing target event with not-found', async () => {
    const code = 'MISS01';
    await getAdminDb().collection('event_invites').doc(code).set({
      eventId: 'eventDoesNotExist',
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 60_000)
      ),
    });

    const wrapped = ftest.wrap(joinEvent);
    await expect(
      wrapped({
        auth: {uid: 'caller'},
        data: {joinCode: code},
      })
    ).rejects.toMatchObject({code: 'not-found'});
  });

  test('happy path: caller joins event via valid code', async () => {
    await seedEvent({
      eventId: 'evtJ1',
      creatorUid: 'creatorJ1',
      memberUids: ['creatorJ1'],
      adminUids: ['creatorJ1'],
      title: 'Trip',
    });

    const code = 'JOINOK';
    await getAdminDb().collection('event_invites').doc(code).set({
      eventId: 'evtJ1',
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 60_000)
      ),
    });

    const wrapped = ftest.wrap(joinEvent);
    const result = await wrapped({
      auth: {uid: 'newMember'},
      data: {joinCode: code},
    });
    expect(result).toMatchObject({eventId: 'evtJ1'});

    const after = await getAdminDb()
      .collection('events')
      .doc('evtJ1')
      .get();
    expect(after.data()!.memberIds).toEqual(
      expect.arrayContaining(['creatorJ1', 'newMember'])
    );
  });
});

describe('removeEventMember', () => {
  test('non-admin/non-self caller rejected with permission-denied', async () => {
    await seedEvent({
      eventId: 'evtR1',
      creatorUid: 'creatorR1',
      memberUids: ['creatorR1', 'admin1', 'victim'],
      adminUids: ['creatorR1', 'admin1'],
    });

    const wrapped = ftest.wrap(removeEventMember);
    await expect(
      wrapped({
        auth: {uid: 'victim'},
        data: {eventId: 'evtR1', targetUserId: 'admin1'},
      })
    ).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('happy path: admin removes another member', async () => {
    await seedEvent({
      eventId: 'evtR2',
      creatorUid: 'creatorR2',
      memberUids: ['creatorR2', 'adminR2', 'memberR2'],
      adminUids: ['creatorR2', 'adminR2'],
    });

    const wrapped = ftest.wrap(removeEventMember);
    const result = await wrapped({
      auth: {uid: 'adminR2'},
      data: {eventId: 'evtR2', targetUserId: 'memberR2'},
    });
    expect(result).toEqual({success: true});

    const after = await getAdminDb()
      .collection('events')
      .doc('evtR2')
      .get();
    expect(after.data()!.memberIds).not.toContain('memberR2');
  });
});

describe('markTaskComplete', () => {
  test('non-admin/non-assignee caller rejected with permission-denied', async () => {
    const eventId = 'evtT1';
    const taskId = 'taskT1';
    await seedEvent({
      eventId,
      creatorUid: 'creatorT1',
      memberUids: ['creatorT1', 'memberT1', 'attacker'],
      adminUids: ['creatorT1'],
    });
    await getAdminDb()
      .collection('events')
      .doc(eventId)
      .collection('tasks')
      .doc(taskId)
      .set({
        eventId,
        createdBy: 'creatorT1',
        assigneeId: 'memberT1',
        title: 'X',
        status: 'todo',
      });

    const wrapped = ftest.wrap(markTaskComplete);
    await expect(
      wrapped({
        auth: {uid: 'attacker'},
        data: {eventId, taskId},
      })
    ).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('happy path: assignee marks task complete', async () => {
    const eventId = 'evtT2';
    const taskId = 'taskT2';
    await seedEvent({
      eventId,
      creatorUid: 'creatorT2',
      memberUids: ['creatorT2', 'assignee'],
      adminUids: ['creatorT2'],
    });
    await getAdminDb()
      .collection('events')
      .doc(eventId)
      .collection('tasks')
      .doc(taskId)
      .set({
        eventId,
        createdBy: 'creatorT2',
        assigneeId: 'assignee',
        title: 'X',
        status: 'todo',
      });

    const wrapped = ftest.wrap(markTaskComplete);
    const result = await wrapped({
      auth: {uid: 'assignee'},
      data: {eventId, taskId},
    });
    expect(result).toEqual({success: true});

    const after = await getAdminDb()
      .collection('events')
      .doc(eventId)
      .collection('tasks')
      .doc(taskId)
      .get();
    expect(after.data()!.status).toBe('done');
    expect(after.data()!.completedBy).toBe('assignee');
  });
});

describe('generateInviteCode', () => {
  test('non-admin/non-creator caller rejected with permission-denied', async () => {
    await seedEvent({
      eventId: 'evtG1',
      creatorUid: 'creatorG1',
      memberUids: ['creatorG1', 'member'],
      adminUids: ['creatorG1'],
    });

    const wrapped = ftest.wrap(generateInviteCode);
    await expect(
      wrapped({auth: {uid: 'member'}, data: {eventId: 'evtG1'}})
    ).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('happy path: creator generates a 6-char code', async () => {
    await seedEvent({
      eventId: 'evtG2',
      creatorUid: 'creatorG2',
    });

    const wrapped = ftest.wrap(generateInviteCode);
    const result = await wrapped({
      auth: {uid: 'creatorG2'},
      data: {eventId: 'evtG2'},
    });
    expect(result.code).toMatch(/^[A-Z0-9]{6}$/);

    const codeDoc = await getAdminDb()
      .collection('event_invites')
      .doc(result.code)
      .get();
    expect(codeDoc.exists).toBe(true);
    expect(codeDoc.data()!.eventId).toBe('evtG2');
  });
});

describe('disputeSettlement', () => {
  test('non-payer/non-payee caller rejected with permission-denied', async () => {
    const eventId = 'evtS1';
    const settlementId = 'set1';
    await seedEvent({
      eventId,
      creatorUid: 'creatorS1',
      memberUids: ['creatorS1', 'payer', 'payee', 'outsider'],
    });
    await getAdminDb()
      .collection('events')
      .doc(eventId)
      .collection('expenses')
      .doc(settlementId)
      .set({
        isPayment: true,
        payerId: 'payer',
        splits: [{userId: 'payee'}],
        amount: 100,
      });

    const wrapped = ftest.wrap(disputeSettlement);
    await expect(
      wrapped({
        auth: {uid: 'outsider'},
        data: {eventId, settlementId},
      })
    ).rejects.toMatchObject({code: 'permission-denied'});
  });

  test('happy path: payee disputes settlement → expense deleted, notice replaced', async () => {
    const eventId = 'evtS2';
    const settlementId = 'set2';
    await seedEvent({
      eventId,
      creatorUid: 'creatorS2',
      memberUids: ['creatorS2', 'payer', 'payee'],
    });
    await getAdminDb()
      .collection('events')
      .doc(eventId)
      .collection('expenses')
      .doc(settlementId)
      .set({
        isPayment: true,
        payerId: 'payer',
        splits: [{userId: 'payee'}],
        amount: 100,
      });

    const wrapped = ftest.wrap(disputeSettlement);
    const result = await wrapped({
      auth: {uid: 'payee'},
      data: {eventId, settlementId},
    });
    expect(result).toEqual({success: true});

    const expenseAfter = await getAdminDb()
      .collection('events')
      .doc(eventId)
      .collection('expenses')
      .doc(settlementId)
      .get();
    expect(expenseAfter.exists).toBe(false);

    const noticeAfter = await getAdminDb()
      .collection('events')
      .doc(eventId)
      .collection('messages')
      .doc(settlementId)
      .get();
    expect(noticeAfter.exists).toBe(true);
    expect(noticeAfter.data()!.kind).toBe('settlement_disputed');
  });
});

describe('deleteEvent', () => {
  test('non-creator caller rejected with permission-denied', async () => {
    await seedEvent({
      eventId: 'evtDE1',
      creatorUid: 'creatorDE1',
      memberUids: ['creatorDE1', 'admin1'],
      adminUids: ['creatorDE1', 'admin1'],
    });

    const wrapped = ftest.wrap(deleteEvent);
    await expect(
      wrapped({
        auth: {uid: 'admin1'},
        data: {eventId: 'evtDE1'},
      })
    ).rejects.toMatchObject({code: 'permission-denied'});
  });

  test(
    'happy path: creator deletes a small event with subcollections',
    async () => {
      const eventId = 'evtDE2';
      await seedEvent({eventId, creatorUid: 'creatorDE2'});

      // Seed a few subcollection docs.
      const eventRef = getAdminDb().collection('events').doc(eventId);
      await eventRef
        .collection('messages')
        .doc('m1')
        .set({senderId: 'creatorDE2', text: 'hi'});
      await eventRef
        .collection('tasks')
        .doc('t1')
        .set({eventId, createdBy: 'creatorDE2', title: 'X'});

      const wrapped = ftest.wrap(deleteEvent);
      const result = await wrapped({
        auth: {uid: 'creatorDE2'},
        data: {eventId},
      });
      expect(result).toEqual({success: true});

      const eventAfter = await eventRef.get();
      expect(eventAfter.exists).toBe(false);
      const messagesAfter = await eventRef.collection('messages').get();
      expect(messagesAfter.empty).toBe(true);
      const tasksAfter = await eventRef.collection('tasks').get();
      expect(tasksAfter.empty).toBe(true);
    }
  );
});
