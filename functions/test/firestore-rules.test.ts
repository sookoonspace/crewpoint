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
  collection,
  getDocs,
  query,
  serverTimestamp,
  where,
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

describe('messages — urgent permission and size', () => {
  const E = 'events/evtMsg';
  const as = (uid: string) => env.authenticatedContext(uid).firestore();
  const seed = () =>
    env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), E), {
        creatorId: 'owner',
        adminIds: ['owner', 'admin'],
        memberIds: ['owner', 'admin', 'member'],
      });
    });
  const send = (uid: string, data: object) =>
    setDoc(doc(as(uid), `${E}/messages/m-${uid}`), {senderId: uid, text: 'hi', ...data});

  test.each(['owner', 'admin'])('%s can send an urgent message', async (uid) => {
    await seed();
    await assertSucceeds(send(uid, {isHighPriority: true}));
  });

  test('a member cannot send an urgent message', async () => {
    await seed();
    await assertFails(send('member', {isHighPriority: true}));
  });

  test('a member can send a normal message', async () => {
    await seed();
    await assertSucceeds(send('member', {isHighPriority: false}));
    await assertSucceeds(send('admin', {}));
  });

  test('text can be 4,000 characters, and no more', async () => {
    await seed();
    await assertSucceeds(send('member', {text: 'a'.repeat(4000)}));
    await assertFails(send('admin', {text: 'a'.repeat(4001)}));
  });

  test('text must be text', async () => {
    await seed();
    await assertFails(send('member', {text: 5}));
  });

  test('a client cannot set the skipped flag', async () => {
    await seed();
    await assertFails(send('member', {urgentPushSkipped: true}));
  });

  test('the rate limit record cannot be read or written', async () => {
    await seed();
    await assertFails(getDoc(doc(as('admin'), `${E}/urgentRates/admin`)));
    await assertFails(setDoc(doc(as('admin'), `${E}/urgentRates/admin`), {sentAt: []}));
  });
});

describe('events update — currency stays fixed', () => {
  const E = 'events/evtCur';
  const seed = () =>
    env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), E), {
        creatorId: 'owner',
        adminIds: ['owner', 'admin'],
        memberIds: ['owner', 'admin'],
        currency: 'USD',
        title: 'Trip',
      });
    });

  test.each(['owner', 'admin'])('%s cannot change currency directly', async (uid) => {
    await seed();
    const db = env.authenticatedContext(uid).firestore();
    await assertFails(updateDoc(doc(db, E), {currency: 'EUR'}));
  });

  test('other event fields can still be edited', async () => {
    await seed();
    const db = env.authenticatedContext('admin').firestore();
    await assertSucceeds(updateDoc(doc(db, E), {title: 'New'}));
  });
});

describe('events update — configuration (Req 18, 18a, 18b)', () => {
  const E = 'events/evtCfg';
  const seed = () =>
    env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), E), {
        creatorId: 'owner',
        organizerId: 'owner',
        templateId: 'blank',
        eventType: 'trip',
        adminIds: ['owner', 'admin'],
        memberIds: ['owner', 'admin', 'member'],
        memberCount: 3,
        currency: 'USD',
        title: 'Trip',
      });
    });

  test.each([
    ['organizerId', 'someone-verified'],
    ['templateId', 'party'],
    ['eventType', 'social'],
    ['memberCount', 1],
  ])('even an admin cannot change %s directly', async (field, value) => {
    await seed();
    const db = env.authenticatedContext('admin').firestore();
    await assertFails(updateDoc(doc(db, E), {[field]: value}));
  });

  test('an admin can set the configuration', async () => {
    await seed();
    const db = env.authenticatedContext('admin').firestore();
    await assertSucceeds(updateDoc(doc(db, E), {
      timeZone: 'America/Chicago',
      venues: [{id: 'v1', name: 'Garland Hall', address: '1 Main St'}],
      languages: ['en', 'gu'],
      labels: {group: {one: 'Team', other: 'Teams'}},
      capacity: 500,
      memberLimit: 100,
    }));
  });

  test('capacity and the member limit can be cleared', async () => {
    await seed();
    const db = env.authenticatedContext('admin').firestore();
    await assertSucceeds(updateDoc(doc(db, E), {capacity: null, memberLimit: null}));
  });

  test.each([
    ['capacity', 0],
    ['capacity', '500'],
    ['memberLimit', -1],
    ['memberLimit', 1.5],
    ['timeZone', 5],
    ['venues', 'Garland Hall'],
    ['languages', 'en'],
    ['labels', 'Team'],
  ])('%s cannot be set to %p', async (field, value) => {
    await seed();
    const db = env.authenticatedContext('admin').firestore();
    await assertFails(updateDoc(doc(db, E), {[field]: value}));
  });

  test('a plain member cannot set the configuration', async () => {
    await seed();
    const db = env.authenticatedContext('member').firestore();
    await assertFails(updateDoc(doc(db, E), {capacity: 500}));
  });

  test('an older event without these fields can still be edited', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'events/old'), {
        creatorId: 'owner',
        adminIds: ['owner'],
        memberIds: ['owner'],
        title: 'Old',
      });
    });
    const db = env.authenticatedContext('owner').firestore();
    await assertSucceeds(updateDoc(doc(db, 'events/old'), {title: 'New'}));
  });
});

