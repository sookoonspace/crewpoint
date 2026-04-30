## Overview

Fix Google sign-in mobile crash by unifying onto Firebase's `signInWithProvider(GoogleAuthProvider)` (same pattern Apple uses). Close the email-verification gap that lets Firebase silently strip the password credential when the same email later signs in via OAuth. Improve sign-in error UX so users land on the right provider instead of guessing. Document the auto-upgrade behavior + recovery paths.

## Context

- **Structure**: feature-first. Auth lives in `lib/app/features/auth/data/` and `lib/app/features/auth/application/`.
- **State management**: Riverpod 3 `Notifier`s. `authProvider` exposes the `IAuthService` seam.
- **Reference implementations**:
  - `lib/app/features/auth/data/firebase_auth_service.dart` lines 87-98 — `signInWithApple()` already uses `signInWithProvider(AppleAuthProvider)`. Mirror it for Google.
  - Phase 6's `sign_in_with_apple` removal — same pubspec simplification pattern.
  - `lib/app/features/auth/data/firebase_auth_error_messages.dart` — central error-code → user-message helper.
- **Root-cause summary** (from the current incident):
  - Test account: signed up with email+password (Firebase set `emailVerified: false` because we never call `sendEmailVerification()`).
  - Same user later signed in with Apple (Apple-issued ID token has `emailVerified: true`).
  - Firebase's "Link accounts that use the same email" mode upgraded the account: kept the UID, added `apple.com` as a provider, **removed the unverified `password` provider** because an OAuth provider's verification is considered canonical and the unverified password is treated as untrusted.
  - Password sign-in for that email now returns `wrong-password` / `invalid-credential` — there is no password on file anymore.
  - Recovery for already-affected accounts: "Forgot password" → reset → password provider re-added alongside Apple. No data loss.
- **Google mobile crash hypothesis**: `google_sign_in: ^6.2.2` legacy native plugin path (Android 14 background restrictions / iOS URL-scheme misconfig). Switching to `signInWithProvider` removes the native plugin; Firebase Auth handles the OAuth flow via Custom Tab / SafariViewController. Apple already uses this path successfully.
- **Trade-off (Google)**: native account picker (faster for already-signed-in users) → in-app browser OAuth flow. Acceptable for V1.
- **Assumptions/Gaps**:
  - Firebase Console → Authentication → Settings → User account linking is set to **"Link accounts that use the same email"** (Firebase default). The auto-upgrade behavior depends on this setting; Phase 4 captures it.
  - Firebase Auth password-reset email template is configured for each flavor (Console default works; can be customized later).
  - Re-authentication during account deletion (`AccountDeletionService.reAuthenticateWithGoogle`) also uses `google_sign_in`; migrate it in the same slice.

## Plan

### Phase 1: Unify Google sign-in onto `signInWithProvider`

- **Goal**: Google sign-in works on iOS + Android + web through Firebase's native OAuth path. `google_sign_in` dep removed.
- [x] `lib/app/features/auth/data/firebase_auth_service.dart` — `signInWithGoogle` now uses `signInWithProvider(GoogleAuthProvider()..addScope('email')..addScope('profile'))`; `googleSignIn` constructor param + `_googleSignIn` field + `package:google_sign_in/google_sign_in.dart` import dropped; `signOut` no longer calls `_googleSignIn.signOut()` (Firebase handles its own session). The existing `firebaseAuthErrorMessage` helper already maps `popup-blocked` / `popup-closed-by-user` / `cancelled-popup-request` from Phase 6.
- [x] `lib/app/core/services/account_deletion_service.dart` — `reAuthenticateWithGoogle()` now calls `currentUser?.reauthenticateWithProvider(GoogleAuthProvider..addScopes)`; `googleSignIn` constructor param + field + import dropped.
- [x] `pubspec.yaml` — `google_sign_in: ^6.2.2` removed with an explanatory comment that consolidates both Google + Apple removals (single Firebase Auth path for all OAuth providers, no native plugin glue).
- [x] `lib/app/core/providers.dart` — `authServiceProvider` and `accountDeletionServiceProvider` already use no-arg / arg-only-internal-state constructors; no changes needed.
- [x] Search the test harness for `GoogleSignIn` references — `grep -rn GoogleSignIn test/` returns empty.
- [ ] Manual smoke (mobile, real device): tap Continue with Google → consent screen opens in an in-app browser → sign in → app lands on dashboard. **Manual user step**
- [ ] Manual smoke (web, dev hosting): same flow, popup-based — confirms web path is unchanged. **Manual user step**
- [x] Verify: `flutter analyze` clean; `flutter test` 165 pass + 4 screenshot suites skipped; `cd functions && npm run build` clean

