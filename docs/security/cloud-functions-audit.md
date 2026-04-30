# Cloud Functions Audit

**Scope**: every callable + trigger under `functions/src/` (10 functions total — 9 callables + 1 Firestore trigger).
**Test coverage**: `functions/test/cloud-functions.test.ts` — 35 emulator-driven integration tests, all green.

## Hardening pattern applied

Every callable now follows the same skeleton:

1. **Auth check** — `if (!request.auth) throw HttpsError("unauthenticated", ...)`. First gate.
2. **Input validation** — `requireString(value, fieldName)` from `functions/src/utils/logging.ts` rejects `undefined`, non-string, and empty-string with `HttpsError("invalid-argument", ...)`.
3. **Structured logging wrapper** — `withStructuredLogs({op, uid, args}, async () => ...)` emits a `start` log line with sanitized args and an `ok` / `fail` line carrying `elapsedMs` + canonical error code on the way out.
4. **Authorization checks** — function-specific (creator-only, admin-or-creator, payer-or-payee, etc.) with the canonical `HttpsError` code (`permission-denied` for actor mismatch, `failed-precondition` for invalid state).
5. **Idempotency notes** — every function's dartdoc-style header documents retry-safety. Most are convergent because they use `arrayUnion`/`arrayRemove` (no-op on second invocation) or set absolute target state.

The Firestore trigger (`onUrgentMessageCreated`) has no callable surface but uses the same logging pattern via direct `logger.info` calls (no auth/input gates required — events come from Firestore).

## Per-function findings

### `account/deleteUserAccount.ts`

