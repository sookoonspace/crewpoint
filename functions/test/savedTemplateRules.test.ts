/**
 * Req 65: saved templates belong to the user who created them. Only they
 * read them, and only `saveAsTemplate` writes them.
 */
import {RulesTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {collection, deleteDoc, doc, getDocs, setDoc} from 'firebase/firestore';
import {getTestEnv} from './setup';

let env: RulesTestEnvironment;
beforeAll(async () => {
  env = await getTestEnv();
});
afterEach(() => env.clearFirestore());
afterAll(() => env.cleanup());

const as = (uid: string) => env.authenticatedContext(uid).firestore();

beforeEach(() => env.withSecurityRulesDisabled((ctx) =>
  setDoc(doc(ctx.firestore(), 'users/ana/templates/t1'), {name: {en: 'Ours'}})));

test('only the owner reads their templates', async () => {
  await assertSucceeds(getDocs(collection(as('ana'), 'users/ana/templates')));
  await assertFails(getDocs(collection(as('bo'), 'users/ana/templates')));
});

test('nobody writes them from the app, though the owner may delete one', async () => {
  await assertFails(setDoc(doc(as('ana'), 'users/ana/templates/t2'), {name: {en: 'Forged'}}));
  await assertFails(deleteDoc(doc(as('bo'), 'users/ana/templates/t1')));
  await assertSucceeds(deleteDoc(doc(as('ana'), 'users/ana/templates/t1')));
});
