import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  setDoc,
  getDoc,
  doc,
  updateDoc,
  deleteDoc,
  arrayUnion,
  arrayRemove,
} from 'firebase/firestore';
import {getTestEnv} from './setup';

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await getTestEnv();
});

afterEach(async () => {
  await env.clearFirestore();
});

afterAll(async () => {
  await env.cleanup();
});

describe('events update — Fix 1.A: field-level guards on memberIds/adminIds/creatorId', () => {
  test('admin cannot promote another member to admin via direct events/{id} update', async () => {
    const eventId = 'evt1';
    const creatorUid = 'creator1';
    const adminUid = 'admin1';
    const targetUid = 'member1';

    // Seed: admin1 is in adminIds + memberIds; member1 is only in memberIds.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `events/${eventId}`), {
        creatorId: creatorUid,
        memberIds: [creatorUid, adminUid, targetUid],
        adminIds: [creatorUid, adminUid],
        title: 'Trip',
      });
    });

    // admin1 (existing admin — passes the actor check) attempts to mutate
    // adminIds directly. Without Fix 1.A this would succeed because the
    // existing rule allows admins to update events. Fix 1.A's field-level
    // guard must block any write that changes adminIds — only the dedicated
    // `promoteToAdmin` Cloud Function (which uses the Admin SDK and bypasses
    // rules) may add to adminIds.
    const adminCtx = env.authenticatedContext(adminUid);
    await assertFails(
      updateDoc(doc(adminCtx.firestore(), `events/${eventId}`), {
        adminIds: arrayUnion(targetUid),
      })
    );
  });

  test('admin cannot remove a member from memberIds via direct events/{id} update', async () => {
    const eventId = 'evt2';
    const creatorUid = 'creator2';
    const adminUid = 'admin2';
    const victimUid = 'victim2';

    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `events/${eventId}`), {
        creatorId: creatorUid,
        memberIds: [creatorUid, adminUid, victimUid],
        adminIds: [creatorUid, adminUid],
        title: 'Trip',
      });
    });

    // Removal must go through the dedicated removeEventMember Cloud Function.
    const adminCtx = env.authenticatedContext(adminUid);
    await assertFails(
      updateDoc(doc(adminCtx.firestore(), `events/${eventId}`), {
        memberIds: arrayRemove(victimUid),
      })
    );
  });

  test('creator can update title without touching member arrays (backward-compat positive case)', async () => {
    const eventId = 'evt3';
    const creatorUid = 'creator3';

    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `events/${eventId}`), {
        creatorId: creatorUid,
        memberIds: [creatorUid],
        adminIds: [creatorUid],
        title: 'Old Title',
      });
    });

    const creatorCtx = env.authenticatedContext(creatorUid);
    await assertSucceeds(
      updateDoc(doc(creatorCtx.firestore(), `events/${eventId}`), {
        title: 'New Title',
      })
    );
  });
});

