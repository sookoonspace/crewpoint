<goal>
Fix the account-delete flow so the user moves cleanly through warn → re-auth → process → /auth gate, the server-side deletion completes atomically (Firestore → Storage → Auth — in that order), and the user never lands on GoRouter's default "page with route blob + Home link" error widget. Refactor the dialog state machine to remove the auth-listener race, confirm and harden the server-side ordering, and back the flow with widget + Cloud Function tests so this can't regress.

**Why now.** Pre-launch the delete-account path is the legal hatch (privacy-policy and Terms both promise it). The reporter observed the bug on iOS — the dialog appears to skip the re-auth step, replaces itself with GoRouter's `_DefaultRouterError` page (a routing-blob + "Home" link), and the Firebase Console shows the user's Firestore docs + Storage gone but the Firebase Auth user still alive — a phantom-account state we cannot ship. Cross-platform reproduction is unverified; Phase 1 explicitly tests web + Android too before scoping the fix to a single platform.

**Who benefits.** Every user exercising the delete-account legal hatch — and the support load post-launch (no orphaned half-deleted accounts to triage). Privacy-policy compliance depends on the deletion actually completing.
</goal>

<background>
**Stack.** Flutter 3.27+ / Dart 3.11.5 / Riverpod 3.0 / Firebase Auth + Cloud Functions v2 (Node 20). Cloud Function emulator + `firebase-functions-test` v3 already configured under `functions/test/`.

**Current implementation (intent vs. observed).**

`lib/app/features/profile/presentation/widgets/delete_account_dialog.dart` (`DeleteAccountDialog`) — 4-step state machine:
- step 0: warning copy + Cancel/Continue
- step 1: re-auth (password field for email; provider button for Google/Apple)
- step 2: processing (Lottie loader, "Deleting your account...")
- step 3: success (Lottie checkmark, 2-second `Future.delayed` then `Navigator.pop` + `widget.onDeleted?.call()`)

`lib/app/core/services/account_deletion_service.dart` (`AccountDeletionService`):
- `currentAuthProvider` reads `_firebaseAuth.currentUser.providerData` to pick `email` / `google` / `apple` / `unknown`
- `reAuthenticateWithEmail|Google|Apple` — wraps Firebase's `reauthenticateWithCredential` / `reauthenticateWithProvider`
- `executeAccountDeletion` — calls the `deleteUserAccount` callable, then `_clearLocalData()` (Drift wipe + secure-storage `deleteAll`)

`lib/app/features/profile/presentation/profile_screen.dart` `_DangerCard` `onTap`:
```dart
DeleteAccountDialog.show(
  context: context,
  onDeleted: () {
    ref.read(onboardingProvider.notifier).completeOnboarding();
    if (context.mounted) {
      context.go(AppRoutes.auth);
    }
  },
);
```

`functions/src/account/deleteUserAccount.ts` server sequence today:
1. Reject unauthenticated callers (`request.auth` guard)
2. For each event the user is in:
   - Solo event (memberIds ≤ 1) → hard-delete event + subcollections (`messages`, `expenses`, `tasks`)
   - Shared event → anonymize messages/expenses (`senderId`/`payerId` → `'deleted_user'`), unassign tasks, transfer ownership to first remaining admin
3. Delete `users/{uid}/private/profile`
4. Delete `users/{uid}`
5. Delete user's Storage folder (`users/{uid}/`) — wrapped in `try/catch`, only logs a warning on failure
6. `await auth.deleteUser(uid)` — **no retry, raw call**
7. Return `{success: true}`

That ordering matches the user's stated correct sequence and stays intact in this spec. The bug is not the order — it is the lack of retry on step 6, the lack of typed-error contract per stage, the client-side state-machine race after the auth user gets deleted, and the missing GoRouter `errorBuilder`.

`lib/app/core/router/app_router.dart` defines `createRouter` with redirect logic but **no `errorBuilder`**. When GoRouter cannot match a location it falls through to Flutter's default `_DefaultRouterError` widget — a route-debug blob with a "Home" link. That is exactly the "page with bunch of code and Home link" the user observed on iOS.

**Observed iOS symptoms (from the user).**
1. User taps Profile → Danger Zone → Delete Account → warning step shows.
2. User taps Continue. Re-auth step (step 1) **does not appear** (per user recall).
3. User lands on the GoRouter error widget (route blob + Home link).
4. Firebase Console shows partial deletion: Firestore docs and Storage files deleted, but the Firebase Auth user still exists.

**Reconciling the contradiction.** The dialog source (`delete_account_dialog.dart`) only fires the Cloud Function from `_reAuthAndDelete`, which is wired to step 1's "Delete Forever" button. So a partial deletion is impossible without the user reaching step 1. There are three reconciliations the investigation phase MUST distinguish (Requirement 1 names the test):
- **(A) Memory-fuzz**: user did see step 1 (the email-password field can read as a continuation of the warning) but doesn't recall it.
- **(B) Hidden call site**: a different code path invokes `httpsCallable('deleteUserAccount')` outside the dialog. (Today there is exactly one client call site at `account_deletion_service.dart:107`.)
- **(C) Two separate bugs**: the GoRouter error page and the partial deletion happened on different attempts; the user is collapsing two incidents into one report.