- Auth + structured logging applied. Wrapper now captures elapsed-ms.
- Internal helpers (`deleteEventCompletely`, `anonymizeUserInEvent`) keep the upfront-ref-collection memory risk — **deferred to Phase 4** for the streaming pagination refactor.
- Cleanup ordering: subcollection (`users/{uid}/private/profile`) → user doc → storage files → auth user. Correct (Firestore doesn't cascade).
- Idempotency: re-runs are safe because the anonymization queries (`where senderId == uid`) converge on the same end state, and `arrayRemove` is idempotent.
- Error catalog: top-level `try/catch` re-throws `HttpsError`s and remaps everything else to `internal`.

### `events/deleteEvent.ts`

- Auth + input + structured logging applied.
- **Memory risk explicitly documented in the function header** — `getSubcollectionRefs()` collects all refs into memory before chunking; a 100k-message event would OOM 256 MiB. Deferred to Phase 4 streaming refactor.
- Caller-must-be-creator check in place. Idempotent on retry.

### `events/joinEvent.ts`

- Auth + input + structured logging applied. `requireString` enforces type; explicit length-6 check stays.
- Rejection codes: missing code → `not-found`; expired code → `not-found` (with code-cleanup side effect); event deleted → `not-found`; already-member → `already-exists`; full → `resource-exhausted`. All canonical.
- Tests cover all four rejection paths + happy path.

### `events/removeEventMember.ts`

- Auth + input + structured logging applied.
- Authorization: caller must be admin/creator OR removing themselves (leave-event). `permission-denied` otherwise.
- Owner-cannot-be-removed check uses `failed-precondition`.
- `arrayRemove` is idempotent; retry-safe.

### `events/promoteToAdmin.ts`

- Auth + input + structured logging applied.
- Creator-only authorization. Target-must-be-member check uses `failed-precondition`.
- Idempotent via `arrayUnion`.

### `events/demoteAdmin.ts`

- Auth + input + structured logging applied.
- **New behavior shipped this phase**: refuses to demote the last remaining admin with `failed-precondition` (TDD-driven; see test `refuses to demote the last remaining admin`).
- Creator-only authorization. Owner-cannot-be-demoted + target-must-be-admin checks both use `failed-precondition`.
- Idempotent via `arrayRemove`.

### `events/markTaskComplete.ts`

- Auth + input + structured logging applied.
- Authorization: owner / admin / assignee. `permission-denied` otherwise.
- Missing-event and missing-task both use `not-found`.
- Idempotent on retry: a re-run will re-stamp `completedAt`/`completedBy` to the second invocation's values (acceptable for V1 — no audit trail).

### `events/disputeSettlement.ts`

- Auth + input + structured logging applied.
- Three-stage validation: settlement exists (`not-found`), is-payment guard (`failed-precondition`), payer/payee identity (`failed-precondition`).
- Caller authorization: payer or payee only (`permission-denied` otherwise).
- Idempotent: chat notice has same id as the deleted expense; `noticeRef.set(...)` with `merge: true` means the second run overwrites the same fields.

### `events/generateInviteCode.ts`

- Auth + input + structured logging applied.
- Admin-or-creator authorization (`permission-denied` otherwise).
- Single-active-code invariant: existing codes for the event are deleted in the same batch as the new code's write.
- Code generation: 6-char from a non-ambiguous charset (`A-Z` minus `O,I,L` + `2-9`); collision-retry up to 10 attempts then `internal`. 24h expiry.
- Idempotent: a retry generates a different code (`Math.random()`), but the existing-codes purge means at most one active code per event at any time.

### `events/onUrgentMessageCreated.ts` (Firestore trigger, not callable)

- **Important fix shipped this phase**: reads `fcmTokens` from `users/{uid}/private/profile` (post Fix 1.B Option A) instead of the public `users/{uid}` doc. Token pruning writes to the same private subdoc. Without this, the trigger would have read `undefined` for every member's tokens after Phase 2 deployed and silently sent zero pushes.
- `retry: false` on the trigger so a transient failure doesn't double-send urgent push notifications.
- Logging: structured-style fields used in `logger.info` / `logger.warn` already.

## HttpsError code catalog

Every `throw new HttpsError(...)` audited against the [Firebase callable error catalog](https://firebase.google.com/docs/reference/functions/2nd-gen/node/firebase-functions.https.functionserrorcode):

| Code | Used for |
| --- | --- |
| `unauthenticated` | `request.auth` is null |
| `invalid-argument` | `request.data` shape failed `requireString` or other field validation |
| `permission-denied` | Authenticated caller lacks the role required for the op |
| `not-found` | Target document (event, task, settlement, invite code) doesn't exist |
| `failed-precondition` | Target exists but is in a state that blocks the op (last admin, owner-target, missing payer/payee data, target-not-an-admin, etc.) |
| `already-exists` | `joinEvent` only — caller is already a member |
| `resource-exhausted` | `joinEvent` only — `MAX_MEMBERS` cap hit |
| `internal` | Caught non-HttpsError exception or `generateInviteCode` collision-retry exhaustion |

No deprecated or non-canonical codes in use.

## Test surface

`functions/test/cloud-functions.test.ts` covers:

- **Auth-failure** — `test.each` over all 8 callables × no-auth → `unauthenticated`. (8 tests)
- **Invalid-argument** — `test.each` over all 8 callables × missing-input → `invalid-argument`. (8 tests)
- **Per-callable function tests** — 19 tests covering authorization rejection + happy path + edge cases (last-admin demote, expired join codes, missing target events, settlement dispute side effects, deleteEvent subcollection cascade).

35 tests total; all green via `firebase-functions-test` v3 online mode + Admin SDK pointed at the Firestore emulator.

## Out of scope (tracked for follow-ups)

- **Streaming pagination refactor** of `deleteEvent` and `deleteUserAccount` — Phase 4 of this plan.
- **Per-uid rate limiting** for callables that accept user input (`joinEvent`, `generateInviteCode`). Firebase's default per-project quotas stand for V1; revisit if abuse data warrants per-uid quotas.
- **Audit-trail logging** for membership changes (`promoteToAdmin`, `demoteAdmin`, `removeEventMember`). Currently only written to Cloud Logging. A separate Firestore audit collection is a separate spec.
- **JSON-schema validation** of `request.data` payloads. The current `requireString` guards are sufficient for V1; adding zod/yup inflates cold-start cost.

## Sign-off checkpoint

This audit reflects the function code at the SHA at which Phase 3 commits land. Re-run `npm --prefix functions test` after any function edit and update the test count above.
