# CrewPoint v1 — Tester Handoff Guide

## What you're testing

CrewPoint is a collaborative event-management app. A group of people (a "crew") create an event, invite each other, assign tasks, chat in real time, log expenses, and settle up. v1 ships five tabs — **Home** (your events), **Tasks** (your assigned tasks across every event), **Chat** (a cross-event inbox of urgent and unread conversations), **Budget** (a cross-event ledger of who owes whom, with one-tap Settle Up via Venmo / Cash App / PayPal / Zelle), and **Profile** — plus the full event-scoped view of each one inside its event.

Your job: run every section of this guide on every device assigned to you, file bugs against anything that diverges from "Expected", and tick off the device coverage matrix as you go.

## How to use this guide

- **Pick any section.** Sections are independent — you can run them in any order. Pre-conditions list anything you need first (e.g. "at least one event exists"), and name the recovery test to run if you don't have it yet.
- **Quote real labels.** Every word in **bold** is the literal label you should see on the screen, verbatim. If the app shows a different word, that's a bug — file it.
- **Try the edge cases.** Each test ends with `Edge cases to try` — short variations that catch most of the bugs we miss in the happy path.
- **Use the bug template.** When something breaks, jump to [§14 Bug-report template](#14-bug-report-template), paste it into the shared bug spreadsheet, fill in the fields. Don't paraphrase — copy the literal text you saw.

## Build info

| Item | Value |
|------|-------|
| iOS build (TestFlight) | `<Insert TestFlight invite link here>` |
| Android build (internal track) | `<Insert Google Play internal-track link here>` |
| Web app (staging) | `<Insert Web Firebase Hosting URL here>` |
| Staging Firebase project | `<Ask the dev team for the project name>` |
| Test account credentials | `<Ask the dev team — they'll give you 2 accounts: a "primary" and a "counterparty" with Venmo configured>` |

**Verify the build before testing.** Open **Profile** (the rightmost tab) and scroll to the bottom. The version footer must read **CrewPoint v\<version\> (\<build\>)** — for example, **CrewPoint v1.0.0 (1)**. If the version or build number is older than what the dev team told you, **stop and report it before testing anything else** — you may be on a stale build.

> ⚠️ The version is rendered by `ProfileStrings.appVersionLabel` in the app's i18n layer; the exact format is `CrewPoint v<version> (<build>)`. If you see `+1` instead of `(1)`, the rendering changed and the guide drifted from the app — file it.

## Device coverage matrix

Tick each cell when you have run that section on that device end-to-end. If a section is N/A for a device (e.g., Apple sign-in on Android), put `N/A`. If a section partially worked but had a bug, put `🐛` and file the bug.

| Section | iPhone | Android | Tablet (rail) | Web Chrome | Web Safari |
|---------|:------:|:-------:|:-------------:|:----------:|:----------:|
| [§0 Pre-flight + onboarding](#0-pre-flight-setup--onboarding) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§1 Authentication](#1-authentication) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§2 Profile](#2-profile) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§3 Dashboard (Home)](#3-dashboard-home) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§4 Event lifecycle](#4-event-lifecycle) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§5 Tasks — event-scoped](#5-tasks--event-scoped) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§6 My Tasks — cross-event](#6-my-tasks--cross-event) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§7 Chat — event-scoped](#7-chat--event-scoped) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§7.5 Push notifications](#75-push-notifications--deep-link) | ☐ | ☐ | ☐ | N/A | N/A |
| [§8 Chat inbox — cross-event](#8-chat-inbox--cross-event) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§9 Budget — event-scoped](#9-budget--event-scoped) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§10 Budget ledger — cross-event](#10-budget-ledger--cross-event) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§11 Responsive shell](#11-responsive-shell) | N/A | N/A | ☐ | ☐ | ☐ |
| [§12 Accessibility](#12-accessibility) | ☐ | ☐ | ☐ | ☐ | ☐ |
| [§13 Offline + sync](#13-offline--sync) | ☐ | ☐ | ☐ | N/A | N/A |

## Per-test format

Every numbered test in this guide follows the same shape:

- **Test ID** — sortable identifier (`SECTION-MNEMONIC-NN`) you cite when filing a bug.
- **Pre-conditions** — bulleted state you need before starting. If you don't have it, the bullet names a recovery test.
- **Steps** — numbered actions. Literal labels in **bold**, user input in _italics_, technical paths in `monospace`.
- **Expected** — bullet list of observable outcomes. No "should" or "may" — these are absolutes.
- **Edge cases to try** — 1-3 micro-tests that catch the bugs we miss in the happy path.
- **Devices** — which device(s) this test is meaningful on. Default is all five columns of the matrix above.

---

## §0 Pre-flight setup + onboarding

**~10 min.** Install the build, complete the 5-page onboarding, sign in with the credentials the dev team gave you.

### PRE-INST-01 — Install the build

**Pre-conditions**
- You've accepted the TestFlight invite (iOS) or Google Play internal-track link (Android), or you have the staging web URL (Web).

**Steps**
1. iOS: Open TestFlight, find **CrewPoint**, tap **Install** then **Open**.
2. Android: Open the Play Store internal-track link, install, then open.
3. Web: Open `<Insert Web Firebase Hosting URL here>` in Chrome or Safari.

**Expected**
- The app cold-launches without crashing.
- The first screen is the onboarding **Welcome** page (charcoal background, sage app-icon block, the word **CrewPoint** in white).

**Edge cases to try**
- Force-quit the app right after the launch screen, reopen — should land on the same place you left off.

**Devices** All.

---

### PRE-OB-01 — 5-page onboarding, swipe forward

**Pre-conditions**
- Fresh install, no prior sign-in on this device.

**Steps**
1. From the **CrewPoint** welcome page, observe the **5 page-indicator dots** at the bottom (one active, four inactive).
2. Tap **Continue**. The next page is **Plan Events Together** (cream background, sage calendar icon, body text "Assign roles, set dates, and track progress—all in one place.").
3. Tap **Continue**. The next page is **Stay in Sync** (charcoal background, terracotta chat icon, body text "Real-time messaging with critical alerts when it matters most.").
4. Tap **Continue**. The next page is **Split Costs Fairly** (cream background, sage wallet icon, body text "Track expenses, upload receipts, and see who owes what.").
5. Tap **Continue**. The final page is **Your Data, Your Rules** (charcoal background, sage shield icon, body text "We believe in transparency. You decide what to share.").

**Expected**
- All 5 pages render in the listed order.
- The page-indicator dot widens to ~28 px and turns sage when active; the others stay ~8 px and dark grey.
- The bottom button reads **Continue** on pages 1-4, then changes to a terracotta **Get Started** button on page 5.
- The **Skip** text button is visible in the top-right corner on pages 1-4 and disappears on page 5.

**Edge cases to try**
- Swipe horizontally instead of tapping **Continue** — same advance behavior.
- Swipe backward from page 5 to page 1 — page indicator and button labels update correctly.

**Devices** All.

---

### PRE-OB-02 — Skip-to-end

**Pre-conditions**
- Onboarding open at page 1 (or any of pages 1-4).

**Steps**
1. Tap **Skip** in the top-right corner.

**Expected**
- The app jumps directly to page 5 (**Your Data, Your Rules**).
- The **Skip** button disappears.
- The bottom button now reads **Get Started**.

**Edge cases to try**
- Tap **Skip** from page 4 — same end state.

**Devices** All.

---

### PRE-OB-03 — Data opt-in toggle

**Pre-conditions**
- On onboarding page 5 (**Your Data, Your Rules**).

**Steps**
1. Find the toggle row labeled **Allow anonymous usage data** above the page indicator.
2. Tap it once → toggle switches ON (sage thumb).
3. Tap it again → toggle switches OFF.

**Expected**
- The toggle visibly flips state each tap (sage when on, neutral when off) without any layout shift.

**Edge cases to try**
- Toggle ON, tap **Get Started**, complete sign-in (PRE-AUTH-01 below). Then sign out (AUTH-OUT-01 in §1), reinstall the app, and verify onboarding does NOT replay — the device remembers you've completed it via secure storage (key `onboarding_complete`). _Note: even deleting your account preserves this flag by design._

**Devices** All. Toggle persistence is per-device, not per-account.

---

### PRE-AUTH-01 — First sign-in with the supplied test account

**Pre-conditions**
- Onboarding complete (**Get Started** tapped on page 5).
- You have the staging credentials from the dev team.

**Steps**
1. On the **Sign In** screen, find the **Continue with Google** and **Continue with Apple** buttons at the top, then the email/password form below the **or continue with email** divider.
2. For the staging account, follow the dev team's instruction for which provider to use. If it's email/password: type the email into the field labeled **Email**, type the password into the field labeled **Password**, then tap **Sign In**.

**Expected**
- After sign-in succeeds, you land on the **Home** tab. The header shows a time-of-day greeting (**Good morning** / **Good afternoon** / **Good evening**) followed by your first name and a 👋, plus today's date subtitle (e.g. **Tuesday, May 19**).
- The bottom navigation bar shows 5 tabs: **Home**, **Tasks**, **Chat**, **Budget**, **Profile**.

**Edge cases to try**
- If the staging account already has events, verify they appear under the **Upcoming** pill on **Home**. If not, your next task is `EV-CRE-01` in §4 to create your first event.
- See `AUTH-VERIFY-01` in §1 for the email-verification banner if your account was just created.

**Devices** All.

---

### PRE-BUILD-01 — Confirm the build number

**Pre-conditions**
- Signed in.

**Steps**
1. Tap the **Profile** tab.
2. Scroll to the very bottom of the screen.

**Expected**
- The footer reads **CrewPoint v\<version\> (\<build\>)** — for example, **CrewPoint v1.0.0 (1)**.
- The version and build numbers match what the dev team told you. If older, stop testing and report.

**Edge cases to try**
- None — this is a one-shot verification.

**Devices** All.

---

> **Sections §1 through §13 are filled in by the remaining phases of the implementation plan.** Each section will follow the same per-test format established in §0.
>
> Until those phases land, treat the section anchors below as placeholders so the table of contents resolves; the device coverage matrix above lists the full v1 surface so reviewers can see the scope.

## §1 Authentication

**~25 min.** Cover every auth provider, the email-verification banner, sign-out, account deletion, and the web popup-blocked recovery.

> ⚠️ **If sign-in fails more than 3 times in a row, stop.** Capture the snackbar text and any error code on screen, paste them into a bug report, and ask the dev team before retrying. The OAuth providers (Google / Apple) and the Email/Password backend both apply rate limits — repeated failures will lock you out of the staging account for a window. See `AUTH-RATE-01` below.

### AUTH-SIGNUP-01 — Email sign-up + verification banner

**Pre-conditions**
- Signed out (see `AUTH-OUT-01` to sign out first if needed).
- You have a fresh email address the staging Firebase project has never seen — easiest is `<your-name>+test-<N>@<your-domain>`.

**Steps**
1. On the auth gate screen (header: **CrewPoint** + tagline **Collaborate. Organize. Deliver.**), find the email/password form below the **or continue with email** divider.
2. Tap the bottom text link reading **Don't have an account? Sign Up**. The form expands to include a **Full Name** field at the top.
3. Type your name into **Full Name**.
4. Type the email into **Email**.
5. Type a password (at least 6 characters) into **Password**.
6. Tap **Create Account**.

**Expected**
- After ~1-3 s you land on the **Home** tab.
- A persistent terracotta banner appears above the body with the title **Verify your email so this sign-in stays active** and body text **We sent a link to \<your-email\>.** plus two action buttons: **Resend** and **I've verified**.
- An actual verification email arrives in the test inbox (usually within ~1 min — check spam).

**Edge cases to try**
- Submit with **Full Name** empty → form refuses, validator shows **Please enter your name**.
- Submit with **Email** empty → validator shows **Please enter your email**.
- Submit with **Email** missing the `@` → validator shows **Please enter a valid email**.
- Submit with **Password** ≤ 5 chars → validator shows **Password must be at least 6 characters**.
- Submit with a password that's already in use → snackbar **An account already exists with this email.**

**Devices** All.

---

### AUTH-VERIFY-01 — Resend + I've verified

**Pre-conditions**
- You just completed `AUTH-SIGNUP-01` and the verification banner is showing.

**Steps**
1. Tap **Resend** in the verification banner.
2. Wait for a second email to arrive.
3. Open the email in your test inbox, click the verification link.
4. Return to the app and tap **I've verified** in the banner.

**Expected**
- After tapping **Resend** a snackbar / toast may appear confirming the resend (variants exist; the banner stays visible).
- After clicking the email link and tapping **I've verified**, the banner disappears (Firebase reloads the user and `emailVerified` flips true).

**Edge cases to try**
- Tap **I've verified** WITHOUT clicking the email link → banner stays put.
- Sign out and back in after verifying → banner stays gone.

**Devices** All.

---

### AUTH-IN-01 — Email sign-in (returning user)

**Pre-conditions**
- An existing email/password account is registered in the staging project (use the dev team's primary test account).
- Signed out.

**Steps**
1. On the auth gate, ensure the form is in sign-in mode (bottom link reads **Don't have an account? Sign Up** — if it reads **Already have an account? Sign In** you're in sign-up mode; tap that link once to switch).
2. Type the email into **Email**.
3. Type the password into **Password**.
4. Tap **Sign In**.

**Expected**
- After ~1-3 s you land on the **Home** tab with the time-of-day greeting in the header.

**Edge cases to try**
- Wrong password → snackbar **Incorrect email or password.**
- Unknown email → snackbar **No account found with this email.** _(may be conflated with wrong-password by Firebase for security; either snackbar is acceptable.)_
- Empty email or password → validator errors as in `AUTH-SIGNUP-01`.

**Devices** All.

---

### AUTH-GOOGLE-01 — Continue with Google

**Pre-conditions**
- Signed out.
- On iOS / Android: a Google account is available to sign in with.
- On Web: popups are NOT blocked in the browser (see `AUTH-WEB-01` for the blocked variant).

**Steps**
1. On the auth gate, find the **Continue with Google** button at the top, above the **or continue with email** divider.
2. Tap **Continue with Google**.
3. iOS / Android: a system OAuth sheet (or Custom Tab) opens — pick the Google account.
   Web: a popup window opens — pick the Google account.

**Expected**
- After the OAuth completes you land on the **Home** tab.
- No verify-your-email banner appears (Google verifies the email for us).

**Edge cases to try**
- Cancel the OAuth sheet → snackbar **Sign-in cancelled.**, no navigation.
- If the same email is already registered as an email/password user, you may instead see a **suggestProvider** snackbar reading **This email is registered with your existing provider. Tap "Continue with your existing provider" above.** _(see `AUTH-SUGG-01`)._

**Devices** iPhone, Android, Web Chrome, Web Safari. _Not surfaced on tablet rail differently — same button._

---

### AUTH-APPLE-01 — Continue with Apple

**Pre-conditions**
- Signed out.
- On iOS: an Apple ID is signed in to the device.
- On Web: popups are NOT blocked.

**Steps**
1. On the auth gate, tap **Continue with Apple** (just below **Continue with Google**).
2. iOS phone / tablet: the system Sign-in-with-Apple sheet appears — confirm.
   Web: a popup appears with Apple's sign-in.

**Expected**
- After the OAuth completes you land on the **Home** tab.
- First-time Apple sign-in may give a one-time choice to share / hide your email; either choice should result in a successful sign-in.

**Edge cases to try**
- Cancel the Apple sheet → snackbar **Sign-in cancelled.**, no navigation.

**Devices** iPhone, iPad rail, Web Chrome, Web Safari. **Not available on Android** — the Apple Auth Provider requires native iOS context and is not surfaced on Android in v1. On Android: mark this section N/A.

---

### AUTH-SUGG-01 — Suggest-provider snackbar (Email collision with Google)

**Pre-conditions**
- An email address has previously been used to sign up with Google in staging (use a Gmail account the dev team provides).
- Signed out.

**Steps**
1. On the auth gate, switch to sign-up mode (**Don't have an account? Sign Up**).
2. Type the Google-registered email into **Email**.
3. Type any password into **Password** + a name in **Full Name**.
4. Tap **Create Account**.

**Expected**
- A terracotta snackbar appears with the text **This email is registered with Google. Tap "Continue with Google" above.**
- You stay on the auth gate (no sign-in happens).
- Tapping **Continue with Google** at the top of the gate then completes the sign-in normally.

**Edge cases to try**
- Repeat with an Apple-registered email — snackbar says **... with Apple. Tap "Continue with Apple" above.**

**Devices** All.

---

### AUTH-WEB-01 — Popup blocked recovery (Web only)

**Pre-conditions**
- Web build only.
- Browser popup-blocker enabled for the staging URL (most browsers block popups by default until allowed).

**Steps**
1. On the auth gate, tap **Continue with Google**.

**Expected**
- A snackbar appears with the literal text **Pop-ups are blocked - please allow pop-ups for this site and try again.**
- The browser's URL bar shows the standard "popups blocked" indicator.
- Click the browser's popup-blocker icon, allow popups for this site, retry **Continue with Google** — succeeds normally.

**Edge cases to try**
- Same flow with **Continue with Apple**.

**Devices** Web Chrome, Web Safari only. Phone / tablet builds use `signInWithProvider` (system sheet / Custom Tab), not popups, so the popup-blocker error path does not apply.

---

### AUTH-RATE-01 — Too many attempts

**Pre-conditions**
- Signed out.

**Steps**
1. Sign in with the wrong password 5+ times in quick succession.

**Expected**
- After several wrong attempts the snackbar changes from **Incorrect email or password.** to **Too many attempts. Please wait a minute before trying again.**
- Further sign-in attempts are rejected with the same snackbar for ~60 s.

**Edge cases to try**
- Wait 1-2 minutes, retry with the CORRECT password — should succeed.

**Devices** All.

> 🚨 **Do not stack this with other tests.** If you trigger the rate limit, the staging account is unusable for ~60 s, which delays the rest of the §1 / §2 tests. Run this last if you want to verify it, OR skip if you've already verified `AUTH-IN-01`.

---

### AUTH-NETERR-01 — Network failure during sign-in

**Pre-conditions**
- Signed out.

**Steps**
1. Put the device in airplane mode (or disable Wi-Fi + cellular).
2. Type valid email + password.
3. Tap **Sign In**.

**Expected**
- After a short delay, a snackbar appears with **Network error. Please check your connection.**
- No navigation occurs.

**Edge cases to try**
- Restore network, retry — succeeds.

**Devices** iPhone, Android, Tablet rail. Web: the message text is the same but the trigger is "DevTools → Network → Offline".

---

### AUTH-OUT-01 — Sign out

**Pre-conditions**
- Signed in.

**Steps**
1. Tap the **Profile** tab (rightmost in the bottom nav).
2. Scroll down to the terracotta-outlined **Sign Out** button (above the Danger Zone).
3. Tap **Sign Out**.
4. A bottom sheet appears titled **Sign out of CrewPoint?** with body text **Your local data will be preserved for next time.** and two buttons: **Cancel** and **Sign Out**.
5. Tap **Sign Out**.

**Expected**
- The app navigates back to the auth gate.
- Next time you sign in, your local Drift data (cached tasks / messages / expenses) is still present — verified by signing back in and observing the cached state load instantly while Firestore re-syncs.

**Edge cases to try**
- Open the sheet, tap **Cancel** — sheet dismisses, you stay on Profile, still signed in.
- On rail (tablet / web ≥ 840 px), there's an additional sign-out **Sign out** tooltip on the bottom of the rail; tapping it skips the bottom-sheet and signs out immediately. _(see `SHELL-OUT-01` in §11.)_

**Devices** All.

---

### AUTH-DEL-01 — Delete Account (destructive — exercise on a throwaway account)

**Pre-conditions**
- Signed in with a throwaway account you created in `AUTH-SIGNUP-01`. **Do NOT use the dev team's shared staging account** — deletion is irreversible.

**Steps**
1. Tap the **Profile** tab.
2. Scroll to the **Delete Account** card (terracotta-outlined, near the bottom).
3. Tap **Delete Account**.
4. A dialog appears titled **Delete Account?** with retention copy ("Your solo events will be permanently deleted. In shared events, your name and account ID will be replaced with 'deleted user' so the historical record stays intact for the rest of your group. This is irreversible. ...") and two buttons: **Cancel** and a terracotta **Continue**.
5. Tap **Continue**.
6. The dialog flips to step 2 (**Confirm Deletion**) and asks you to re-authenticate. For an email account: the prompt is **Enter your password to confirm deletion.** with a **Password** field; type your password.
7. Tap **Delete Forever**.

**Expected**
- Step 2 shows a loader and the text **Deleting your account...**
- Within ~3-5 s the Cloud Function (`deleteUserAccount`) completes:
  - The app navigates back to the auth gate.
  - Trying to sign in with the deleted account's email gives **No account found with this email.**

**Edge cases to try**
- On step 0, tap **Cancel** — dialog dismisses, account untouched.
- On step 1, type the wrong password → error message **Incorrect password. Please try again.** stays on step 1 until you enter the right one or **Cancel**.
- For a Google account: step 1 prompts **Sign in with Google to confirm** instead of a password field; for Apple it prompts **Sign in with Apple to confirm**.
- Re-create an account with the same email after deletion — the account creates fresh; the deleted user's solo events are gone; shared events show "deleted user" where the old account used to be.

**Devices** All. The web build's re-auth flow uses a popup for Google/Apple — same expected behavior, different UI.

---

### AUTH-LEGAL-01 — Legal footer links

**Pre-conditions**
- On the auth gate (signed out).

**Steps**
1. Scroll to the bottom of the auth gate.
2. The footer reads **By continuing, you agree to our Terms and Privacy Policy.** with **Terms** and **Privacy Policy** underlined in sage.
3. Tap **Terms**.
4. Tap **Privacy Policy**.

**Expected**
- Each tap opens the corresponding URL in the system browser (production build: `crewpoint.sookoon.space/terms` and `crewpoint.sookoon.space/privacy`; staging may use a `*.web.app` host — whatever the dev team configured).
- If the URL fails to launch, a snackbar appears reading **Could not open \<url\>**.

**Edge cases to try**
- On Web, the links open in a new tab.
- Long-press a link (mobile) — context menu appears (no break).

**Devices** All.

---

## §2 Profile

**~15 min.** Cover the hero card, Edit Profile (display name + photo + payment), Privacy Dashboard, legal pages, the Notifications no-op row, and the stats triplet.

### PROF-HERO-01 — Profile hero card

**Pre-conditions**
- Signed in.

**Steps**
1. Tap the **Profile** tab.

**Expected**
- A gradient charcoal hero card sits at the top with:
  - The word **Profile** at the top-left.
  - A circular avatar with a sage glow halo. If you haven't uploaded a photo, the avatar shows a default placeholder; if you have one, it shows your photo.
  - Your display name below the avatar. If `displayName` is empty (rare), the fallback **User** is shown.
  - Your email address below the display name.
  - A sage-pill **Edit Profile** button at the bottom of the hero.
- Below the hero is the **StatTriplet** showing three numbers with the labels **Events** / **Tasks** / **Owed** (covered in `PROF-STATS-01`).

**Edge cases to try**
- Sign in as a Google/Apple-only account that never set a display name — verify the fallback rendering.
- Pinch-zoom is disabled — the hero card stays put.

**Devices** All.

---

### PROF-EDIT-01 — Edit Profile (display name + payment)

**Pre-conditions**
- Signed in.

**Steps**
1. From **Profile**, tap the **Edit Profile** button (sage pill in the hero).
2. The Edit Profile screen opens with the app bar title **Edit Profile** and an **X** close icon at the top-left.
3. Find the **Display Name** field (hint: **How others see you**) and replace your name with `Test Display _<your initials>_`.
4. Scroll to the **Payment Info** section (subtitle: **Optional — helps your crew settle up with you**).
5. Tap the **Select payment method** dropdown → choose **Venmo**.
6. Type a fake handle like `@test-user` into the field labeled **@username, phone, or email**.
7. Scroll to **Settle handles** (subtitle: **Used by the Venmo / CashApp deep-link buttons in Budget**).
8. Type `test-venmo` into **Venmo handle (optional)**.
9. Type `$test-cashapp` into **Cash App $cashtag (optional)**.
10. Tap **Save Changes** at the bottom.

**Expected**
- After ~1-2 s you see a sage check Lottie animation with the text **Profile updated!**, then the screen pops back to **Profile**.
- The hero now shows the new display name.
- The **Payment** card in Profile body now shows **Venmo: @test-user** and the icon switches to the Venmo glyph.

**Edge cases to try**
- Clear **Display Name** entirely → validator error **Please enter your name**, save button disabled.
- Type an invalid handle into **Venmo handle** (e.g., `bad handle!`) → validator error **Letters, numbers, _ or - only (≤30 chars)**.
- Tap the close **X** with unsaved changes → screen pops without saving; your edits are discarded.

**Devices** All.

---

### PROF-PHOTO-01 — Edit Profile photo (gallery)

**Pre-conditions**
- Signed in.
- The device's photo library has at least one image.

**Steps**
1. From Edit Profile (`PROF-EDIT-01` step 2), tap the circular avatar at the top.
2. A bottom sheet appears with two options: **Choose from Gallery** and **Take a Photo**.
3. Tap **Choose from Gallery**.
4. The system photo picker opens — pick any image.
5. The avatar updates locally with a sage glow + the helper text **Tap photo to change** below it.
6. Tap **Save Changes**.

**Expected**
- Upload + save completes within ~3-5 s on Wi-Fi.
- The hero on **Profile** shows the new photo.
- Sign out and back in — the photo persists (sourced from `users/{uid}.photoUrl` in Firestore).

**Edge cases to try**
- Cancel the photo picker → no avatar change, no save needed.
- Pick a large image (~5+ MB) → upload still succeeds within a reasonable window; if it fails, a snackbar appears with one of **Permission denied. Please try again.** / **Network error. Check your connection.** / **Failed to save profile. Please try again.** depending on the cause.

**Devices** iPhone, Android, iPad rail. Web: gallery picker is the OS file picker. Web Safari may show a different picker UI than Chrome.

---

### PROF-PHOTO-02 — Edit Profile photo (camera)

**Pre-conditions**
- Signed in.
- Device has a camera and the app has (or can prompt for) camera permission.

**Steps**
1. From Edit Profile, tap the avatar.
2. Tap **Take a Photo**.
3. iOS / Android prompts for camera permission the first time — grant.
4. Take a photo, confirm.
5. Tap **Save Changes**.

**Expected**
- Same end state as `PROF-PHOTO-01`: avatar updated, persisted to Firestore.

**Edge cases to try**
- Deny camera permission → app falls back gracefully (no crash); follow the platform's settings deep-link to re-enable.

**Devices** iPhone, Android. iPad rail: works if the device has a camera. Web: **Take a Photo** is not available — mark N/A. _(Drafter: verify what the bottom sheet shows on web — it may hide the Take a Photo option.)_

---

### PROF-PRIV-01 — Privacy Dashboard

**Pre-conditions**
- Signed in.

**Steps**
1. From **Profile**, in the **SETTINGS** section, tap the **Privacy Dashboard** row.

**Expected**
- A new screen opens with the app bar title **Privacy Dashboard**.
- The screen lists four sections (all-caps section labels):
  - **DATA WE COLLECT**
  - **WHAT WE DO NOT COLLECT**
  - **THIRD-PARTY SERVICES**
  - **LEGAL DOCUMENTS** — contains two rows: **Privacy Policy** and **Terms of Service**, each tappable.
- Tapping **Privacy Policy** opens the rendered markdown of `assets/legal/privacy-policy.md` in an in-app screen.
- Tapping **Terms of Service** opens the rendered markdown of `assets/legal/terms-of-service.md`.

**Edge cases to try**
- Tap "View online" / "View hosted version" inside the markdown screen (if present) → opens the production-hosted URL in the system browser.
- Use the back button → returns to Privacy Dashboard.

**Devices** All.

---

### PROF-NOTIF-01 — Notifications row is a deliberate no-op (NOT a bug)

**Pre-conditions**
- Signed in.

**Steps**
1. From **Profile**, in the **SETTINGS** section, tap the **Notifications** row.

**Expected**
- **Nothing happens.** The row is visible as a placeholder for future notification-preference UI but is intentionally not wired in v1.

**Edge cases to try**
- Long-press → no context menu, no navigation.

**Devices** All.

> ℹ️ This is documented as a Known Limitation (Appendix D). Do not file a bug for the no-op.

---

### PROF-STATS-01 — Stats triplet shows live values

**Pre-conditions**
- Signed in.
- You have at least 1 event, 1 task assigned to you, and 1 expense in any event (run `EV-CRE-01` + `TASK-CRE-01` + `BUD-EXP-01` first if not — references are in §4, §5, §9).

**Steps**
1. Tap **Profile**.
2. Observe the row of three numbers below the hero card: each cell has a numeric value above its label (**Events**, **Tasks**, **Owed**).

**Expected**
- **Events** cell shows the count of events visible on **Home** (Upcoming + Past combined).
- **Tasks** cell shows the count of tasks assigned to you across every event (matches the count on the **Tasks** tab).
- **Owed** cell shows the dollar amount you owe across all events, formatted as `$N` (rounded). If you're net positive (owed money), the cell shows `$0`.
- A loading cell shows **—** until its underlying provider has data; an empty cell never crashes.

**Edge cases to try**
- Pull-to-refresh on Profile (if implemented) — values should update.
- Create / delete an event → return to Profile → the **Events** count reflects the change immediately (or after a short Firestore sync).

**Devices** All.

---

### PROF-VER-01 — Version footer (re-verification)

**Pre-conditions**
- Signed in.

**Steps**
1. Tap **Profile**, scroll to the bottom.

**Expected**
- The version footer reads **CrewPoint v\<version\> (\<build\>)** (e.g., **CrewPoint v1.0.0 (1)**) — same as `PRE-BUILD-01` in §0 but reverified after a session of edits.

**Edge cases to try**
- None — this is a one-shot verification.

**Devices** All.

---

## §3 Dashboard (Home)

**~15 min.** The Home tab — greeting, Upcoming / Past pill filter, Create Event CTA, Join Event tooltip, empty state, error state.

### HOME-GRT-01 — Time-of-day greeting + date

**Pre-conditions**
- Signed in.
- Your Profile display name is set (e.g., `Alex Rivera`).

**Steps**
1. Tap the **Home** tab.
2. Look at the header.

**Expected**
- Header line 1: a greeting that follows the pattern **\<time-of-day\>, \<first-name\> 👋**, where:
  - Before 12:00 → **Good morning**
  - 12:00 – 16:59 → **Good afternoon**
  - 17:00 onward → **Good evening**
  - First name = the first whitespace-separated token of your display name (so `Alex Rivera` → `Alex`).
- Header line 2: today's date formatted as **\<Day-of-week\>, \<Mon\> \<D\>** (e.g., **Wednesday, May 20**).

**Edge cases to try**
- Change the device clock (or just open the app at different times) and confirm the prefix flips.

**Devices** All.

---

### HOME-GRT-02 — Greeting first-name edge cases

**Pre-conditions**
- Signed in. You can edit your Profile display name (see `PROF-EDIT-01`).

**Steps**
1. Open **Edit Profile**, set **Display Name** to one of the following values one at a time, save, return to **Home**:
   - `Émile 😀` _(diacritic + emoji in name)_
   - `A` _(single character)_
   - `Mary-Anne Schmidt-Williams` _(hyphenated multi-word)_
   - (empty string — clear the field) _(only possible if the validator allows it; if it rejects, skip this variant)_
   - `   ` _(whitespace only — again, only if the validator allows it)_

**Expected**
- For each: the greeting renders gracefully with no layout overflow and no exception.
- For `Émile 😀` → greeting reads **Good \<time-of-day\>, Émile 😀 👋** (whole token, including the emoji).
- For `A` → greeting reads **Good \<time-of-day\>, A 👋**.
- For `Mary-Anne Schmidt-Williams` → greeting takes the first whitespace-separated token: **Good \<time-of-day\>, Mary-Anne 👋**.
- For empty / whitespace-only display name → greeting falls back to **Good \<time-of-day\>, there 👋**.

**Edge cases to try**
- Single Right-to-left character in name (Arabic / Hebrew letter) → greeting still renders.
- Very long single-token name (~30+ chars) → greeting either fits on one line with ellipsis, or wraps gracefully; no overflow exception.

**Devices** All. _(Drafter cites `lib/app/features/dashboard/domain/greeting_first_name.dart` for testers who want to sanity-check the parser logic.)_

---

### HOME-FILT-01 — Upcoming / Past pill split (equalWidth)

**Pre-conditions**
- Signed in. You have at least 1 event (run `EV-CRE-01` first if not).

**Steps**
1. On **Home**, observe the pair of pills below the header: **Upcoming** and **Past**.
2. Tap **Past** if you're on Upcoming, then back to **Upcoming**.

**Expected**
- The two pills split the available width roughly 50 / 50 (the bar uses `equalWidth: true` — both labels are short, so the LayoutBuilder distributes them via `Expanded`).
- The active pill has a charcoal background + white label; the inactive pill has a white background + charcoal label.
- Switching pills repartitions the events list below by date: events whose end-or-start date is today or later show under **Upcoming**; the rest show under **Past**.

**Edge cases to try**
- On iPhone SE (320 px width), the equalWidth fallback may kick in if the device's text scale + label widths exceed the viewport. Verify there's no overflow and labels never truncate to ellipsis on default font scale. _(see also `A11Y-OVR-01` in §12.)_
- Bump system text scaling to 200% — pills should still render without overflow exception (they may fall back to scrolling layout under extreme scaling — that's correct, not a bug).

**Devices** All.

---

### HOME-CRE-01 — Create Event CTA visible

**Pre-conditions**
- Signed in.

**Steps**
1. On **Home**, find the wide charcoal button under the filter pills.

**Expected**
- The button reads **Create Event** with a leading `+` icon.
- Tap → navigates to the Create Event screen (covered in `EV-CRE-01` in §4).

**Edge cases to try**
- Tap rapidly twice — no duplicate navigation, no crash.

**Devices** All.

---

### HOME-JOIN-01 — Join Event tooltip + sheet

**Pre-conditions**
- Signed in.
- Another staging user has generated an invite code via `EV-MEM-02` (or the dev team provided one).

**Steps**
1. On **Home**, find the small icon button in the top-right of the header (looks like a person-plus / link icon).
2. Long-press the icon (mobile) or hover (web/tablet rail) → tooltip reads **Join Event**.
3. Tap the icon. A bottom sheet appears with:
   - Title: **Join Event**
   - Subtitle: **Enter the 6-character code shared by the event organizer**
   - A 6-character code input field (hint: `------`).
   - **Join Event** primary button at the bottom.
4. Type the 6-character code into the field (the input UPPERCASES letters as you type).
5. Tap **Join Event**.

**Expected**
- After ~1-3 s the sheet dismisses and a snackbar appears: **You joined the event!**.
- The new event appears in your **Upcoming** list.

**Edge cases to try**
- Type a code that doesn't exist → error message appears in red below the input.
- Type fewer than 6 chars → **Join Event** button can be tapped but the server rejects; an error appears.
- Cancel the sheet by swiping down → no join attempt, no snackbar.

**Devices** All.

---

### HOME-EMPTY-01 — Empty state

**Pre-conditions**
- Signed in.
- You have ZERO events. (Easiest: create a fresh throwaway account via `AUTH-SIGNUP-01` and don't create or join anything.)

**Steps**
1. Tap **Home**.

**Expected**
- The list area renders the empty state placeholder:
  - Title: **No events yet**
  - Subtitle: **Create an event or join one with a code**
  - CTA: **Join with Code** (tappable — opens the same Join Event sheet from `HOME-JOIN-01`).

**Edge cases to try**
- Tap **Join with Code** CTA → Join Event sheet opens.

**Devices** All.

---

### HOME-ERR-01 — Error state + retry

**Pre-conditions**
- Signed in.
- A way to force the events provider into an error (network failure during initial load; airplane mode + sign-in + tap Home before the cache loads).

**Steps**
1. Put the device in airplane mode while signed out.
2. Sign in (if the cached auth lets you) or restart the app.
3. Tap **Home** before any cached events render.

**Expected**
- The body shows centered text **We couldn't load your events.** in dark grey.
- Below the text, an outlined button reads **Try again** with a refresh icon.
- Tap **Try again** → the provider re-invalidates; if network is restored, events appear; if still offline, the error state stays.

**Edge cases to try**
- Restore network → tap **Try again** → events load.
- Restore network → wait without tapping → the auto-revalidation may not fire; tester reports whether the screen recovers without explicit retry.

**Devices** iPhone, Android, Tablet rail (airplane mode is the easiest trigger). Web: simulate offline via DevTools → Network → Offline.

---

### HOME-LIST-01 — Section header counts

**Pre-conditions**
- Signed in.
- You have at least 1 Upcoming event AND at least 1 Past event.

**Steps**
1. On **Home**, tap **Upcoming**. Observe the section header above the list.
2. Tap **Past**. Observe the section header.

**Expected**
- Upcoming header reads **\<N\> UPCOMING EVENTS** in dark-grey letterspaced caps, where N is the number of upcoming events.
- Past header reads **\<N\> PAST EVENTS** similarly.
- Singular and plural use the same template (so 1 event reads `1 UPCOMING EVENTS`) — that's a known i18n caveat, not a bug.

**Edge cases to try**
- Create another event → header count increments by 1.

**Devices** All.

---

## §4 Event lifecycle

**~25 min.** Create, edit, archive, leave, delete; member management; admin role transitions.

### Role permission matrix

Tick each cell as you verify it on the device under test. **Allow / deny** is what the app's UI should expose — if a role can perform the action via the UI without an error, mark allowed; if the UI hides the affordance or a snackbar denies it, mark denied.

| Action | Owner | Admin | Member |
|--------|:-----:|:-----:|:------:|
| Edit event details (settings gear → Edit Event screen) | ☐ allow | ☐ allow | ☐ deny |
| Archive Event toggle (event dashboard) | ☐ allow | ☐ allow | ☐ deny |
| Delete Event (event dashboard danger zone) | ☐ allow | ☐ deny | ☐ deny |
| Leave Event | ✗ (owner cannot leave — must delete) | ☐ allow | ☐ allow |
| Regenerate invite code (Add Member sheet) | ☐ allow | ☐ allow | ☐ deny |
| Remove other member | ☐ allow | ☐ allow (cannot remove owner) | ☐ deny |
| Promote member to admin | ☐ allow | ☐ deny | ☐ deny |
| Demote admin to member | ☐ allow | ☐ deny | ☐ deny |
| Edit any task in event (`canEditTask`) | ☐ allow | ☐ allow | ☐ deny (own/assigned only) |
| Change any task status (`canChangeStatus`) | ☐ allow | ☐ allow | ☐ deny (own/assigned only — verify via snackbar `Only the assignee or an admin can change this`) |
| Edit any expense | ☐ allow | ☐ allow | ☐ deny (own only) |
| Delete any expense | ☐ allow | ☐ allow | ☐ deny (own only) |

> 📌 The role checks live in `lib/app/features/dashboard/domain/models/event.dart` (`isOwner`, `isAdmin`, `isMember` — admin is implicitly anyone who is owner OR in `adminIds`). The task-permission checks live in the `TaskModel` (`canChangeStatus`). Tasks and expenses rows in this matrix are verified in §5 and §9; this matrix is the cross-reference. Settings-gear visibility uses `event.isAdmin(uid)`, which is true for the owner — so owners DO see the gear despite the spec earlier framing it as "owner-only".

---

### EV-CRE-01 — Create event

**Pre-conditions**
- Signed in.

**Steps**
1. On **Home**, tap **Create Event** (or tap the FAB on event dashboard if you're already in an event).
2. The Create Event screen appears with app bar title **Create Event**.
3. Pick an **Event Type** chip from the row: **Trip**, **Project**, **Social**, or **Custom** (the chip you tap turns sage with white text). _(There is NO emoji selector — selection is by ChoiceChip with the type label.)_
4. Type a title (1-200 chars) into the field labeled **Title** with hint **What are you planning?**
5. (Optional) Type a description into the field labeled **Description** with hint **Details, location, notes... (optional)**.
6. (Optional) Tap **Start Date** row. The picker subtitle reads **Optional — tap to set**. Pick a date; the row now shows the date and gains a clear (✕) button on the right.
7. The **Currency** dropdown defaults to **USD**. Tap it → menu shows 7 options: **USD**, **EUR**, **GBP**, **CAD**, **AUD**, **JPY**, **INR**. Helper text below the dropdown reads **Cannot be changed after creating the event.**
8. Tap **Create Event** at the bottom.

**Expected**
- After ~1-3 s the screen pops back to **Home**.
- A snackbar appears with the text **Event created** and an action button **Share invite** (visible for ~6 s).
- The new event appears at the top of the **Upcoming** list (because its start date is today or later, or it has no start date).
- Tapping the snackbar's **Share invite** action before it disappears opens the Add Member sheet (`EV-MEM-02`).

**Edge cases to try**
- Submit with **Title** empty → validator error: **Please enter a title**.
- Submit with **Title** > 200 chars → validator error: **Title must be under 200 characters**.
- Network failure during submit → error box appears with text **Couldn't create event — try again**; the submit button is re-enabled for retry.
- Sign-in expires mid-form → inline error: **Sign-in required to create an event.**.

**Devices** All.

> 📌 **The Create Event form does NOT have an end-date field.** End date is editable only after creation, via Edit Event (`EV-EDIT-01`). If the dev team adds an end-date field in a later build, the field will appear here and this note becomes stale — flag it.

---

### EV-EDIT-01 — Edit event (settings gear, owner + admin)

**Pre-conditions**
- Signed in as an owner OR admin of an event with ≥ 1 other member.

**Steps**
1. From **Home**, tap the event tile to open the event dashboard.
2. In the top-right of the event header, find the settings gear icon ⚙️ (visible only if you're owner or admin).
3. Tap the gear → Edit Event screen opens with app bar title **Edit Event**.
4. The screen exposes:
   - The same row of ChoiceChips for event type (**Trip** / **Project** / **Social** / **Custom**).
   - **Title** field (hint **Title**).
   - **Description** field (hint **Description (optional)**).
   - **Start Date** ListTile (subtitle **Optional** if unset; date string if set).
   - **End Date** ListTile (subtitle **Optional** if unset).
   - **Archived** SwitchListTile (subtitle **Event is read-only** when on, otherwise the subtitle reads the active-state copy).
5. Change the title to something new, e.g. append ` — edited` to the existing title.
6. Tap **Save** (or the equivalent save action — verify with the actual button label on screen; drafter: if a label other than `Save` is rendered, file as a bug or update this step).

**Expected**
- After ~1-3 s you pop back to the event dashboard.
- The header now shows the new title.
- Open **Home** → the event tile reflects the new title.

**Edge cases to try**
- Sign in as a Member (not owner/admin) → open the event → the settings gear is **NOT visible** in the header. Mark this row as `deny` in the role matrix.
- Set **Start Date** > **End Date** → validator shows an inline date error.
- Toggle **Archived** ON via this screen — should produce the same effect as the event-dashboard Archive Event switch (covered in `EV-ARCH-01`).

**Devices** All.

---

### EV-ARCH-01 — Archive Event toggle

**Pre-conditions**
- Signed in as owner or admin of an event.

**Steps**
1. Open the event dashboard. Scroll to the section that contains the actions cards.
2. Find the **Archive Event** SwitchListTile.
   - When **OFF** the subtitle reads **Archive to make read-only**.
   - When **ON** the subtitle reads **Event is archived (read-only)**.
3. Toggle **ON**.

**Expected**
- The switch flips to ON instantly (optimistic update).
- The event header (in the gradient hero) now shows a small terracotta **Archived** pill.
- The event status is now `EventStatus.archived` in Firestore.
- **The event does NOT move to the Past filter on Home.** Past / Upcoming is partitioned by **date** (`startDate` / `endDate` vs today), not by archive state. An archived event whose start date is in the future still shows under **Upcoming**.
- Read-only effect: archived events should reject mutating actions (verify with task status change attempts in §5). _(Drafter: confirm against actual archive-read-only contract in code — this is a spec-level promise that may not be fully enforced in v1.)_

**Edge cases to try**
- Toggle OFF → subtitle returns to **Archive to make read-only**; pill disappears.
- Trigger a failure (airplane mode while toggling) → snackbar: **Could not update archive status**.
- Sign in as a Member → archive switch is **NOT visible** on the event dashboard.

**Devices** All.

> ⚠️ **Common phantom bug to avoid filing:** archived events staying under **Upcoming** is NOT a bug — Past / Upcoming is date-driven only.

---

### EV-LEAVE-01 — Leave Event (members + admins, NOT owner)

**Pre-conditions**
- Signed in as a non-owner member (or admin) of an event.

**Steps**
1. Open the event dashboard.
2. Scroll to the **Leave Event** action card (with a left-arrow icon).
3. Tap **Leave Event**. A dialog appears with:
   - Title: **Leave Event?**
   - Body: **You will lose access to this event. Your past messages and expenses will remain.**
   - Buttons: **Cancel** + **Leave** (terracotta).
4. Tap **Leave**.

**Expected**
- After ~2-3 s you navigate back to **Home**.
- The event is no longer in your Upcoming or Past list.
- The Cloud Function `removeEventMember` ran successfully.
- The other event members can still see the event; in the Members screen, you no longer appear.

**Edge cases to try**
- Cancel mid-dialog → no navigation, you stay in the event.
- Network failure → snackbar: **Failed to leave event**.
- Sign in as the OWNER → the **Leave Event** card is NOT visible (you cannot leave your own event; delete it instead).

**Devices** All.

---

### EV-MEM-01 — Members screen + roles

**Pre-conditions**
- Signed in to an event with ≥ 2 members.

**Steps**
1. On the event dashboard, tap the members card. Title reads **\<N\> member** (singular) or **\<N\> members** (plural).
2. The Members screen opens with app bar title **Members (\<N\>)**.
3. Each row shows: avatar circle, display name (or UID fallback), and a role label: **Owner** (sage), **Admin** (info-blue), or **Member** (grey).
4. Note: the floating action button (FAB) at the bottom-right is visible only if you're owner or admin — it opens the Add Member sheet.

**Expected**
- The owner row always shows **Owner** in sage.
- Admins show **Admin** in info-blue.
- Other members show **Member** in grey.
- Your own row has no "remove" action.
- For non-owner non-self rows, owners and admins see a remove affordance; admins cannot remove the owner.
- For non-owner non-self rows, owners see a promote/demote affordance; admins do NOT see it.

**Edge cases to try**
- Sign in as a plain Member → open Members screen → no FAB, no remove or promote affordances on any row.

**Devices** All.

---

### EV-MEM-02 — Add member by code

**Pre-conditions**
- Signed in as owner or admin of an event.

**Steps**
1. Open Members screen (`EV-MEM-01`). Tap the sage **+** FAB at the bottom-right.
2. The Add Member bottom sheet appears.
3. The first state shows a loader with the text **Generating code...**.
4. After ~1-2 s the loader is replaced by the 6-character code in large type, plus a row with a **Copy** button (with a copy icon) and a **Generate New Code** outline button below.
5. Tap **Copy**.

**Expected**
- A snackbar appears with the text **Code copied to clipboard**.
- The system clipboard now holds the 6-character code.
- Share the code with another staging account; that account uses `HOME-JOIN-01` to join.

**Edge cases to try**
- Tap **Generate New Code** → loader reappears briefly; a new 6-char code replaces the old one. The OLD code stops working (an attempt to join with it produces an error).
- Network failure during initial generation → error state with a **Try Again** button.

**Devices** All.

---

### EV-MEM-03 — Remove member

**Pre-conditions**
- Signed in as owner or admin.
- The event has ≥ 2 non-owner members.

**Steps**
1. Open Members screen.
2. Tap the remove affordance on a non-owner non-self row.
3. A dialog appears with:
   - Title: **Remove Member?**
   - Body: **They will lose access to this event. Their past messages and expenses will remain.**
   - Buttons: **Cancel** + **Remove** (terracotta).
4. Tap **Remove**.

**Expected**
- The row processes (~1-2 s) then disappears from the list.
- Snackbar: **Member removed** (on sage background).
- The member count in the app bar decrements.

**Edge cases to try**
- Cancel the dialog → no change.
- Network failure → snackbar: **Failed to remove member**.
- Try to remove the OWNER → no remove affordance is shown on the owner row even for an admin.

**Devices** All.

---

### EV-MEM-04 — Promote to admin / Demote admin (OWNER ONLY)

**Pre-conditions**
- Signed in as the OWNER of an event with ≥ 1 non-owner member.

**Steps**
1. Open Members screen.
2. Tap the promote affordance on a Member row.

**Expected**
- After ~1-2 s, snackbar: **Promoted to admin** (sage background).
- The row's role label flips from **Member** (grey) to **Admin** (info-blue).
3. Tap the same row's demote affordance.
- After ~1-2 s, snackbar: **Demoted to member** (sage background).
- The role label flips back to **Member**.

**Edge cases to try**
- Network failure during promote → snackbar: **Failed to promote**.
- Network failure during demote → snackbar: **Failed to demote admin**.
- Sign in as an Admin (not owner) → the promote / demote affordance is **NOT visible** on any row.

**Devices** All.

---

### EV-DEL-01 — Delete Event (destructive — OWNER ONLY, exercise last)

**Pre-conditions**
- Signed in as the owner of an event you no longer need.
- **Do NOT** use a shared event the team is testing against — deletion is permanent for all members.

**Steps**
1. Open the event dashboard.
2. Scroll to the bottom; find the terracotta-outlined **Delete Event** card (in the danger zone, after Archive + Members + Leave). Visible only if you're the owner.
3. Tap **Delete Event**. **Step 1 dialog** appears:
   - Title: **Delete Event?** (in terracotta).
   - Body: **This will permanently delete the event and all its data: messages, expenses, tasks, and invite codes.** + new paragraph + **This action cannot be undone.**
   - Buttons: **Cancel** + **Continue** (terracotta).
4. Tap **Continue**. **Step 2 dialog** appears:
   - Title: **Are you sure?** (in terracotta).
   - Body: **All event data will be permanently erased for all members.**
   - Buttons: **Cancel** + **Delete Forever** (terracotta elevated button).
5. Tap **Delete Forever**.

**Expected**
- Loader briefly appears, then you're returned to **Home**.
- The event no longer appears in your Upcoming or Past list.
- Other staging members also lose access (the `deleteEvent` Cloud Function wipes the doc + subcollections).

**Edge cases to try**
- Cancel on either step → no deletion.
- Network failure → snackbar: **Failed to delete event**.
- Sign in as Admin (not owner) → **Delete Event** card is **NOT visible**.

**Devices** All.

> 🚨 **Run this test last in §4.** Deletion is permanent. Use a throwaway event you created yourself; never delete the team's shared staging event.

---

## §5 Tasks — event-scoped

**~30 min.** Inside an event you opened from **Home**, tap the **Tasks** quick-link. Tests below cover create / status cycle / edit / duplicate / delete / checklist / filter bar / sort / group / PDF export.

### TASK-CRE-01 — Create task (full form)

**Pre-conditions**
- Signed in. You're an owner / admin / member of the event (any role can create).
- Open the event → Tasks list (app bar reads **Tasks**).

**Steps**
1. Tap the sage **+** FAB at the bottom-right of the Tasks list.
2. The Create Task screen opens with app bar title **Create Task**. Three sections render: **Details**, **Assignment**, **Timing & Budget**.
3. **Details** section:
   - Type a title (1-120 chars) in the field with hint **Task Title**.
   - (Optional) Type a description in the field with hint **Description (optional)** (3 lines).
4. **Assignment** section:
   - Tap the **Assignee** dropdown (hint: **Unassigned**); pick a member from the event roster.
   - Pick a **Priority** radio row: **None** / **Low** / **Medium** / **High**.
5. **Timing & Budget** section:
   - (Optional) Tap **Due Date** to pick a date. (Date-only — no time of day.)
   - (Optional) Type a number into **Budget Estimate (optional)**. The currency symbol prefix mirrors the event's currency.
6. Tap **Create Task** at the bottom.

**Expected**
- After ~1-3 s you pop back to the Tasks list.
- The new task tile appears at the top of the appropriate group (Status group by default → under **To Do**).
- The tile shows the title, the assignee's initials (or **Unassigned**), the priority pill if non-None, the due-date pill if set, and the budget pill if set.

**Edge cases to try**
- Submit with **Title** empty → validator error **Please enter a title**.
- Submit with **Title** > 120 chars → validator error **Title must be 120 characters or fewer**.
- Tap the dropdown's **Unassigned** option → task created with no assignee → tile shows **Unassigned**.
- Cancel mid-form (back button) → no task created.
- Network failure during submit → snackbar **Failed to create task** (terracotta).

**Devices** All.

---

### TASK-CRE-02 — Create task with checklist items

**Pre-conditions**
- Signed in.

**Steps**
1. Open Create Task (`TASK-CRE-01` steps 1-2).
2. Scroll past the three form sections; the checklist editor isn't on Create — checklist items are added AFTER creation, on the Task Detail screen. _(Drafter: verify against `create_task_screen.dart` — if a checklist field IS present, document it here.)_

> 📌 Skip this test if Create Task does not surface a checklist editor in v1. Use `TASK-CHK-01` after creation instead.

**Devices** All.

---

### TASK-STAT-01 — Status cycle (todo → doing → done)

**Pre-conditions**
- Signed in.
- The task is assigned to you, OR you're an admin / owner of the event (`canChangeStatus` permission).

**Steps**
1. On the Tasks list, find your task tile (status **To Do**).
2. Tap the status chip on the tile (left-side colored stripe area).
3. The chip cycles to **In Progress** (sage stripe).
4. Tap again → cycles to **Done** (sageDark stripe).
5. Tap again → cycles back to **To Do**.

**Expected**
- Each tap commits the new status via `updateStatus` on `taskRepositoryProvider`; the tile re-renders with the new color stripe within ~1 s.
- The group header recomputes (the task may move to a new group if grouped by Status).
- If the task has a checklist, when status flips to **Done** the progress bar disappears (avoids the "60% bar under a done icon" inconsistency).

**Edge cases to try**
- Network failure mid-tap → snackbar **Could not update status** (terracotta); the optimistic UI may revert.
- Try to tap on a task you can't change (you're not the assignee and not an admin) → snackbar **Only the assignee or an admin can change this** (covered in `TASK-PERM-01`).

**Devices** All.

---

### TASK-PERM-01 — Unauthorized status change snackbar

**Pre-conditions**
- Signed in as a non-assignee non-admin member.
- A task in the event is assigned to someone else.

**Steps**
1. Tap the status chip on a task that's NOT assigned to you.

**Expected**
- A terracotta snackbar appears with the literal text **Only the assignee or an admin can change this**.
- The task status does NOT change.

**Edge cases to try**
- Try the same tap on an unassigned task — the snackbar fires (`canChangeStatus` requires the actor to be the assignee OR an admin; no assignee + non-admin = denied).
- Sign back in as an admin → tap the same task's status chip → it cycles normally (no snackbar).

**Devices** All.

---

### TASK-DET-01 — Task detail screen + status badge

**Pre-conditions**
- Signed in.
- At least one task exists in the event.

**Steps**
1. From the Tasks list, tap a task tile.
2. The Task Detail screen opens with the task title as the app bar title.

**Expected**
- A pill badge near the top shows the current status: **To Do** (light grey on charcoal), **In Progress** (white on sage), or **Done** (white on sageDark).
- The description (if any) renders below.
- If assignee is set, a row reads **Assigned to \<display name\>** (falls back to a truncated UID).
- If due-date is set, a row reads **Due \<Mon\> \<D\>, \<YYYY\>**.
- If the task is **Done** and has a completedAt timestamp, a row reads **Completed \<date\> by \<name-or-uid\>**.
- An overflow menu (⋮) in the top-right surfaces three items: **Edit**, **Duplicate**, **Delete** (only visible options for your role).
- A checklist editor is rendered below.

**Edge cases to try**
- If the assignee has left the event, the assignee row shows the small italic **(no longer in event)** annotation in terracotta.
- If you're offline + you toggled status earlier, a "Will sync when online" row may appear above the status badge.

**Devices** All.

---

### TASK-EDIT-01 — Edit task

**Pre-conditions**
- Signed in as creator / owner / admin (`canEdit`).
- On the Task Detail screen.

**Steps**
1. Tap the overflow ⋮ → **Edit**.
2. Edit Task screen opens with app bar title **Edit Task** and the same 3-section form, pre-filled with the task's current values.
3. Change the title (or any other field).
4. Tap **Save changes** at the bottom.

**Expected**
- After ~1-3 s you pop back to the Task Detail screen.
- The new values are visible.

**Edge cases to try**
- Validator errors as in `TASK-CRE-01`.
- Network failure → snackbar **Could not save changes** (terracotta).
- Sign in as a non-creator non-admin member → the overflow ⋮ does NOT show **Edit** for them (canEdit is false).

**Devices** All.

---

### TASK-DUP-01 — Duplicate task

**Pre-conditions**
- Signed in (any role can duplicate — the new task gets your uid as createdBy).
- On the Task Detail screen of a task with ≥ 1 checklist item.

**Steps**
1. Tap the overflow ⋮ → **Duplicate**.
2. The Create Task screen opens, pre-filled with the source task's fields, BUT with the title suffixed with ` (copy)` (per `TaskModel.duplicate`).
3. (Optional) Edit any of the pre-filled fields.
4. Tap **Create Task**.

**Expected**
- A new task appears in the Tasks list with the ` (copy)` suffix.
- The new task carries every checklist item from the source (per `createTaskWithChecklist`).
- Your uid is the new task's `createdBy`.

**Edge cases to try**
- Network failure → snackbar **Could not duplicate task** (terracotta).
- Duplicate a task you don't have edit rights to → the new task still creates (any viewer can duplicate; the copy is under YOUR createdBy).

**Devices** All.

---

### TASK-DEL-01 — Delete task

**Pre-conditions**
- Signed in as creator / owner / admin (`canEdit`).
- On the Task Detail screen.

**Steps**
1. Tap the overflow ⋮ → **Delete** (terracotta).
2. A dialog appears with:
   - Title: **Delete this task?**
   - Body: **This cannot be undone. Members will lose the task and any checklist items.**
   - Buttons: **Cancel** + **Delete** (terracotta).
3. Tap **Delete**.

**Expected**
- The dialog dismisses.
- You navigate back to the Tasks list.
- The task is gone from the list.

**Edge cases to try**
- Tap **Cancel** → no deletion, dialog dismisses.
- Network failure → task stays in the list; no snackbar fires explicitly (the screen-pop only happens on success).

**Devices** All.

---

### TASK-CHK-01 — Checklist editor (add / edit / delete)

**Pre-conditions**
- Signed in as creator / owner / admin (full checklist permissions).
- On the Task Detail screen.

**Steps**
1. Scroll to the checklist editor below the metadata.
2. (Add) In the inline field with hint **Add item**, type `Pack sunscreen` and tap the sage add (+) button on the right.
3. (Toggle) Tap the checkbox of any existing item → strikethrough applies.
4. (Edit text) Tap the pencil affordance on an existing item → inline editing; type new text, tap done.
5. (Delete) Tap the delete affordance on an existing item → item disappears.

**Expected**
- Add appends the new item to the end (sortOrder = items.length).
- Toggle flips `isCompleted`; the progress bar on the parent task tile updates next time you return to the list.
- Edit + delete propagate via `updateChecklistItem` / `deleteChecklistItem` on the repo.
- Maximum of **25 items per task** (`ChecklistEditor.maxItems`) — the add affordance is hidden when at the limit.
- Maximum **120 chars per item** (`maxItemLength`).

**Edge cases to try**
- Try to add a 26th item → add field hidden / disabled.
- Sign in as the assignee (not creator/admin): only the toggle is available; the add / edit-text / delete affordances are hidden.
- Sign in as a non-assignee non-admin viewer: NONE of the checklist affordances are interactive (read-only).

**Devices** All.

---

### TASK-FILT-01 — Filter bar (search + chips)

**Pre-conditions**
- Signed in. At least 5 tasks exist with varied status / assignee / dueDate / budget.

**Steps**
1. On the Tasks list, find the **TasksFilterBar** above the list. It has 4 zones:
   1. Search row (hint **Search tasks**).
   2. Filter chips: **Mine**, **Overdue**, **Has budget**, **To Do**, **In Progress**, **Done**.
   3. Sort menu (covered in `TASK-SORT-01`).
   4. Group toggle (covered in `TASK-GRP-01`).
2. Type a partial title into the search row → the list narrows in real time as you type.
3. Tap **Mine** → list narrows to tasks assigned to you (chip turns sage with ~25% alpha).
4. Tap **Mine** again to deselect.
5. Tap **Overdue** → list narrows to tasks with a due date before today (chip turns terracotta with ~25% alpha).
6. Tap **Has budget** → list narrows to tasks with a non-null `budgetEstimate`.
7. Tap **To Do**, then **In Progress**, then **Done** in turn → these are multi-select status chips.

**Expected**
- Each chip toggles independently; multiple can be active simultaneously.
- The list re-filters on every chip change; if nothing matches, the empty-match placeholder shows (covered in `TASK-EMPTY-01`).

**Edge cases to try**
- Tap **Mine** + **Overdue** simultaneously → intersection.
- Clear all → all tasks visible.
- Type a search query that matches nothing → empty-match placeholder.

**Devices** All.

---

### TASK-SORT-01 — Sort menu

**Pre-conditions**
- Signed in. ≥ 3 tasks.

**Steps**
1. In the filter bar, tap the sort row reading **Sort by: \<current key\>** (with a sort icon prefix).
2. A popup menu appears with 4 options: **Due date**, **Priority**, **Created**, **Title**.
3. Pick each in turn.

**Expected**
- The list re-sorts immediately; the sort row's "\<current key\>" updates to the chosen option's label.
- **Due date**: ascending, no-due-date last.
- **Priority**: descending (High → None).
- **Created**: descending (newest first).
- **Title**: ascending alphabetical.

**Edge cases to try**
- Combine with a filter chip → sorted within the filtered set.

**Devices** All.

---

### TASK-GRP-01 — Group toggle

**Pre-conditions**
- Signed in. ≥ 3 tasks with varied status / assignee / due window.

**Steps**
1. In the filter bar, find the segmented group-toggle on the right: **Status** / **Assignee** / **Due window**.
2. Tap **Assignee** → list groups by assignee with a header per assignee display name; **Unassigned** group at the bottom.
3. Tap **Due window** → list groups by **Today**, **This week**, **Later**, **No due date**.
4. Tap **Status** → list groups by **To Do** / **In Progress** / **Done**.

**Expected**
- Group headers render at the top of each section.
- Tasks re-arrange under the new headers immediately.

**Edge cases to try**
- Empty group sections do not render headers.

**Devices** All.

---

### TASK-EMPTY-01 — Empty states

**Pre-conditions**
- Signed in.

**Steps**
1. Open a new event with no tasks → list shows **No tasks yet** title + **Tap + to create your first task** subtitle.
2. With tasks present, apply a filter that matches none → list shows **No tasks match this filter** with a **Clear filters** CTA.
3. Tap **Clear filters** → all filters reset; full list visible.

**Expected**
- Both empty states render in the body where the list would be.
- The clear-filters CTA fires `setState(() => filter = TasksFilter())` (resets every chip + search + sort + group).

**Devices** All.

---

### TASK-EXP-01 — Export PDF

**Pre-conditions**
- Signed in.
- At least one task in the event.

**Steps**
1. From the Tasks list, find the top-right action button (looks like a share icon).
2. Long-press to confirm the tooltip reads **Export PDF**.
3. Tap it.

**Expected**
- A PDF is generated by `runTaskPdfExport` via `taskRepositoryProvider`'s exporter seam.
- iOS / Android: the system share sheet opens with a `.pdf` file attached. Save / share as desired.
- Web: a `.pdf` file downloads to the browser's downloads folder.

**Edge cases to try**
- Generation failure → snackbar **Couldn't generate report** (terracotta).

**Devices** All.

---

## §6 My Tasks — cross-event

**~10 min.** The Tasks tab, top-level. Shows tasks assigned to YOU across every event you belong to.

### MYT-LAYOUT-01 — Layout sanity

**Pre-conditions**
- Signed in.
- You are assigned to ≥ 1 task in ≥ 1 event.

**Steps**
1. Tap the **Tasks** tab.

**Expected**
- Header: **My Tasks** title in the standard ScreenHeader.
- Below the header: a **TaskProgressSummary** strip showing todo / doing / done counts of YOUR filtered tasks.
- Below the strip: the SegmentedFilterBar (default scroll layout, NOT equalWidth — to support i18n widening). Segments: **All**, **To Do**, **Doing**, **Done**.
- Below the segments: an independent **Overdue** badge (urgent style, terracotta) with a count. Tapping toggles its filter.
- The list below groups your tasks by event with a `SectionLabel` per event (`{emoji}  {event title}`).

**Edge cases to try**
- Pinch-zoom is disabled.

**Devices** All.

---

### MYT-FILT-01 — Segmented filter (All / To Do / Doing / Done)

**Pre-conditions**
- Signed in.
- You have tasks across multiple statuses.

**Steps**
1. From the Tasks tab, tap each segment in turn: **All** → **To Do** → **Doing** → **Done**.

**Expected**
- The list re-filters to only tasks in the picked status.
- The progress summary strip ALSO re-narrows to the picked status (a Doing-filter shows only doing counts).
- The default layout is scrollable (NOT equalWidth) — verify the bar is in a `SingleChildScrollView` and the 4 segments don't get crushed at 320 px.

**Edge cases to try**
- 320 px viewport — 4 long-ish labels stay scrollable, no crush.
- 200% text scale — 4 segments may need to scroll; no overflow exception.

**Devices** All.

---

### MYT-OVR-01 — Overdue toggle

**Pre-conditions**
- Signed in.
- You have ≥ 1 overdue task (`dueDate` is past + status != done).

**Steps**
1. Below the segmented filter, tap the **Overdue** badge (terracotta urgent style with a numeric count).

**Expected**
- The badge brightens to full opacity (it's at ~0.55 opacity when off).
- The list narrows to overdue tasks only.
- Combining with a segment filter (e.g., **To Do** + Overdue) intersects the predicates.
- Tap again to deselect → returns to full opacity off state.

**Edge cases to try**
- No overdue tasks → the count badge reads 0 but the toggle is still tappable.

**Devices** All.

---

### MYT-EMPTY-01 — Adaptive empty states

**Pre-conditions**
- Signed in.

**Steps**
1. **Path A (no tasks assigned, but you have events)**: sign in with an account that has 0 assigned tasks across all its events.
2. **Path B (no events at all)**: sign in with a brand-new account that has no events.
3. **Path C (no match)**: with tasks present, pick the **Done** segment but with all tasks still under **To Do**.

**Expected**
- Path A: empty placeholder **No tasks assigned to you** + subtitle **Open an event from the Dashboard to view or create tasks.** + CTA **Open Dashboard** → goes to Home.
- Path B: same title + subtitle **Create an event from the Dashboard to get started.** + CTA **Create an event** → goes to Home.
- Path C: a centered light note (no Lottie) reading **No tasks match "To Do" yet.** (using the segment label). If Overdue is on: **No overdue tasks match "To Do".**

**Edge cases to try**
- The empty placeholder's CTA navigation goes to `/dashboard` (Home tab) — verify it doesn't navigate to a deleted route.

**Devices** All.

---

### MYT-SIGN-01 — Sign-in-required

**Pre-conditions**
- Signed out.

**Steps**
1. Tap the **Tasks** tab.

**Expected**
- Empty placeholder with title **Sign in to view your tasks**. No CTA (the user is already past the auth gate by definition; this is an edge case during token expiry / sign-out flicker).

**Edge cases to try**
- Sign in → the screen recovers to the data state without restart.

**Devices** All.

---

### MYT-NAV-01 — Tap to open task detail

**Pre-conditions**
- Signed in.
- ≥ 1 task assigned to you.

**Steps**
1. Tap any row in the Tasks list.

**Expected**
- Navigates to `/dashboard/event/{eventId}/tasks/{taskId}` — the same Task Detail screen tested in `TASK-DET-01`, scoped to the right event.
- Status changes are NOT directly toggleable from the My Tasks tile (`canChangeStatus: false` is passed in `_MyTasksList`); status changes must go through Task Detail or the event-scoped Tasks list.

**Edge cases to try**
- Use the device back button → returns to the **Tasks** tab with the same scroll position.

**Devices** All.

---

## §7 Chat — event-scoped

**~20 min.** Inside an event, tap the **Chat** quick-link. Covers send / critical alert / settlement dispute / send-failed retry / empty state.

### CHAT-SEND-01 — Send a message

**Pre-conditions**
- Signed in as a member of the event.
- The event has ≥ 2 members (so you can see another user's name in your inbox preview later).

**Steps**
1. Open the event → tap **Chat**.
2. App bar reads **Chat**. Below the message list, an input row shows a text field with hint **Type a message...**.
3. Type a short message, e.g. `Hey crew, packing list ready?`.
4. Tap the send icon button (right side of the input).

**Expected**
- The message appears at the bottom of the chat list within ~1-2 s as a charcoal-on-cream bubble aligned to the right (your own message).
- The send field clears.
- The keyboard stays open for follow-up messages.

**Edge cases to try**
- Submit with the field empty → no message sent, no snackbar.
- Send a very long message (~500 chars) → bubble wraps gracefully.
- Tap the send icon while a previous send is in flight (`isSending: true`) → the input is disabled; no duplicate send.

**Devices** All.

---

### CHAT-EMPTY-01 — Empty chat state

**Pre-conditions**
- Signed in.
- Open the Chat for an event with zero messages (a freshly created event).

**Steps**
1. Open the event → tap **Chat**.

**Expected**
- The body shows centered text **No messages yet — be the first to say something.** in medium grey.
- The input row is still active at the bottom — type + send works as in `CHAT-SEND-01`.

**Edge cases to try**
- Send one message → the empty state disappears and the message renders as a bubble.

**Devices** All.

---

### CHAT-FAIL-01 — Send-failed inline error + retry

**Pre-conditions**
- Signed in. In an event Chat.

**Steps**
1. Put the device in airplane mode.
2. Type a message and tap send.

**Expected**
- After a short delay, an inline row appears just above the input with a terracotta error icon and the text **Send failed — tap Send again to retry**.
- The input field re-enables; you can tap send to retry.

**Edge cases to try**
- Restore network → tap send again → message goes out, error row disappears.
- Send multiple messages while offline — each fail; the error row stays visible until the next success.

**Devices** All.

---

### CHAT-URG-01 — Critical alert modal (send urgent)

**Pre-conditions**
- Signed in.
- In an event Chat.

**Steps**
1. Tap the urgent icon (looks like a warning) in the chat's app bar (terracotta-colored, right side of **Chat** title).
2. A bottom sheet appears with title **Send Critical Alert** (with the urgent icon as prefix).
3. Below the title, four predefined option rows:
   - **Emergency - Everyone stop and check in**
   - **Meeting point changed - Check details**
   - **Weather alert - Take shelter**
   - **Schedule changed - Check new times**
4. Tap any one. The row gets a terracotta-tinted background + a terracotta border.
5. Tap the terracotta **Send Alert** button at the bottom.

**Expected**
- The sheet dismisses.
- The alert appears in the chat as a normal bubble BUT with a **Critical Alert** label above the text (terracotta with the priority-high icon).
- All other members of the event receive a push notification (covered in §7.5).

**Edge cases to try**
- Type into **Or type a custom alert...** field — selection clears on any of the predefined options.
- Tap a predefined option after typing → the custom field clears.
- Tap **Send Alert** with both empty → no send (silent no-op per `_send` guard).

**Devices** All.

---

### CHAT-DISP-01 — Settlement dispute sheet

**Pre-conditions**
- Signed in.
- An event chat that contains at least one settlement-kind message (created when a user taps Settle Up → marks paid; or seeded by the dev team).

**Steps**
1. Find a settlement-kind bubble in the chat (visually different from regular messages — typically sage-tinted with a coin / handshake glyph; tester confirms the exact visual treatment in the build).
2. Tap the settlement bubble.
3. A bottom sheet opens with:
   - Title: **Settlement**
   - Summary line (e.g. **You settled $25 with Alex**).
   - Subtitle: **Disputing will remove this settlement and restore the balance.**
   - Sage filled button: **All good — keep it**
   - Terracotta outlined button: **Dispute this settlement**

**Expected**
- Tap **All good — keep it** → sheet dismisses, no action.
- Tap **Dispute this settlement** → sheet dismisses + Cloud Function `disputeSettlement` fires.
  - On success: sage snackbar **Settlement disputed**.
  - On failure: terracotta snackbar **Could not dispute — try again**.

**Edge cases to try**
- Tap a regular (non-settlement) message → sheet does NOT appear.
- Dispute a settlement that was already disputed → behavior is server-driven; verify the snackbar text matches one of the two expected outcomes.

**Devices** All.

---

## §7.5 Push notifications + deep-link

**~15 min.** V1 wires FCM end-to-end via `lib/app/core/services/fcm_service.dart` + `fcm_handler.dart` + `fcm_gateway.dart`, plus the Cloud Function `onUrgentMessageCreated` (`functions/src/events/onUrgentMessageCreated.ts`). Tests below need TWO staging accounts and at least one phone-form-factor device (simulator push delivery is unreliable; prefer real hardware).

> 🔧 **Notification payload (for technical testers):**
> - Title: **🚨 Urgent in \<event title\>**
> - Body: the alert text, truncated to 80 chars with an ellipsis suffix `…`.
> - Data: `eventId`, `deepLink: /dashboard/event/{eventId}/chat`, `messageId`.

### PUSH-PERM-01 — Permission grant on first run

**Pre-conditions**
- Fresh install (no prior notification grant on this device for the app).

**Steps**
1. Sign in for the first time on this build.

**Expected**
- iOS / Android prompts for notification permission within a short window after sign-in.
- Grant → the device's FCM token is written to `users/{uid}/private/profile.fcmTokens` (technical testers can verify in Firestore via [Appendix B](#appendix-b--firebase-staging-console)).

**Edge cases to try**
- Deny the permission → no token is written; no notifications arrive in the rest of §7.5 (those tests should be marked N/A or skipped).
- Re-grant via OS Settings later → the token is written on next app foreground.

**Devices** iPhone, Android, Tablet rail. Web: N/A — `firebase_messaging` web support is not configured in v1.

---

### PUSH-URG-01 — Urgent message → push arrives

**Pre-conditions**
- TWO staging accounts: **A** (recipient — your device) and **B** (sender — second device or simulator).
- Both accounts are members of the same event.
- A's device has notifications granted (`PUSH-PERM-01`).

**Steps**
1. On device A: sign in as A → app is backgrounded (swipe up to background; or fully terminate for `PUSH-COLD-01`).
2. On device B: sign in as B → open the event chat → fire a Critical Alert via `CHAT-URG-01`.
3. Wait up to ~30 s.

**Expected**
- Device A receives a system notification:
  - Title: **🚨 Urgent in \<event title\>** (the title is prefixed with the 🚨 emoji).
  - Body: the alert text (e.g. **Emergency - Everyone stop and check in**), truncated to 80 chars with `…` if longer.
- The notification appears in the system notification shade.

**Edge cases to try**
- Send a NON-critical message from B (`CHAT-SEND-01`) → no notification arrives on A. The `onUrgentMessageCreated` Cloud Function fires only when `data.isHighPriority === true`.
- Send a Critical Alert from A's OWN account → A does NOT get a notification (the function skips the sender).
- Verify only event members receive the notification — non-members don't.

**Devices** iPhone, Android. Tablet rail: same as phone (FCM works on any iOS/Android device with notification permission). Web: N/A.

---

### PUSH-FG-01 — Foreground delivery (in-app banner, not system notification)

**Pre-conditions**
- Same as `PUSH-URG-01` setup.
- Device A has the app open in the foreground but is NOT on the event chat screen for the target event (e.g., browsing Home or Profile or a different event).

**Steps**
1. From device B, fire a Critical Alert in the shared event.

**Expected**
- Device A's app shows an in-app banner (NOT a system notification) within ~30 s, surfacing the title + body.
- Tapping the banner deep-links to the event's chat screen (`/dashboard/event/{eventId}/chat`).

**Edge cases to try**
- Device A is ON the target event's chat screen when the alert fires → the foreground banner is **suppressed** (no in-app banner; the message just appears in the chat list). This is per `FcmHandler.handleForegroundMessage` which suppresses banners for the current event.

**Devices** iPhone, Android. Web N/A.

---

### PUSH-BG-01 — Tap from background

**Pre-conditions**
- Device A's app is BACKGROUNDED (not killed — the app's process is still running, just not foregrounded).
- A push notification from `PUSH-URG-01` is in the notification shade.

**Steps**
1. Pull down the notification shade.
2. Tap the **🚨 Urgent in \<event title\>** notification.

**Expected**
- The app foregrounds.
- It deep-links directly to the correct event chat screen (`/dashboard/event/{eventId}/chat`) — bypassing Home / Tasks / wherever the user was before.

**Edge cases to try**
- Tap a notification for an event you've since left → the app navigates to `/dashboard/event/{eventId}/chat` but the screen may show an empty / error state because you no longer have access. That's a graceful failure, not a bug.

**Devices** iPhone, Android. Web N/A.

---

### PUSH-COLD-01 — Tap from killed state (cold start deep-link)

**Pre-conditions**
- Device A's app is FULLY TERMINATED (swipe up + flick away on iOS; force-stop on Android).
- A push notification from `PUSH-URG-01` is in the notification shade.

**Steps**
1. Tap the notification.

**Expected**
- The app cold-starts.
- After the auth gate / splash, it deep-links to the correct event chat screen — NOT to Home / Tasks default.

**Edge cases to try**
- Tap a stale notification (the event was deleted in the meantime) → the app cold-starts and shows a graceful "event not found" state instead of crashing.

**Devices** iPhone, Android. Web N/A.

---

## §8 Chat inbox — cross-event

**~10 min.** The Chat tab, top-level. Cross-event inbox of conversation rows.

### INBOX-LAYOUT-01 — Inbox layout

**Pre-conditions**
- Signed in.
- You have ≥ 2 events with at least one chat message each.

**Steps**
1. Tap the **Chat** tab.

**Expected**
- Header: **Chat** title in the standard ScreenHeader (NOT the event-scoped **Chat** app bar — same word, different context).
- Below the header: a scrollable list of conversation rows, one per event with ≥ 1 message.
- Each conversation row is wrapped in an **elevated Card** (white background, rounded corners, ~16 px horizontal margin, ~4 px vertical margin) — verifies the Phase-6 polish from `cohesive design refresh + cross-event tabs + constants centralization`.
- Each row shows:
  - Left: event emoji (per event type — e.g. ✈️ for Trip, 🎯 for Project, 🎉 for Social, 📌 for Custom).
  - Center: event title (bold if unread or urgent) + last-message preview (one line, truncated).
  - Right: relative timestamp + unread pill (if any).

**Edge cases to try**
- Pull-to-refresh (if implemented) → reloads the inbox.

**Devices** All.

---

### INBOX-UNREAD-01 — Unread pill + cap at 99+

**Pre-conditions**
- Signed in.
- A second staging account has sent ≥ 1 message to a shared event since the last time you opened that event's chat.

**Steps**
1. Tap **Chat** tab. Find the conversation row for that event.

**Expected**
- The row's right side shows a small dark-charcoal pill with the unread count (e.g., **3**).
- The event title and last-message preview render in bold weight.
- Have a second account send 100+ messages → unread pill caps at **99+** (per `_unreadLabel` in `ConversationTile`).

**Edge cases to try**
- Tap the row → opens the event chat → the read state clears via `markEventRead` post-frame.
- Return to the **Chat** tab → the pill is gone and the row reverts to non-bold weight.

**Devices** All.

---

### INBOX-URG-01 — URGENT badge

**Pre-conditions**
- Signed in.
- A second staging account has sent a Critical Alert (urgent) to a shared event AND you haven't opened that chat yet.

**Steps**
1. Tap **Chat** tab. Find the affected conversation row.

**Expected**
- A small terracotta **URGENT** badge appears to the left of the event title.
- The title is bold; the last-message preview text is also in a terracotta-tinted heavier weight.
- The unread pill (if also present) is **terracotta** (not charcoal) to reinforce urgency.

**Edge cases to try**
- Tap the row → opens chat → on return, the URGENT badge is gone (`markEventRead` clears the urgent flag along with the unread state).

**Devices** All.

---

### INBOX-PREVIEW-01 — Last-message preview "You: ..." prefix

**Pre-conditions**
- Signed in.
- You are the most recent sender in a shared event.

**Steps**
1. Send a message in an event chat.
2. Return to the **Chat** tab.

**Expected**
- The conversation row for that event shows the last-message preview prefixed with **You:** (e.g., `You: Packing list ready?`).
- Long previews truncate at ~60 chars with `…`.

**Edge cases to try**
- A second account sends a message after yours → the preview now reads **\<their display name\>: \<their text\>**, with the prefix being their actual display name (NOT "You").
- When `displayName` is null for the sender, the prefix falls back to their UID.

**Devices** All.

---

### INBOX-TIME-01 — Timestamp formatting

**Pre-conditions**
- Signed in.
- Events with messages of various recency: <1 min, <1 h, <24 h, yesterday, <30 d, >30 d.

**Steps**
1. Tap **Chat**. Inspect each row's timestamp on the right.

**Expected**
- < 1 minute ago: **now**
- < 1 hour ago: **\<N\>m**
- < 24 hours ago: **\<N\>h**
- 1 day ago: **Yesterday**
- < 30 days ago: **\<N\>d**
- ≥ 30 days ago: **\<Mon\> \<D\>** (e.g. **Apr 12**)

**Edge cases to try**
- Pull-to-refresh (if implemented) — relative timestamps recompute.
- The relative labels are English-only in v1 (see Appendix D Known Limitations) — don't file as a bug for non-English locales.

**Devices** All.

---

### INBOX-TAP-01 — Tap to open event chat

**Pre-conditions**
- Signed in.
- ≥ 1 conversation row in the inbox.

**Steps**
1. Tap any conversation row.

**Expected**
- Navigates to `/dashboard/event/{eventId}/chat` — the event-scoped chat screen tested in §7.
- The unread + URGENT state on the row clears (via `markEventRead` on first frame).
- Use the device back button → returns to **Chat** tab with the same scroll position.

**Edge cases to try**
- Tap a row whose event you've since left → graceful "event not found" or empty chat state.

**Devices** All.

---

### INBOX-EMPTY-01 — Adaptive empty states

**Pre-conditions**
- Signed in.

**Steps**
1. **Path A (no messages, but has events)**: account belongs to events but no event has any messages.
2. **Path B (no events at all)**: fresh account, no events.

**Expected**
- Path A: empty placeholder **No messages yet** + subtitle **Open an event from the Dashboard to start chatting.** + CTA **Open Dashboard** → goes to Home.
- Path B: same title + subtitle **Create or join an event to chat with your crew.** + CTA **Create an event** → goes to Home.

**Edge cases to try**
- The CTA navigates to `/dashboard` (Home tab).

**Devices** All.

---

### INBOX-ERR-01 — Inbox error state

**Pre-conditions**
- Signed in.
- A way to force the `globalInboxProvider` into error (typically airplane mode + cold start before the cache loads).

**Steps**
1. Trigger the error state (network failure + restart).

**Expected**
- The body shows an EmptyStatePlaceholder with title **Could not load your inbox** and the underlying error message as the subtitle, plus an error Lottie animation.

**Edge cases to try**
- Restore network → the screen recovers without restart.

**Devices** iPhone, Android, Tablet rail. Web: simulate offline via DevTools.

---

## §9 Budget — event-scoped

**~25 min.** Inside an event, tap the **Budget** quick-link. Covers Total + Balances + Settle Up + Expenses CRUD + receipt upload + PDF/CSV export.

### BUD-LAYOUT-01 — Budget screen layout

**Pre-conditions**
- Signed in to an event with ≥ 2 members and ≥ 1 expense.

**Steps**
1. Open the event → tap **Budget**.

**Expected**
- App bar reads **Budget**.
- Top: **Total Expenses** card showing the currency-formatted sum (e.g., **$245.50**).
- Below, three sections each with a dark-grey letterspaced caps header:
  - **BALANCES** — one row per member, sorted high → low. Positive (sage) shows **\<name\> is owed +$N**; negative (terracotta) shows **\<name\> owes -$N**; zero shows **\<name\> settled $0**.
  - **SETTLE UP** — one row per outstanding settlement, formatted **\<from\> pays \<to\>** with amount in terracotta + a **Settle** text button.
  - **EXPENSES** — list of `ExpenseTile`s for non-payment expenses (`!isPayment`).
- A sage **+** FAB at the bottom-right opens the Expense modal (`BUD-EXP-01`).
- A top-right share icon (tooltip **Export**) opens a menu with **Export PDF** + **Export CSV** options.

**Edge cases to try**
- Empty expenses → the EXPENSES section shows **No expenses yet** in a centered light placeholder.
- Single-member event (just you) → the **BALANCES** section is hidden (memberIds.length > 1 is the gate).

**Devices** All.

---

### BUD-EXP-01 — Add expense (with split + donation toggle)

**Pre-conditions**
- Signed in to an event.

**Steps**
1. Tap the sage **+** FAB.
2. Expense modal opens as a bottom sheet titled **Add Expense**.
3. Type a value into **Amount ($)** (hint dynamically uses the event currency symbol — e.g., **Amount (€)** for an EUR event).
4. Type a description in **Description (optional)**.
5. (Optional) Toggle **Donate this cost** ON — when on, splits exclude the payer.
6. (Optional) Tap **Add receipt** outlined button → see `BUD-RECEIPT-01`.
7. Observe the live split helper text below: **Split: \<symbol\>\<per-person-amount\> per person (\<N\> people)**.
8. Tap **Add Expense**.

**Expected**
- The modal dismisses.
- The new expense appears at the top of the **EXPENSES** list.
- Balances recompute: payer net positive (or zero if donation), all other members net negative.

**Edge cases to try**
- Amount empty → validator error **Enter an amount**.
- Non-numeric amount → validator error **Invalid amount**.
- Amount < 0.01 → validator error **Amount must be at least 0.01**.
- Amount > 10000000 → validator error **Amount must be at most 10000000**.
- Toggle **Donate this cost** ON in a 4-member event → split shows **3 people** (excludes payer).
- Network failure during create → snackbar **Failed to add expense** (terracotta).

**Devices** All.

---

### BUD-EXP-EDIT-01 — Edit expense

**Pre-conditions**
- Signed in as creator / owner / admin of the expense (any of the three has `canEdit`).
- ≥ 1 expense exists.

**Steps**
1. On an `ExpenseTile`, tap the overflow ⋮ → **Edit**.
2. Expense modal opens titled **Edit Expense**, pre-filled with the expense's current values.
3. Change the amount or description.
4. Tap **Save changes** (the primary button label switches from **Add Expense** to **Save changes** in edit mode).

**Expected**
- Modal dismisses.
- The expense tile reflects the new values.
- Balances re-compute.

**Edge cases to try**
- Sign in as a non-creator non-admin member → the overflow ⋮ does NOT show **Edit**.
- Network failure → snackbar **Could not update expense** (terracotta).

**Devices** All.

---

### BUD-EXP-DEL-01 — Delete expense

**Pre-conditions**
- Signed in as creator / owner / admin.
- ≥ 1 expense exists.

**Steps**
1. On an `ExpenseTile`, tap the overflow ⋮ → **Delete** (terracotta).
2. A confirmation dialog appears titled **Delete this expense?**.
3. Tap the terracotta delete button.

**Expected**
- The tile disappears from the EXPENSES list.
- Balances recompute.

**Edge cases to try**
- Cancel mid-dialog → no deletion.
- Network failure → snackbar **Could not delete expense** (terracotta).

**Devices** All.

---

### BUD-RECEIPT-01 — Receipt upload + viewer

**Pre-conditions**
- Signed in.
- In the Add or Edit Expense modal.

**Steps**
1. Tap **Add receipt** (outlined button with a camera icon).
2. The system image picker opens (gallery or camera per OS dialog).
3. Pick an image.
4. A receipt preview row appears: 56 × 56 thumbnail + the text **Receipt attached** + a close ✕ icon to clear.
5. Tap **Add Expense** (or **Save changes** in edit mode) to commit.
6. After save, tap the expense tile's small receipt thumbnail (if surfaced — drafter verifies the entry point) → full-screen **ReceiptViewer** opens.

**Expected**
- The thumbnail appears in the modal.
- After save, the receipt is uploaded to Firebase Storage and the expense doc gets a `receiptPath`.
- ReceiptViewer renders the full-resolution image; tap outside / back to dismiss.

**Edge cases to try**
- Cancel the picker → no thumbnail change.
- Tap the close ✕ on the thumbnail → preview cleared.
- Image loading failure in the picker preview → falls back to a broken-image icon placeholder.

**Devices** iPhone (gallery + camera). Android (gallery + camera). iPad rail (gallery only on most models). Web: file picker (no camera).

---

### BUD-SETTLE-01 — Event-scoped Settle Up (Pay with Venmo / Cash App / Copy)

**Pre-conditions**
- Signed in.
- You owe at least one other member (you appear as the `from` on a settlement row).
- The counterparty has `venmoHandle` and/or `cashappHandle` set in their Profile.

**Steps**
1. On Budget, in the SETTLE UP section, tap the **Settle** text button on the row where you're the `from`.
2. A bottom sheet opens with:
   - The amount in large headline type.
   - A subtitle reading **\<You-or-fromName\> pay \<toName-or-"them"\>** (e.g., **You pay Alex**).
   - A sage filled button: **Pay with Venmo** (or **No Venmo handle** disabled if the counterparty has no Venmo handle).
   - An outlined button: **Pay with Cash App** (or **No Cash App handle** disabled).
   - A text button: **Copy payment details**.
3. Tap **Pay with Venmo** (if the counterparty has a Venmo handle).

**Expected**
- The Venmo app deep link (`venmo://paycharge?txn=pay&recipients=\<handle\>&amount=\<x.xx\>&note=\<event title\> settle`) launches.
- If Venmo isn't installed, the app falls back to `https://venmo.com/\<handle\>?...` in the system browser.
- After returning to the app: a dialog appears titled **Did you send the payment?** with buttons **Not yet** + **Yes, recorded**. Tap **Yes, recorded** → the settlement is recorded as a payment expense.

**Edge cases to try**
- Tap **Pay with Cash App** → opens `https://cash.app/$\<handle\>/\<amount\>`.
- Tap **Copy payment details** → snackbar **Copied — paste it where you settle** and the system clipboard now holds **\<symbol\>\<amount\> to \<recipient name or uid\> for \<event title\>**.
- Counterparty handle contains invalid characters → snackbar **That payment handle looks invalid** (terracotta); no launch.
- Counterparty has neither handle → both buttons are disabled; only the **Copy payment details** path works.

**Devices** iPhone (Venmo / Cash App both work natively). Android (Venmo / Cash App apps must be installed; otherwise web fallback opens). Web: deep links open in a new tab or fall back to the web URL.

---

### BUD-EXPORT-01 — Export PDF / Export CSV

**Pre-conditions**
- Signed in.
- At least one expense in the event.

**Steps**
1. On Budget, tap the top-right share icon (tooltip **Export**).
2. A menu appears with **Export PDF** + **Export CSV**.
3. Pick one.

**Expected**
- A file is generated and offered through the system share sheet (iOS / Android) or downloaded (Web).
- PDF: human-readable report of expenses + balances.
- CSV: machine-readable spreadsheet, one row per expense.

**Edge cases to try**
- Generation failure → snackbar **Couldn't generate report** (terracotta).

**Devices** All.

---

## §10 Budget ledger — cross-event

**~25 min.** The **Budget** tab, top-level. Cross-event ledger with BalanceTile + Debts + Recent Expenses + Settle Up.

### LED-LAYOUT-01 — Ledger layout

**Pre-conditions**
- Signed in.
- You have ≥ 2 events with expenses.

**Steps**
1. Tap the **Budget** tab.

**Expected**
- Header: **Budget** title in the standard ScreenHeader.
- Body, top to bottom:
  - **BalanceTile** showing the **YOU ARE OWED** column (sage) + **YOU OWE** column (terracotta) split, each with a money value. Currency: USD by default.
  - **Settle up** section header (sage) → list of `DebtTile` cards, each wrapped in an elevated white Card per Phase-6 polish.
  - **Recent expenses** section header → list of `RecentExpenseTile` cards.

**Edge cases to try**
- Pull-to-refresh (if implemented) — both BalanceTile and debt list reload.

**Devices** All.

---

### LED-CUR-01 — Multi-currency disclaimer (BUD-CUR-01)

**Pre-conditions**
- Signed in.
- ≥ 1 event uses USD, ≥ 1 event uses a non-USD currency (e.g., EUR or GBP), and each has at least one expense.

**Steps**
1. Tap **Budget**.
2. Inspect the area just below the BalanceTile hero.

**Expected**
- A small disclaimer line reads **Totals are approximate when events use different currencies.**

**Edge cases to try**
- Sign in to an account where every event is USD → the disclaimer is NOT shown.
- Add an EUR expense to a fresh event → return to **Budget** → disclaimer appears.

**Devices** All.

---

### LED-ALLSETTLED-01 — "All settled" chip

**Pre-conditions**
- Signed in.
- You have 0 outstanding debts across every event.

**Steps**
1. Tap **Budget**.

**Expected**
- The Settle Up section shows a sage **You're all settled up.** chip instead of debt rows.
- The Recent expenses section still renders if there are recent expenses.

**Edge cases to try**
- Create a new debt → return → the chip is replaced by debt rows.

**Devices** All.

---

### LED-DEBT-01 — DebtTile layout + Settle Up CTA

**Pre-conditions**
- Signed in.
- You owe at least one counterparty in any event.

**Steps**
1. Tap **Budget**.
2. In Settle up, find the relevant DebtTile.

**Expected**
- Avatar circle with the counterparty's first letter (sage background, charcoal letter).
- Counterparty display name (or UID fallback).
- An event chip with the event title.
- Right-side: money amount in **You owe** style (terracotta with a `-` sign) + an outlined **Settle Up** button below the amount.
- Each tile is wrapped in an elevated white **Card** (per Phase-6 polish).

**Edge cases to try**
- Counterparty with a very long display name → name truncates with an ellipsis.

**Devices** All.

---

### LED-SETTLE-01 — Settle Up — Venmo deep link

**Pre-conditions**
- Signed in.
- Counterparty's Profile has `paymentMethod: venmo` AND a non-empty `paymentHandle` (e.g., `@alex-test`).

**Steps**
1. On a DebtTile for that counterparty, tap **Settle Up**.

**Expected**
- The Venmo app deep link fires: `venmo://paycharge?txn=pay&recipients=\<handle\>&amount=\<x.xx\>&note=\<event title\> settle-up`.
- If Venmo isn't installed (or the launch fails), the controller falls back to the manual fallback sheet (`LED-FALL-01`).

**Edge cases to try**
- Counterparty's `paymentHandle` is invalid (contains spaces, special chars, > 30 chars) → no deep link fires; fallback sheet opens instead.

**Devices** iPhone (Venmo native). Android (Venmo native). Web: deep links may not launch — fallback sheet opens.

---

### LED-SETTLE-02 — Settle Up — Cash App universal link

**Pre-conditions**
- Counterparty's Profile has `paymentMethod: cashapp` AND a non-empty `paymentHandle`.

**Steps**
1. Tap **Settle Up** on the DebtTile.

**Expected**
- The Cash App universal link opens: `https://cash.app/$\<handle\>/\<amount\>` (formatted to 2 decimals).
- iOS: opens in the Cash App if installed; otherwise in the system browser.
- Android: same behavior.
- Web: opens in a new tab.

**Edge cases to try**
- Invalid `paymentHandle` → no launch; fallback sheet opens.

**Devices** All.

---

### LED-FALL-01 — Settle Up — fallback sheet (Zelle / PayPal / Cash / Other / no handle)

> 📌 **Correction to spec:** v1 has **deep-link support for Venmo and Cash App only**. Zelle, PayPal, Cash, Other, or a missing `paymentMethod` ALL fall through to the manual fallback sheet — there is no Zelle or PayPal deep link in v1, contrary to early drafts of the spec.

**Pre-conditions**
- Counterparty's Profile has ONE of these:
  - `paymentMethod: zelle` / `paypal` / `cash` / `other` / null with any handle.
  - Any `paymentMethod` but no `paymentHandle` set.
  - Any `paymentMethod` with an invalid `paymentHandle` (e.g., `bad handle!`).

**Steps**
1. Tap **Settle Up** on the DebtTile.

**Expected**
- The manual fallback bottom sheet (`SettleUpFallbackSheet`) opens with:
  - Title: **Pay \<counterparty display name\>**
  - Large amount in terracotta (e.g., **$45.00**).
  - **Copy amount** outlined button (always present).
  - **Copy handle** outlined button (only if counterparty has a non-empty handle).
  - **Mark paid in event budget** text button at the bottom — tapping it dismisses the sheet and navigates to `/dashboard/event/{eventId}/budget`.

**Edge cases to try**
- Tap **Copy amount** → the raw amount (e.g. `45.00`) is on the clipboard.
- Tap **Copy handle** (if visible) → counterparty's handle is on the clipboard.
- Tap **Mark paid in event budget** → app navigates to the event's per-event budget screen where the tester can record the payment via `BUD-SETTLE-01`.

**Devices** All.

---

### LED-SETTLE-ERR-01 — Counterparty user-doc load failure

**Pre-conditions**
- Signed in. You owe a counterparty.
- A way to force `userRepository.getUser` to throw (e.g., network failure right after tap).

**Steps**
1. Tap **Settle Up** with a flaky network.

**Expected**
- A snackbar appears with the text **Could not load contact info**.
- The fallback sheet opens with the counterparty's name shown as the UID (null counterparty data) — the user can still **Copy amount** and **Mark paid**.

**Edge cases to try**
- Restore network, retry → succeeds with full counterparty data.

**Devices** All.

---

### LED-RECENT-01 — Recent expenses feed

**Pre-conditions**
- Signed in.
- ≥ 1 expense recorded across any of your events in the last 30 days.

**Steps**
1. Tap **Budget**.
2. Scroll to the **Recent expenses** section.

**Expected**
- Each row is a `RecentExpenseTile` wrapped in an elevated Card (per Phase-6 polish).
- Row layout: avatar with payer's first letter + description (or `\<payer\> paid` fallback if no description) + event title (medium-grey small text) + amount on the right + relative timestamp below the amount.
- Relative timestamps follow the same ladder as `INBOX-TIME-01`: **now** / **\<N\>m** / **\<N\>h** / **yesterday** (lowercase here) / **\<N\>d** / **\<Mon\> \<D\>**.

**Edge cases to try**
- Tap a row → navigates to the event's per-event budget screen for that expense's event (`/dashboard/event/{eventId}/budget`).
- The "You" prefix doesn't apply here — `RecentExpenseTile` shows **You** as the payer label only when `payerId == currentUserId`.

**Devices** All.

---

### LED-EMPTY-01 — Adaptive empty states

**Pre-conditions**
- Signed in.

**Steps**
1. **Path A (no balances, but has events)**: account belongs to events but no event has any expenses with splits affecting you.
2. **Path B (no events at all)**: fresh account, no events.

**Expected**
- Path A: empty placeholder **No balances yet** + subtitle **Open an event from the Dashboard to log an expense.** + CTA **Open Dashboard** → goes to Home.
- Path B: same title + subtitle **Create an event from the Dashboard to start tracking expenses.** + CTA **Create an event** → goes to Home.

**Edge cases to try**
- Add an expense in any event → return → empty state replaced by ledger.

**Devices** All.

---

### LED-ERR-01 — Ledger error state

**Pre-conditions**
- Signed in.
- A way to force `globalBalanceLedgerProvider` into error (network failure + cold start before cache loads).

**Steps**
1. Trigger the error state.

**Expected**
- An EmptyStatePlaceholder appears with title **Could not load your ledger** + the underlying error message as subtitle + a Lottie error animation.

**Edge cases to try**
- Restore network → screen recovers without restart.

**Devices** iPhone, Android, Tablet rail. Web: simulate offline via DevTools.

---

## §11 Responsive shell

**~10 min.** The adaptive bottom-bar ↔ rail transition at the 840 px breakpoint. Most relevant on iPad / Android tablet / web.

### SHELL-BREAK-01 — Bottom bar at < 840 px

**Pre-conditions**
- Signed in. App open on a phone-width device OR Web with the browser window < 840 px.

**Steps**
1. Look at the bottom of the screen.

**Expected**
- A 5-destination NavigationBar is pinned at the bottom: **Home**, **Tasks**, **Chat**, **Budget**, **Profile**.
- Each destination shows an icon + label.
- The active destination has a filled icon variant; inactive destinations use the outlined variant.

**Edge cases to try**
- Switch destinations rapidly — no flicker, no destination lag.
- The keyboard appearing (e.g., compose in Chat) does NOT cover the bar — the bar drops with the keyboard.

**Devices** iPhone, Android phone. Web at < 840 px window width.

---

### SHELL-BREAK-02 — Navigation rail at ≥ 840 px

**Pre-conditions**
- Signed in. App open on an iPad / Android tablet ≥ 840 px wide, OR Web with the browser window ≥ 840 px.

**Steps**
1. Look at the LEFT edge of the screen.

**Expected**
- A NavigationRail with the same 5 destinations is pinned at the left, extended mode (icons + labels visible inline).
- A vertical divider separates the rail from the body.
- The bottom-bar is NOT shown.
- A sign-out icon button is pinned to the BOTTOM of the rail with the tooltip **Sign out**. Tapping it signs you out without showing the bottom-sheet confirmation (see `SHELL-OUT-01`).

**Edge cases to try**
- Hover the sign-out button on web → tooltip **Sign out** appears.

**Devices** iPad, Android tablet (≥ 840 px), Web Chrome / Safari at ≥ 840 px window width.

---

### SHELL-RESIZE-01 — Route stack survives breakpoint transition

**Pre-conditions**
- Signed in.
- Web build (easiest test environment for live resize) OR a foldable Android device.

**Steps**
1. Open the **Tasks** tab.
2. Scroll halfway down the list.
3. Resize the browser window from 1200 px → 700 px (cross the 840 px breakpoint).
4. Observe the navigation switching from rail → bar.

**Expected**
- The Tasks list stays at the same scroll position.
- The Tasks tab remains selected (no jump to Home).
- No flicker, no widget tree teardown of the body.

**Edge cases to try**
- Reverse: resize from 700 px → 1200 px → rail re-appears.
- Cross the breakpoint while a modal sheet is open → sheet stays open.

**Devices** Web Chrome, Web Safari. Tablet rail to phone bar transition is the foldable / Stage Manager / Split View scenario on hardware.

---

### SHELL-OUT-01 — Rail sign-out (skips bottom sheet)

**Pre-conditions**
- Signed in. On rail (≥ 840 px).

**Steps**
1. Tap the sign-out icon button at the bottom of the rail.

**Expected**
- The app signs out immediately and navigates to the auth gate, **without** showing the bottom-sheet confirmation from `AUTH-OUT-01`.

**Edge cases to try**
- This is by design — the rail's sign-out is a "no friction" exit point. Document under Known Limitations if a tester reports it as a missing confirmation.

**Devices** iPad, Android tablet, Web Chrome / Safari at ≥ 840 px.

---

## §12 Accessibility

**~15 min.** Dynamic Type, VoiceOver / TalkBack pass, 320 px small-screen overflow audit.

### A11Y-TS-01 — Dynamic Type at 200% per tab

**Pre-conditions**
- Signed in.
- Device set to maximum system text scale (200% on iOS via Settings → Display & Brightness → Text Size, then Accessibility → Display & Text Size; ~Large Font Size on Android via Accessibility settings).

**Steps**
1. Open the app fresh after changing the system text scale.
2. Visit each tab in turn: **Home**, **Tasks**, **Chat**, **Budget**, **Profile**.

**Expected**
- All text scales up gracefully on every tab.
- No `RenderFlex overflowed` exceptions (no yellow + black "RenderFlex overflowed by N pixels" warnings).
- Tile-style components (`ConversationTile`, `EventTile`, `DebtTile`, `TaskTile`) wrap or shrink gracefully — no clipped text.
- The progress ring + status badges remain readable.

**Edge cases to try**
- Combine 200% scale + 320 px viewport (Safari responsive mode) — see `A11Y-OVR-01`.
- The Dashboard `Upcoming` / `Past` pills may automatically fall back from `equalWidth: true` to scrolling layout when labels exceed the available width — that's correct behavior, not a bug.

**Devices** All.

---

### A11Y-VO-01 — VoiceOver / TalkBack pass

**Pre-conditions**
- Signed in.
- iOS: enable VoiceOver via Settings → Accessibility, OR triple-click side button.
- Android: enable TalkBack via Settings → Accessibility.

**Steps**
1. Navigate through the **Home** tab using VoiceOver swipe gestures.
2. Focus on the `ProgressRing` on an EventTile.
3. Focus on the `StatusBadge` on a TaskTile (open the Tasks tab → focus on a task).
4. Focus on the URGENT badge on a ConversationTile (Chat tab — needs an urgent unread row).

**Expected**
- The screen reader announces meaningful labels:
  - ProgressRing: "N of M tasks done" (or similar — see `progress_ring.dart` for the actual `Semantics` label).
  - StatusBadge: announces the status text + count if any.
  - URGENT badge: announces "URGENT".
- Tapping with VoiceOver works the same as tapping without — buttons / tiles all fire their `onTap`.

**Edge cases to try**
- Switch tab focus with VoiceOver swipes — current tab is announced.
- The auth gate works with VoiceOver — input fields are labeled.

**Devices** iPhone (VoiceOver), Android (TalkBack), iPad (VoiceOver). Web: NVDA / VoiceOver Safari support varies — out of scope unless specifically requested.

---

### A11Y-OVR-01 — 320 px small-screen overflow audit

**Pre-conditions**
- Signed in.
- Test environment that can render at exactly 320 px width:
  - iPhone SE 1st gen (320 × 568).
  - Safari → Develop → Enter Responsive Design Mode → set viewport width to 320 px.
  - Chrome DevTools → Device Toolbar → custom width 320 px.

**Steps**
1. Set viewport / device to 320 px width.
2. Visit each tab and inspect the tiles named below.

**Expected**
- `ConversationTile` (Chat tab) with URGENT badge + long event title + long unread count → no overflow.
- `EventTile` (Home tab) with a long event title + member count + progress ring → no overflow.
- `DebtTile` (Budget tab) with a long counterparty name + large amount + Settle Up button → no overflow.
- `TaskTile` (Tasks tab) with a long title + budget pill + priority pill + overdue badge → no overflow.

**Edge cases to try**
- Combine 320 px width + 200% text scale (worst case) — some `RenderFlex overflowed` warnings may appear; document them as **known limitations** for v1 with a screenshot rather than blocking ship.

**Devices** iPhone SE (real hardware), Web Safari / Chrome at 320 px.

---

## §13 Offline + sync

**~10 min.** Airplane-mode behavior + pending-writes badge + resume-from-cold-start.

### SYNC-OFFLINE-01 — "Will sync when online" badge

**Pre-conditions**
- Signed in.
- Open a task detail screen (`TASK-DET-01`).

**Steps**
1. Put the device in airplane mode (or disable Wi-Fi + cellular).
2. Toggle the task's status (`TASK-STAT-01`) — e.g. tap to flip from **To Do** to **In Progress**.
3. Return to the task detail screen.

**Expected**
- A small row appears above the description with a "cloud off" icon and the literal text **Will sync when online** in medium-grey.
- The task's optimistic UI shows the new status; locally cached state reflects the change.

**Edge cases to try**
- Force-quit + reopen while still offline → the optimistic change persists; badge still shows.
- Restore network → the badge disappears within ~10 s as the pending Firestore write commits.

**Devices** iPhone, Android, iPad rail. Web: simulate offline via DevTools → Network → Offline.

---

### SYNC-RES-01 — Cold-start resume after offline edit

**Pre-conditions**
- Signed in.
- Open the Tasks tab in an event.

**Steps**
1. Put the device in airplane mode.
2. Create a task (`TASK-CRE-01`) — title `Offline Cold Start Resume Test`.
3. Verify the task appears in the local list (optimistic create).
4. Force-quit the app.
5. Wait ~5 s.
6. Restore network.
7. Re-open the app.

**Expected**
- The task is still present in the list after cold start (Drift cache).
- Within ~10 s after reconnect, the task syncs to Firestore — verify by signing in on a second device or checking the Firebase staging console (Appendix B).
- The task is NOT duplicated (single create, single Firestore doc).

**Edge cases to try**
- The same flow but with a status toggle instead of create.
- Repeated offline edits across multiple events → all sync in order on reconnect.

**Devices** iPhone, Android. Web: not fully supported — IndexedDB persistence has known caveats in Private Mode (see Appendix D).

---

### SYNC-NET-01 — Network failure mid-write (generic catch-all)

**Pre-conditions**
- Signed in.

**Steps**
1. With a flaky network connection (or DevTools throttling on Web), attempt any mutating action: create event, create task, send message, log expense.

**Expected**
- The app either:
  - Optimistically applies the change locally + queues the Firestore write to sync when network returns (see `SYNC-OFFLINE-01`), OR
  - Shows a terracotta snackbar (e.g. **Failed to create task**, **Could not update status**, **Failed to add expense**, etc.) and rejects the optimistic change.
- No crash, no silent failure.

**Edge cases to try**
- Repeated failures in sequence → no compounding error state; each retry is independent.

**Devices** All.

---

---

## §14 Bug-report template

Paste this block into the shared bug spreadsheet (or email it to the dev team) **once per bug**. Replace each `<...>` with the literal facts of the bug you saw. Don't paraphrase — copy what was on the screen.

```
BUG REPORT
----------
Date / Time:      <when you observed it, e.g. 2026-05-19 14:32 PT>
Tester name:      <your name>
Device:           <e.g. iPhone 15 Pro, iOS 18.2 — or "Web Chrome 124 on macOS 14.5">
App build:        <from Profile → version footer, e.g. CrewPoint v1.0.0 (1)>
Network:          <Wi-Fi / cellular / airplane>

Test ID:          <copy from the guide, e.g. EV-CRE-03>
Steps to reproduce:
  1. <first step>
  2. <next step>
  3. <... finish with the step that triggered the bug>

Expected:         <quote the "Expected" bullet from the guide>
Actual:           <what really happened — quote on-screen text if any>

Frequency:        <every time / intermittent (N out of M tries) / once>
Severity:         <blocker / major / minor / cosmetic>

Attachments:      <screenshot file names, screen recording link if any>
Notes:            <anything else — recent actions, suspected trigger, console errors>
```

### Severity rubric

- **Blocker** — the app crashes, won't launch, or a core flow is fully broken (sign-in, create event, send message, log expense, settle up).
- **Major** — a non-core flow is broken or a core flow is broken on one device but works on another.
- **Minor** — wrong label / wrong copy / off-by-one count / visual glitch that doesn't block use.
- **Cosmetic** — pixel-level visual issue, padding nit, color slightly off.

### Useful info to capture before filing

- **Logs** — see [Appendix A](#appendix-a--reading-device-logs). If you can capture the red exception trace at the moment of the bug, paste it in `Notes`.
- **Screenshot** — name it `<test-id>.png` and drop it into `docs/qa/screenshots/` if you have write access, otherwise attach to your bug entry.
- **Account context** — which staging account were you signed in as (primary or counterparty)? In which event?

---

## Appendix A — Reading device logs

This appendix is for technical testers (devs / QA). Non-technical testers can skip it — the bug-report template (§14) lets the dev team triage without log snippets.

### iOS

- Connect the device via USB.
- Open Xcode → **Window** → **Devices and Simulators**.
- Select the device on the left.
- Click **Open Console**.
- Filter the console by **process: Runner** to see only this app's output.
- What to look for:
  - **Red exception traces** — `══╡ EXCEPTION CAUGHT BY ...` blocks.
  - **Firebase HTTP errors** — 4xx / 5xx responses from `firestore.googleapis.com` or `firebasestorage.googleapis.com`.
  - `developer.log` tags emitted by the app — common ones: `chat.inbox`, `budget.ledger`, `budget.settleUp`, `fcm`, `tasks.myTasks`, `auth.legal`, `events`, `profile`.

### Android

Pick whichever fits your setup:

- **Easiest:** `flutter logs` (run from the project root in a terminal while a device is connected via USB or wireless ADB). Shows Flutter-tagged log output cleanly.
- **More control:** `adb logcat *:E flutter:V` — shows all errors at level E plus all flutter-tagged output at level V.
- **Filter by app:** `adb logcat --pid=$(adb shell pidof -s app.sookoon.crewpoint)` — only this app's lines (replace package name if the staging build uses a different applicationId).

> 🚫 **Do NOT run `adb logcat | grep -i crewpoint`** — Flutter doesn't tag logs with the app's package name. The tag is `flutter` (or whatever `developer.log(name: ...)` value the app passed). You'll see nothing and conclude (wrongly) that the app is silent.

What to look for: same as iOS — red exception traces, Firebase 4xx/5xx, and the `developer.log` tag list above.

### Web

- Chrome / Edge: F12 → **Console** tab (for app logs) + **Network** tab (for Firestore / Storage / Functions HTTP traffic).
- Safari: **Develop** → **Show Web Inspector** → **Console** + **Network**.
- What to look for:
  - Console errors (red rows).
  - Firestore reconnect storms (lots of `wss://...firestore.googleapis.com` reconnects with non-2xx).
  - Cloud Function 4xx/5xx responses (`onCall` endpoints under `*.cloudfunctions.net`).

### What a useful log snippet looks like in a bug report

When you paste log output into the bug template's `Notes:` field, include:

- The minute leading up to the bug.
- The first ~10 lines of any exception trace.
- The HTTP method + URL + response code of any non-2xx Firebase call near the bug.

Don't dump 1000s of lines — pick the 20 lines around the error.

---

## Appendix B — Firebase staging console

This appendix is for testers with read access to the staging Firebase project. If the dev team hasn't given you access, **skip it** — your bug reports should describe app behavior, not Firestore state.

### Access

- Console URL: `<Insert Firebase Console URL for the staging project — typically https://console.firebase.google.com/project/<staging-project-id>/overview>`.
- Sign in with your team Google account.
- The dev team must add you to the staging project as **Viewer** (read-only is sufficient for QA).

### What to inspect

| Section | Path | What you're verifying |
|---------|------|-----------------------|
| **Authentication → Users** | top-nav | Test accounts exist + `emailVerified` flag is set as expected. |
| **Firestore → Data** | top-nav | `events/{eventId}` — title, currency, memberIds, adminIds, creatorId, EventStatus (active / archived). |
| | | `events/{eventId}/tasks/{taskId}` — task fields (status, assigneeId, dueDate, priority, budgetEstimate, checklistItems). |
| | | `events/{eventId}/messages/{messageId}` — chat messages with `senderId`, `text`, `isHighPriority`, `timestamp`. |
| | | `events/{eventId}/expenses/{expenseId}` — expenses + splits + payment + receiptPath. |
| | | `users/{uid}` — public user doc (displayName, photoUrl, paymentMethod, paymentHandle, venmoHandle, cashappHandle). |
| | | `users/{uid}/private/profile.fcmTokens` — per-device FCM tokens (`PUSH-PERM-01`). |
| **Storage** | top-nav | `users/{uid}/profile.jpg` (avatar uploads from `PROF-PHOTO-01/02`); receipt images (`BUD-RECEIPT-01`). |
| **Functions** | top-nav | Recent invocations + duration + error rate. Look for `deleteUserAccount`, `deleteEvent`, `removeEventMember`, `promoteToAdmin`, `demoteAdmin`, `joinEvent`, `generateInviteCode`, `markTaskComplete`, `disputeSettlement`, `onUrgentMessageCreated`. |

### Common verifications mid-test

- After `AUTH-DEL-01`: the user doc should be deleted from `users/{uid}`; the auth user gone from **Authentication**.
- After `EV-DEL-01`: `events/{eventId}` is gone; all subcollections (tasks/messages/expenses) are cascaded.
- After `EV-MEM-04` (Promote to admin): `events/{eventId}.adminIds` array contains the promoted uid.
- After `PUSH-URG-01`: a recent `onUrgentMessageCreated` invocation in Functions logs.

---

## Appendix C — Settle Up deep-link reference

Source of truth: `lib/app/features/budget/data/pay_link_builder.dart` (note `data/`, NOT `application/`).

> ⚠️ **v1 has deep-link support for VENMO and CASH APP ONLY.** Zelle, PayPal, Cash, Other, missing `paymentHandle`, and invalid `paymentHandle` all fall through to the manual fallback sheet (`LED-FALL-01`). There is NO Zelle URI and NO PayPal URI in v1.

### Venmo

| Variant | URI template |
|---------|--------------|
| Native scheme (iOS / Android) | `venmo://paycharge?txn=pay&recipients=<handle>&amount=<x.xx>&note=<note>` |
| HTTPS fallback (when native launch fails) | `https://venmo.com/<handle>?txn=pay&amount=<x.xx>&note=<note>` |

**Pick rule** (cross-event ledger via `SettleUpController`):
1. Try the native scheme first.
2. If `urlLauncher.launch(uri)` returns false or throws, fall through to the manual fallback sheet.

**Pick rule** (event-scoped via `event_budget_page._launchVenmo`):
1. Try the native scheme.
2. If the launch fails, retry with the HTTPS fallback URL.
3. If that also fails, the pending-settlement notifier holds the state.

### Cash App

| Variant | URI template |
|---------|--------------|
| Universal link | `https://cash.app/$<handle>/<x.xx>` |

There is no separate native scheme for Cash App in v1 — the universal link works on both iOS and Android via the Cash App's app-link handler.

### Zelle / PayPal / Cash / Other / null

**No URI is built.** Tapping **Settle Up** opens the manual `SettleUpFallbackSheet` with **Copy amount** + **Copy handle** + **Mark paid in event budget** buttons (`LED-FALL-01`).

### Handle validation

The handle must match `^[A-Za-z0-9_-]{1,30}$`. Invalid handles (spaces, special chars, > 30 chars):
- In the event-scoped Settle sheet: snackbar **That payment handle looks invalid**, no launch.
- In the cross-event ledger: silently falls back to the manual sheet.

### Note length

The Venmo `note` parameter is truncated to 60 chars by `_truncateNote`.

---

## Appendix D — Known v1 limitations

This is the canonical list of intentional gaps. **Do NOT file bugs for any item below.** If a tester is unsure whether something is a bug or a known limitation, ping the dev team before filing.

### UI / UX

- **Notifications row in Profile is a deliberate no-op** — the tile is visible to reserve the slot for future notification-preference UI. The tap is bound to `() {}` in `profile_screen.dart`. (`PROF-NOTIF-01`)
- **Singular / plural section headers** — "1 UPCOMING EVENTS" uses the plural template; this is an i18n caveat documented in `HOME-LIST-01`. ICU pluralization is deferred to a future round.
- **Onboarding "Get Started" copy and most event-scoped page snackbars are still hardcoded English** — the i18n promotion sweep (Phase 5 of `constants-and-polish`) is scoped to `presentation/` widget trees only; deeper rounds are deferred.
- **Relative timestamp abbreviations** (`m` / `h` / `d` / `yesterday` / `now`) are English-only. Documented in `INBOX-TIME-01`.
- **Rail sign-out skips the bottom-sheet confirmation** that bottom-nav sign-out shows — by design (`SHELL-OUT-01`).
- **iPhone SE small-screen (320 px) + 200% Dynamic Type** may produce occasional RenderFlex warnings on a few tiles; capture with a screenshot if seen but don't block ship (`A11Y-OVR-01`).
- **Web Safari Private Mode** disables IndexedDB; Firestore persistence falls back to memory-only. Test in normal browsing mode unless explicitly verifying private-mode behavior.

### Auth

- **Apple sign-in is not surfaced on Android** — the Apple Auth Provider requires native iOS context. Web + iOS phone are the only Apple surfaces in v1 (`AUTH-APPLE-01`).
- **Web uses `signInWithPopup`, not `signInWithProvider`** — the popup-blocked error path is web-only (`AUTH-WEB-01`).

### Settle Up / payments

- **v1 has deep-link support for VENMO and CASH APP ONLY** — Zelle / PayPal / Cash / Other / null `paymentMethod` ALL fall through to the manual fallback sheet (`LED-FALL-01`). This is by design; deeper provider support is post-v1.

### Sync / push

- **Web push notifications are NOT in v1 scope** — `firebase_messaging` web is not configured. Mark `§7.5` rows N/A for Web Chrome / Web Safari.

### Misc

- **The pre-existing `TableMigration` analyzer warning** in `lib/app/core/database/app_database.dart:172` is expected — not introduced by recent work. Don't report it.
- **`AppDurations` token file exists with no production callers** — it's forward-looking (Phase 4 of `constants-and-polish` deliberately left durations inline; no regression).
- **No `flutter_localizations` is wired in v1** — every label in the app is English. Non-English locale testing is out of scope.

---