The current code has no retry on `auth.deleteUser` and no typed-error code per stage, so the client returns the function's generic `internal` error and never shows it because the dialog's parent context has been replaced by a router redirect by the time the error path runs. That diagnosis stands regardless of which reconciliation (A/B/C) explains the user's recall.

**Constraints.**
- UX must not regress on any platform (web, Android, iOS).
- All current 228 tests must stay green.
- No new packages required — `cloud_functions`, `firebase_auth`, Riverpod, and the existing CF-emulator harness cover the spec.
- Pre-launch: the orphaned-account population is effectively zero, so this spec deliberately does not handle pre-existing orphans (out of scope).
- Cross-platform reproduction is unverified; Phase 1 (Requirement 1) attempts reproduction on web + Android before any code changes. If the bug reproduces only on iOS, scope can narrow then.

**Files to examine before implementing:**
- @lib/app/features/profile/presentation/widgets/delete_account_dialog.dart
- @lib/app/core/services/account_deletion_service.dart
- @lib/app/features/profile/presentation/profile_screen.dart (lines 82–104 — `_DangerCard.onTap`)
- @lib/app/core/router/app_router.dart (no `errorBuilder`)
- @functions/src/account/deleteUserAccount.ts
- @functions/src/utils/batch.ts (`commitInChunks`, `streamDeleteSubcollection`)
- @functions/src/utils/logging.ts (`withStructuredLogs`)
- @test/app/features/auth/fake_auth_service.dart (re-auth fake reference)
- @lib/app/features/auth/application/auth_provider.dart (`AuthNotifier` — drives the auth-listener race)
</background>

<user_flows>
**Primary (happy path), iOS:**
1. Profile screen → scroll to Danger Zone → tap "Delete Account".
2. `DeleteAccountDialog` opens at step 0 (warning copy from privacy policy).
3. User taps "Continue" → step 1 (re-auth).
4. Email user: types password → taps "Delete Forever". OAuth user (Google/Apple): taps the provider tile → native sheet pops → user confirms.
5. Step 2 (processing — loader) shows. `executeAccountDeletion` calls the Cloud Function.
6. Cloud Function completes: Firestore wiped/anonymized, Storage wiped, Firebase Auth user deleted.
7. The deletion of the Auth user revokes the client token; `authStateChanges` fires `null`. `AuthNotifier` flips to `Unauthenticated`. `main.dart` watches `authProvider` and rebuilds `MaterialApp.router`. GoRouter's redirect (driven by `isAuthenticated = false`) routes the entire app to `/auth` — destroying the dialog as part of the route-stack reconciliation.
8. The dialog's `await executeAccountDeletion()` returns into a state where the dialog may already be unmounted. **All post-CF dialog code is `mounted`-guarded; the dialog never calls `Navigator.pop` or `context.go` itself.** The organic GoRouter redirect is the navigation; the dialog is the passenger.

**Alternative — recent re-auth on iOS:**
- Firebase may skip the OAuth sheet if the user re-authenticated very recently (token still considered "recent"). Step 1 still shows (so the user knows what is about to happen) but `reauthenticateWithProvider` returns immediately. Acceptable.

**Alternative — wrong password (email user):**
- Step 1 → "Delete Forever" → re-auth fails → step rolls back to 1 with error message. No CF call, no deletion.

**Alternative — OAuth sheet cancelled:**
- Step 1 → tap provider tile → user cancels native sheet → re-auth fails → step rolls back to 1 with error message. No CF call.

**Error — Cloud Function fails at Firestore stage:**
- Typed error `firestore-cleanup-failed`. Dialog returns to step 1 with a stage-specific message ("We couldn't delete your data. Try again or contact support."). No partial deletion visible — Firestore writes that already committed before the failure remain, but tearing down the user doc is the last Firestore action, so failures earlier in the loop are addressable on retry.

**Error — Cloud Function fails at Storage stage:**
- Storage failures are non-fatal in current code (warning logged, function continues). Spec keeps that behaviour but logs structured stage info so support can find lingering Storage files.

**Error — Cloud Function fails at Auth-deletion stage (current bug):**
- Bounded retry (3 attempts, 250 ms backoff) inside the function. If all retries fail, throw `HttpsError('internal', ...)` with code `auth-delete-failed`. Client surfaces "We couldn't fully delete your account. Please try again or contact support." with a Retry button. The function is idempotent over its earlier stages (Firestore docs already gone → no-op; Storage already empty → no-op), so retry is safe.

**Error — auth-listener "race" on success (architectural reframe):**
- When the Cloud Function completes step 6 (`auth.deleteUser`), the client's `authStateChanges` fires `null` immediately — Firebase revokes the token at the SDK level. `AuthNotifier` flips to `Unauthenticated` → `main.dart` rebuilds the router → GoRouter redirects to `/auth` → the dialog's host route is replaced and the dialog itself is unmounted as part of the route-stack reconciliation.
- This is **not** something the dialog can win by detaching from `authProvider` or by trying to navigate first — the listener lives on `authProvider` at the app root (see `main.dart:35`), not in the dialog. Even if the dialog stops watching, the global router still rebuilds.
- Today the bug is the inverse: the dialog runs `Navigator.pop` + `widget.onDeleted?.call()` (which calls `context.go`) AFTER the global redirect has already torn the tree down → the deferred actions hit a destroyed context → GoRouter falls through to its default error widget.
- Spec resolution: stop fighting the race. Embrace the global redirect. The dialog only needs `if (mounted)` guards on every state update and never calls navigation primitives itself. See Requirement 7.