describe('event status (Req 19, GE-08)', () => {
  const E = 'events/evtStatus';
  const seed = (status: string | undefined, over: object = {}) =>
    env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, E), {
        creatorId: 'owner',
        adminIds: ['owner', 'admin'],
        memberIds: ['owner', 'admin', 'member'],
        title: 'Convention',
        ...(status ? {status} : {}),
        ...over,
      });
      await setDoc(doc(db, `${E}/tasks/t1`), {
        eventId: 'evtStatus',
        title: 'Task',
        createdBy: 'member',
        assigneeId: 'member',
        status: 'todo',
      });
      await setDoc(doc(db, `${E}/tasks/t1/checklist/c1`), {
        text: 'Item',
        isCompleted: false,
      });
      await setDoc(doc(db, `${E}/messages/m1`), {senderId: 'member', text: 'Hi'});
      await setDoc(doc(db, `${E}/expenses/x1`), {payerId: 'member', amount: 1});
    });
  const as = (uid: string) => env.authenticatedContext(uid).firestore();
  const message = (uid: string) => ({senderId: uid, text: 'Hello'});
  const task = (uid: string) => ({eventId: 'evtStatus', title: 'New', createdBy: uid});

  describe('changing status', () => {
    const change = (uid: string, status: string) =>
      updateDoc(doc(as(uid), E), {status, statusSetAt: serverTimestamp()});

    test.each(['draft', 'published', 'live', 'ended', 'archived'])('an organizer can set %s', async (status) => {
      await seed('published', {memberIds: ['owner', 'admin']});
      await assertSucceeds(change('admin', status));
    });

    test.each(['active', 'finished', ''])('%p is not a status', async (status) => {
      await seed('published');
      await assertFails(change('admin', status));
    });

    test('a plain member cannot change it', async () => {
      await seed('published');
      await assertFails(change('member', 'ended'));
    });

    test('a change by hand must record when it happened', async () => {
      await seed('published');
      await assertFails(updateDoc(doc(as('admin'), E), {status: 'ended'}));
    });

    test('an event with plain members cannot go back to draft', async () => {
      await seed('published');
      await assertFails(change('admin', 'draft'));
    });

    test('an event from before statuses can still be edited', async () => {
      await seed('active');
      await assertSucceeds(updateDoc(doc(as('admin'), E), {title: 'New'}));
    });
  });

  describe('draft', () => {
    test('an organizer can read it', async () => {
      await seed('draft');
      await assertSucceeds(getDoc(doc(as('admin'), E)));
    });

    test('a plain member cannot, even if one is listed', async () => {
      await seed('draft');
      await assertFails(getDoc(doc(as('member'), E)));
    });

    test('the event list still works for members', async () => {
      await seed('published');
      await assertSucceeds(
        getDocs(query(collection(as('member'), 'events'), where('memberIds', 'array-contains', 'member'))),
      );
    });
  });

  describe.each(['published', 'live', 'active'])('%s', (status) => {
    test('members can chat and work on tasks', async () => {
      await seed(status);
      await assertSucceeds(setDoc(doc(as('member'), `${E}/messages/new`), message('member')));
      await assertSucceeds(setDoc(doc(as('member'), `${E}/tasks/new`), task('member')));
      await assertSucceeds(updateDoc(doc(as('member'), `${E}/tasks/t1`), {title: 'Edited'}));
    });
  });

  describe('ended', () => {
    test('chat stays open', async () => {
      await seed('ended');
      await assertSucceeds(setDoc(doc(as('member'), `${E}/messages/new`), message('member')));
    });

    test('expenses stay open', async () => {
      await seed('ended');
      await assertSucceeds(deleteDoc(doc(as('member'), `${E}/expenses/x1`)));
    });

    test('tasks are read-only to a plain member', async () => {
      await seed('ended');
      const db = as('member');
      await assertSucceeds(getDoc(doc(db, `${E}/tasks/t1`)));
      await assertFails(setDoc(doc(db, `${E}/tasks/new`), task('member')));
      await assertFails(updateDoc(doc(db, `${E}/tasks/t1`), {title: 'Edited'}));
      await assertFails(deleteDoc(doc(db, `${E}/tasks/t1`)));
      await assertFails(updateDoc(doc(db, `${E}/tasks/t1/checklist/c1`), {isCompleted: true}));
    });

    test('tasks stay editable to an organizer', async () => {
      await seed('ended');
      const db = as('admin');
      await assertSucceeds(setDoc(doc(db, `${E}/tasks/new`), task('admin')));
      await assertSucceeds(updateDoc(doc(db, `${E}/tasks/t1`), {title: 'Edited'}));
      await assertSucceeds(updateDoc(doc(db, `${E}/tasks/t1/checklist/c1`), {isCompleted: true}));
    });
  });

  describe('archived', () => {
    test('everyone can still read', async () => {
      await seed('archived');
      await assertSucceeds(getDoc(doc(as('member'), E)));
      await assertSucceeds(getDoc(doc(as('member'), `${E}/messages/m1`)));
    });

    test.each(['owner', 'member'])('%s cannot write anything', async (uid) => {
      await seed('archived');
      const db = as(uid);
      await assertFails(updateDoc(doc(db, E), {title: 'New'}));
      await assertFails(setDoc(doc(db, `${E}/messages/new`), message(uid)));
      await assertFails(deleteDoc(doc(db, `${E}/messages/m1`)));
      await assertFails(setDoc(doc(db, `${E}/tasks/new`), task(uid)));
      await assertFails(updateDoc(doc(db, `${E}/tasks/t1`), {title: 'Edited'}));
      await assertFails(deleteDoc(doc(db, `${E}/tasks/t1`)));
      await assertFails(updateDoc(doc(db, `${E}/tasks/t1/checklist/c1`), {isCompleted: true}));
      await assertFails(deleteDoc(doc(db, `${E}/expenses/x1`)));
    });

    test('an organizer can restore it, changing nothing else', async () => {
      await seed('archived');
      const db = as('admin');
      await assertFails(
        updateDoc(doc(db, E), {status: 'published', statusSetAt: serverTimestamp(), title: 'New'}),
      );
      await assertSucceeds(
        updateDoc(doc(db, E), {status: 'published', statusSetAt: serverTimestamp()}),
      );
    });

    test('a plain member cannot restore it', async () => {
      await seed('archived');
      await assertFails(
        updateDoc(doc(as('member'), E), {status: 'published', statusSetAt: serverTimestamp()}),
      );
    });
  });
});

