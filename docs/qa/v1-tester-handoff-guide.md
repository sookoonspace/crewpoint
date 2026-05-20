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

_Section pending — to be authored in Phase 3._

Covers: greeting, Upcoming / Past pill split, Create Event CTA, Join Event tooltip, empty state, error state retry, greeting first-name edge cases.

## §4 Event lifecycle

_Section pending — to be authored in Phase 3._

Covers: **Role permission matrix** (owner / admin / member), Create event, Edit event, Archive event, Leave event, Delete event, Members screen, Promote to admin, Demote admin.

## §5 Tasks — event-scoped

_Section pending — to be authored in Phase 4._

Covers: Create task, status cycle, edit, duplicate, delete, checklist editor, filter bar, sort, group, export PDF, validators, unauthorized-status snackbar.

## §6 My Tasks — cross-event

_Section pending — to be authored in Phase 4._

Covers: All / To Do / Doing / Done segmented filter, Overdue badge toggle, progress summary, grouped list by event, adaptive empty states, sign-in-required state.

## §7 Chat — event-scoped

_Section pending — to be authored in Phase 5._

Covers: Send message, critical-alert modal, settlement dispute sheet, send-failed retry, empty state.

## §7.5 Push notifications + deep-link

_Section pending — to be authored in Phase 5._

Covers: Permission grant, urgent message → push arrives, tap from background, tap from killed state, non-urgent silent, web N/A.

## §8 Chat inbox — cross-event

_Section pending — to be authored in Phase 5._

Covers: Inbox app bar, ConversationTile cards, unread pill, URGENT badge, last-message preview, timestamp formatting, tap to open, adaptive empty states.

## §9 Budget — event-scoped

_Section pending — to be authored in Phase 6._

Covers: Add expense, edit, delete, receipt viewer, splits, payment expenses, PDF export, CSV export.

## §10 Budget ledger — cross-event

_Section pending — to be authored in Phase 6._

Covers: BalanceTile owed/owe split, multi-currency disclaimer, debts breakdown, **Settle Up — 4 deep-link paths + fallback** (Venmo native + web, Cash App, Zelle fallback, PayPal), recent expenses feed.

## §11 Responsive shell

_Section pending — to be authored in Phase 7._

Covers: Bottom NavigationBar at < 840 px, NavigationRail at ≥ 840 px, route stack survives resize, sign-out tooltip on rail.

## §12 Accessibility

_Section pending — to be authored in Phase 7._

Covers: Dynamic Type 200% on every tab, VoiceOver / TalkBack on Dashboard + Tasks, 320 px overflow audit (ConversationTile + EventTile + DebtTile + TaskTile).

## §13 Offline + sync

_Section pending — to be authored in Phase 7._

Covers: Airplane-mode toggle, "Will sync when online" badge, sync on reconnect, cold-start resume after offline edit.

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

_Appendix pending — to be authored in Phase 7. Will cover: iOS Console (Window → Devices and Simulators), Android `flutter logs` and `adb logcat *:E flutter:V` (NOT `grep -i crewpoint` — Flutter doesn't tag logs with the app name), Web DevTools console + Network tab, and the `developer.log` tag list (`chat.inbox`, `budget.ledger`, `fcm`, `tasks.myTasks`)._

## Appendix B — Firebase staging console

_Appendix pending — to be authored in Phase 7._

## Appendix C — Settle Up deep-link reference

_Appendix pending — to be authored in Phase 7. Will cover both native scheme + web-fallback URIs per provider (Venmo, Cash App, Zelle, PayPal), sourced from `lib/app/features/budget/data/pay_link_builder.dart`._

## Appendix D — Known v1 limitations

_Appendix pending — to be authored in Phase 7. Will list intentional gaps the tester should NOT report as bugs._