**Edge — user backgrounds the app mid-flow on iOS:**
- Cloud Function continues server-side (already started). On resume the dialog is gone (the OS may have killed Flutter); the user signs in to a deleted account → fails → /auth gate. Acceptable for V1.
</user_flows>

<requirements>

## Functional

1. **Reproduce + diagnose first.** Phase 1 of any plan is "reproduce on iOS, web, and Android; capture logs that distinguish reconciliations A/B/C in `<background>`." Concrete recipe:
   - **Add temporary instrumentation** before reproducing:
     - In `delete_account_dialog.dart`, log every `setState(_step = ...)` transition with the prior step (`log('dialog: $oldStep → $newStep', name: 'deletion')`).
     - In `_reAuthAndDelete`, log the resolved provider, the boolean returned by `reAuthenticateWith*`, and the result of `executeAccountDeletion` before the success/error branch.
     - In `account_deletion_service.dart`, log entry/exit of `executeAccountDeletion` and `_clearLocalData`.
   - **Tail Cloud Logging** for the function's existing `withStructuredLogs` info entries (search by `op=deleteUserAccount` + uid).
   - **Success criteria** (any one of these closes Phase 1):
     - The instrumented log stream identifies the last dialog step rendered before the GoRouter error widget appears, AND identifies whether `auth.deleteUser` threw.
     - Or grep finds a second client call site of `httpsCallable('deleteUserAccount')` (reconciliation B).
     - Or the user re-runs and confirms the GoRouter error and the partial deletion are separable incidents (reconciliation C).
   - **Timebox**: 60 minutes of focused investigation. If the timebox runs out without a definitive answer, capture an iOS Simulator screen recording and review frame-by-frame; if still inconclusive after another 30 minutes, ship the state-machine + retry + errorBuilder fixes anyway (they are correct under all three reconciliations) and treat root-cause confirmation as a follow-up.
   - **Cross-platform check**: run the same recorded reproduction on web (Chrome) and Android emulator. If both reproduce, drop the iOS-only language across the spec; if only iOS reproduces, narrow the manual smoke section to iOS.

2. **Server-side ordering matches the user-stated correct sequence.** The current code already follows this order; spec asserts it explicitly to lock in:
   1. Verify caller (`request.auth.uid` exists)
   2. Firestore wipe + anonymization (solo events delete, shared events anonymize/owner-transfer, `users/{uid}/private/profile`, `users/{uid}`)
   3. Storage wipe (`users/{uid}/` prefix)
   4. Auth user deletion (`admin.auth().deleteUser(uid)`)
   5. Return `{success: true}`
   No reordering. No tombstone-then-async-sweep. Synchronous, single-call.

3. **Server-side `auth.deleteUser` retry.** Wrap step 4 in a bounded retry: 3 attempts with 250 ms linear backoff. On the 4th failure throw `HttpsError('internal', 'auth-delete-failed', { stage: 'auth' })` so the client can map the typed code. Function remains idempotent under the retry — earlier stages are no-ops on the retry path.

4. **Typed error contract per stage.** `deleteUserAccount` throws `HttpsError` with the `code` field set to one of `'firestore-cleanup-failed'`, `'storage-cleanup-failed'`, `'auth-delete-failed'`, `'unauthenticated'`. The client maps each to a stage-specific user message. Storage failures stay non-fatal (current behaviour) but the function logs a structured `{stage: 'storage', uid, error}` warning so support can find leftover files. Use the existing `withStructuredLogs` wrapper for stage-by-stage info logs.

5. **Client-side state machine refactor.** `DeleteAccountDialog`:
   - Step 1 (re-auth) MUST always render after step 0 → Continue. Add an explicit widget test that asserts `find.byKey(Key('deleteAccount.dialog.reauth'))` resolves after tapping Continue.
   - `executeAccountDeletion` MUST be gated on a `_reAuthSuccess` flag set only after `reAuthenticateWith*` returns `true`. Removing this guard never lets the Cloud Function fire without re-auth.
   - **Step 3 (success) is removed.** The dialog has only steps 0/1/2. On CF success, the dialog stays at step 2 (processing UI) until the global GoRouter redirect (triggered by `authProvider` flipping to `Unauthenticated`) reconciles the route stack and unmounts the dialog. From the user's perspective: warning → re-auth → loader → /auth gate. No success Lottie, no manual navigation from the dialog.
   - **The dialog never calls `Navigator.pop` or `context.go` on the success path.** Trying to do so races against the global router's reconciliation and reproduces the "code-blob + Home" widget — which is exactly today's bug. The success path is owned by GoRouter; the dialog only updates its own UI under `mounted` guards.
   - On CF failure (any non-success result), the dialog DOES update itself: `if (mounted) setState(() { _step = 1; _errorMessage = ...; })`. CF failure means `auth.deleteUser` did not run to completion, the client token still works, `authStateChanges` did not fire, the global router did not reconcile, the dialog is still mounted — `setState` is safe.
   - **Drop the success Lottie entirely** (`assets/animations/success.json`) — there's no step 3 to host it, and embedding a celebratory beat in step 2 only extends the time the dialog spends competing with the global redirect. The auth gate's own appear animation is the success beat.
   - `widget.onDeleted` is dropped from the dialog API. Onboarding-flag preservation moves into `AccountDeletionService._clearLocalData` (see Requirement 8a) so it doesn't depend on dialog code running after CF success.

