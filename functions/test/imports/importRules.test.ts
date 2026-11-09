/**
 * Req 44a: import jobs and files need `participants.import`. A client queues
 * a check, then queues the apply once the check is done; everything else on
 * a job is written by the server. The file lives in Storage under
 * `events/{id}/imports/`.
 */
import {readFileSync} from 'fs';
import {resolve} from 'path';
import {RulesTestEnvironment, assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, getDoc, serverTimestamp, setDoc, updateDoc} from 'firebase/firestore';
import {ref, uploadString, getBytes, deleteObject} from 'firebase/storage';
import {computePermissions} from '../../src/events/permissions';

let env: RulesTestEnvironment;
const E = 'events/conv';

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
    await setDoc(doc(db, E), {title: 'Convention', status: 'published', creatorId: 'owner', memberIds: ['owner', 'lead', 'plain']});
    for (const [uid, roles] of [['owner', ['owner']], ['lead', ['crewLead']], ['plain', ['participant']]] as const) {
      await setDoc(doc(db, `${E}/members/${uid}`), {uid, roleIds: roles, permissions: computePermissions([...roles], {})});
    }
    await setDoc(doc(db, `${E}/imports/done`), {status: 'checked', mode: 'dryRun', targets: ['name'], createdBy: 'owner', fileName: 'a.csv'});
    await setDoc(doc(db, `${E}/participants/p1`), {
      name: 'Ana', sortName: 'ana', groupId: null, isChild: false, status: 'active', createdBy: 'owner', imported: true,
    });
  });
});

const as = (uid: string) => env.authenticatedContext(uid);
const newJob = (uid: string, over: object = {}) => ({
  fileName: 'roster.csv', targets: ['name', 'group'], header: ['Name', 'Group'],
  mode: 'dryRun', status: 'queued', createdBy: uid, createdAt: serverTimestamp(), ...over,
});

describe('import jobs', () => {
  test('participants.import queues a check, and reads jobs', async () => {
    await assertSucceeds(setDoc(doc(as('owner').firestore(), `${E}/imports/j1`), newJob('owner')));
    await assertSucceeds(getDoc(doc(as('owner').firestore(), `${E}/imports/done`)));
    // A crew lead edits people but does not import.
    await assertFails(setDoc(doc(as('lead').firestore(), `${E}/imports/j1`), newJob('lead')));
    await assertFails(getDoc(doc(as('lead').firestore(), `${E}/imports/done`)));
  });

  test('a job starts queued, by its creator, with nothing else', async () => {
    const db = as('owner').firestore();
    await assertFails(setDoc(doc(db, `${E}/imports/j1`), newJob('owner', {status: 'done'})));
    await assertFails(setDoc(doc(db, `${E}/imports/j1`), newJob('lead')));
    await assertFails(setDoc(doc(db, `${E}/imports/j1`), newJob('owner', {report: {}})));
    await assertFails(setDoc(doc(db, `${E}/imports/j1`), newJob('owner', {mode: 'wipe'})));
  });

  test('once checked, it can be queued again to apply, and nothing more', async () => {
    const db = as('owner').firestore();
    await assertSucceeds(updateDoc(doc(db, `${E}/imports/done`), {mode: 'apply', status: 'queued'}));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), `${E}/imports/done`), {status: 'checked'});
    });
    await assertFails(updateDoc(doc(db, `${E}/imports/done`), {status: 'done'}));
    await assertFails(updateDoc(doc(db, `${E}/imports/done`), {report: {valid: 1000}}));
  });
});

describe('imported people', () => {
  test('the imported flag is the server’s, and edits keep it', async () => {
    const db = as('owner').firestore();
    await assertSucceeds(updateDoc(doc(db, `${E}/participants/p1`), {name: 'Anaya', sortName: 'anaya'}));
    await assertFails(updateDoc(doc(db, `${E}/participants/p1`), {imported: false}));
    await assertFails(setDoc(doc(db, `${E}/participants/p2`), {
      name: 'Bo', sortName: 'bo', groupId: null, isChild: false, status: 'active', createdBy: 'owner', imported: true,
    }));
  });

  test('an imported email can sit with the private details', async () => {
    const db = as('owner').firestore();
    await assertSucceeds(setDoc(doc(db, `${E}/participants/p1/private/details`), {
      birthDate: null, email: 'ana@x.test', fields: {},
    }));
  });
});

describe('import files', () => {
  test('participants.import uploads, reads and deletes a CSV', async () => {
    const file = ref(as('owner').storage(), `${E}/imports/j1.csv`);
    await assertSucceeds(uploadString(file, 'Name\nAna\n'));
    await assertSucceeds(getBytes(file));
    await assertSucceeds(deleteObject(file));
  });

  test('nobody else can, and only CSV names under 5 MB', async () => {
    await assertFails(uploadString(ref(as('lead').storage(), `${E}/imports/j1.csv`), 'Name\n'));
    await assertFails(uploadString(ref(as('plain').storage(), `${E}/imports/j1.csv`), 'Name\n'));
    await assertFails(uploadString(ref(as('owner').storage(), `${E}/imports/../x.csv`), 'Name\n'));
    await assertFails(uploadString(ref(as('owner').storage(), `${E}/imports/j1.exe`), 'Name\n'));
  });
});