describe('tasks update — Fix 1.C: field-level guards on eventId/createdBy', () => {
  test('assignee cannot rewrite eventId on a task they are assigned to', async () => {
    const eventId = 'evtT1';
    const taskId = 'taskT1';
    const creatorUid = 'creatorT1';
    const assigneeUid = 'assigneeT1';

    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `events/${eventId}`), {
        creatorId: creatorUid,
        memberIds: [creatorUid, assigneeUid],
        adminIds: [creatorUid],
        title: 'Trip',
      });
      await setDoc(doc(db, `events/${eventId}/tasks/${taskId}`), {
        eventId,
        createdBy: creatorUid,
        assigneeId: assigneeUid,
        title: 'Buy snacks',
        status: 'todo',
      });
    });

    // Assignee tries to rewrite eventId. Without Fix 1.C this would
    // succeed because the existing rule allows assignee updates to
    // any field. Fix 1.C must block writes that change eventId.
    const assigneeCtx = env.authenticatedContext(assigneeUid);
    await assertFails(
      updateDoc(
        doc(assigneeCtx.firestore(), `events/${eventId}/tasks/${taskId}`),
        {eventId: 'attackerOwnedEvent'}
      )
    );
  });

  test('assignee cannot rewrite createdBy on a task they are assigned to', async () => {
    const eventId = 'evtT2';
    const taskId = 'taskT2';
    const creatorUid = 'creatorT2';
    const assigneeUid = 'assigneeT2';

    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `events/${eventId}`), {
        creatorId: creatorUid,
        memberIds: [creatorUid, assigneeUid],
        adminIds: [creatorUid],
      });
      await setDoc(doc(db, `events/${eventId}/tasks/${taskId}`), {
        eventId,
        createdBy: creatorUid,
        assigneeId: assigneeUid,
        title: 'Buy snacks',
        status: 'todo',
      });
    });

    const assigneeCtx = env.authenticatedContext(assigneeUid);
    await assertFails(
      updateDoc(
        doc(assigneeCtx.firestore(), `events/${eventId}/tasks/${taskId}`),
        {createdBy: assigneeUid}
      )
    );
  });

  test('assignee can update task status (backward-compat positive case)', async () => {
    const eventId = 'evtT3';
    const taskId = 'taskT3';
    const creatorUid = 'creatorT3';
    const assigneeUid = 'assigneeT3';

    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `events/${eventId}`), {
        creatorId: creatorUid,
        memberIds: [creatorUid, assigneeUid],
        adminIds: [creatorUid],
      });
      await setDoc(doc(db, `events/${eventId}/tasks/${taskId}`), {
        eventId,
        createdBy: creatorUid,
        assigneeId: assigneeUid,
        title: 'Buy snacks',
        status: 'todo',
      });
    });

    const assigneeCtx = env.authenticatedContext(assigneeUid);
    await assertSucceeds(
      updateDoc(
        doc(assigneeCtx.firestore(), `events/${eventId}/tasks/${taskId}`),
        {status: 'in_progress'}
      )
    );
  });
});

