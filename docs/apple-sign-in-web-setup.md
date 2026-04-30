# Apple sign-in for CrewPoint web — setup

Reusable runbook for enabling **"Continue with Apple"** on the web app
across the three Firebase projects (`crewpoint-dev`, `crewpoint-stg`,
`crewpoint-prod`). Apple sign-in is significantly more involved than
Google sign-in: it needs Apple Developer Console artifacts on top of
the Firebase configuration. Most of the Apple-side setup is **one-time
per organization** — only the per-flavor pieces vary.

> **Code is already wired.** `lib/app/features/auth/data/firebase_auth_service.dart`
> calls `_firebaseAuth.signInWithProvider(AppleAuthProvider())` which
> drives both iOS (system sheet) and web (popup) without a `kIsWeb`
> branch. Nothing in this app's code needs to change for any of the
> steps below.

> **Web vs mobile, important difference**: native iOS Apple sign-in
> already worked before this guide existed (it uses the App ID
> directly). The web flow is what this guide unblocks — it requires a
> separate **Services ID** and a domain-association file hosted at the
> origin where the app runs.

## Prerequisites

- **Apple Developer Program enrollment** — Sookoon Space must be
  enrolled (paid; ~$99 USD/year for an organization). One enrollment
  covers all flavors.
- **Apple Developer Console access** — you need a role with permission
  to manage Identifiers + Keys (Account Holder, Admin, or App Manager).
- **Editor / Owner on the Firebase project** for the flavor.
- **Web hosting is provisioned and serving the flavor's URL** — so the
  domain-association file can be reached.

## Apple-side topology (read this first)

For Apple sign-in via Firebase's `signInWithProvider(AppleAuthProvider)`,
the runtime flow on web is:

1. User visits e.g. `https://crewpoint.sookoon.space/` and clicks
   "Continue with Apple."
2. Firebase Auth web SDK opens a popup to
   `https://appleid.apple.com/auth/authorize?...&client_id=<services-id>&redirect_uri=https://crewpoint-<flavor>.firebaseapp.com/__/auth/handler&...`.
3. Apple validates that:
   - The **Services ID** (`client_id`) is registered.
   - The **redirect URI** is in the Services ID's allowed return URLs.
   - The **originating domain** (`crewpoint.sookoon.space`) is in the
     Services ID's verified domain list.
4. User authenticates with Apple.
5. Apple redirects to the Firebase auth handler at the
   `*.firebaseapp.com` domain.
6. Firebase auth handler returns to the originating window with a
   credential.

So you'll touch four artifacts on the Apple side:

| Artifact | What it is | Per flavor? |
| -------- | ---------- | ----------- |
| **App ID** | Identifier for the iOS app (com.sookoonspace.crewpoint et al.). Already exists for native iOS sign-in. | One per native iOS bundle (you may have one for prod and one for dev). |
| **Services ID** | Web-only identifier. Tells Apple "this Services ID can use Sign in with Apple from these domains." | One can serve all flavors with multiple registered domains, OR one per flavor for cleaner separation. **This guide uses one Services ID per flavor.** |
| **Key (.p8)** | Private key Firebase uses to verify Apple's identity tokens. Has a Key ID. | **One key can be reused across flavors** — same Sookoon Space Apple Developer account signs all of them. Recommended: one key. |
| **Domain verification file** | Apple-issued text payload hosted at `<domain>/.well-known/apple-developer-domain-association.txt`. Proves you control the domain. | Per domain. Each Services ID's verified-domain list is verified separately. |

## Step 1 — Confirm "Sign in with Apple" capability on the App ID (one-time)

Skip if you already configured native iOS Apple sign-in (it's a
prerequisite for that too). Otherwise:

1. Apple Developer Console → **Certificates, Identifiers & Profiles**
   → **Identifiers** → find your App ID
   (`space.sookoon.crewpoint.app` or similar).
2. **Capabilities** tab → check **Sign in with Apple** → **Save**.
3. If the App ID was used by an existing provisioning profile,
   regenerate the profile (Xcode does this automatically on next
   archive).

## Step 2 — Create a Services ID for this flavor

This is the **web-side identifier**. The recommended naming convention
in this guide is `com.sookoonspace.crewpoint.<flavor>.web`:

- `com.sookoonspace.crewpoint.dev.web`
- `com.sookoonspace.crewpoint.stg.web`
- `com.sookoonspace.crewpoint.prod.web` (or simply `com.sookoonspace.crewpoint.web` for prod)

