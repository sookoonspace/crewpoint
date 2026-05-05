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

### Phase 2: AuthNotifier listener wiring (consumer slice) ✓

- **Goal**: Listener invokes repo on every non-null emission with resolved displayName, errors swallowed, sign-in unblocked.
- [x] TDD: `AuthNotifier` listener calls `userRepository.createUserIfNotExists` exactly once when fake auth stream emits non-null user (capture call count + args via hand-rolled fake `IUserRepository`)
- [x] TDD: not called when emission is null (sign-out path)
- [x] TDD: provider-supplied `displayName='Jane Doe'` flows through unchanged (trim applied)
- [x] TDD: provider `displayName=null` + `email='apple+sub@privaterelay.appleid.com'` → repo receives `displayName: 'Apple'`
- [x] TDD: repo throws (`FirebaseException` simulated by fake) → state still becomes `Authenticated`; listener does not rethrow; error logged via `dart:developer`
- [x] TDD: rapid double emission → repo called twice but no test failure (idempotency lives in repo, not notifier)
- [x] `lib/app/features/auth/application/auth_provider.dart`:
  - Added `IUserRepository?` constructor param (optional with null default — see deviation note below) + private field
  - Imported `IUserRepository` and `deriveDisplayNameFromEmail` helper
  - Listener calls `unawaited(_ensureUserDoc(user))` on non-null emission; cold-start `currentUser` path also fires it
  - `_ensureUserDoc` short-circuits when repo is null, when `user.email` is empty, then resolves displayName (trim provider value or derive from email) and calls `createUserIfNotExists`
  - **Untyped `catch (e, st)`** absorbs `FirebaseException`, generic `Exception`, and any sync throw; logged via `dart:developer.log` with `name: 'auth'`; never rethrows
- [x] `lib/app/core/providers.dart:57` — `authProvider` factory now passes `userRepository: FirestoreUserRepository()`
- [x] `test/app/features/auth/auth_provider_test.dart` + new `fake_user_repository.dart` fixture — 5 new tests covering call count, sign-out no-op, derived-name fallback, FirebaseException swallow, repeat emission
- [x] Spec req #7: per-method handlers (`signInWithEmail`/`signUpWithEmail`/`signInWithGoogle`/`signInWithApple`) untouched — verified by grep (`_ensureUserDoc` referenced only inside `build()`)
- [x] Spec — `firestore.rules` and `functions/` untouched; `providerIds` not promoted to public doc
- [x] Verify: `flutter analyze` clean; `flutter test` 256 passed
- [ ] Manual smoke (one-time, simulator): Google sign-in on fresh install → Firestore console shows public doc with `displayName`+`photoUrl`, private subdoc with `email`+`providerIds`+`preferences`+timestamps

**Deviation from plan**: `userRepository` made optional (default `null`) instead of `required`. Reason: the codebase has 11 widget/layout/router test files that construct `AuthNotifier` directly; making the param required would have required mechanical edits across all of them with no behavior benefit (those tests don't exercise the user-doc path). Optional + `null` short-circuit keeps the production callsite explicit (`providers.dart` always passes the real repo) while leaving unrelated tests unchanged.

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
