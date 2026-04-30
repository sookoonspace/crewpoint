# Account linking behavior

How CrewPoint handles users who sign in with the same email through
multiple providers, what happens when those signals conflict, and how
to recover an account that's been silently upgraded.

> **TL;DR**: Firebase will **drop a password credential** when the same
> email later signs in via OAuth — but only if the email/password
> account was **never verified**. CrewPoint now sends a verification
> email immediately on signup and surfaces a banner until the user
> verifies, so this auto-upgrade trap should not fire on accounts
> created post-Phase-2. Recovery for already-affected accounts is
> "Forgot password" → reset → password provider re-added alongside
> OAuth.

## The scenario

Reproduced in our own dev testing during Phase 1's Apple sign-in
work. Numbered for reference:

1. User signs up with email + password. Firebase creates a user with
   UID `X` and `emailVerified: false`.
2. Same user later taps "Continue with Apple" using **the same email
   address**. Apple's identity token has `emailVerified: true`.
3. Firebase recognises the email match and runs its **auto-link**
   logic on the account in question.
4. Result: Firebase **keeps UID `X`**, **adds `apple.com`** to
   `providerData`, and **removes the `password`** provider entirely.
   The Firestore `users/X` doc is unchanged. Email is now
   `emailVerified: true`.
5. The next email/password sign-in attempt for that email returns
   `wrong-password` / `invalid-credential` — the password the user
   originally chose simply isn't on the account anymore.

The Firebase Console → Authentication → Users tab shows a single row
for that email with **only the Apple provider icon**. From the user's
perspective this looks like Apple "took over" the account.

## Why Firebase does this

Trust hierarchy: the OAuth-provided email is **verified by Apple**
(or Google), while the email/password credential was registered
without proving ownership of the email. If Firebase trusted the
unverified password, anyone could pre-claim a victim's email with a
chosen password and wait for the victim to sign in via Apple — at
which point both credentials would be valid and the attacker would
have a backdoor.

By dropping the unverified password and treating the OAuth provider
as canonical, Firebase ensures that only the **provably owned**
credential survives. This matches the general security stance of
"verified email > unverified email."

When the email **was** verified at password-signup time, Firebase
auto-links the OAuth provider as a sibling — both credentials remain
valid and the user can sign in with either. That's the merge case.

## What CrewPoint does about it

### Phase 2 — verification gate (default for all new signups)

Every email/password signup now triggers `sendEmailVerification()`
immediately after `createUserWithEmailAndPassword`. A persistent
banner (`Key('auth.verifyBanner')`) appears at the top of the
authenticated shell whenever:

- the user is `Authenticated`,
- `emailVerified` is `false`, AND
- the only attached provider is `password` (`isPasswordOnly` getter).

The banner exposes two actions:

- **Resend** — re-sends the verification email. Rate-limited by
  Firebase (`too-many-requests` error code → friendly message).
- **I've verified — refresh** — reloads the user from Firebase via
  `currentUser.reload()` and updates the `emailVerified` flag. The
  banner self-hides on success.

If the user verifies before any OAuth attempt, the auto-upgrade trap
never fires — Firebase auto-links rather than auto-drops.

### Phase 3 — provider-suggestion hint on password failure

When password sign-in fails, CrewPoint best-effort calls
`fetchSignInMethodsForEmail(email)` and inspects the result:

- `['password']` or `['password', 'apple.com']` etc. — silent fall
  through to the generic "Incorrect email or password." snackbar
  (the user just typed wrong; nothing to suggest).
- `['apple.com']` or `['google.com']` (no `password`) — surface
  the "This email is registered with Apple. Tap 'Continue with
  Apple' above." snackbar. Stable key:
  `auth.suggestProvider.{apple|google|other}`.
- `[]` — never suggest. Empty is the privacy-protected response when
  Email Enumeration Protection is on, OR when no account exists, OR
  on any error. Conflating the cases would leak account existence.

This means a user whose password got silently dropped by the
auto-upgrade gets routed straight to the OAuth tile that owns their
account, instead of being stuck on a generic error.

## Recovery path for affected accounts

For users whose password was already dropped (Phase 2 + 3 don't
help retroactively):

1. On the auth gate, tap the OAuth tile that now owns the account
   (e.g., **Continue with Apple**) — confirms they can still sign
   in.
2. Sign out.
3. On the auth gate, tap **Forgot password** with the email.
4. Firebase emails a reset link.
5. Set a new password.
6. The **`password` provider is re-added** alongside the OAuth one.
   Firebase Console → Users now shows both icons on the row.

UID is preserved through this flow; no Firestore data is lost.

## "Hide my email" Apple relay edge case

Apple's "Hide my email" feature returns a relay address like
`xxx@privaterelay.appleid.com` to Firebase instead of the user's real
email. That relay **does not match** the original email/password
account's email, so Firebase treats them as different accounts:

