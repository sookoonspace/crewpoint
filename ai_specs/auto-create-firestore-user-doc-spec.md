<goal>
Automatically materialize a Firestore user document on first authenticated entry into the app, sourcing displayName, photoUrl, email, and providerIds from Firebase Auth, so the app has a durable per-user record without requiring a manual visit to Edit Profile.

Today, `FirebaseAuth` creates a user (email signup or Google/Apple OAuth) and the app proceeds to onboarding/dashboard, but no `users/{uid}` Firestore document is written until the user explicitly opens Edit Profile and saves. A tested-but-unused `FirestoreUserRepository.createUserIfNotExists()` already exists; this spec wires it into the auth flow, extends it to capture `photoUrl` + `providerIds`, and adds an email-derived displayName fallback for cases where the provider doesn't supply one (notably Apple after the first sign-in).

**Who benefits:** every signed-in user. Downstream features that read `users/{uid}` (event member lookups, payment displays, profile cards) will find a populated doc instead of nothing. UX: profile screen shows the user's name and avatar immediately on first dashboard visit, not only after they manually save Edit Profile.
</goal>

<background>
**Tech stack:**
- Flutter `^3.11.5`, Riverpod 3, GoRouter 14
- `firebase_auth: ^5.5.3`, `cloud_firestore: ^5.6.7`
- Auth flows: email/password, Google OAuth, Apple OAuth (all via Firebase Auth's unified `signInWithProvider()`)

**Files to examine before implementing:**
- `@lib/app/features/auth/application/auth_provider.dart` — `AuthNotifier`, the auth state machine; `authStateChanges` listener at line 47
- `@lib/app/features/auth/data/firebase_auth_service.dart` — `_mapUser()` at line 151 maps `firebase_auth.User` → `AppUser`
- `@lib/app/features/auth/domain/models/app_user.dart` — `AppUser` model with `displayName`, `photoUrl`, `email`, `providerIds`
- `@lib/app/features/profile/data/firestore_user_repository.dart` — `createUserIfNotExists()` at line 152, currently writes only `displayName` (public) and `email + preferences + timestamps` (private)
- `@firestore.rules` — `users/{userId}` rules (lines 126–143): authenticated read on public, self-only on private
- `@ai_specs/profile-and-functions-guide-plan.md` — projection-split schema reference (public vs private subdoc)

**Relevant constraints:**
- Public projection (`users/{uid}`) is readable by any authenticated user → only place fields here that are safe to share (display name, photo, payment handles)
- Private projection (`users/{uid}/private/profile`) is self-only → email, providerIds, FCM tokens, preferences live here
- `createUserIfNotExists()` must remain idempotent — existing callers depend on early-return when public doc already exists
- Apple OAuth returns `displayName` only on the *first* sign-in; subsequent logins return null. Firebase caches it after first login, so `firebase_auth.User.displayName` is usually populated — but not guaranteed.
- Apple OAuth never returns a `photoURL` at all → photoUrl will be null for Apple-only accounts (UI must already gracefully handle missing avatars)
</background>

<user_flows>
**Primary flow — new user, Google OAuth:**
1. User taps "Continue with Google" on login screen
2. Firebase OAuth sheet completes; `firebase_auth.User` is created with `displayName='Jane Doe'`, `photoURL='https://lh3.googleusercontent.com/...'`, `email='jane@gmail.com'`, `providerData=[google.com]`
3. `AuthNotifier`'s `authStateChanges` listener fires with the mapped `AppUser`
4. Listener calls `FirestoreUserRepository.createUserIfNotExists()` with `uid`, `email`, `displayName='Jane Doe'`, `photoUrl=<googleusercontent URL>`, `providerIds=['google.com']`
5. Repository writes public doc (`displayName`, `photoUrl`) + private subdoc (`email`, `providerIds`, `preferences`, timestamps) in a batch
6. State transitions to `Authenticated(user)`; router proceeds to onboarding/dashboard
7. User sees their name + avatar on profile screen without ever visiting Edit Profile

**Primary flow — new user, email signup:**
1. User submits email + password + displayName form
2. Firebase Auth user created; `signUpWithEmail` writes the displayName to the Auth profile
3. Listener fires → `createUserIfNotExists` called with displayName from form, photoUrl=null, providerIds=['password']
4. Doc written; user proceeds to onboarding

**Alternative flow — Apple OAuth, first sign-in:**
- Same as Google but provider returns displayName='Jane' (first login only) and photoURL=null
- Doc written with displayName='Jane', photoUrl=null, providerIds=['apple.com']

**Alternative flow — Apple OAuth, subsequent login on a fresh install (no Firebase cache, displayName lost):**
- Provider returns displayName=null, photoURL=null, email='jane@privaterelay.appleid.com'
- Listener calls `createUserIfNotExists` with displayName=null
- Repository (or caller) applies fallback: `deriveDisplayNameFromEmail('jane@privaterelay.appleid.com')` → 'Jane'
- Doc written with derived displayName, photoUrl=null

**Alternative flow — returning user, doc already exists:**
- Listener fires on every cold-start with cached session, every token refresh, every sign-in
- `createUserIfNotExists` reads the public doc; if it exists, early-returns without writing
- No-op; user proceeds normally

**Alternative flow — user previously edited displayName in app, signs in again on another device:**
- Existing public doc has displayName='Janie' (user-edited)
- `createUserIfNotExists` early-returns (doc exists)
- User-edited value is preserved; provider's stale displayName never overwrites it

**Error flow — Auth succeeds, Firestore write fails (offline/transient):**
- `createUserIfNotExists` catches the exception, logs via `dart:developer log`, swallows
- Sign-in proceeds; state still becomes `Authenticated(user)`; router proceeds normally
- On next successful auth state change (next app open, next sign-in), the listener retries — public doc still missing, write succeeds
- Self-healing; no UI error surfaced

**Error flow — listener fires but mapped AppUser is null:**
- Should not happen (we only call when listener emits non-null), but guard anyway: skip the call
</user_flows>

<requirements>
**Functional:**

1. `FirestoreUserRepository.createUserIfNotExists()` MUST accept four parameters: `uid` (String, required), `email` (String, required), `displayName` (String?), `photoUrl` (String?), `providerIds` (List<String>, default `const []`).

2. When the public `users/{uid}` doc does NOT exist, the method MUST write in a single batch:
   - Public doc fields: `displayName` (the resolved value — see #4), `photoUrl` (nullable, written as null if absent)
   - Private subdoc `users/{uid}/private/profile` fields: `email`, `providerIds`, `preferences: {dataOptIn: false, currency: 'USD'}`, `createdAt: serverTimestamp()`, `updatedAt: serverTimestamp()`

3. When the public doc already exists, the method MUST early-return without any writes (existing behavior — preserve idempotency).

4. A pure helper `String deriveDisplayNameFromEmail(String? email)` MUST resolve the displayName fallback:
   - Strip everything after `+` in the local-part (e.g., `jane+work@x.com` → local `jane`)
   - Split local-part by `.`, `_`, `-` into tokens; drop empty tokens
   - Title-case each token (first letter uppercase, rest lowercase if alphabetic; preserve all-numeric tokens as-is)
   - Join tokens with single space
   - If email is null/empty/has no local-part: return `'CrewPoint user'`
   - Examples: `jane.doe@x.com` → `Jane Doe`; `JOHN_smith@x.com` → `John Smith`; `a@x.com` → `A`; `12345@x.com` → `12345`; `jane+work@x.com` → `Jane`; `''` → `CrewPoint user`

5. The displayName resolution at the call site MUST be: `(rawDisplayName?.trim().isNotEmpty == true) ? rawDisplayName!.trim() : deriveDisplayNameFromEmail(email)`. The repository writes whichever value the caller resolves — keep the helper out of the repository so it stays pure and testable.

6. `AuthNotifier` MUST invoke `createUserIfNotExists` from a single site: inside the `authStateChanges` listener at `lib/app/features/auth/application/auth_provider.dart:47`, immediately after determining `user != null`. The call MUST be fire-and-forget (`unawaited`) so it does not delay the state transition to `Authenticated(user)`.

7. The per-method calls in `signInWithEmail`, `signUpWithEmail`, `signInWithGoogle`, `signInWithApple` MUST NOT be modified to add the call directly — the listener is the single source of truth.

8. `AuthNotifier` MUST gain a dependency on the user repository (via Riverpod). The existing `userRepositoryProvider` (or equivalent) already exists in `lib/app/features/profile/`; use it. Do NOT introduce a new provider for this purpose.

9. Cold-start with cached session (existing user reopens app) MUST also trigger `createUserIfNotExists` — this is satisfied automatically because `authStateChanges` emits on subscription. The early-return path keeps it free for existing users.

**Error Handling:**

10. Firestore write failures inside `createUserIfNotExists` MUST be caught, logged via `dart:developer.log` with `name: 'profile'`, and swallowed. They MUST NOT propagate to `AuthNotifier` or change the auth state.

11. If `createUserIfNotExists` throws synchronously (it shouldn't, but guard), `AuthNotifier`'s call site MUST NOT crash. Wrap the unawaited future call so any sync throw is caught.

**Edge Cases:**

12. Multiple rapid auth state emissions (e.g., listener fires twice in quick succession on token refresh) MUST be safe — the early-return on existing public doc handles this. No additional debouncing needed.

13. If the public doc exists but the private subdoc is missing (legacy state from manual data entry), the method still early-returns — out of scope to backfill private subdocs.

14. `providerIds` from `firebase_auth.User.providerData.map((p) => p.providerId).toList()` may include duplicates if the user has linked the same provider twice; preserve as-is (Firebase shouldn't allow this anyway).

**Validation:**

15. New unit tests for `deriveDisplayNameFromEmail` MUST cover: typical name, single-token, all-numeric, plus-tag, mixed case, empty/null, no local-part.
16. Updated repository tests MUST cover the new `photoUrl` + `providerIds` parameters in both the create-path and the early-return path.
17. New `AuthNotifier` tests MUST verify the listener invokes `createUserIfNotExists` exactly once per non-null auth emission, with the correct resolved displayName (provider-supplied vs derived).
</requirements>

<boundaries>
**Edge cases:**
- Apple OAuth subsequent login with displayName=null and Apple's private relay email (`@privaterelay.appleid.com`): derivation yields the relay-token portion (e.g., `abc123` → `Abc123`). Acceptable; user can edit later.
- Email contains only `+` tags (e.g., `+work@x.com`): local-part before `+` is empty → fallback to `'CrewPoint user'`.
- Email local-part is exactly one character (`a@x.com`): yields `'A'`. Acceptable.
- Anonymous auth (Firebase Auth supports `signInAnonymously`): currently not used by this app. If introduced later, anonymous users have no email — the listener should skip the call (add a `email == null || email.isEmpty` guard).

**Error scenarios:**
- Firestore write fails (offline, rules denial, quota): logged, swallowed. Self-heals on next listener emission.
- `userRepositoryProvider` not yet ready when listener fires: should not happen since providers are eagerly resolved, but `ref.read` is safe to call from inside the listener body.

**Limits:**
- No retry loop, no exponential backoff inside the repository — relying on auth listener re-firing as the natural retry mechanism. If that proves insufficient in production telemetry, follow up with explicit retry.
- No queue or debounce for multiple in-flight `createUserIfNotExists` calls — Firestore's transactional get-then-batch-set is safe; worst case is wasted reads.
</boundaries>

<implementation>
**Files to modify:**

1. `lib/app/features/profile/data/firestore_user_repository.dart`
   - Update `UserRepository` interface (in `domain/repositories/`) `createUserIfNotExists` signature to include `String? photoUrl` and `List<String> providerIds = const []`
   - Update `FirestoreUserRepository.createUserIfNotExists` implementation:
     - Accept new params
     - Public doc batch write: include `photoUrl` (whether null or not — Firestore stores null fields fine, but prefer omitting when null to keep doc shape clean; use a map literal that conditionally includes it)
     - Private subdoc batch write: include `providerIds` alongside email/preferences/timestamps

2. `lib/app/features/auth/application/auth_provider.dart`
   - Inject `UserRepository` via `ref.read(userRepositoryProvider)` inside the listener body
   - In the `authStateChanges` listener (around line 47), when `user != null`, call `unawaited(_ensureUserDoc(user))`
   - Add private method `Future<void> _ensureUserDoc(AppUser user) async { ... }` that:
     - Resolves displayName: trimmed `user.displayName` if non-empty, else `deriveDisplayNameFromEmail(user.email)`
     - Calls `userRepo.createUserIfNotExists(uid: user.uid, email: user.email ?? '', displayName: resolved, photoUrl: user.photoUrl, providerIds: user.providerIds)`
     - Wraps in try/catch to swallow any synchronous throw (defense-in-depth)

3. **New file:** `lib/app/features/auth/domain/display_name_helper.dart`
   - Pure top-level function `String deriveDisplayNameFromEmail(String? email)` per requirement #4
   - No dependencies on Flutter, Firebase, or any service — purely string transformation

4. `test/features/profile/data/firestore_user_repository_test.dart` (existing)
   - Update existing `createUserIfNotExists` tests for new params
   - Add coverage for: photoUrl written to public doc; providerIds written to private subdoc; null photoUrl handled; empty providerIds handled

5. **New file:** `test/features/auth/domain/display_name_helper_test.dart`
   - Cover all examples in requirement #4 plus boundaries listed in requirement #15

6. `test/features/auth/application/auth_provider_test.dart` (existing or new)
   - Add tests verifying listener invokes the repository method exactly once per emission, with correct resolved displayName

**Patterns to follow:**
- Keep `deriveDisplayNameFromEmail` pure — no Firebase dependency, no logging. This is the testable seam.
- Use `unawaited(future)` from `dart:async` to fire-and-forget (lints will complain otherwise).
- Match existing repository code style: `dart:developer.log` with `name: 'profile'` for swallowed errors.
- Preserve the existing batch-set pattern; do not switch to runTransaction unless there's a concrete reason.

**What to avoid (and why):**
- Do NOT call `createUserIfNotExists` from individual signIn methods. Reason: the `authStateChanges` listener already covers every entry path including cold-start with cached session — duplicating the call invites bugs and means future auth methods (e.g., anonymous, phone) would need to remember the call.
- Do NOT add a Cloud Function trigger for this. Reason: scope decision — client-side path is simpler, idempotent, and self-heals. Cloud Function would also lose access to OAuth-only fields like Apple's first-login displayName which only the client receives.
- Do NOT download the provider photo to Firebase Storage. Reason: scope decision — accept that provider URLs may rotate; user can re-upload via Edit Profile to switch to a Storage-backed URL.
- Do NOT modify Firestore security rules. The existing rules already allow self-write to both public doc and private subdoc, which is exactly what `createUserIfNotExists` does.
- Do NOT promote `providerIds` to the public doc. Reason: minor information leak (other users could see auth method) for no current UX benefit.
</implementation>

<validation>
**Baseline automated coverage outcomes:**
- **Logic / business rules:** 100% branch coverage on `deriveDisplayNameFromEmail` (pure function, trivial to fully cover).
- **Repository behavior:** `createUserIfNotExists` covered for: (a) writes correct public + private fields when doc absent, (b) early-returns when doc exists, (c) handles null photoUrl, (d) handles empty providerIds, (e) swallows Firestore exceptions.
- **Auth state listener:** `AuthNotifier` covered for: (a) listener invokes repository method on first non-null emission, (b) does not invoke on null emission, (c) resolves provider-supplied displayName when present, (d) falls back to derived displayName when provider returns null/empty, (e) does not block state transition to `Authenticated`.

**TDD-first expectations (per `flutter-tdd` skill):**

Implement vertical slices in this order, one RED → GREEN → REFACTOR cycle per slice. Do not write the next slice's test until the previous slice is green.

Slice 1 — `deriveDisplayNameFromEmail` happy path:
- RED: test `'jane.doe@x.com' → 'Jane Doe'`
- GREEN: minimal split-and-titlecase implementation
- REFACTOR: extract token-titlecase helper if multiple tests demand it

Slice 2 — `deriveDisplayNameFromEmail` edge cases (one test at a time, in this order):
- All-numeric local: `'12345@x.com' → '12345'`
- Plus-tag stripping: `'jane+work@x.com' → 'Jane'`
- Single-char local: `'a@x.com' → 'A'`
- Underscore separator: `'JOHN_smith@x.com' → 'John Smith'`
- Empty/null: `'' → 'CrewPoint user'`, `null → 'CrewPoint user'`
- No local-part (`'@x.com'`): `→ 'CrewPoint user'`

Slice 3 — repository writes new fields (RED → GREEN):
- Test that `createUserIfNotExists(uid, email, displayName: 'X', photoUrl: 'http://...', providerIds: ['google.com'])` writes `photoUrl: 'http://...'` to public doc and `providerIds: ['google.com']` to private subdoc, using `fake_cloud_firestore`

Slice 4 — repository handles nulls (RED → GREEN):
- Test that `photoUrl: null` results in null (or absent) field in public doc; `providerIds: const []` results in empty array in private subdoc

Slice 5 — repository idempotency preserved (RED → GREEN):
- Existing test should still pass; if not, verify nothing in the new params changed early-return behavior

Slice 6 — `AuthNotifier` listener triggers on emission:
- RED: test that when `authStateChanges` emits a non-null user, the mock `UserRepository.createUserIfNotExists` is called exactly once with the expected resolved args
- GREEN: add the listener-side call

Slice 7 — `AuthNotifier` falls back to derived name (RED → GREEN):
- Test that when `user.displayName` is null and `user.email = 'apple+sub@privaterelay.appleid.com'`, the call receives `displayName: 'Apple'`

**Testability seams (must be in place before implementing):**
- `deriveDisplayNameFromEmail` is a pure top-level function in its own file — directly importable into tests, no DI needed.
- `UserRepository` is already abstracted via interface; tests inject a mock or `fake_cloud_firestore`-backed concrete.
- `AuthRepository` already injectable into `AuthNotifier` via Riverpod override; reuse the existing pattern to inject `UserRepository`.
- Tests for `AuthNotifier` use Riverpod's `ProviderContainer` with overrides for both repositories.

**Mocking policy:**
- Prefer `fake_cloud_firestore` for repository tests (matches existing test file pattern).
- Use a hand-rolled fake `UserRepository` for `AuthNotifier` tests — captures call count + last args. Avoid mocktail unless project already uses it elsewhere.
- Do NOT mock `firebase_auth` directly in `AuthNotifier` tests — work at the `AuthRepository` interface seam, which already has a fake/mock pattern in `test/features/auth/`.

**Test-type mapping for this feature:**
- **Unit tests (logic):** `deriveDisplayNameFromEmail`, `createUserIfNotExists` repository behavior, `AuthNotifier` listener trigger.
- **Widget tests:** none required — this feature has zero UI surface. Visual verification happens via existing profile screen rendering correctly with the now-populated doc.
- **Robot-driven journey tests:** none required — no new user-facing journey or screen. The feature is invisible plumbing; existing journey tests (sign-in → onboarding → dashboard → profile) implicitly verify it works because the profile screen now shows data without an explicit Edit Profile detour.

**Manual verification (one-time, after code lands):**
- Fresh install on a clean device, sign in with Google → check Firestore console: public doc has displayName + photoUrl; private subdoc has email, providerIds=['google.com'], preferences, timestamps.
- Sign out → sign in with same account → verify no duplicate writes, doc unchanged.
- Sign in with Apple (clean install) → check Firestore: photoUrl is null, providerIds=['apple.com'], displayName populated.
- Manually delete the Firestore doc while user is signed in → background app → reopen → verify doc is recreated on the next listener emission (cold-start path).

**Known testing risks:**
- `AuthNotifier` tests must avoid hitting real Firebase. Existing test setup should already overrideAuthRepository — verify before relying on it.
- Apple's relay-email derivation (e.g., `abc123@privaterelay.appleid.com` → `Abc123`) is technically correct per the algorithm but cosmetically unhelpful. Acceptable given user can edit later; flag in code review if reviewer wants tighter handling.
</validation>

<done_when>
1. `lib/app/features/auth/domain/display_name_helper.dart` exists with the pure `deriveDisplayNameFromEmail` function and is fully unit-tested.
2. `FirestoreUserRepository.createUserIfNotExists` accepts and persists `photoUrl` (public) and `providerIds` (private subdoc); existing tests updated and new tests added; idempotency preserved.
3. `AuthNotifier`'s `authStateChanges` listener calls `createUserIfNotExists` (fire-and-forget) on every non-null emission with the resolved displayName; new tests verify listener behavior including the email-derived fallback path.
4. No per-method calls were added to `signInWithEmail` / `signUpWithEmail` / `signInWithGoogle` / `signInWithApple` — listener is the only call site.
5. `flutter analyze` clean; `flutter test` passes; `riverpod_lint` clean (no missed unawaited or invalid_use_of_internal_member warnings).
6. Manual smoke test on simulator (Google sign-in → Firestore console shows public + private docs populated) confirms end-to-end behavior.
7. Firestore security rules unchanged (verified by `git diff firestore.rules` showing no edits).
8. No Cloud Functions changes (verified by `git diff functions/` showing no edits).
</done_when>