describe('users — Fix 1.B Option A: PII isolated in users/{uid}/private/profile', () => {
  test('self can read own users/{uid}/private/profile', async () => {
    const selfUid = 'selfB1';

    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `users/${selfUid}`), {
        displayName: 'Alice',
        photoUrl: 'https://example.com/alice.jpg',
      });
      await setDoc(doc(db, `users/${selfUid}/private/profile`), {
        email: 'alice@example.com',
        providerIds: ['password'],
        fcmTokens: ['tok1'],
      });
    });

    const selfCtx = env.authenticatedContext(selfUid);
    await assertSucceeds(
      getDoc(doc(selfCtx.firestore(), `users/${selfUid}/private/profile`))
    );
  });

  test('non-self cannot read users/{otherUid}/private/profile', async () => {
    const ownerUid = 'ownerB2';
    const otherUid = 'otherB2';

    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `users/${ownerUid}/private/profile`), {
        email: 'owner@example.com',
      });
    });

    const otherCtx = env.authenticatedContext(otherUid);
    await assertFails(
      getDoc(doc(otherCtx.firestore(), `users/${ownerUid}/private/profile`))
    );
  });

  test('non-self can still read users/{otherUid} public projection (display fields)', async () => {
    const ownerUid = 'ownerB3';
    const otherUid = 'otherB3';

    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${ownerUid}`), {
        displayName: 'Bob',
        photoUrl: 'https://example.com/bob.jpg',
        paymentMethod: 'venmo',
        paymentHandle: '@bob',
      });
    });

    const otherCtx = env.authenticatedContext(otherUid);
    await assertSucceeds(
      getDoc(doc(otherCtx.firestore(), `users/${ownerUid}`))
    );
  });

  test('self can write users/{uid}/private/profile', async () => {
    const selfUid = 'selfB4';

    const selfCtx = env.authenticatedContext(selfUid);
    await assertSucceeds(
      setDoc(
        doc(selfCtx.firestore(), `users/${selfUid}/private/profile`),
        {email: 'self@example.com', fcmTokens: ['tok-fresh']}
      )
    );
  });

  test('non-self cannot write users/{otherUid}/private/profile', async () => {
    const ownerUid = 'ownerB5';
    const attackerUid = 'attackerB5';

    const attackerCtx = env.authenticatedContext(attackerUid);
    await assertFails(
      setDoc(
        doc(attackerCtx.firestore(), `users/${ownerUid}/private/profile`),
        {email: 'phished@example.com'}
      )
    );
  });
});

describe('expenses update — payer/creator/admin allowed, others denied; payerId/eventId locked', () => {
  const eventId = 'evtExp';
  const creatorUid = 'creator1';
  const adminUid = 'admin1';
  const payerUid = 'payer1';
  const memberUid = 'member1';
  const outsiderUid = 'outsider1';
  const expenseId = 'exp1';

  async function seed() {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `events/${eventId}`), {
        creatorId: creatorUid,
        adminIds: [creatorUid, adminUid],
        memberIds: [creatorUid, adminUid, payerUid, memberUid],
        title: 'Trip',
      });
      await setDoc(
        doc(ctx.firestore(), `events/${eventId}/expenses/${expenseId}`),
        {
          eventId,
          payerId: payerUid,
          amount: 25,
          description: 'Original',
        }
      );
    });
  }

  test('payer can update their own expense (amount, description)', async () => {
    await seed();
    const payerCtx = env.authenticatedContext(payerUid);
    await assertSucceeds(
      updateDoc(
        doc(payerCtx.firestore(), `events/${eventId}/expenses/${expenseId}`),
        {amount: 50, description: 'Edited'}
      )
    );
  });

  test('event creator can update any expense', async () => {
    await seed();
    const creatorCtx = env.authenticatedContext(creatorUid);
    await assertSucceeds(
      updateDoc(
        doc(creatorCtx.firestore(), `events/${eventId}/expenses/${expenseId}`),
        {description: 'Creator edit'}
      )
    );
  });

  test('event admin can update any expense', async () => {
    await seed();
    const adminCtx = env.authenticatedContext(adminUid);
    await assertSucceeds(
      updateDoc(
        doc(adminCtx.firestore(), `events/${eventId}/expenses/${expenseId}`),
        {amount: 75}
      )
    );
  });

  test('random member (non-payer, non-creator, non-admin) is denied', async () => {
    await seed();
    const memberCtx = env.authenticatedContext(memberUid);
    await assertFails(
      updateDoc(
        doc(memberCtx.firestore(), `events/${eventId}/expenses/${expenseId}`),
        {amount: 999}
      )
    );
  });

  test('non-member is denied', async () => {
    await seed();
    const outsiderCtx = env.authenticatedContext(outsiderUid);
    await assertFails(
      updateDoc(
        doc(outsiderCtx.firestore(), `events/${eventId}/expenses/${expenseId}`),
        {amount: 999}
      )
    );
  });

  test('payer cannot reassign payerId via update', async () => {
    await seed();
    const payerCtx = env.authenticatedContext(payerUid);
    await assertFails(
      updateDoc(
        doc(payerCtx.firestore(), `events/${eventId}/expenses/${expenseId}`),
        {payerId: outsiderUid}
      )
    );
  });

  test('admin cannot move an expense to a different eventId', async () => {
    await seed();
    const adminCtx = env.authenticatedContext(adminUid);
    await assertFails(
      updateDoc(
        doc(adminCtx.firestore(), `events/${eventId}/expenses/${expenseId}`),
        {eventId: 'evtOther'}
      )
    );
  });
});

describe('expenses delete — payer/creator/admin allowed, others denied', () => {
  const eventId = 'evtExpDel';
  const creatorUid = 'creator2';
  const adminUid = 'admin2';
  const payerUid = 'payer2';
  const memberUid = 'member2';
  const expenseId = 'exp2';

  async function seed() {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `events/${eventId}`), {
        creatorId: creatorUid,
        adminIds: [creatorUid, adminUid],
        memberIds: [creatorUid, adminUid, payerUid, memberUid],
        title: 'Trip',
      });
      await setDoc(
        doc(ctx.firestore(), `events/${eventId}/expenses/${expenseId}`),
        {eventId, payerId: payerUid, amount: 25}
      );
    });
  }

  test('event admin can delete an expense (new permission)', async () => {
    await seed();
    const adminCtx = env.authenticatedContext(adminUid);
    await assertSucceeds(
      deleteDoc(
        doc(adminCtx.firestore(), `events/${eventId}/expenses/${expenseId}`)
      )
    );
  });

  test('random member cannot delete an expense', async () => {
    await seed();
    const memberCtx = env.authenticatedContext(memberUid);
    await assertFails(
      deleteDoc(
        doc(memberCtx.firestore(), `events/${eventId}/expenses/${expenseId}`)
      )
    );
  });
});

describe('event_invites — client access denied universally', () => {
  test('authenticated user cannot read event_invites', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'event_invites/CODE01'), {
        eventId: 'evtX',
        expiresAt: new Date(Date.now() + 60_000),
      });
    });

    const userCtx = env.authenticatedContext('anyUser');
    await assertFails(
      getDoc(doc(userCtx.firestore(), 'event_invites/CODE01'))
    );
  });

  test('authenticated user cannot create event_invites', async () => {
    const userCtx = env.authenticatedContext('anyUser');
    await assertFails(
      setDoc(doc(userCtx.firestore(), 'event_invites/CODE02'), {
        eventId: 'evtY',
      })
    );
  });
});

describe('access matrix smoke', () => {
  test('anonymous user cannot read events', async () => {
    const eventId = 'evtAnon';
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `events/${eventId}`), {
        creatorId: 'someone',
        memberIds: ['someone'],
        adminIds: ['someone'],
        title: 'Private',
      });
    });

    const anonCtx = env.unauthenticatedContext();
    await assertFails(
      getDoc(doc(anonCtx.firestore(), `events/${eventId}`))
    );
  });

  test('non-member cannot read events/{id}', async () => {
    const eventId = 'evtMembers';
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `events/${eventId}`), {
        creatorId: 'memberA',
        memberIds: ['memberA'],
        adminIds: ['memberA'],
        title: 'Members Only',
      });
    });

    const outsiderCtx = env.authenticatedContext('outsider');
    await assertFails(
      getDoc(doc(outsiderCtx.firestore(), `events/${eventId}`))
    );
  });
});

describe('eventMutes — self-only access (Phase 5)', () => {
  test('user can write their own users/{uid}/eventMutes/{eventId}', async () => {
    const uid = 'self';
    const eventId = 'evt-1';
    const selfCtx = env.authenticatedContext(uid);

    await assertSucceeds(
      setDoc(
        doc(selfCtx.firestore(), `users/${uid}/eventMutes/${eventId}`),
        {mutedUntil: '2026-06-01T12:00:00.000Z'}
      )
    );
  });

  test('user can read their own users/{uid}/eventMutes/{eventId}', async () => {
    const uid = 'self';
    const eventId = 'evt-1';

    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), `users/${uid}/eventMutes/${eventId}`),
        {mutedUntil: '2026-06-01T12:00:00.000Z'}
      );
    });

    const selfCtx = env.authenticatedContext(uid);
    await assertSucceeds(
      getDoc(doc(selfCtx.firestore(), `users/${uid}/eventMutes/${eventId}`))
    );
  });

  test('user CANNOT read another user\'s eventMutes/{eventId}', async () => {
    const ownerUid = 'owner';
    const otherUid = 'snooper';
    const eventId = 'evt-1';

    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), `users/${ownerUid}/eventMutes/${eventId}`),
        {mutedUntil: '2026-06-01T12:00:00.000Z'}
      );
    });

    const otherCtx = env.authenticatedContext(otherUid);
    await assertFails(
      getDoc(
        doc(otherCtx.firestore(), `users/${ownerUid}/eventMutes/${eventId}`)
      )
    );
  });

  test('user CANNOT write another user\'s eventMutes/{eventId}', async () => {
    const ownerUid = 'owner';
    const attackerUid = 'attacker';
    const eventId = 'evt-1';

    const attackerCtx = env.authenticatedContext(attackerUid);
    await assertFails(
      setDoc(
        doc(attackerCtx.firestore(), `users/${ownerUid}/eventMutes/${eventId}`),
        {mutedUntil: '2099-01-01T00:00:00.000Z'}
      )
    );
  });

  test('anonymous user CANNOT read eventMutes', async () => {
    const ownerUid = 'owner';
    const eventId = 'evt-1';

    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), `users/${ownerUid}/eventMutes/${eventId}`),
        {mutedUntil: '2026-06-01T12:00:00.000Z'}
      );
    });

    const anonCtx = env.unauthenticatedContext();
    await assertFails(
      getDoc(
        doc(anonCtx.firestore(), `users/${ownerUid}/eventMutes/${eventId}`)
      )
    );
  });

  test('user can delete their own eventMutes/{eventId} (unmute)', async () => {
    const uid = 'self';
    const eventId = 'evt-1';

    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), `users/${uid}/eventMutes/${eventId}`),
        {mutedUntil: '2026-06-01T12:00:00.000Z'}
      );
    });

    const selfCtx = env.authenticatedContext(uid);
    await assertSucceeds(
      deleteDoc(doc(selfCtx.firestore(), `users/${uid}/eventMutes/${eventId}`))
    );
  });
});