- A separate user record is created (different UID).
- The original email/password account is untouched.
- Apple's relay account has its own Firestore `users/{uid}` doc.

Result: a user who picked "Hide my email" once won't accidentally
upgrade their existing email/password account — but they will end up
with two distinct CrewPoint identities tied to the same human. Apple
sign-in is sticky to whichever choice the user made on the first
authorization; reverting requires the user to revoke access in their
Apple ID settings and start over.

We do not currently merge these manually. If a user reports it,
direct them to revoke + re-authorize with "Share my email."

## How to inspect linked providers on a user

### Firebase Console (operator)

Authentication → Users tab → search for the email → the **Sign-in
providers** column shows one icon per attached provider:

- Email/password: envelope icon
- Apple: apple icon
- Google: G logo

Hovering the row also reveals the `providerData` entries.

### In-app (developer / programmatic)

```dart
final user = FirebaseAuth.instance.currentUser;
for (final p in user!.providerData) {
  print('${p.providerId}: ${p.email}');
}
// Example output:
// password: alice@example.com
// apple.com: alice@example.com
```

`AppUser.providerIds` (added in Phase 2) exposes the same data to the
rest of the app, and `AppUser.isPasswordOnly` is the simple boolean
that drives the verification banner.

## Firebase Console settings audit

Run this checklist on each flavor (`crewpoint-dev`,
`crewpoint-stg`, `crewpoint-prod`) once. Auth-side settings are
independent per project so a misconfig on one flavor won't show up
on another.

### User account linking

Path: **Firebase Console → Authentication → Settings tab → User
account linking**.

| Setting | Status | Why |
| --- | --- | --- |
| ✅ Link accounts that use the same email *(default)* | **Required** | Drives the verified-email merge logic this doc relies on. |
| ❌ Create multiple accounts for each email *(legacy)* | Don't pick | Each provider would create a separate user; CrewPoint's data flows assume a stable UID per real human. |

If the legacy mode was ever selected, switch to "Link accounts" and
re-test sign-up + Apple sign-in with the same email — you should see
a single row in the Users tab afterwards, not two.

### Email enumeration protection

Path: **Firebase Console → Authentication → Settings tab → Email
enumeration protection**.

| Setting | Recommendation | Trade-off |
| --- | --- | --- |
| ✅ **Enabled** *(recommended)* | Keep ON | Phase 3's provider-suggestion hint silently degrades — the snackbar falls back to the generic "Incorrect password" message because `fetchSignInMethodsForEmail` returns empty. Worth the security trade-off. |
| ⚠️ Disabled | Only if you need the suggest-provider UX badly | Lets unauthenticated callers learn whether an email is registered. Don't disable on prod. |

CrewPoint's Phase 3 widget tests assert that the empty-list response
falls back to the generic snackbar specifically so this protection
stays usable.

### Authorized domains

Path: **Firebase Console → Authentication → Settings tab → Authorized
domains**.

For each flavor, confirm the domains the web app runs on are listed.
See `docs/google-sign-in-web-setup.md` and
`docs/apple-sign-in-web-setup.md` Step 6 — they enumerate the exact
entries per flavor.

## Limitations

- **Phase 3 hint requires Email Enumeration Protection OFF** to
  surface. We've chosen security over UX hint here. Most users hit
  the wrong-password message instead of the suggestion.
- **The verification banner is non-blocking.** A user can keep using
  the app indefinitely without verifying — they just see the banner
  every time they're signed in. We chose this over hard-blocking the
  dashboard so users can complete in-app actions and verify later.
  Future-self: revisit if abuse rates become a concern.
- **No in-app "Linked sign-in methods" UI yet.** Users can't see
  which providers are attached or unlink one. Tracked under
  `ai_specs/todo.md`.
- **No explicit account-linking ceremony.** A user who's OAuth-only
  and wants to add a password must use the Forgot password flow
  (which Firebase handles via email link). Tracked under
  `ai_specs/todo.md` as the V2 "explicit linking flow."

## Cross-references

- `docs/google-sign-in-web-setup.md` — Google sign-in operator runbook.
- `docs/apple-sign-in-web-setup.md` — Apple sign-in operator runbook.
- `docs/web-hosting-guide.md` — `authDomain` decision, Firebase Auth
  Authorized Domains list per flavor.
- `lib/app/features/auth/data/firebase_auth_error_messages.dart` —
  user-facing copy for popup-blocked / cancelled-popup-request /
  too-many-requests / wrong-password.
- `lib/app/features/auth/presentation/widgets/email_unverified_banner.dart`
  — the Phase 2 banner.
- `lib/app/features/auth/presentation/widgets/email_auth_form.dart`
  — the Phase 3 suggest-provider snackbar.
- `ai_specs/auth-google-mobile-fix-plan.md` — phased plan that drove
  this doc.