describe('modules (Req 22, GE-02)', () => {
  const E = 'events/evtMod';
  const seed = (modules?: object) =>
    env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, E), {
        creatorId: 'owner',
        adminIds: ['owner'],
        memberIds: ['owner', 'member'],
        status: 'published',
        title: 'T',
        ...(modules ? {modules} : {}),
      });
      await setDoc(doc(db, `${E}/messages/m1`), {senderId: 'member', text: 'Hi'});
      await setDoc(doc(db, `${E}/tasks/t1`), {
        eventId: 'evtMod',
        title: 'T',
        createdBy: 'member',
        assigneeId: 'member',
        status: 'todo',
      });
      await setDoc(doc(db, `${E}/tasks/t1/checklist/c1`), {text: 'I', isCompleted: false});
      await setDoc(doc(db, `${E}/expenses/x1`), {payerId: 'member', amount: 1});
    });
  const member = () => env.authenticatedContext('member').firestore();
  const newTask = {eventId: 'evtMod', title: 'New', createdBy: 'member'};

  test('an organizer can turn a module off, and a member cannot', async () => {
    await seed();
    await assertFails(updateDoc(doc(member(), E), {modules: {chat: false}}));
    const owner = env.authenticatedContext('owner').firestore();
    await assertSucceeds(updateDoc(doc(owner, E), {modules: {chat: false}}));
    await assertFails(updateDoc(doc(owner, E), {modules: 'none'}));
  });

  test('with chat off, nobody can send, and messages can still be read', async () => {
    await seed({chat: false});
    await assertFails(setDoc(doc(member(), `${E}/messages/new`), {senderId: 'member', text: 'Hi'}));
    await assertFails(deleteDoc(doc(member(), `${E}/messages/m1`)));
    await assertSucceeds(getDoc(doc(member(), `${E}/messages/m1`)));
  });

  test('with tasks off, nobody can change tasks', async () => {
    await seed({tasks: false});
    await assertFails(setDoc(doc(member(), `${E}/tasks/new`), newTask));
    await assertFails(updateDoc(doc(member(), `${E}/tasks/t1`), {title: 'E'}));
    await assertFails(deleteDoc(doc(member(), `${E}/tasks/t1`)));
    await assertFails(updateDoc(doc(member(), `${E}/tasks/t1/checklist/c1`), {isCompleted: true}));
  });

  test('with budget off, expenses cannot be deleted', async () => {
    await seed({budget: false});
    await assertFails(deleteDoc(doc(member(), `${E}/expenses/x1`)));
  });

  test.each([[undefined], [{chat: true, tasks: true, budget: true}], [{budget: false}]])(
    'other modules keep working with %j',
    async (modules) => {
      await seed(modules);
      await assertSucceeds(setDoc(doc(member(), `${E}/messages/new`), {senderId: 'member', text: 'Hi'}));
      await assertSucceeds(setDoc(doc(member(), `${E}/tasks/new`), newTask));
    },
  );
});