6. **GoRouter `errorBuilder`.** Add a top-level `errorBuilder` to `createRouter` rendering a friendly fallback (cream background, "Something went wrong" message, single button "Go home" → `context.go(AppRoutes.dashboard)`). This eliminates the "route blob + Home link" page even if some other flow ever reaches an unmatched route.

7. **Embrace the global redirect; do not race it.** When the Cloud Function deletes the Firebase Auth user, `authStateChanges` fires `null`, `AuthNotifier` flips to `Unauthenticated`, `main.dart` rebuilds the router, and GoRouter's redirect routes the entire app to `/auth`. The dialog cannot win this race — `authProvider` is watched at the app root in `main.dart:35`, not inside the dialog, so "detaching" from it inside the dialog is meaningless. Trying to call `Navigator.pop` + `context.go(AppRoutes.auth)` from the dialog after CF success is precisely the bug today: the deferred calls land on a destroyed context and GoRouter renders the "code-blob + Home" error widget.
    - The dialog MUST NOT call `Navigator.pop` or `context.go` on the CF-success path. Period.
    - Every `setState`/state-update on the success path MUST be wrapped in `if (mounted)`. If `mounted` is `false` (the global redirect won the race and unmounted the dialog), the guard short-circuits and the dialog tears down cleanly.
    - On CF failure the dialog DOES drive its own UI update (rollback to step 1 + error message) because no auth-state flip occurred and the dialog is still mounted.
    - The dialog does not need to "detach" from `authProvider` — it doesn't watch it for state-3 navigation purposes (there is no state 3, and there is no manual navigation). The dialog only watches `authProvider` for the step-0/1 dismiss case (Requirement 11), and that listener naturally tears down with the dialog when the global redirect destroys it.

8. **Local-data clear order.** `_clearLocalData` runs AFTER the Cloud Function returns success (current behaviour). Order inside `_clearLocalData` is unchanged: Drift tables (`chat_messages`, `expenses`, `tasks`, `events`, `users`) → secure storage. If `_clearLocalData` throws (e.g. Drift connection issue), the function MUST NOT propagate that as a deletion failure — log it and continue to navigate. The server-side state is the source of truth; the local cache is best-effort.

