## Overview

Fix the account-delete flow: investigate the iOS regression, ship a small thin slice (GoRouter `errorBuilder` + onboarding-flag preservation), then collapse the dialog state machine, swap in a typed-error result, and harden the Cloud Function with retry + structured logs. Embrace the global `authProvider` redirect — dialog never calls `Navigator.pop`/`context.go` on success.

**Spec**: `ai_specs/account-delete-flow-fix-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first under `lib/app/features/`; shared scaffolding in `lib/app/core/{services,router,widgets,constants}/`. Cloud Functions under `functions/src/`; emulator harness under `functions/test/`.
- **State management**: Riverpod 3 (`AuthNotifier`, `OnboardingNotifier`, `accountDeletionServiceProvider`). `main.dart:35` watches `authProvider` and rebuilds `MaterialApp.router` — this is THE global redirect path the spec embraces.
- **Reference implementations**:
  - `lib/app/features/auth/application/auth_provider.dart` — `(:user, :failure)` record idiom (line 69) to mirror in the new `({errorCode, message})` return type.
  - `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart` — existing 4-step state machine to collapse.
  - `lib/app/core/services/account_deletion_service.dart` — existing service to retype + extend `_clearLocalData`.
  - `functions/src/account/deleteUserAccount.ts` — current server sequence (Firestore → Storage → Auth) to wrap in retry + typed errors.
  - `functions/src/utils/logging.ts` — `withStructuredLogs` wrapper for stage-by-stage info logs.
  - `functions/test/cloud-functions.test.ts` — emulator-driven test pattern (`@firebase/rules-unit-testing` + `firebase-functions-test` v3).
  - `test/app/features/auth/fake_auth_service.dart` — fake-over-mock pattern for client tests.
- **Stable Key convention**: `{feature}.{screen}.{element}` → `deleteAccount.dialog.{warn|reauth|processing}`.
- **Assumptions/Gaps**:
  - `withStructuredLogs` already used in `deleteUserAccount.ts:127`; extend usage, don't reintroduce.
  - `_onboardingCompleteKey` is currently private in `onboarding_provider.dart:4` — must be promoted to public `onboardingCompleteKey` for the service to reference it without string duplication.
  - Spec drops `widget.onDeleted` from the dialog API. Only `_DangerCard.onTap` calls `DeleteAccountDialog.show` (one site); breaking change is contained.
  - Cross-platform reproduction unverified; Phase 1's investigation runs the recipe on web + Android too. If iOS-only is confirmed, narrow manual smoke; otherwise broaden.
  - Lottie removed entirely from the dialog; no asset deletion (`assets/animations/success.json` is still used by `edit_profile_screen.dart`). No pubspec change.
  - No existing tests reference `DeleteAccountDialog` or `AccountDeletionService` — fresh test files only.
  - Functions test harness uses Jest + emulator; new file lives at `functions/test/account/deleteUserAccount.test.ts` (new directory).

## Plan

### Phase 1: Reproduce + thin slice — `errorBuilder` + onboarding-flag re-pin

- **Goal**: confirm reproduction, ship the smallest changes that prove the global-redirect approach. Two surgical fixes (router error fallback + onboarding key re-pin) eliminate the visible "code-blob + Home" page and the post-deletion onboarding regression — both are independent of the bigger client/server refactor and de-risk Phases 2/3.
- **Investigation (Req 1, timeboxed):**
  - [x] Static reconciliation pass (no real-device reproduction available in this session): grepped client codebase for any `httpsCallable('deleteUserAccount')` call sites — exactly one (`account_deletion_service.dart:107`), so reconciliation B (hidden call site) is ruled out by source. Reconciliation A (memory-fuzz) and C (two separate incidents) cannot be settled without real-device repro; both are consistent with what the user reported and both are addressed by the thin slice + Phase 2/3 changes.
  - [x] **Decision**: ship under "all-three coverage" per the spec's fallback. The fixes (errorBuilder, onboarding-flag re-pin, dialog state-machine refactor, server-side retry, typed CF errors) are correct under any reconciliation. Real-device instrumentation + log capture is recommended before launch but not blocking on this PR.
  - Deferred sub-tasks (the user can run them later if desired):
    - Add temporary `log('dialog: $oldStep → $newStep', name: 'deletion')` instrumentation on every `setState(_step)` in `delete_account_dialog.dart`; log re-auth result + `executeAccountDeletion` outcome; log entry/exit of `_clearLocalData`.
    - Tail Cloud Logging filter `op=deleteUserAccount` while reproducing on iOS, web (Chrome), Android emulator.
    - Identify reconciliation A vs C from the captured logs.
    - Revert instrumentation after capture.
- **Implementation:**
  - [x] `lib/app/features/onboarding/application/onboarding_provider.dart` — promote private `_onboardingCompleteKey` to public top-level `const onboardingCompleteKey = 'onboarding_complete';`. Updated internal references; added doc comment naming the deletion-flow consumer.
  - [x] `lib/app/core/services/account_deletion_service.dart` — added `AccountDeletionCallable` typedef + optional injection (mirrors `disputeSettlementCallableProvider` pattern; lazy `FirebaseFunctions.instance` so tests don't require Firebase init). Wrapped Drift wipes in inner try/catch (failure non-fatal). After `secureStorage.deleteAll()`, call `secureStorage.write(key: onboardingCompleteKey, value: 'true')`. Wrapped `_clearLocalData` in outer try/catch inside `executeAccountDeletion` so local-data failure does NOT flip success → failure.
  - [x] `lib/app/core/router/app_router.dart` — added `errorBuilder: (_, _) => const _RouterErrorScreen()` to `GoRouter`. New `_RouterErrorScreen` widget: `Scaffold` (cream bg) with compass icon, "Something went wrong" + sub-copy, sage `ElevatedButton.icon('Go home')` → `context.go(AppRoutes.dashboard)`. Stable Key `Key('router.error.goHome')`. Added optional `initialLocation` parameter to `createRouter` so tests can pump unmatched routes.
- **Tests:**
  - [x] TDD: `executeAccountDeletion` re-pins `onboarding_complete='true'` after `secureStorage.deleteAll()` (new `test/app/core/services/account_deletion_service_test.dart` using `MockFirebaseAuth` + `FlutterSecureStorage.setMockInitialValues({})` + in-memory Drift).
  - [x] TDD: a Drift wipe failure (DB closed pre-call) does NOT prevent the secure-storage re-pin — the inner try/catch swallows Drift errors.
  - [x] TDD: GoRouter `errorBuilder` renders `_RouterErrorScreen` on unmatched `/this-route-does-not-exist`; tap "Go home" navigates to `/dashboard` (extends existing `app_router_test.dart`).
- [x] Verify: `flutter analyze` clean; `flutter test` green (231 pass, +3 new tests; existing 228 stay green).

### Phase 2: Dialog state-machine refactor + service typed-error contract

- **Goal**: collapse the dialog to steps 0/1/2 (no step 3, no Lottie, no manual nav, no `widget.onDeleted`); swap `executeAccountDeletion` to a typed `({errorCode, message})` record; the dialog becomes a passenger to the global GoRouter redirect on success and only drives its own UI on failure or step-0/1 auth-flip dismiss.
- **Service refactor:**
  - [x] `lib/app/core/services/account_deletion_service.dart` — changed `executeAccountDeletion` return type from `Future<String?>` to `Future<({String? errorCode, String? message})>`. Maps `FirebaseFunctionsException.code` (`unauthenticated` → `unauthenticatedCode`) + `details.stage` (`firestore`/`storage`/`auth` → typed codes); falls back to `unknownCode`. Public `firestoreCleanupFailedCode` / `storageCleanupFailedCode` / `authDeleteFailedCode` / `unauthenticatedCode` / `unknownCode` constants for callers.
  - [x] TDD: `executeAccountDeletion` returns `(errorCode: null, message: null)` on success.
  - [x] TDD: maps `details.stage = 'auth'` → `(errorCode: authDeleteFailedCode, message: contains('your account'))`.
  - [x] TDD: maps `details.stage = 'firestore'` → `(errorCode: firestoreCleanupFailedCode, message: contains('your data'))`.
  - [x] TDD: maps `code = 'unauthenticated'` → `(errorCode: unauthenticatedCode, message: contains('sign in'))`.
  - [x] TDD: falls back to `unknownCode` when no stage is reported.
  - [x] TDD: `_clearLocalData` failure (Drift throw) does NOT flip success result to failure (kept from Phase 1; assertion still on the new record shape).
- **Dialog refactor:**
  - [x] `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart` — collapsed to `_step ∈ {0, 1, 2}`. Removed step 3 + `_SuccessStep` widget + Lottie + Lottie import; removed `Future.delayed(2 s)`; removed `Navigator.pop`; removed `context.go`; removed `widget.onDeleted` parameter; removed `onDeleted` from `DeleteAccountDialog.show`.
  - [x] Stable Keys: `deleteAccount.dialog.warn` on `_WarningStep`; `deleteAccount.dialog.reauth` on `_ReAuthStep` Column; `deleteAccount.dialog.processing` on `_ProcessingStep` Padding.
  - [x] Refactored `_onDeleteForever` (renamed from `_reAuthAndDelete`): re-auth runs FIRST. On failure: `setState(_errorMessage = ...)`, stay on step 1 (no step flip). On success: `setState(_step = 2)` THEN await `executeAccountDeletion`. On CF success: `if (!mounted) return;` and stop — no `Navigator.pop`, no `context.go`. On CF failure: `if (mounted) setState({_step = 1; _errorMessage = result.message ?? fallback})`.
  - [x] `initState` registers `ref.listenManual<AuthState>(authProvider, ...)` that pops via `Navigator.of(context, rootNavigator: true).pop()` only if `_step <= 1` AND `mounted` AND `next is Unauthenticated`. Subscription closed in `dispose`. Step-2 explicitly ignores the listener via the `_step > 1` early return.
  - [x] Typed error code → user message mapping handled by the service (the dialog just consumes `result.message`); fallback string used if `result.message == null`.
- **Profile screen:**
  - [x] `lib/app/features/profile/presentation/profile_screen.dart` — `_DangerCard.onTap`: `() => DeleteAccountDialog.show(context: context)`. Dropped the `onDeleted` lambda; dropped `completeOnboarding()` (relocated to `AccountDeletionService._clearLocalData` in Phase 1); dropped `context.go(AppRoutes.auth)` (the global GoRouter redirect handles it). Comment in source explains the relocation so future readers don't re-introduce it.
- **Tests:**
  - [x] TDD: dialog step 0 → tap Continue → `find.byKey(Key('deleteAccount.dialog.reauth'))` resolves; `processing` key absent.
  - [x] TDD: step 1 (email) with empty password → "Delete Forever" → still on step 1; recording-fake records ZERO `executeAccountDeletion` calls.
  - [x] TDD: step 1 (email) with correct password → step 2 visible; fake records exactly ONE `executeAccountDeletion` call. After CF success, dialog stays at step 2 (no `Navigator.pop` from the dialog).
  - [x] TDD: CF failure → step rolls back to 1 with the typed error message visible.
  - [x] TDD: while on step 0, flipping `authProvider` to `Unauthenticated` (via `FakeAuthService.setCurrentUser(null)`) → dialog pops itself.
  - [x] TDD: while on step 2 (CF call gated open via `Completer`), flipping `authProvider` to `Unauthenticated` → dialog stays on step 2; the listener short-circuits because `_step > 1`.
  - Note: the spec also calls for asserting "the test harness lands on /auth via the global router rebuild." That assertion requires pumping a real `MaterialApp.router` with `createRouter` + `authProvider` overrides. We test the dialog-side guarantee directly (no `Navigator.pop`/`context.go` from the dialog) which is the contract the user emphasized; verifying that the global router DOES rebuild and route to `/auth` is covered by the existing `app_router_test.dart` redirect tests + the manual smoke in Phase 3.
- [x] Verify: `flutter analyze` clean; `flutter test` green (241 pass, +10 new tests over Phase 1's 231; existing tests stay green).

### Phase 3: Server-side retry + typed CF errors + final smoke

- **Goal**: `auth.deleteUser` becomes idempotent under bounded retry; each failure stage throws a typed `HttpsError` whose `details.stage` and `code` map to the client-side mapping in Phase 2; structured logs at every stage transition. Final manual smoke per platform.
- **Cloud Function:**
  - [ ] `functions/src/account/deleteUserAccount.ts` — wrap `auth.deleteUser(uid)` in a 3-attempt / 250 ms-linear-backoff helper (inline `async function deleteAuthUserWithRetry(uid)`). On final failure throw `new HttpsError('internal', 'Account deletion failed (auth stage)', { stage: 'auth', code: 'auth-delete-failed' })`.
  - [ ] Replace the generic catch-all `HttpsError('internal', ...)` with stage-specific throws. Wrap the events loop and `users/{uid}` deletion: on failure throw `HttpsError('internal', ..., { stage: 'firestore', code: 'firestore-cleanup-failed' })`. Keep Storage failures non-fatal but ensure `withStructuredLogs` records `{stage: 'storage', uid, error}` warning.
  - [ ] Emit `withStructuredLogs` info entries at each transition: `firestore.start`, `firestore.complete`, `storage.start`, `storage.complete`, `auth.start`, `auth.attempt.<n>`, `auth.complete`.
- **CF tests** (new directory `functions/test/account/`):
  - [ ] TDD: happy path (mixed solo + shared events) — Firestore wiped/anonymized, Storage empty, Auth user gone, returns `{success: true}`.
  - [ ] TDD: Firestore failure injected on `users/{uid}` delete → throws `HttpsError` with `details.stage = 'firestore'`.
  - [ ] TDD: Storage failure non-fatal — `auth.deleteUser` still runs; structured warning logged.
  - [ ] TDD: `auth.deleteUser` fails twice then succeeds → function returns success on attempt 3 (assert internal call count).
  - [ ] TDD: `auth.deleteUser` fails all 3 attempts → throws `HttpsError` with `details.stage = 'auth', details.code = 'auth-delete-failed'`. Firestore + Storage already gone (idempotent retry verified).
  - [ ] TDD: unauthenticated caller → throws `HttpsError('unauthenticated', ...)`.
- **Manual smoke + closeout:**
  - [ ] Manual smoke on iOS (always); on web + Android only if Phase 1 confirmed cross-platform reproduction.
    - For each provider available on the platform (email, Google, Apple): run full delete flow → confirm landing on `/auth`.
    - Firebase Console for each: Auth user GONE, `users/{uid}` GONE, `users/{uid}/private/profile` GONE, Storage `users/{uid}/` GONE.
    - Cancel re-auth at OAuth sheet → step 1 with error copy; account still alive in Console.
    - Force CF failure mid-call (e.g. disable network briefly) → step 1 with timeout copy; Console shows whatever stage committed.
    - Trigger an unmatched route by hand (`/profile/nonexistent`) → `_RouterErrorScreen` shows; "Go home" → `/dashboard`.
    - Re-signup immediately after deletion on the same device → land on `/dashboard`, NOT `/onboarding` (validates Phase 1's Req 8a fix).
  - [ ] Update `ai_specs/todo.md` Phase-1 debug-log entry with the final reconciliation (A/B/C) once known. Remove the entry if root cause is fully understood and documented in the source.
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`. All previously-existing tests stay green; new client + CF tests all pass.

