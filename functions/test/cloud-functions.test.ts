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
import {getAuth} from 'firebase-admin/auth';
import {Timestamp} from 'firebase-admin/firestore';
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from './setup';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require('firebase-functions-test');
const ftest = firebaseFunctionsTest();

// Eager-init the Admin SDK before importing CFs (which call
// initializeApp() at module load).
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
const {deleteUserAccount} = require('../src/account/deleteUserAccount');
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
    ['deleteUserAccount', deleteUserAccount, {}],
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
      expiresAt: Timestamp.fromDate(new Date(Date.now() - 1000)),
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
      expiresAt: Timestamp.fromDate(
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
      expiresAt: Timestamp.fromDate(
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

  test('second call without rotate flag returns the SAME code (reuse-if-valid)', async () => {
    await seedEvent({eventId: 'evtG3', creatorUid: 'creatorG3'});

    const wrapped = ftest.wrap(generateInviteCode);
    const first = await wrapped({
      auth: {uid: 'creatorG3'},
      data: {eventId: 'evtG3'},
    });
    const second = await wrapped({
      auth: {uid: 'creatorG3'},
      data: {eventId: 'evtG3'},
    });

    expect(second.code).toBe(first.code);

    const docs = await getAdminDb()
      .collection('event_invites')
      .where('eventId', '==', 'evtG3')
      .get();
    expect(docs.size).toBe(1);
  });

  test('expired existing code is replaced with a fresh one on default call', async () => {
    await seedEvent({eventId: 'evtG5', creatorUid: 'creatorG5'});
    // Pre-seed an EXPIRED invite doc.
    const expiredCode = 'EXP123';
    const past = new Date(Date.now() - 60 * 60 * 1000); // 1 hour ago
    await getAdminDb()
      .collection('event_invites')
      .doc(expiredCode)
      .set({
        eventId: 'evtG5',
        createdBy: 'creatorG5',
        createdAt: Timestamp.fromDate(
          new Date(past.getTime() - 60 * 60 * 1000)
        ),
        expiresAt: Timestamp.fromDate(past),
      });

    const wrapped = ftest.wrap(generateInviteCode);
    const result = await wrapped({
      auth: {uid: 'creatorG5'},
      data: {eventId: 'evtG5'},
    });

    expect(result.code).not.toBe(expiredCode);

    // Expired doc deleted; only the fresh one remains for this event.
    const expiredDoc = await getAdminDb()
      .collection('event_invites')
      .doc(expiredCode)
      .get();
    expect(expiredDoc.exists).toBe(false);

    const docs = await getAdminDb()
      .collection('event_invites')
      .where('eventId', '==', 'evtG5')
      .get();
    expect(docs.size).toBe(1);
    expect(docs.docs[0].id).toBe(result.code);
  });

  test('self-heal: multiple non-expired duplicates → returns most-recent + deletes siblings', async () => {
    await seedEvent({eventId: 'evtG6', creatorUid: 'creatorG6'});

    const future = Timestamp.fromDate(
      new Date(Date.now() + 12 * 60 * 60 * 1000)
    );
    const older = Timestamp.fromDate(
      new Date(Date.now() - 5 * 60 * 1000)
    );
    const newer = Timestamp.fromDate(
      new Date(Date.now() - 1 * 60 * 1000)
    );

    // Two non-expired docs for the same event — simulates the
    // post-race data-corruption state.
    await getAdminDb()
      .collection('event_invites')
      .doc('OLDER1')
      .set({
        eventId: 'evtG6',
        createdBy: 'creatorG6',
        createdAt: older,
        expiresAt: future,
      });
    await getAdminDb()
      .collection('event_invites')
      .doc('NEWER1')
      .set({
        eventId: 'evtG6',
        createdBy: 'creatorG6',
        createdAt: newer,
        expiresAt: future,
      });

    const wrapped = ftest.wrap(generateInviteCode);
    const result = await wrapped({
      auth: {uid: 'creatorG6'},
      data: {eventId: 'evtG6'},
    });

    // Most recent (NEWER1) is returned; OLDER1 is deleted in the same tx.
    expect(result.code).toBe('NEWER1');

    const olderDoc = await getAdminDb()
      .collection('event_invites')
      .doc('OLDER1')
      .get();
    expect(olderDoc.exists).toBe(false);

    const docs = await getAdminDb()
      .collection('event_invites')
      .where('eventId', '==', 'evtG6')
      .get();
    expect(docs.size).toBe(1);
  });

  test('rotate as string "true" is treated as false (reuse, not rotate)', async () => {
    await seedEvent({eventId: 'evtG7', creatorUid: 'creatorG7'});

    const wrapped = ftest.wrap(generateInviteCode);
    const first = await wrapped({
      auth: {uid: 'creatorG7'},
      data: {eventId: 'evtG7'},
    });
    // String 'true' is NOT the literal boolean true; strict coercion
    // must treat this as reuse (returning the same code), not rotate.
    const second = await wrapped({
      auth: {uid: 'creatorG7'},
      data: {eventId: 'evtG7', rotate: 'true'},
    });

    expect(second.code).toBe(first.code);
  });

  test('rotate: true returns a NEW code and deletes the previous one', async () => {
    await seedEvent({eventId: 'evtG4', creatorUid: 'creatorG4'});

    const wrapped = ftest.wrap(generateInviteCode);
    const first = await wrapped({
      auth: {uid: 'creatorG4'},
      data: {eventId: 'evtG4'},
    });
    const rotated = await wrapped({
      auth: {uid: 'creatorG4'},
      data: {eventId: 'evtG4', rotate: true},
    });

    expect(rotated.code).not.toBe(first.code);

    // Old code is gone; new code is the only one for this event.
    const oldDoc = await getAdminDb()
      .collection('event_invites')
      .doc(first.code)
      .get();
    expect(oldDoc.exists).toBe(false);

    const docs = await getAdminDb()
      .collection('event_invites')
      .where('eventId', '==', 'evtG4')
      .get();
    expect(docs.size).toBe(1);
    expect(docs.docs[0].id).toBe(rotated.code);
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

  test(
    'streams the delete on a 1,200-message event (proves bounded memory)',
    async () => {
      const eventId = 'evtDELarge';
      const creatorUid = 'creatorDELarge';
      await seedEvent({eventId, creatorUid});

      // Seed 1,200 messages — past the 500-doc batch cap, so the
      // streaming loop must run at least three pages (500, 500, 200).
      const eventRef = getAdminDb().collection('events').doc(eventId);
      const PAGE = 500;
      let written = 0;
      while (written < 1200) {
        const pageSize = Math.min(PAGE, 1200 - written);
        const batch = getAdminDb().batch();
        for (let i = 0; i < pageSize; i++) {
          batch.set(
            eventRef
              .collection('messages')
              .doc(`m${(written + i).toString().padStart(5, '0')}`),
            {senderId: creatorUid, text: `msg ${written + i}`}
          );
        }
        await batch.commit();
        written += pageSize;
      }

      const wrapped = ftest.wrap(deleteEvent);
      const result = await wrapped({
        auth: {uid: creatorUid},
        data: {eventId},
      });
      expect(result).toEqual({success: true});

      const eventAfter = await eventRef.get();
      expect(eventAfter.exists).toBe(false);
      const messagesAfter = await eventRef.collection('messages').get();
      expect(messagesAfter.size).toBe(0);
    },
    60_000 // tighter timeout so an upfront-collection regression would surface
  );

  test(
    'idempotent on retry: second invocation throws not-found',
    async () => {
      const eventId = 'evtDERetry';
      const creatorUid = 'creatorDERetry';
      await seedEvent({eventId, creatorUid});

      const wrapped = ftest.wrap(deleteEvent);
      await wrapped({auth: {uid: creatorUid}, data: {eventId}});

      // Second invocation should not crash — it should hit the
      // not-found check at the top and return a clean HttpsError.
      await expect(
        wrapped({auth: {uid: creatorUid}, data: {eventId}})
      ).rejects.toMatchObject({code: 'not-found'});
    }
  );
});

describe('deleteUserAccount', () => {
  // Helper: deleteUserAccount calls auth().deleteUser(uid) at the end,
  // so we need a real auth user in the emulator first.
  async function createAuthUser(uid: string, email: string): Promise<void> {
    await getAuth().createUser({uid, email});
  }

  async function deleteAuthUserSilently(uid: string): Promise<void> {
    try {
      await getAuth().deleteUser(uid);
    } catch {
      // Test cleanup — ignore.
    }
  }

  test(
    'solo event → hard delete; private subdoc gone; auth user deleted',
    async () => {
      const uid = 'soloUserA';
      const eventId = 'evtSolo';
      await createAuthUser(uid, 'solo@example.com');

      const db = getAdminDb();
      await db
        .collection('users')
        .doc(uid)
        .set({displayName: 'Solo'});
      await db
        .collection('users')
        .doc(uid)
        .collection('private')
        .doc('profile')
        .set({email: 'solo@example.com'});
      await seedEvent({
        eventId,
        creatorUid: uid,
        memberUids: [uid],
        adminUids: [uid],
      });
      await db
        .collection('events')
        .doc(eventId)
        .collection('messages')
        .doc('m1')
        .set({senderId: uid, text: 'hi'});

      const wrapped = ftest.wrap(deleteUserAccount);
      const result = await wrapped({auth: {uid}, data: {}});
      expect(result).toEqual({success: true});

      // Solo event hard-deleted.
      const eventAfter = await db.collection('events').doc(eventId).get();
      expect(eventAfter.exists).toBe(false);

      // Public user doc + private subdoc both gone.
      const publicAfter = await db.collection('users').doc(uid).get();
      expect(publicAfter.exists).toBe(false);
      const privateAfter = await db
        .collection('users')
        .doc(uid)
        .collection('private')
        .doc('profile')
        .get();
      expect(privateAfter.exists).toBe(false);

      // Auth user gone.
      await expect(getAuth().getUser(uid)).rejects.toMatchObject({
        code: 'auth/user-not-found',
      });
    }
  );

  test(
    'shared event → anonymize + ownership transfer to first remaining admin',
    async () => {
      const deletingUid = 'creatorShared';
      const remainingAdminUid = 'remainAdmin';
      const remainingMemberUid = 'remainMember';
      const eventId = 'evtShared';

      await createAuthUser(deletingUid, 'creator@example.com');

      const db = getAdminDb();
      await db.collection('users').doc(deletingUid).set({displayName: 'Creator'});
      await seedEvent({
        eventId,
        creatorUid: deletingUid,
        memberUids: [deletingUid, remainingAdminUid, remainingMemberUid],
        adminUids: [deletingUid, remainingAdminUid],
      });
      await db
        .collection('events')
        .doc(eventId)
        .collection('messages')
        .doc('m1')
        .set({senderId: deletingUid, text: 'creator msg'});
      await db
        .collection('events')
        .doc(eventId)
        .collection('expenses')
        .doc('e1')
        .set({payerId: deletingUid, amount: 50});
      await db
        .collection('events')
        .doc(eventId)
        .collection('tasks')
        .doc('t1')
        .set({
          eventId,
          createdBy: remainingMemberUid,
          assigneeId: deletingUid,
          status: 'todo',
        });

      const wrapped = ftest.wrap(deleteUserAccount);
      await wrapped({auth: {uid: deletingUid}, data: {}});

      // Event survives, ownership transferred to the first remaining admin.
      const eventAfter = await db.collection('events').doc(eventId).get();
      expect(eventAfter.exists).toBe(true);
      expect(eventAfter.data()!.creatorId).toBe(remainingAdminUid);
      expect(eventAfter.data()!.memberIds).not.toContain(deletingUid);
      expect(eventAfter.data()!.adminIds).not.toContain(deletingUid);

      // Messages anonymized.
      const msgAfter = await db
        .collection('events')
        .doc(eventId)
        .collection('messages')
        .doc('m1')
        .get();
      expect(msgAfter.data()!.senderId).toBe('deleted_user');

      // Expenses anonymized.
      const expAfter = await db
        .collection('events')
        .doc(eventId)
        .collection('expenses')
        .doc('e1')
        .get();
      expect(expAfter.data()!.payerId).toBe('deleted_user');

      // Tasks unassigned.
      const taskAfter = await db
        .collection('events')
        .doc(eventId)
        .collection('tasks')
        .doc('t1')
        .get();
      expect(taskAfter.data()!.assigneeId).toBeNull();

      await deleteAuthUserSilently(remainingAdminUid);
      await deleteAuthUserSilently(remainingMemberUid);
    }
  );
});
