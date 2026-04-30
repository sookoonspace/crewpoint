# Google sign-in for CrewPoint web — setup

Reusable runbook for enabling **"Continue with Google"** on the web app
across the three Firebase projects (`crewpoint-dev`, `crewpoint-stg`,
`crewpoint-prod`). Run the full procedure once per flavor; the
**dev-first** order in `docs/dev-first-rollout-checklist.md` applies.

> **Code is already wired.** `lib/app/features/auth/data/firebase_auth_service.dart`
> calls `_firebaseAuth.signInWithProvider(GoogleAuthProvider())` which
> drives both iOS / Android (system sheet) and web (popup) without a
> `kIsWeb` branch. Nothing in this app's code needs to change for any
> of the steps below.

## Prerequisites (per flavor)

- You have **Editor** or **Owner** on the Firebase project (`crewpoint-<flavor>`).
- You can sign into the linked Google Cloud Console project (same
  project ID as the Firebase project — Firebase projects are GCP
  projects under the hood).
- Web hosting is provisioned for the flavor (see
  `docs/web-hosting-guide.md`).

## Step 1 — Enable Google as a sign-in provider

1. Firebase Console → `crewpoint-<flavor>` → **Authentication** →
   **Sign-in method** tab.
2. Find **Google** in the provider list → click → toggle **Enable**.
3. Set:
   - **Project public-facing name**: `CrewPoint` (this shows on the
     Google consent screen — keep consistent across flavors).
   - **Support email**: a valid email you control. Google requires
     this; users see it on the consent screen.
4. **Save**.

That single toggle automatically:
- Creates an **OAuth 2.0 Web Client ID** under the matching Google
  Cloud project (`APIs & Services → Credentials → OAuth 2.0 Client IDs`).
- Adds the Firebase auth handler URL
  (`https://crewpoint-<flavor>.firebaseapp.com/__/auth/handler`) to
  the OAuth client's **Authorized redirect URIs**.

You don't normally need to touch the Cloud Console for Google sign-in
to work — verify in Step 4 if anything's off.

## Step 2 — Add Authorized Domains in Firebase Auth

Firebase Auth refuses to complete a popup-based sign-in unless the
**originating domain** (the URL the user was on when they clicked
"Continue with Google") is on the Authorized Domains list.

1. Firebase Console → **Authentication** → **Settings** tab →
   **Authorized domains**.
2. Confirm or add (each on its own line):

   | Flavor | Domain |
   | ------ | ------ |
   | dev | `crewpoint-dev.web.app` |
   | dev | `crewpoint-dev.firebaseapp.com` *(usually pre-listed)* |
   | stg | `crewpoint-stg.web.app` |
   | stg | `crewpoint-stg.firebaseapp.com` *(usually pre-listed)* |
   | prod | `crewpoint.sookoon.space` *(custom domain; add it AFTER Stage 4 of `web-hosting-guide.md` connects it)* |
   | prod | `crewpoint-prod.firebaseapp.com` *(usually pre-listed)* |

   Don't add `localhost` to prod. Add `localhost` to dev only if you
   intend to test sign-in against the dev Firebase project from a
   local `flutter run -d chrome` session.

3. **Save**.

## Step 3 — Configure the OAuth consent screen (one-time per project)

Each flavor's consent screen is a separate config. Users see the app
name + logo + support email on the Google sign-in popup, so it's worth
making it look right before public launch.

1. Google Cloud Console → switch project to `crewpoint-<flavor>` →
   **APIs & Services** → **OAuth consent screen**.
2. **User Type**:
   - **External** for prod (any Google account can sign in).
   - **Internal** is only available if you have Google Workspace; not
     applicable for CrewPoint.
3. **App name**: `CrewPoint`.
4. **User support email**: same email you used in Step 1.
5. **App logo** (optional but recommended for prod): upload
   `assets/icons/launcher_icon.png`. Square, ≥ 120×120, ≤ 1 MB.
6. **Application home page**: `https://crewpoint.sookoon.space`.
7. **Application privacy policy link**: `https://sookoon.space/crewpoint/privacy/`.
8. **Application terms of service link**: `https://sookoon.space/crewpoint/terms/`.
9. **Authorized domains** (yes, this is a separate list from Firebase's
   list — same idea, different surface):
   - `crewpoint-<flavor>.firebaseapp.com`
   - For prod: also `sookoon.space`.
10. **Developer contact information**: your email.
11. **Save and continue** → on the **Scopes** page, leave defaults
    (Firebase requests only `email` + `profile` for sign-in). **Save and continue**.
12. **Test users** (only matters while the app is in **Testing**
    mode): add the Google accounts that will sign in for QA. Once you
    submit for production verification (prod only), this list is
    bypassed.
13. **Back to dashboard**.

### Production-only: publishing status

While the consent screen is in **Testing** status, only test users can
sign in. For prod's public launch:

1. **Publishing status** → **Publish app**.
2. Google may ask for verification if the app uses sensitive scopes —
   for sign-in only (`email` + `profile`), this typically passes
   instantly. Sensitive scope review can take days; we don't request
   any in V1.

Dev and stg can stay in **Testing** indefinitely — there's no public
expectation either of those needs to support arbitrary user accounts.

## Step 4 — Verify the OAuth client (sanity check)

If Step 1 didn't auto-populate the client, fix it manually:

1. Google Cloud Console → `crewpoint-<flavor>` → **APIs & Services** →
   **Credentials** → find the **Web client (auto created by Google
   Service)**.
2. Click into it; confirm the URLs lists are populated:
   - **Authorized JavaScript origins**:
     - `https://crewpoint-<flavor>.firebaseapp.com`
     - `https://crewpoint-<flavor>.web.app`
     - For prod: `https://crewpoint.sookoon.space`
     - Add `http://localhost:5000` only if you regularly run
       `firebase emulators:start --only hosting` and need sign-in
       against this flavor's real Firebase project.
   - **Authorized redirect URIs**:
     - `https://crewpoint-<flavor>.firebaseapp.com/__/auth/handler`
     - `https://crewpoint-<flavor>.web.app/__/auth/handler`
3. **Save**.

If you only ever interact with Firebase Console + the in-app sign-in
flow, you usually never visit this page. Visit it only when sign-in
fails with `auth/unauthorized-domain` or `redirect_uri_mismatch`.

## Step 5 — Smoke test

Open the deployed web app for the flavor in **incognito Chrome**:

| Flavor | URL |
| ------ | --- |
| dev | `https://crewpoint-dev.web.app` |
| stg | `https://crewpoint-stg.web.app` |
| prod | `https://crewpoint.sookoon.space` |

Then:

1. On the auth gate, click **Continue with Google**.
2. The Google account chooser appears in a popup.
3. Pick (or paste) the test account.
4. The popup closes; the app lands on the dashboard.
5. Open Firebase Console → Authentication → **Users** tab → confirm a
   row with that account's email exists. Confirm
   `Firestore → users/{uid}` has a doc.

If the popup opens and immediately closes with no console error in
DevTools, that's the **third-party-cookies** issue — see
Troubleshooting below.

## Troubleshooting

### `auth/unauthorized-domain` (in DevTools console)

The originating domain isn't on Firebase's Authorized Domains list.
Add it in Step 2 and refresh.

### `Error 400: redirect_uri_mismatch`

The OAuth client doesn't list the redirect URI Firebase is asking it
to use. Visit the OAuth client (Step 4) and add
`https://crewpoint-<flavor>.firebaseapp.com/__/auth/handler` to
**Authorized redirect URIs**.

### Popup closes silently with no token

Most often **third-party cookies blocked**. The Firebase Auth web SDK
needs the `firebaseapp.com` cookie to round-trip. Browsers that block
all third-party cookies (Brave default, Firefox strict mode, Safari
default) break popup sign-in. Workarounds:

- Use `signInWithRedirect()` instead of the popup variant. Code-side
  change required — out of scope for V1; documented in `ai_specs/todo.md`.
- Tell users to allow `firebaseapp.com` cookies for the site.

### `auth/popup-blocked` snackbar

`firebaseAuthErrorMessage('popup-blocked')` is mapped to the user-facing
"Pop-ups are blocked - please allow pop-ups for this site and try again."
The user needs to click the address-bar pop-up icon and allow once.

### Consent screen says "App is being verified"

Production verification with Google takes 0–6 days for sensitive
scopes. CrewPoint requests only `email` + `profile`, which is
"non-sensitive" — verification is instant. If you see this banner,
double-check you didn't accidentally request additional scopes.

### Test-mode "App not verified" warning

When the consent screen is in **Testing** status, users outside the
test-user list see "Continue (unsafe)" warnings. Either add them to
test users (Step 3) or **Publish app** (prod only).

## Quick reference

| Step | Surface | One-time / per-flavor |
| ---- | ------- | --------------------- |
| 1. Enable Google provider | Firebase Console → Auth | Per flavor |
| 2. Authorized Domains | Firebase Console → Auth | Per flavor |
| 3. OAuth consent screen | Google Cloud Console | Per flavor |
| 4. Verify OAuth client URIs | Google Cloud Console | Per flavor (rarely needed) |
| 5. Smoke test | Browser | Per flavor |

For Apple sign-in, see **[apple-sign-in-web-setup.md](./apple-sign-in-web-setup.md)**.
For the dev → stg → prod rollout order, see
**[dev-first-rollout-checklist.md](./dev-first-rollout-checklist.md)**.
For what happens when the same email signs in via multiple providers
(silent password drop, recovery via Forgot password, "Hide my email"
caveat), see **[account-linking-behavior.md](./account-linking-behavior.md)**.
