/**
 * Spec #233 Req 51, 51a: clients, signed in or not, cannot read or write the
 * email outbox, its delivery log or the server mail settings.
 */
import {RulesTestEnvironment, assertFails} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, setDoc} from 'firebase/firestore';
import {getTestEnv} from '../setup';

let env: RulesTestEnvironment;
beforeAll(async () => {
  env = await getTestEnv();
});
beforeEach(async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'mailOutbox/m1'), {to: 'a@b.co', uid: 'u1', status: 'sent'});
    await setDoc(doc(ctx.firestore(), 'serverConfig/mail'), {deliveryEnabled: true});
  });
});
afterEach(() => env.clearFirestore());
afterAll(() => env.cleanup());

describe('mail rules', () => {
  for (const who of ['signed out', 'recipient', 'someone else'] as const) {
    test(`${who} cannot read or write the outbox or mail settings`, async () => {
      const db = who === 'signed out' ? env.unauthenticatedContext().firestore() :
        env.authenticatedContext(who === 'recipient' ? 'u1' : 'u2').firestore();
      await assertFails(getDoc(doc(db, 'mailOutbox/m1')));
      await assertFails(getDocs(collection(db, 'mailOutbox')));
      await assertFails(setDoc(doc(db, 'mailOutbox/m2'), {to: 'x@y.z', template: 'deliveryCheck', status: 'queued'}));
      await assertFails(getDoc(doc(db, 'serverConfig/mail')));
      await assertFails(setDoc(doc(db, 'serverConfig/mail'), {deliveryEnabled: false}));
    });
  }
});
