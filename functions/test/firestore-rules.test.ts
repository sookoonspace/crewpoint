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