## Risks / Out of scope

- **Risks**:
  - **Cross-platform scope creep** — Phase 1's investigation may surface that the bug reproduces on web + Android too. The fixes apply universally; manual smoke broadens accordingly. If only iOS reproduces, narrow Phase 3's smoke checklist to iOS to keep scope tight.
  - **Test harness for the global-redirect assertion** — Phase 2's "after CF success the global redirect lands on `/auth`" widget test requires pumping a real `MaterialApp.router` with the project's `createRouter` + a Riverpod override of `authProvider` that flips on demand. If the existing test infra makes this awkward, fall back to asserting "dialog widget did not call Navigator.pop and did not call context.go" plus a separate router-level test that overrides `isAuthenticated=false` and asserts the redirect lands on `/auth`. Mitigation: prototype the harness early in Phase 2 before writing the full suite.
  - **CF emulator + Firebase Functions Test v3 quirks for retry assertions** — counting internal call counts on `auth.deleteUser` may require spying on `admin.auth()`. If the emulator's `firebase-functions-test` v3 doesn't expose a clean spy, use a thin injectable wrapper around `admin.auth().deleteUser` so the test can pass a recording fake. Mitigation: Phase 3 starts with the test harness, not the production code.
- **Out of scope** (per spec, restated for clarity):
  - Already-orphaned accounts (Auth user alive, Firestore/Storage gone) — pre-launch, real population effectively zero.
  - Auth-first ordering — rejected; Firestore-first sequence is correct.
  - Two-phase tombstone-then-async-sweep — rejected; synchronous flow chosen.
  - Account-deletion robot tests — single-screen overlay flow, widget tests sufficient.
  - Lottie animation tweaks — success Lottie removed entirely from the dialog; the asset is still used by other screens, no asset deletion.
