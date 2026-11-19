/**
 * Spec #186 Req 41, 42 (ledger L12): an event's cover photo in Storage, at
 * `events/{id}/cover.jpg`, for each of the twelve preset roles. Everyone in
 * the event reads it; only `event.manage` holders upload, replace and
 * delete it; outsiders and signed-out users do nothing; a file of 5 MB or
 * more, or a non-image, is refused. The event's `cover` field names only
 * that file. Built like `imports/importRules.test.ts`.
 */
import {readFileSync} from 'fs';
import {resolve} from 'path';
import {RulesTestEnvironment, assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, serverTimestamp, setDoc, updateDoc} from 'firebase/firestore';
import {ref, uploadBytes, getBytes, deleteObject} from 'firebase/storage';
import {PRESET_ROLES, computePermissions} from '../../src/events/permissions';

let env: RulesTestEnvironment;
const E = 'events/conv';
const COVER = `${E}/cover.jpg`;
const ROLES = Object.keys(PRESET_ROLES);
const MANAGERS = new Set(['owner', 'coOwner', 'admin']);
const jpeg = {contentType: 'image/jpeg'};
const small = () => new Uint8Array(1024);

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-crewpoint',
    firestore: {
      rules: readFileSync(resolve(__dirname, '../../../firestore.rules'), 'utf8'),
      host: 'localhost', port: 8080,
    },
    storage: {
      rules: readFileSync(resolve(__dirname, '../../../storage.rules'), 'utf8'),
      host: 'localhost', port: 9199,
    },
  });
});
afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, E), {
      title: 'Convention', status: 'published', creatorId: 'owner',
      memberIds: ROLES, adminIds: ['owner', 'coOwner', 'admin'],
    });
    for (const role of ROLES) {
      await setDoc(doc(db, `${E}/members/${role}`), {
        uid: role, roleIds: [role], permissions: computePermissions([role], {}),
      });
    }
    await uploadBytes(ref(ctx.storage(), COVER), small(), jpeg);
  });
});

const as = (uid: string) => env.authenticatedContext(uid);

test('the managers are exactly the roles holding event.manage', () => {
  for (const role of ROLES) {
    expect(PRESET_ROLES[role].permissions.includes('event.manage')).toBe(MANAGERS.has(role));
  }
});

describe.each(ROLES)('%s', (role) => {
  test('reads the cover', async () => {
    await assertSucceeds(getBytes(ref(as(role).storage(), COVER)));
  });

  test(MANAGERS.has(role) ? 'uploads, replaces and deletes it' : 'cannot upload, replace or delete it', async () => {
    const file = ref(as(role).storage(), COVER);
    const check = MANAGERS.has(role) ? assertSucceeds : assertFails;
    await check(uploadBytes(file, small(), jpeg));
    await check(uploadBytes(file, small(), {contentType: 'image/png'}));
    await check(deleteObject(file));
  });
});

test('outsiders and signed-out visitors do nothing', async () => {
  for (const ctx of [as('stranger'), env.unauthenticatedContext()]) {
    const file = ref(ctx.storage(), COVER);
    await assertFails(getBytes(file));
    await assertFails(uploadBytes(file, small(), jpeg));
    await assertFails(deleteObject(file));
  }
});

test('only JPEG, PNG or WebP under 5 MB', async () => {
  const file = ref(as('owner').storage(), COVER);
  await assertSucceeds(uploadBytes(file, small(), {contentType: 'image/webp'}));
  await assertFails(uploadBytes(file, new Uint8Array(5 * 1024 * 1024), jpeg));
  await assertFails(uploadBytes(file, small(), {contentType: 'image/gif'}));
  await assertFails(uploadBytes(file, small(), {contentType: 'text/plain'}));
  // Only the one cover file: nothing else under the event.
  await assertFails(uploadBytes(ref(as('owner').storage(), `${E}/other.jpg`), small(), jpeg));
});

describe('the cover field', () => {
  test('event.manage names the event’s own cover file', async () => {
    const db = as('owner').firestore();
    await assertSucceeds(updateDoc(doc(db, E), {
      cover: {path: COVER, updatedAt: serverTimestamp()},
    }));
  });

  test('and nothing else', async () => {
    const db = as('owner').firestore();
    await assertFails(updateDoc(doc(db, E), {
      cover: {path: 'events/other/cover.jpg', updatedAt: serverTimestamp()},
    }));
    await assertFails(updateDoc(doc(db, E), {
      cover: {path: COVER, updatedAt: serverTimestamp(), url: 'https://x.test'},
    }));
    await assertFails(updateDoc(doc(db, E), {cover: {path: COVER, updatedAt: 'now'}}));
  });

  test('a plain member cannot set it', async () => {
    await assertFails(updateDoc(doc(as('participant').firestore(), E), {
      cover: {path: COVER, updatedAt: serverTimestamp()},
    }));
  });
});