**Steps** (run for each flavor you're setting up):

1. Apple Developer Console → **Certificates, Identifiers & Profiles**
   → **Identifiers** → **+** (top right) → **Services IDs** → **Continue**.
2. **Description**: `CrewPoint <Flavor> Web` (e.g. `CrewPoint Prod Web`).
3. **Identifier**: `com.sookoonspace.crewpoint.<flavor>.web`.
4. **Continue** → **Register**.
5. **Open the new Services ID** in the list → check **Sign in with
   Apple** → click **Configure**.
6. **Primary App ID**: select your iOS App ID
   (e.g. `space.sookoon.crewpoint.app`).
7. **Domains and Subdomains**: list the **originating domains** the
   web app runs on:

   | Flavor | Domain entry |
   | ------ | ------------ |
   | dev | `crewpoint-dev.web.app` |
   | stg | `crewpoint-stg.web.app` |
   | prod | `crewpoint.sookoon.space` |

   *Apple usually accepts only one domain per Services ID; if it
   rejects multiple, create one Services ID per domain. For dev/stg
   testing, the Firebase default `*.web.app` host is fine.*

8. **Return URLs**: paste the Firebase auth handler URL for this
   flavor:

   | Flavor | Return URL |
   | ------ | ---------- |
   | dev | `https://crewpoint-dev.firebaseapp.com/__/auth/handler` |
   | stg | `https://crewpoint-stg.firebaseapp.com/__/auth/handler` |
   | prod | `https://crewpoint-prod.firebaseapp.com/__/auth/handler` |

   *Note*: this is the `firebaseapp.com` domain even for prod (because
   that's where Firebase Auth actually completes the OAuth dance — see
   the `authDomain` decision in `web-hosting-guide.md` Stage 6). The
   custom subdomain `crewpoint.sookoon.space` is the **originating**
   domain (Step 2.7 above), not the redirect.

9. **Next** → Apple shows a domain-verification dialog with a file
   download button. **Download the file** (it's the
   `apple-developer-domain-association.txt` text payload). Keep this
   tab open — you'll come back to verify after hosting the file.

## Step 3 — Host the domain verification file

Apple needs to fetch the file from each domain you registered in
Step 2.7.

This repo's `web/.well-known/apple-developer-domain-association.txt`
is committed as a **PLACEHOLDER** with the exact replacement
procedure. Per flavor:

1. Replace the contents of `web/.well-known/apple-developer-domain-association.txt`
   with the file Apple gave you in Step 2.9.
   - **Note**: Apple sometimes issues different files per Services ID.
     If you're setting up multiple flavors in parallel, each flavor
     deploys a different file. Don't commit a flavor's file to a
     shared branch — replace, deploy, verify, then revert (or use a
     branch per flavor).
2. Deploy the flavor's hosting:
   ```bash
   firebase deploy --only hosting:crewpoint-<flavor> --project=crewpoint-<flavor>
   ```
3. Verify the file is reachable:
   ```bash
   curl -fsSL \
     https://<domain>/.well-known/apple-developer-domain-association.txt \
     | head -5
   ```
   Should show the Apple-issued JWT-looking content, **not** the word
   `PLACEHOLDER`.
4. Back in the Apple Developer Console (Step 2's tab) → click **Verify**
   next to the domain. Apple fetches the file. Within a few seconds
   the row flips to **Verified ✓**.

If it fails, Apple shows the HTTP response it got. The most common
failure modes:

| Failure | Cause |
| ------- | ----- |
| 404 | The file isn't being served. Confirm `web/.well-known/` was included in `firebase.json`'s hosting `public` (it ships from `build/web/.well-known/` after `flutter build web`). |
| 200 with placeholder body | You forgot to swap the placeholder for Apple's content. |
| Wrong content-type | Apple expects `text/plain`. Firebase Hosting serves `.txt` as `text/plain` by default — no override needed. |

5. Click **Save** in the Services ID configuration.
6. **Continue** through any remaining dialogs.

### Post-deploy guard (run before public launch)

Run after each prod deploy until the file is replaced:

```bash
curl -fsSL \
  https://crewpoint.sookoon.space/.well-known/apple-developer-domain-association.txt \
  | grep -q PLACEHOLDER \
  && echo 'NOT REPLACED — Apple sign-in will fail; block public launch'
```

The grep should fail (exit 1) once the placeholder is gone. If it
succeeds, the placeholder shipped and Apple sign-in won't round-trip.

## Step 4 — Create (or reuse) a `.p8` private key

Firebase needs a private key from your Apple Developer account to
verify the identity tokens Apple returns. **One `.p8` key works for
all three flavors** — you don't need separate keys per environment.

**If you already created a Sign-in-with-Apple key** for any prior
project (Sanctuary, an earlier CrewPoint setup, etc.), you can reuse
it. Otherwise:

1. Apple Developer Console → **Certificates, Identifiers & Profiles**
   → **Keys** → **+**.
2. **Key Name**: `CrewPoint Sign in with Apple` (or `Sookoon Apps Sign in with Apple` if you want the same key to cover Sanctuary).
3. Check **Sign in with Apple** → click **Configure** next to it.
4. **Primary App ID**: select the iOS App ID
   (`space.sookoon.crewpoint.app`).
5. **Save** → **Continue** → **Register**.
6. **Download** the `.p8` file. **You can only download it once.**
   Store it somewhere safe (1Password, internal vault). **Never commit
   it to git.**
7. Note the **Key ID** (10-character string shown next to the key
   name). You'll paste it into Firebase.
8. Note your **Team ID** (top-right corner of the Apple Developer
   Console next to your account name; 10-character string).

## Step 5 — Wire the Services ID + Key into Firebase

Run this for each flavor you're setting up.

1. Firebase Console → `crewpoint-<flavor>` → **Authentication** →
   **Sign-in method** tab.
2. Find **Apple** in the provider list → click → toggle **Enable**.
3. Fill in:
   - **Services ID**: the identifier from Step 2.3 (e.g.
     `com.sookoonspace.crewpoint.prod.web`).
   - **Apple Team ID**: from Step 4.8.
   - **Key ID**: from Step 4.7.
   - **Private key**: paste the **entire contents** of the `.p8` file
     (including the `-----BEGIN PRIVATE KEY-----` / `-----END PRIVATE KEY-----`
     headers).
4. **Save**.

## Step 6 — Add Authorized Domains in Firebase Auth

Same list as for Google sign-in — Firebase Auth refuses popup-based
sign-in unless the **originating domain** is on the Authorized Domains
list.

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

3. **Save**.

(If you already set this up for Google sign-in, the same list serves
Apple — no additional entries needed.)

## Step 7 — Smoke test

Open the deployed web app for the flavor in **incognito Chrome**:

| Flavor | URL |
| ------ | --- |
| dev | `https://crewpoint-dev.web.app` |
| stg | `https://crewpoint-stg.web.app` |
| prod | `https://crewpoint.sookoon.space` |

Then:

1. On the auth gate, click **Continue with Apple**.
2. Apple sign-in popup appears. First time: Apple prompts for the
   account password. Subsequent times: Touch ID / Face ID / passkey.
3. Apple asks whether to **Share** or **Hide** your email.
4. The popup closes; the app lands on the dashboard.
5. Open Firebase Console → Authentication → **Users** tab → confirm a
   row with the Apple-relayed email exists. Confirm
   `Firestore → users/{uid}` has a doc.

## Troubleshooting

### `auth/invalid-credential` after the popup closes

Most often **clock skew between your machine and Apple** (Apple ID
tokens have a tight `iat`/`exp` window). Verify your system clock is
NTP-synced. Less commonly: the `.p8` private key paste was truncated
or the Key ID + Team ID don't match the key.

### Apple popup says "Sign in with Apple is not configured for this app"

The Services ID isn't recognized — most likely the value in Firebase
Step 5.3 doesn't match Apple Step 2.3 exactly. Copy-paste both,
character-for-character.

### Apple popup says "Verification failed" / "The website cannot be verified"

The domain-verification file hasn't been fetched successfully. Re-run
the `curl` check from Step 3.3. Verify the file is at
`https://<domain>/.well-known/apple-developer-domain-association.txt`
(note `.well-known` is a hidden directory; some hosting setups omit
it).

### `auth/popup-blocked` snackbar

`firebaseAuthErrorMessage('popup-blocked')` is mapped to the user-facing
"Pop-ups are blocked - please allow pop-ups for this site and try again."
The user needs to click the address-bar pop-up icon and allow once.

### `auth/cancelled-popup-request` or `auth/popup-closed-by-user`

User aborted; mapped to a quiet "Sign-in cancelled." Not actionable.

### "This app's not playing well with Apple's anti-tracking" / Safari blocks the popup

Safari's strict third-party-cookie policy can break popup flows. If
this becomes a recurring issue we'll switch the web flow to
`signInWithRedirect()` (out of scope for V1; tracked in
`ai_specs/todo.md`).

## Quick reference

| Step | Surface | One-time / per-flavor |
| ---- | ------- | --------------------- |
| 1. App ID — Sign in with Apple capability | Apple Developer Console | One-time |
| 2. Services ID + register domains + return URL | Apple Developer Console | Per flavor |
| 3. Domain verification file deployed | This repo + Firebase Hosting | Per domain |
| 4. `.p8` key | Apple Developer Console | One-time (reuse across flavors) |
| 5. Wire into Firebase | Firebase Console → Auth | Per flavor |
| 6. Authorized Domains | Firebase Console → Auth | Per flavor |
| 7. Smoke test | Browser | Per flavor |

For Google sign-in, see **[google-sign-in-web-setup.md](./google-sign-in-web-setup.md)**.
For the dev → stg → prod rollout order, see
**[dev-first-rollout-checklist.md](./dev-first-rollout-checklist.md)**.
For the underlying `authDomain` decision (why prod's redirect URL is
`crewpoint-prod.firebaseapp.com`, not the custom subdomain), see
**[web-hosting-guide.md](./web-hosting-guide.md)** Stage 6.
For what happens when the same email signs in via Apple after an
unverified email/password signup (silent password drop + recovery),
see **[account-linking-behavior.md](./account-linking-behavior.md)**.