8a. **Onboarding flag preservation — server-side ordered.** `_clearLocalData` calls `secureStorage.deleteAll()` which wipes the `onboarding_complete` key (`onboarding_provider.dart`). The current `_DangerCard.onTap` re-writes that key by calling `completeOnboarding()` AFTER the dialog finishes — but per Requirement 7 the dialog can't reliably run code after the Cloud Function returns (the global redirect may have unmounted it). The flag re-write MUST therefore happen INSIDE `AccountDeletionService._clearLocalData`, before the function returns:
   1. `deleteAll()` Drift tables (current order).
   2. `secureStorage.deleteAll()`.
   3. `secureStorage.write(key: onboardingCompleteKey, value: 'true')` — last step, before returning.
   - Export the `onboarding_complete` key constant from `onboarding_provider.dart` (it's currently a private `_onboardingCompleteKey`) so `_clearLocalData` can reference it without string duplication. Rename to `onboardingCompleteKey` (public).
   - This way the persisted secure-storage state is correct by the time `_clearLocalData` returns. The next cold launch reads `'true'`, `OnboardingNotifier` initializes to `state = true`, and the router does not redirect to `/onboarding`. No client-side post-CF code required.

## Error Handling

9. **No silent CF call without re-auth.** Even if `currentAuthProvider == AuthProviderType.unknown`, the dialog must NOT call the Cloud Function. Step 1 shows the "Unable to determine your sign-in method" copy with a Cancel button — no path forward.

10. **Typed-code → user message mapping** (client side):
    - `firestore-cleanup-failed` → "We couldn't delete your data. Tap Try again or contact support."
    - `storage-cleanup-failed` → never user-visible (function continues; warning-only).
    - `auth-delete-failed` → "Your data was deleted but we couldn't fully remove your account. Tap Try again — your data is gone, only the sign-in record remains."
    - `unauthenticated` → "Please sign in again to delete your account."
    - any other code → "Account deletion failed. Please try again or contact support."

11. **Mid-dialog auth-state-flip handling.**
    - **Step 0 or 1**: if `authProvider` flips to `Unauthenticated` (token expired, user signed out from another tab) the dialog `pop`s itself — not throw. The deletion can't proceed and the router redirect will land the user on `/auth` anyway. Concretely: a `ref.listen(authProvider, ...)` set up in `initState` calls `Navigator.of(context, rootNavigator: true).pop()` if state is `Unauthenticated` AND `_step <= 1`. The pop here is safe because the dialog isn't competing with a successful deletion — the auth flip is a different cause (sign-out elsewhere, not `auth.deleteUser`).
    - **Step 2** (after CF call started): the listener is irrelevant because per Requirement 7 the dialog never drives navigation post-CF. The global router unmounts the dialog as part of its reconciliation; `mounted` guards on any in-flight `setState` short-circuit cleanly. No "detach" needed because the dialog's listener isn't doing anything during step 2 anyway.

12. **Cloud Function timeout.** Current `timeoutSeconds: 120` stays. On client-side timeout the dialog returns to step 1 with the generic timeout message; server may still complete. Spec does NOT add client-side retry; user must tap "Delete Forever" again.

## Edge Cases

13. **Recent re-auth.** Firebase's `reauthenticateWithProvider` may skip the OAuth UI if a recent token is in cache. Step 1 still renders so the user can confirm intent.

14. **Backgrounded app on iOS during processing.** The `Future.delayed` and CF call continue; on resume the dialog is gone. No special handling — V1 acceptable.

15. **Offline.** No special offline behaviour. `executeAccountDeletion` returns the typed `network-error` mapping → step 1 with "Please check your connection and try again."

16. **Concurrent sign-out.** If the user is already signed out when they tap "Delete Account" (router would have redirected away anyway), the danger card never reaches `_DangerCard.onTap`. No special handling needed.

17. **Re-auth succeeds but Cloud Function token expires before call.** Re-auth refreshes the token; the call fires within the same `_reAuthAndDelete` invocation. Token expiry is not a realistic edge case in the milliseconds between reAuth and CF call.

## Validation

18. **Cloud Function emulator tests** at `functions/test/account/deleteUserAccount.test.ts`:
    - Happy path (solo event + shared event mix): Firestore docs gone, Storage empty, Auth user gone, returns `{success: true}`.
    - Firestore failure injected at the user-doc delete step: throws `firestore-cleanup-failed`.
    - Storage failure injected: function continues; structured warning logged; Auth user still deleted.
    - Auth-deletion failure: first 3 attempts throw, function returns success on attempt 4 (retry succeeds).
    - Auth-deletion failure exhausts retry: throws `auth-delete-failed`; Firestore + Storage already gone.
    - Unauthenticated caller: throws `unauthenticated`.

19. **Service-level unit tests** at `test/app/core/services/account_deletion_service_test.dart` (new file):
    - `currentAuthProvider` correctly maps each provider id.
    - `reAuthenticateWithEmail` returns `true` on success / `false` on `FirebaseAuthException`.
    - `executeAccountDeletion` returns `null` on Cloud Function success.
    - `executeAccountDeletion` returns the stage-specific message string on each typed error code.
    - `_clearLocalData` deletes from all five Drift tables in order then calls `secureStorage.deleteAll()`.
    - Local-data clear failure does NOT mask Cloud Function success.

20. **Widget tests** at `test/app/features/profile/presentation/widgets/delete_account_dialog_test.dart` (new file):
    - Step 0 → tap Continue → step 1 visible (`Key('deleteAccount.dialog.reauth')` resolves).
    - Step 1 (email) with empty password → "Delete Forever" → step 1 stays with error message.
    - Step 1 (email) with correct password (faked) → step 2 visible (`Key('deleteAccount.dialog.processing')` resolves) AND the recording-fake records exactly one `httpsCallable('deleteUserAccount')` invocation.
    - On CF success the dialog does NOT call `Navigator.pop` and does NOT call `context.go`. (Assert by spying the navigator: zero pops attributable to the dialog after CF returns.) The test simulates the global flow by overriding `authProvider` to flip to `Unauthenticated` post-CF and asserting the test harness lands on `/auth` via `MaterialApp.router`.
    - CF success path also asserts `secureStorage.read(onboardingCompleteKey) == 'true'` after `_clearLocalData` returns — onboarding flag preserved at the persistence layer (Requirement 8a).
    - Cloud Function failure → step rolls back to 1 with stage-specific message; `mounted` is true; dialog still on screen.
    - Mid-dialog auth-state flip to `Unauthenticated` while on step 0 or 1 → dialog pops itself; `Navigator.canPop` matches the root state at end.
    - Auth-state flip while on step 2 (the inevitable consequence of CF success) → dialog does NOT call any navigation primitive; the global `MaterialApp.router` rebuild is what routes to `/auth`.
    - Cloud Function never called when re-auth fails (assert via fake recording zero callable invocations).

21. **GoRouter test** at `test/app/core/router/app_router_test.dart` (extend or add) — pump an unmatched location, expect the new friendly error builder, not `_DefaultRouterError`. Tap the "Go home" button and assert navigation to `/dashboard`.

22. **Existing 228 tests stay green.** No regressions allowed.

23. **`flutter analyze` clean. `npm --prefix functions run build && npm --prefix functions test` clean.**

24. **Manual smoke gates on iOS** (post-merge, pre-ship):
    - Open profile → Delete Account → step 0 visible → Continue → step 1 visible (re-auth).
    - Email: enter password → Delete Forever → see step 2 → step 3 brief → /auth gate.
    - Google: tap tile → OAuth sheet → confirm → /auth gate.
    - Apple: tap tile → Apple sheet → confirm → /auth gate.
    - Firebase Console after each: Auth user GONE, `users/{uid}` GONE, `users/{uid}/private/profile` GONE, Storage `users/{uid}/` GONE.
    - GoRouter "code + Home" page never appears in any of the above.
    - Cancel re-auth at OAuth sheet → return to step 1 with error copy. Account still alive in Console.

</validation>

<boundaries>

**Edge cases:**
- Stage-skip scenario where Firestore deletion partially succeeds (e.g. event A deleted, event B fails): the function throws after the second event fails. Already-deleted event A stays gone; user retry runs the loop again; event A is a no-op (event already gone), event B is reattempted. Acceptable.
- Profile photo missing in Storage: `bucket.getFiles({prefix: ...})` returns empty list → `Promise.all([])` resolves immediately. No-op.
- User has no events: events loop skipped; only user doc + Storage + Auth deletion run.
- Apple's `reauthenticateWithProvider` requires the original sign-in. If the user signed in via Apple but the Apple ID has been disconnected upstream, `reauthenticateWithProvider` throws → `false` → step 1 with error. Acceptable.

**Error scenarios:**
- Network drop during CF call → client gets `FirebaseFunctionsException` of code `unavailable` or similar → typed mapping → step 1 with "Please check your connection."
- Cloud Function cold-start exceeds 120s timeout → client gets `deadline-exceeded` → step 1 with retry copy. Server may still complete; subsequent retry is idempotent.
- Token revoked between re-auth and CF call (extremely rare): CF throws `unauthenticated` → step 1.

**Limits:**
- Per-user-per-event document loops are bounded by the user's actual event participation (typical: under 50). No streaming refactor required for V1.
- Retry budget: 3 attempts on `auth.deleteUser` with 250 ms backoff. Beyond that, surface failure.
- Lottie display: at most 1 second on success, dropped entirely if the auth-listener race fires earlier.

</boundaries>

<implementation>

**Files to modify (server side):**
- `functions/src/account/deleteUserAccount.ts`
  - Wrap `auth.deleteUser(uid)` in a bounded retry helper (3 attempts, 250 ms linear backoff).
  - Replace the generic `throw new HttpsError("internal", "Account deletion failed...")` catch-all with stage-specific throws keyed on a `stage` enum (`'firestore' | 'storage' | 'auth'`). Storage failures stay swallowed (warning only). Firestore + Auth failures throw `HttpsError('internal', message, { stage, code })` with `code` ∈ `'firestore-cleanup-failed' | 'auth-delete-failed'`.
  - Add `withStructuredLogs` info entries for every stage transition (`stage: 'firestore.start'`, `'firestore.complete'`, `'storage.start'`, `'storage.complete'`, `'auth.start'`, `'auth.attempt.<n>'`, `'auth.complete'`).

**Files to modify (client side):**
- `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart`
  - Add stable Keys (CrewPoint convention `{feature}.{screen}.{element}`): `Key('deleteAccount.dialog.warn')`, `Key('deleteAccount.dialog.reauth')`, `Key('deleteAccount.dialog.processing')`. (No `success` key — step 3 is removed per Requirement 5.)
  - Collapse the state machine to three steps: `_step ∈ {0, 1, 2}`. Drop step 3, drop the success Lottie reference, drop the `Future.delayed(2 s)`, drop the `Navigator.pop`, drop the `widget.onDeleted` callback, drop the `onDeleted` parameter from `DeleteAccountDialog.show`.
  - Refactor `_reAuthAndDelete` so re-auth runs FIRST (without flipping to step 2), and only flips to step 2 once re-auth has returned `true`. Today step 2 flips before re-auth even starts — the processing UI flashes during the OAuth sheet. Move the flip to AFTER `reAuthSuccess == true`.
  - On CF success: `if (!mounted) return;` and stop. The global GoRouter redirect unmounts the dialog as part of routing to `/auth`. No `Navigator.pop`, no `context.go`. The dialog is the passenger.
  - On CF failure: `if (mounted) setState(() { _step = 1; _errorMessage = <typed-code message>; });`. The auth user wasn't deleted, the global redirect doesn't fire, the dialog is still mounted, the rollback is safe.
  - Add a `ref.listen(authProvider, ...)` in `initState` that pops the dialog (with `mounted` guard, root navigator) IF state is `Unauthenticated` AND `_step <= 1`. Step 2 ignores the listener — the dialog is committed to letting the global redirect handle teardown.
  - Map typed CF error codes (Requirement 10) to the displayed `_errorMessage` on rollback to step 1.

- `lib/app/core/services/account_deletion_service.dart`
  - Change `executeAccountDeletion` return type from `Future<String?>` to `Future<({String? errorCode, String? message})>` matching the `(:user, :failure)` record idiom already used in `auth_provider.dart:69`. `errorCode == null` means success; non-null surfaces the stage-specific code (`'firestore-cleanup-failed'`, `'storage-cleanup-failed'`, `'auth-delete-failed'`, `'unauthenticated'`, `'unknown'`) and the user-facing message.
  - Map `FirebaseFunctionsException.code` + the function's `details.stage` to the typed mapping.
  - Wrap `_clearLocalData` in its own try/catch — local-data clear failure must NOT flip the result from success to failure (log only).
  - **Onboarding flag preservation** (per Requirement 8a) — at the end of `_clearLocalData`, after `secureStorage.deleteAll()`, call `secureStorage.write(key: onboardingCompleteKey, value: 'true')` to re-pin the flag.

- `lib/app/features/onboarding/application/onboarding_provider.dart`
  - Promote the existing private `_onboardingCompleteKey` constant to a public top-level `onboardingCompleteKey` so `AccountDeletionService` can reference it without string duplication.

- `lib/app/features/profile/presentation/profile_screen.dart`
  - Simplify `_DangerCard.onTap`:
    ```dart
    onTap: () => DeleteAccountDialog.show(context: context),
    ```
  - Drop both the `onDeleted` callback wiring AND the `completeOnboarding()` + `context.go(AppRoutes.auth)` calls. The dialog no longer accepts an `onDeleted`; the navigation is handled by the global GoRouter redirect (Requirement 7); the onboarding flag is preserved inside `_clearLocalData` (Requirement 8a). All three responsibilities relocated, none silently dropped.

- `lib/app/core/router/app_router.dart`
  - Add `errorBuilder` to `GoRouter`:
    ```dart
    errorBuilder: (context, state) => const _RouterErrorScreen(),
    ```
    where `_RouterErrorScreen` is a Scaffold (cream background, sage text) with a "Go home" button → `context.go(AppRoutes.dashboard)`. Never the default `_DefaultRouterError` route blob.

**Files to create (tests):**
- `functions/test/account/deleteUserAccount.test.ts` — emulator-driven CF tests per Requirement 18.
- `test/app/core/services/account_deletion_service_test.dart` — unit tests per Requirement 19.
- `test/app/features/profile/presentation/widgets/delete_account_dialog_test.dart` — widget tests per Requirement 20.

**Patterns to use:**
- Existing `withStructuredLogs` wrapper for server-side stage logs.
- Existing `FakeAuthService` pattern at `test/app/features/auth/fake_auth_service.dart` for client tests; extend with a `FakeAccountDeletionService` for the dialog widget tests.
- Riverpod `accountDeletionServiceProvider.overrideWithValue(...)` for the dialog widget tests to inject a recording fake.
- TDD red-green-refactor for every behaviour; one failing test, minimum implementation, refactor, repeat.
- For server retry helper, use `Promise<T>` + linear backoff with explicit `sleep(250)` — no library dependency.

**What to avoid (and why):**
- **No "tombstone-then-async-sweep" pattern.** Synchronous deletion gives the user immediate feedback; the spec choose synchronous explicitly.
- **No reordering Auth-first.** Deleting the Auth user before Firestore would leave the user unable to retry on partial failure (no auth context for the next CF call). Keep Firestore → Storage → Auth.
- **No client-side retry loops.** One CF call per "Delete Forever" tap. Retries are user-initiated.
- **No removal of the warning step.** Legal copy in step 0 is policy-approved; do not edit.
- **No on-sign-in self-heal for orphan accounts.** Out of scope per user decision.
- **No web/Android-specific changes** beyond what's needed for parity. The bug is iOS-only by report; the fix should not regress the other platforms but does not need a separate web reproduction.

</implementation>

<validation>

**Baseline coverage outcomes** (logic, UI, journeys):

- **Logic — `AccountDeletionService` unit tests:**
  - Provider-id mapping (4 cases: password / google.com / apple.com / unknown).
  - Re-auth success/fail per provider.
  - `executeAccountDeletion` typed-code → message mapping (5 cases including the catch-all).
  - `_clearLocalData` deletion order + secure-storage call.
  - Local-data clear failure does not flip success result.

- **Logic — Cloud Function emulator tests:**
  - Happy path (mixed solo + shared events).
  - Each stage's failure-path mapping (`firestore-cleanup-failed`, `auth-delete-failed`).
  - Storage failure non-fatal.
  - Retry succeeds on attempt 4.
  - Retry exhausts → typed throw.
  - Unauthenticated caller.

- **UI — `DeleteAccountDialog` widget tests:**
  - Step transitions 0 → 1 (after Continue), 1 → 2 (only after re-auth success), 2 → 3 (only after CF success), 3 → dismissed.
  - Re-auth failure stays on step 1 with error.
  - CF failure rolls back to step 1 with typed message.
  - Mid-dialog auth-state flip dismisses dialog.
  - CF never called without successful re-auth (recording-fake assertion).

- **UI — Router error builder test:**
  - Unmatched route → friendly `_RouterErrorScreen` rendered (not `_DefaultRouterError`).
  - "Go home" button → `/dashboard`.

**TDD expectations (this feature has substantial testable logic + state-machine behaviour, so strict TDD applies):**

- **Behaviour order** (one test per cycle, RED → GREEN → REFACTOR):
  1. RED: `currentAuthProvider` returns `email` for password provider. GREEN: minimal `currentAuthProvider` impl.
  2. RED: `executeAccountDeletion` returns `DeletionSuccess` when CF returns success. GREEN: minimal impl.
  3. RED: `executeAccountDeletion` returns `DeletionFailure(code: 'auth-delete-failed', ...)` when CF throws with that code. GREEN: extend impl.
  4. (repeat per typed code)
  5. RED: dialog step 0 → Continue → step 1 visible. GREEN: minimal `_step` flip.
  6. RED: dialog step 1 → Delete Forever → step 2 visible only AFTER re-auth resolves true. GREEN: refactor `_reAuthAndDelete` to flip step AFTER re-auth.
  7. RED: dialog step 3 → 600 ms → `context.go('/auth')`. GREEN: minimal navigation.
  8. RED: server CF retry succeeds on attempt 4. GREEN: retry helper.
  9. RED: server CF throws `auth-delete-failed` after retry exhausts. GREEN: extend retry to surface typed error.
  10. (repeat per CF stage)

- **Vertical-slice cycles:** one cycle per behaviour, not all tests up-front. Each cycle is a committable unit.

- **Testability seams:**
  - `AccountDeletionService` constructor injection of `FirebaseAuth`, `FirebaseFunctions`, `AppDatabase`, `SecureStorageService` (already in place).
  - Add a `Clock`/`sleep` seam for the server retry helper so tests can assert retry behaviour without real-time waits.
  - `accountDeletionServiceProvider` Riverpod override for the dialog widget tests.
  - `FakeAuthService` extension for re-auth scenarios.

- **Mocking policy:** prefer fakes (recording, in-memory) over mocks. CF emulator + real Drift in-memory DB for service tests. No mocking of internal classes; mock only at platform boundaries (`FirebaseAuth`, `FirebaseFunctions`).

- **Justified exception — none.** Every behaviour has a deterministic test seam. No "constant-change refactor" excuses.

**Robot tests:** **none required.** This is a single overlay-dialog flow on the Profile screen. Widget-level coverage of the dialog state machine + a CF integration suite together cover the critical path. If a future spec adds cross-screen account-management journeys (e.g. delete from Settings + from Profile + from web), revisit and add a `DeleteAccountRobot`.

**Test-type mapping:**
- **Unit (`AccountDeletionService`):** typed-error mapping, re-auth gating, local-data clear order.
- **Widget (`DeleteAccountDialog`):** state-machine transitions, error-message display, navigation, auth-flip mid-dialog handling, CF-never-called-without-reauth.
- **Widget (router error builder):** unmatched-location fallback.
- **CF integration (`deleteUserAccount`):** stage success/failure paths, retry, structured logs, typed-error codes.
- **Existing journeys:** must stay green; no robot changes.

**Manual smoke checklist (post-merge, pre-ship):**
- Run the full delete flow on iOS first (the original report). If Phase 1's cross-platform check (Requirement 1) confirmed reproduction on web/Android, run the same checklist there too.
- For each platform under test, sign in with each provider available on that platform (email, Google, Apple where applicable) and run the full delete flow.
- After each, verify Firebase Console:
  - Authentication tab: user GONE.
  - Firestore: `users/{uid}` GONE; `users/{uid}/private/profile` GONE.
  - Storage: `users/{uid}/` GONE.
- Cancel re-auth at the OAuth sheet → return to step 1 with the error message; account still alive in Console.
- Force a Cloud Function failure (simulate by signing out via dev tools mid-call) → step 1 with the timeout message; Console shows whatever stage actually committed.
- Trigger an unmatched route by hand (`go_router` extension URL like `/profile/nonexistent`) → friendly `_RouterErrorScreen` shows. Tap "Go home" → `/dashboard`.
- Sign up again on the same device immediately after deletion → land on `/dashboard`, NOT `/onboarding` (confirms Requirement 8a's onboarding-flag preservation).

</validation>

<done_when>

**Implementation gates** (each maps to a specific Requirement; no restated detail):
- Phase-1 reproduction recipe executed (Req 1) — root-cause confirmed under reconciliation A/B/C, or fix shipped under "all three" coverage.
- Server-side ordering matches Req 2; retry helper per Req 3; typed `HttpsError` codes per Req 4.
- Dialog state machine collapsed to steps 0/1/2 per Req 5 (no step 3, no Lottie, no manual `Navigator.pop`/`context.go`); embraces the global redirect per Req 7.
- Onboarding flag preserved server-of-`_clearLocalData` per Req 8a; `onboardingCompleteKey` exported from `onboarding_provider.dart`.
- `AccountDeletionService` returns `({String? errorCode, String? message})` per Req 10 + Implementation block; local-data-clear failure non-fatal per Req 8.
- Mid-dialog auth-state-flip handling per Req 11 (steps 0/1 dismiss; step 2 lets global redirect handle teardown).
- `GoRouter.errorBuilder` configured per Req 6.

**Test-level gates** (per Validation §18–§22):
- `npm --prefix functions test` green, including the new `deleteUserAccount` stage + retry suite.
- `flutter test` green: new service unit tests + dialog widget tests + router error-builder test all pass.
- All existing 228 tests still green; `flutter analyze` clean.

**Manual smoke gates** (per Validation manual checklist):
- iOS happy + cancelled-reauth + forced-CF-failure paths land deterministically.
- Firebase Console confirms full deletion (Auth + Firestore + Storage) per provider tested.
- GoRouter "code + Home" page never appears.
- Re-signup immediately after deletion lands on `/dashboard`, not `/onboarding`.
- If Phase 1 confirmed cross-platform reproduction, the same gates pass on web + Android.

**Out of scope** (explicit, per user):
- Already-orphaned accounts (Auth user alive, Firestore/Storage gone) — pre-launch, real population is effectively zero.
- Auth-first ordering — rejected; Firestore-first sequence is correct.
- Two-phase tombstone-then-async-sweep — rejected; synchronous flow chosen.
- Account-deletion robot tests — single-screen overlay flow, widget tests sufficient.

</done_when>
