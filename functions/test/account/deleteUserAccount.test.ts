/**
 * Phase 3 tests for `deleteUserAccount`:
 * - Unit-level: `deleteAuthUserWithRetry` retry semantics (3 attempts,
 *   linear backoff, exhaustion throws the underlying error).
 * - Integration: auth-stage retry exhaustion surfaces a typed
 *   `HttpsError` with `details.stage = 'auth'` and
 *   `details.code = 'auth-delete-failed'` against the local emulator.
 *
 * Happy-path coverage (solo + shared events) lives in
 * `functions/test/cloud-functions.test.ts` and is intentionally not
 * duplicated here — those tests already prove the post-refactor
 * function returns `{success: true}`.
 */
import {clearFirestoreEmulator, getAdminApp, getAdminDb} from "../setup";

// eslint-disable-next-line @typescript-eslint/no-var-requires
const firebaseFunctionsTest = require("firebase-functions-test");
const ftest = firebaseFunctionsTest();

// Eager-init Admin SDK before requiring the CF source — the module
// calls `admin.firestore()` at load time, which otherwise throws
// "default app does not exist".
getAdminApp();

/* eslint-disable @typescript-eslint/no-var-requires */
const {
  deleteUserAccount,
  deleteAuthUserWithRetry,
} = require("../../src/account/deleteUserAccount");
/* eslint-enable @typescript-eslint/no-var-requires */

afterEach(async () => {
  await clearFirestoreEmulator();
});

afterAll(() => {
  ftest.cleanup();
});

describe("deleteAuthUserWithRetry (unit)", () => {
  test("returns immediately when the deleter succeeds on the first attempt", async () => {
    let callCount = 0;
    await deleteAuthUserWithRetry(
      "u1",
      async () => {
        callCount++;
      },
      {attempts: 3, backoffMs: 0}
    );
    expect(callCount).toBe(1);
  });

  test("succeeds on attempt 3 after two transient failures", async () => {
    let callCount = 0;
    await deleteAuthUserWithRetry(
      "u1",
      async () => {
        callCount++;
        if (callCount < 3) throw new Error("transient");
      },
      {attempts: 3, backoffMs: 0}
    );
    expect(callCount).toBe(3);
  });

  test(
    "exhausts all attempts and rethrows the underlying error when every " +
      "attempt fails",
    async () => {
      let callCount = 0;
      const failure = new Error("permanent");
      await expect(
        deleteAuthUserWithRetry(
          "u1",
          async () => {
            callCount++;
            throw failure;
          },
          {attempts: 3, backoffMs: 0}
        )
      ).rejects.toBe(failure);
      expect(callCount).toBe(3);
    }
  );

  test("respects the configured attempt budget", async () => {
    let callCount = 0;
    await expect(
      deleteAuthUserWithRetry(
        "u1",
        async () => {
          callCount++;
          throw new Error("nope");
        },
        {attempts: 2, backoffMs: 0}
      )
    ).rejects.toBeDefined();
    expect(callCount).toBe(2);
  });
});

describe("deleteUserAccount auth-stage retry exhaustion (integration)", () => {
  test(
    "throws HttpsError with details.stage='auth' and " +
      "details.code='auth-delete-failed' when the user has no Firebase " +
      "Auth record (retry budget exhausts on user-not-found)",
    async () => {
      // No auth user exists; Firestore wipe is a no-op (no events, no
      // user doc); storage is empty (no files). The auth stage throws
      // `auth/user-not-found` on every attempt. After 3 retries the
      // function surfaces the typed error.
      const uid = "noAuthUserAtAll";
      const wrapped = ftest.wrap(deleteUserAccount);

      await expect(
        wrapped({auth: {uid}, data: {}})
      ).rejects.toMatchObject({
        code: "internal",
        details: {stage: "auth", code: "auth-delete-failed"},
      });
    },
    /* timeout: defaults are fine — retry backoff is 3 × 250 ms = 750 ms. */
    5000
  );

  test(
    "auth-stage failure leaves no orphaned Firestore data — the " +
      "Firestore stage runs to completion before the auth stage is " +
      "reached, and retry exhaustion does not roll Firestore back",
    async () => {
      // Seed a user doc so we can verify it gets wiped before the auth
      // stage fails. There is no auth user, so the auth stage will
      // exhaust its retries and throw.
      const uid = "userWithDocButNoAuth";
      const db = getAdminDb();
      await db.collection("users").doc(uid).set({displayName: "Orphan"});
      await db
        .collection("users")
        .doc(uid)
        .collection("private")
        .doc("profile")
        .set({email: "orphan@example.com"});

      const wrapped = ftest.wrap(deleteUserAccount);

      await expect(
        wrapped({auth: {uid}, data: {}})
      ).rejects.toMatchObject({
        code: "internal",
        details: {stage: "auth"},
      });

      // Firestore wipes happened despite the auth-stage failure —
      // that is the whole point of the typed error: the client knows
      // the auth retry is the only thing left to recover.
      const publicAfter = await db.collection("users").doc(uid).get();
      expect(publicAfter.exists).toBe(false);
      const privateAfter = await db
        .collection("users")
        .doc(uid)
        .collection("private")
        .doc("profile")
        .get();
      expect(privateAfter.exists).toBe(false);
    },
    5000
  );
});
