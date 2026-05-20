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

_Section pending — to be authored in Phase 2 of `ai_specs/v1-qa-handoff-guide-plan.md`._

Covers: Email sign-up + verification, Email sign-in, Google sign-in (provider sheet on phone, popup on web), Apple sign-in (iOS phone + web), suggest-provider snackbar, sign-out, delete account (destructive), web popup-blocked recovery.

## §2 Profile

_Section pending — to be authored in Phase 2._

Covers: Hero card, Edit Profile (display name, photo from gallery, photo from camera, payment method picker + handle), Privacy Dashboard, legal pages (Privacy Policy + Terms of Service), Notifications row (deliberate no-op), stats triplet (Events / Tasks / Owed).

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
