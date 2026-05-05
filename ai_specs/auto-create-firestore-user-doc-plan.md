# Auto-Create Firestore User Doc — Plan

## Overview

Wire `createUserIfNotExists` into `AuthNotifier`'s authStateChanges listener; extend it to persist `photoUrl` + `providerIds`; add pure email→name fallback helper.

**Spec**: `ai_specs/auto-create-firestore-user-doc-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first (`lib/app/features/{auth,profile,...}/{domain,application,data,presentation}`)
- **State management**: Riverpod 3, manual `NotifierProvider` for `AuthNotifier` (not codegen)
- **Reference implementations**:
  - `lib/app/features/auth/application/auth_provider.dart` — listener target (line 47)
  - `lib/app/features/profile/data/firestore_user_repository.dart:152` — method to extend
  - `lib/app/core/providers.dart:57-89` — `authProvider` + `userRepositoryProvider` wiring
  - `test/app/features/auth/auth_provider_test.dart` — existing per-test `NotifierProvider` override pattern
  - `test/app/features/profile/firestore_user_repository_test.dart` — `fake_cloud_firestore` pattern
- **Assumptions/Gaps**:
  - `authProvider` in `providers.dart:57` hardcodes deps (no `ref.watch`); preserve that style — pass a new `FirestoreUserRepository()` instance into `AuthNotifier` constructor.
  - `IUserRepository` is the interface name (capital `I` prefix); `userRepositoryProvider` already exists.
  - `dart:developer` already imported in `auth_provider.dart`.
  - Test override pattern: each test builds its own `NotifierProvider<AuthNotifier, AuthState>(() => AuthNotifier(authRepository: ..., userRepository: ...))` — no `overrideWithValue` on global provider.

## Plan

### Phase 1: Pure helper + repository extension (data layer slice) ✓

- **Goal**: Thinnest slice that produces correct Firestore writes given provider data.
- [x] TDD: `deriveDisplayNameFromEmail('jane.doe@x.com') == 'Jane Doe'` → minimal split-and-titlecase
- [x] TDD: `'12345@x.com' → '12345'` (numeric tokens preserved)
- [x] TDD: `'jane+work@x.com' → 'Jane'` (strip after `+`)
- [x] TDD: `'a@x.com' → 'A'` (single-char)
- [x] TDD: `'JOHN_smith@x.com' → 'John Smith'` (underscore split, mixed case)
- [x] TDD: null/empty/`'@x.com'`/`'+work@x.com'` → `'CrewPoint user'`
- [x] `lib/app/features/auth/domain/display_name_helper.dart` — pure top-level `deriveDisplayNameFromEmail(String?)`; no Flutter/Firebase imports
- [x] `test/app/features/auth/domain/display_name_helper_test.dart` — host the cases above
- [x] TDD: repo writes `photoUrl` to public doc + `providerIds` to private subdoc when both supplied
- [x] TDD: repo handles `photoUrl: null` (omit key from public doc map) + `providerIds: const []` (empty array in private)
- [x] TDD: repo idempotency preserved — early-returns when public doc exists, regardless of new params
- [x] `lib/app/features/profile/domain/repositories/i_user_repository.dart` — extend `createUserIfNotExists` signature: add `String? photoUrl`, `List<String> providerIds = const []`
- [x] `lib/app/features/profile/data/firestore_user_repository.dart:152` — implement: conditionally include `photoUrl` in public batch.set map (omit key when null); add `providerIds` to private subdoc batch.set map
- [x] `test/app/features/profile/firestore_user_repository_test.dart` — update existing 3 callsites of `createUserIfNotExists` to compile against new signature (use named defaults); add the new test cases above
- [x] Verify: `flutter analyze && flutter test`

### Phase 2: AuthNotifier listener wiring (consumer slice)

- **Goal**: Listener invokes repo on every non-null emission with resolved displayName, errors swallowed, sign-in unblocked.
- [ ] TDD: `AuthNotifier` listener calls `userRepository.createUserIfNotExists` exactly once when fake auth stream emits non-null user (capture call count + args via hand-rolled fake `IUserRepository`)
- [ ] TDD: not called when emission is null (sign-out path)
- [ ] TDD: provider-supplied `displayName='Jane Doe'` flows through unchanged (trim applied)
- [ ] TDD: provider `displayName=null` + `email='apple+sub@privaterelay.appleid.com'` → repo receives `displayName: 'Apple'`
- [ ] TDD: repo throws (`FirebaseException` simulated by fake) → state still becomes `Authenticated`; listener does not rethrow; error logged via `dart:developer`
- [ ] TDD: rapid double emission → repo called twice but no test failure (idempotency lives in repo, not notifier)
- [ ] `lib/app/features/auth/application/auth_provider.dart`:
  - Add `IUserRepository` constructor param + private field
  - Import `IUserRepository` from `features/profile/domain/repositories/i_user_repository.dart`
  - Import helper from `features/auth/domain/display_name_helper.dart`
  - In listener (line 47), when `user != null`, call `unawaited(_ensureUserDoc(user))` BEFORE `state = Authenticated(user)` (or after — order indifferent because fire-and-forget)
  - Add `Future<void> _ensureUserDoc(AppUser user) async { try { ... } catch (e, st) { log(...) } }`
  - **CRITICAL (per spec req #10 + user note)**: catch clause must be untyped `catch (e, st)` so it captures `FirebaseException`, generic `Exception`, and any sync-thrown error; log via `developer.log('failed to ensure user doc for ${user.uid}', error: e, stackTrace: st, name: 'auth')`; never rethrow
  - displayName resolution at call site: `final raw = user.displayName?.trim(); final resolved = (raw != null && raw.isNotEmpty) ? raw : deriveDisplayNameFromEmail(user.email);`
  - Skip the call when `user.email == null || user.email!.isEmpty` (anonymous/guard) — log a `developer.log` debug line, return
- [ ] `lib/app/core/providers.dart:57` — update `authProvider` factory: pass `userRepository: FirestoreUserRepository()` alongside existing `authRepository`
- [ ] `test/app/features/auth/auth_provider_test.dart` — update `setUp` to construct `AuthNotifier` with a `FakeUserRepository` (new test fixture in `test/app/features/auth/fake_user_repository.dart`); existing tests must still pass
- [ ] Per spec req #7: do NOT add the call to `signInWithEmail`/`signUpWithEmail`/`signInWithGoogle`/`signInWithApple` (verify via grep at end of phase)
- [ ] Per spec — do NOT modify `firestore.rules`, do NOT add Cloud Functions, do NOT promote `providerIds` to public doc
- [ ] Verify: `flutter analyze && flutter test`
- [ ] Manual smoke (one-time, simulator): Google sign-in on fresh install → Firestore console shows public doc with `displayName`+`photoUrl`, private subdoc with `email`+`providerIds`+`preferences`+timestamps

## Risks / Out of scope

- **Risks**:
  - Listener fires on cold-start with cached session — repo gets called every app open. Read cost = 1 doc.get per cold-start; acceptable. Watch profile-screen telemetry post-merge.
  - `fake_cloud_firestore` may not surface a thrown exception path naturally — Phase 2 swallow-test may need a hand-rolled throwing fake `IUserRepository` rather than going through the real `FirestoreUserRepository`.
  - Apple's relay-email derivation produces cosmetically odd names (`abc123 → Abc123`); spec accepts this — flagged for code review only.
- **Out of scope**:
  - Cloud Function on `auth.user().onCreate`
  - Downloading provider photo to Firebase Storage
  - Backfilling existing users (any user already past first sign-in without a doc will self-heal on their next session emission)
  - Modifying `firestore.rules` (existing self-write rules already cover this path)
  - Onboarding's preferences-write path (separate flow; this spec only seeds defaults at first-doc creation)