### Phase 2: Email verification for email/password signups

- **Goal**: close the silent-upgrade trap. Email/password accounts must verify email before they're considered "complete"; users learn that early so they don't get surprised when OAuth later promotes the account and drops their password.
- [x] `lib/app/core/services/i_auth_service.dart` — `IAuthService` gains `Future<void> sendEmailVerification()` and `Future<void> reloadCurrentUser()`. `AuthUser` gains `emailVerified` + `providerIds`.
- [x] `lib/app/features/auth/data/firebase_auth_service.dart` — implements both; `signUpWithEmail` fire-and-forgets `sendEmailVerification()` after the user is created (failure logged, doesn't block the signup). `_mapUser` populates `emailVerified` and `providerIds` from the underlying `fb.User`.
- [x] `lib/app/features/auth/data/auth_repository.dart` + `lib/app/features/auth/domain/repositories/i_auth_repository.dart` — repository gains matching `sendEmailVerification` + `reloadCurrentUser` methods; `_toAppUser` propagates `emailVerified` + `providerIds`.
- [x] `lib/app/features/auth/domain/models/app_user.dart` — `AppUser` gains `emailVerified` + `providerIds` + an `isPasswordOnly` getter (drives banner visibility).
- [x] `lib/app/features/auth/application/auth_provider.dart` — `AuthNotifier` exposes `resendVerificationEmail()` and `reloadCurrentUser()` methods. Errors during resend surface via a transient `AuthError` then restore the prior `Authenticated` state so the user isn't kicked out of the app.
- [x] `lib/app/features/auth/presentation/widgets/email_unverified_banner.dart` — non-dismissible banner with `Key('auth.verifyBanner')`. Two action buttons (`auth.verifyBanner.resend`, `auth.verifyBanner.refresh`) call the matching notifier methods. Self-hides for verified users + OAuth-linked accounts.
- [x] `lib/app/core/router/app_router.dart` — banner mounted above the `StatefulNavigationShell` body inside the existing `Consumer` so it renders on every authenticated screen but doesn't pollute `ResponsiveShell`'s provider-free contract.
- [x] TDD: `firebaseAuthErrorMessage('too-many-requests')` returns "Too many attempts. Please wait a minute before trying again."
- [x] TDD: `AuthNotifier.resendVerificationEmail()` calls `sendEmailVerification` exactly once when `Authenticated`; no-ops when `Unauthenticated`. (Plus a parallel test for `reloadCurrentUser`.)
- [x] Widget test: 6 cases in `email_unverified_banner_test.dart` cover signed-out, verified, OAuth-linked (banner absent), unverified-password-only (banner present + email + buttons), and tap behavior on Resend / I've verified.
- [x] `test/app/features/auth/fake_auth_service.dart` — extended with `sendEmailVerificationCalls`, `sendEmailVerificationError`, `reloadCalls`, and a `setCurrentUser` test setter so harnesses don't have to drive sign-in flows just to seed state.
- [ ] Manual smoke: sign up with email+password → verification email lands → tap link → return to app, tap "I've verified" → banner disappears. **Manual user step**
- [x] Verify: `flutter analyze` clean; `flutter test` 175 pass + 4 screenshot suites skipped

### Phase 3: Sign-in error UX — guide users to the right provider

- **Goal**: when password sign-in fails because Firebase auto-upgraded the account, the user is told "this email signs in with Apple/Google — tap that instead" instead of being stuck on a generic "Incorrect email or password" message.
- [ ] `lib/app/core/services/i_auth_service.dart` — add `Future<List<String>> fetchSignInMethodsForEmail(String email)` — wraps `FirebaseAuth.instance.fetchSignInMethodsForEmail(email)` (returns provider strings like `password`, `apple.com`, `google.com`). Disabled-by-default in newer Firebase projects when "Email enumeration protection" is on; this task is best-effort.
- [ ] `lib/app/features/auth/data/firebase_auth_service.dart` — implement, return empty list on failure (don't bubble the exception).
- [ ] `lib/app/features/auth/application/auth_provider.dart` — when `signInWithEmail` returns `AuthResultFailure` for `wrong-password`/`invalid-credential`, internally call `fetchSignInMethodsForEmail` and, if it returns OAuth providers without `password`, surface a structured error: `AuthResultRedirect(suggestedProvider: 'apple.com')`. Email enumeration protection ON → fall back to the existing generic message.
- [ ] `lib/app/features/auth/presentation/widgets/email_auth_form.dart` — on `AuthResultRedirect` show a snackbar / inline message: "This email is registered with Apple. Tap Continue with Apple above." (or Google). Never show this when Firebase doesn't return providers (don't enumerate emails).
- [ ] TDD: `AuthNotifier.signInWithEmail` returns `AuthResultRedirect(suggestedProvider: 'apple.com')` when the underlying service returns `wrong-password` AND `fetchSignInMethodsForEmail` returns `['apple.com']`.
- [ ] TDD: `AuthNotifier.signInWithEmail` returns the existing generic `AuthResultFailure` when `fetchSignInMethodsForEmail` returns `[]` (enumeration protection on) — never leak account existence.
- [ ] TDD: `AuthNotifier.signInWithEmail` returns the existing generic failure when the email genuinely has no account (404-style, `[]` from Firebase).
- [ ] Widget test: when an `AuthResultRedirect` lands on `email_auth_form.dart`, a `Key('auth.suggestProvider.apple')` (or `.google`) snackbar/widget renders with copy mentioning the provider name.
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Document the auto-upgrade behavior + verify Firebase Console settings

- **Goal**: future-self / contributors / support understand exactly what happens when an unverified email/password account collides with an OAuth sign-in; Firebase Console settings are captured per flavor.
- [ ] Manual: per flavor — Firebase Console → Authentication → Settings → **User account linking** = **"Link accounts that use the same email"** (the default that drives the auto-upgrade behavior). If "Create multiple accounts for each email" is selected anywhere, switch and re-test. **Manual user step (per flavor: dev / stg / prod).**
- [ ] Manual: per flavor — Firebase Console → Authentication → Settings → **Email enumeration protection** decision. **Recommend ON** (don't leak existence); accept that Phase 3's "right-provider" hint silently degrades when ON. Document the trade-off.
- [ ] `docs/account-linking-behavior.md` — new doc covering:
  - Plain-English flow walkthrough of the silent-upgrade scenario the user just hit (email+password unverified → OAuth sign-in same email → password credential dropped → only OAuth on the account).
  - Why Firebase does this (security: prevents pre-claim attack on a victim's email).
  - Recovery for an affected account: "Forgot password" → reset email → password provider re-added alongside OAuth. No data loss; same UID.
  - The "Hide my email" Apple relay caveat (different relay address → separate account, can't auto-merge).
  - How to inspect the providers on a user record (Firebase Console Users tab + the `providerData` field on `currentUser`).
  - The Phase 2 (verification banner) and Phase 3 (right-provider hint) defenses + their limitations under email enumeration protection.
- [ ] `docs/google-sign-in-web-setup.md` + `docs/apple-sign-in-web-setup.md` — Cross-references line pointing at `account-linking-behavior.md`.
- [ ] `ai_specs/todo.md` — add follow-ups: (a) optional "Linked sign-in methods" UI under Profile listing providers + offering link/unlink (V2); (b) explicit account-linking flow when password sign-in fails AND user wants to add password to OAuth-only account.
- [ ] Verify: `flutter analyze` && `flutter test` (docs-only — no behavior change)

## Risks / Out of scope

- **Risks**:
  - `signInWithProvider` on Android opens a Custom Tab — if the user's default browser is misconfigured or has aggressive cookie blocking, the round-trip can fail. Test on a clean Chrome install before assuming the migration is good.
  - `fetchSignInMethodsForEmail` is **disabled** when Firebase's email enumeration protection is on. Phase 3 silently degrades to the generic error in that case. Acceptable trade-off — security > UX hint.
  - `sendEmailVerification` is rate-limited per email per minute. The "Resend" button must debounce or we'll surface `too-many-requests` errors to users.
  - Email-verification deliverability depends on the Firebase Auth email template + the user's email provider. Some users won't receive the verification email reliably; the banner's "I've verified — refresh" button gives them a recovery path.
- **Out of scope**:
  - Switching to `signInWithRedirect()` for Safari third-party-cookie users on web (tracked separately in `ai_specs/todo.md`).
  - In-app "Linked sign-in methods" UI for users to inspect / unlink providers.
  - Forcing `Authenticated` state to gate the dashboard on `emailVerified` (Phase 2 just shows a banner; gating the whole app behind verification is a UX decision punted to a later spec).
  - Custom Firebase Auth email-verification template (use Firebase's default copy until product asks for branded copy).
  - Email-link sign-in (passwordless) — separate spec if pursued.
  - Migrating already-affected users in production (none yet; Phase 4 doc captures the recovery path).