describe('organizers — written only by the server', () => {
  const O = 'organizers/me';
  const seed = () =>
    env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), O), {ownerId: 'me', verified: false});
    });

  test('the owner can read their organizer, and nobody else can', async () => {
    await seed();
    await assertSucceeds(getDoc(doc(env.authenticatedContext('me').firestore(), O)));
    await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(), O)));
  });

  test('nobody can verify themselves, or create an organizer', async () => {
    await seed();
    const db = env.authenticatedContext('me').firestore();
    await assertFails(updateDoc(doc(db, O), {verified: true}));
    await assertFails(setDoc(doc(db, 'organizers/new'), {ownerId: 'new', verified: true}));
  });
});

describe('events create — only the createEvent callable', () => {
  test('a client cannot create an event directly, even as its owner', async () => {
    const db = env.authenticatedContext('me').firestore();
    await assertFails(
      setDoc(doc(db, 'events/direct'), {
        creatorId: 'me',
        adminIds: ['me'],
        memberIds: ['me'],
        title: 'Direct',
      })
    );
  });

  test('a client cannot create an event listing a stranger', async () => {
    const db = env.authenticatedContext('me').firestore();
    await assertFails(
      setDoc(doc(db, 'events/stranger'), {
        creatorId: 'me',
        adminIds: ['me'],
        memberIds: ['me', 'stranger'],
        title: 'With a stranger',
      })
    );
  });
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

describe('tasks — who may edit, and completion only through markTaskComplete', () => {
  const E = 'events/evtTP';
  const T = `${E}/tasks/t1`;
  const as = (uid: string) => env.authenticatedContext(uid).firestore();

  async function seed(task: object = {}) {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, E), {
        creatorId: 'owner',
        adminIds: ['owner', 'admin'],
        memberIds: ['owner', 'admin', 'creator', 'assignee', 'member'],
      });
      await setDoc(doc(db, T), {
        eventId: 'evtTP',
        createdBy: 'creator',
        assigneeId: 'assignee',
        title: 'Buy snacks',
        status: 'todo',
        ...task,
      });
      await setDoc(doc(db, `${T}/checklist/c1`), {text: 'Chips', isCompleted: false});
    });
  }

  test.each(['owner', 'admin', 'creator'])('%s may edit any task field', async (uid) => {
    await seed();
    await assertSucceeds(
      updateDoc(doc(as(uid), T), {title: 'New', assigneeId: 'member', status: 'in_progress'})
    );
  });

  test('another member may not edit', async () => {
    await seed();
    await assertFails(updateDoc(doc(as('member'), T), {title: 'New'}));
    await assertFails(updateDoc(doc(as('member'), T), {status: 'in_progress'}));
  });

  test('an assignee may change status', async () => {
    await seed();
    await assertSucceeds(updateDoc(doc(as('assignee'), T), {status: 'in_progress'}));
  });

  test.each([
    ['title', {title: 'New'}],
    ['description', {description: 'New'}],
    ['assignee', {assigneeId: 'member'}],
    ['due date', {dueDate: null}],
    ['status and title together', {status: 'in_progress', title: 'New'}],
  ])('an assignee may not change %s', async (_name, change) => {
    await seed();
    await assertFails(updateDoc(doc(as('assignee'), T), change));
  });

  test('an assignee may tick a checklist item, and not rewrite it', async () => {
    await seed();
    const item = doc(as('assignee'), `${T}/checklist/c1`);
    await assertSucceeds(updateDoc(item, {isCompleted: true}));
    await assertFails(updateDoc(item, {text: 'Changed'}));
  });

  test('the creator may rewrite a checklist item', async () => {
    await seed();
    await assertSucceeds(updateDoc(doc(as('creator'), `${T}/checklist/c1`), {text: 'Changed'}));
  });

  test.each(['owner', 'admin', 'creator', 'assignee'])(
    '%s cannot mark a task done directly',
    async (uid) => {
      await seed();
      await assertFails(updateDoc(doc(as(uid), T), {status: 'done'}));
    }
  );

  test.each(['owner', 'creator', 'assignee'])('%s cannot write completion fields', async (uid) => {
    await seed();
    await assertFails(updateDoc(doc(as(uid), T), {completedBy: uid}));
    await assertFails(updateDoc(doc(as(uid), T), {completedAt: new Date()}));
    await assertFails(
      updateDoc(doc(as(uid), T), {status: 'in_progress', completedBy: uid})
    );
  });

  test('completion cannot be rewritten on a finished task', async () => {
    await seed({status: 'done', completedBy: 'assignee', completedAt: new Date(0)});
    await assertFails(updateDoc(doc(as('owner'), T), {completedBy: 'owner'}));
    await assertFails(updateDoc(doc(as('owner'), T), {completedBy: null}));
  });

  test('a finished task can be reopened, which clears completion', async () => {
    await seed({status: 'done', completedBy: 'assignee', completedAt: new Date(0)});
    await assertSucceeds(
      updateDoc(doc(as('assignee'), T), {status: 'todo', completedAt: null, completedBy: null})
    );
  });

  test('a finished task can still be edited', async () => {
    await seed({status: 'done', completedBy: 'assignee', completedAt: new Date(0)});
    await assertSucceeds(updateDoc(doc(as('creator'), T), {title: 'New'}));
  });

  test('any member may create a task, but not a finished one', async () => {
    await seed();
    const base = {eventId: 'evtTP', createdBy: 'member', title: 'New'};
    const ref = (id: string) => doc(as('member'), `${E}/tasks/${id}`);
    await assertSucceeds(
      setDoc(ref('a'), {...base, status: 'todo', completedAt: null, completedBy: null})
    );
    await assertFails(setDoc(ref('b'), {...base, status: 'done'}));
    await assertFails(setDoc(ref('c'), {...base, status: 'todo', completedBy: 'member'}));
    await assertFails(setDoc(ref('d'), {...base, status: 'todo', completedAt: new Date()}));
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

describe('expenses create and update — only the saveExpense and recordSettlement callables write them', () => {
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

  test('payer cannot update directly', async () => {
    await seed();
    const payerCtx = env.authenticatedContext(payerUid);
    await assertFails(
      updateDoc(
        doc(payerCtx.firestore(), `events/${eventId}/expenses/${expenseId}`),
        {amount: 50, description: 'Edited'}
      )
    );
  });

  test('event creator cannot update directly', async () => {
    await seed();
    const creatorCtx = env.authenticatedContext(creatorUid);
    await assertFails(
      updateDoc(
        doc(creatorCtx.firestore(), `events/${eventId}/expenses/${expenseId}`),
        {description: 'Creator edit'}
      )
    );
  });

  test('event admin cannot update directly', async () => {
    await seed();
    const adminCtx = env.authenticatedContext(adminUid);
    await assertFails(
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

  test('a member cannot create a non-payment expense directly', async () => {
    await seed();
    const payerCtx = env.authenticatedContext(payerUid);
    const ref = doc(payerCtx.firestore(), `events/${eventId}/expenses/forged`);
    await assertFails(setDoc(ref, {eventId, payerId: payerUid, amount: -500, isPayment: false}));
    await assertFails(setDoc(ref, {eventId, payerId: payerUid, amount: 5}));
  });

  test('a member cannot create a settlement payment directly', async () => {
    await seed();
    const payerCtx = env.authenticatedContext(payerUid);
    const ref = doc(payerCtx.firestore(), `events/${eventId}/expenses/pay`);
    await assertFails(setDoc(ref, {eventId, payerId: payerUid, amount: 5, isPayment: true}));
  });

  test('a member cannot forge a notice, but can send a normal message', async () => {
    await seed();
    const db = env.authenticatedContext(payerUid).firestore();
    const message = {senderId: payerUid, text: 'hi', isHighPriority: false};
    await assertSucceeds(setDoc(doc(db, `events/${eventId}/messages/ok`), message));
    for (const kind of ['settlement', 'settlement_disputed', 'normal', null]) {
      await assertFails(setDoc(doc(db, `events/${eventId}/messages/forged`), {...message, kind}));
    }
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

describe('removed members lose write access', () => {
  const E = 'events/evRemoved';
  const T = `${E}/tasks`;

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, E), {
        creatorId: 'owner',
        memberIds: ['owner', 'current'],
        adminIds: ['owner'],
        title: 'Event',
      });
      for (const uid of ['gone', 'current']) {
        await setDoc(doc(db, `${E}/expenses/${uid}Exp`), {
          eventId: 'evRemoved',
          payerId: uid,
          amount: 10,
        });
        await setDoc(doc(db, `${E}/messages/${uid}Msg`), {
          senderId: uid,
          text: 'hi',
        });
        await setDoc(doc(db, `${T}/${uid}Assigned`), {
          eventId: 'evRemoved',
          createdBy: 'owner',
          assigneeId: uid,
          title: 'x',
        });
        await setDoc(doc(db, `${T}/${uid}Created`), {
          eventId: 'evRemoved',
          createdBy: uid,
          assigneeId: 'owner',
          title: 'x',
        });
        await setDoc(doc(db, `${T}/${uid}Assigned/checklist/c1`), {done: false});
        await setDoc(doc(db, `${T}/${uid}Created/checklist/c1`), {done: false});
      }
    });
  });

  const as = (uid: string) => env.authenticatedContext(uid).firestore();

  test.each([
    ['delete their old expense', (u: string) => deleteDoc(doc(as(u), `${E}/expenses/${u}Exp`))],
    ['delete their old message', (u: string) => deleteDoc(doc(as(u), `${E}/messages/${u}Msg`))],
    ['change status on a task assigned to them', (u: string) => updateDoc(doc(as(u), `${T}/${u}Assigned`), {status: 'in_progress'})],
    ['delete a task they created', (u: string) => deleteDoc(doc(as(u), `${T}/${u}Created`))],
    ['toggle a checklist item on an assigned task', (u: string) => updateDoc(doc(as(u), `${T}/${u}Assigned/checklist/c1`), {isCompleted: true})],
    ['add a checklist item to a task they created', (u: string) => setDoc(doc(as(u), `${T}/${u}Created/checklist/c2`), {done: false})],
    ['delete a checklist item from a task they created', (u: string) => deleteDoc(doc(as(u), `${T}/${u}Created/checklist/c1`))],
  ])('%s: denied once removed, allowed while a member', async (_name, write) => {
    await assertFails(write('gone'));
    await assertSucceeds(write('current'));
  });
});
