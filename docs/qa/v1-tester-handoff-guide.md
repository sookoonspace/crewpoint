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
