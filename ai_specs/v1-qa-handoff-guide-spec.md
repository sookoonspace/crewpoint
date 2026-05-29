<goal>
Produce a single self-contained QA handoff guide that walks an internal tester through every feature shipped in CrewPoint v1, with step-by-step instructions, expected vs actual outcomes, edge cases to try, device + browser matrix coverage, and a copyable bug-report template.

The guide exists so the dev team can hand a TestFlight / Android internal-track build to an internal tester (technical or not), point at one markdown file, and walk away — confident the tester can exercise every flow, hit the named edge cases, and report findings in a consistent format without back-and-forth questions.

Primary readers:
- **Non-technical internal testers** (product / ops / friends-and-family) who follow the test steps in plain language.
- **Technical QA / dev testers** who can also use the appendix (logs, Firebase console pointers, deep-link verification, dev-mode tips).

The guide is NOT a marketing tour. It is a structured, comprehensive test plan that biases toward catching bugs.
</goal>

<background>
Tech stack and surface area to cover:
- Flutter app (iOS / Android / Web). Material 3 + custom design language (cream surface, sage / charcoal / terracotta accents).
- Backend: Firebase (Auth, Firestore, Cloud Functions, Storage, Messaging).
- Local DB: Drift (sqlite3) with reactive task-count streams.
- State: Riverpod 3.
- Navigation: go_router; responsive shell switches between bottom `NavigationBar` (< 840 px) and `NavigationRail` (≥ 840 px).
- Auth providers wired: Google, Apple, Email/Password (+ email verification, sign-out, account deletion).

Test environment (confirmed):
- **Staging Firebase project** (separate from production). Test accounts and events can be wiped freely between sessions.
- **TestFlight build (iOS)** + **Android internal-track build**. No local builds required.

Device matrix (confirmed):
- iPhone (phone-width, including iPhone SE small-screen at 320 px).
- Android phone (12+).
- iPad / Android tablet (≥ 840 px → rail layout).
- Web (Chrome + Safari).

Bug reporting (confirmed):
- Lightweight: a copyable template the tester pastes into a **shared spreadsheet or email** to the dev team. No issue tracker integration.

Files to examine when drafting the guide:
- @lib/app/core/router/app_router.dart — every route the tester can reach.
- @lib/app/features/*/presentation/ — every screen.
- @lib/app/core/widgets/responsive_shell.dart — bar vs rail breakpoint.
- @lib/app/core/i18n/app_strings.dart — exact English copy the tester will see (test steps must quote real labels, not paraphrase).
- @ai_specs/*-spec.md — every shipped spec is the source of truth for what v1 includes.

Output location of the deliverable (the actual guide):
`docs/qa/v1-tester-handoff-guide.md` (create the `docs/qa/` directory).

Output location of this specification:
`ai_specs/v1-qa-handoff-guide-spec.md`.

The guide is a deliverable for testers, not internal planning — so it lives in `docs/qa/`, not `ai_specs/`. The spec describing the guide lives in `ai_specs/`.
</background>

<user_flows>
Primary flow (the tester's day):
1. Tester opens the email from the dev team containing the link to `docs/qa/v1-tester-handoff-guide.md` (rendered on GitHub) + the TestFlight / Play internal-track invite + a staging test-account credential.
2. Tester reads "Pre-flight setup" (≤ 5 minutes), installs the build, signs in.
3. Tester picks any section (sections are independent — must not require prior steps from another section unless explicitly noted).
4. For each numbered test, tester reads pre-conditions, performs steps, compares observed result to "Expected", and tries 1-2 listed edge cases.
5. When something diverges from "Expected", tester pastes the bug-report template into the shared spreadsheet + adds a screenshot.
6. When done, tester records device + build number in a sign-off row at the bottom of the spreadsheet.

Alternative flows:
- **Technical tester**: skips to the appendix first, sets up `adb logcat` / Xcode console / browser DevTools, then runs the same tests with logs flowing. Reports include relevant log snippets.
- **Resumed session**: tester closes the app mid-flow and reopens. Guide must explicitly call out which tests have a "resume from cold start" sub-step.
- **Cross-device tester**: same tester runs the same test on iPhone then Android then web. Guide must include a device-coverage matrix at the top so each test ID can be ticked off per device.

Error / friction flows the guide must address:
- Staging Firebase project is empty on first sign-in — guide must clarify which tests need a seeded second account (e.g., "settle up" needs a counterparty with a `paymentMethod`).
- Email-verification link goes to a different device — guide explains that the verify-banner re-checks on app foreground.
- Deep links to payment apps (Venmo etc.) fail when the app isn't installed — guide must say: this is expected, the fallback sheet appears, mark it as PASS.
- Web build doesn't support `signInWithProvider` — guide must say: Google/Apple use a popup on web (different UX); test both.
- TestFlight build number drift: guide includes a "How to read the build number" snippet so testers don't report stale-build bugs.
</user_flows>

<requirements>
**Functional — guide structure:**

1. **Single file** at `docs/qa/v1-tester-handoff-guide.md`. Renders cleanly on GitHub (mobile + desktop browser). No external assets required beyond optional screenshots in `docs/qa/screenshots/`.

2. **Top-of-file orientation block** (in this order):
   - One-paragraph "What you're testing" — what CrewPoint v1 is, in plain language.
   - "How to use this guide" — pick any section; tests are independent; use the bug-report template at the bottom.
   - **Build info block** — TestFlight invite link placeholder, Android internal-track link placeholder, staging-Firebase test account placeholder ("ask the dev team for credentials"), build number expectation. The actual on-device format (from `ProfileStrings.appVersionLabel` → renders as `CrewPoint v<version> (<build>)`, e.g. `CrewPoint v1.0.0 (1)`) must be quoted exactly so testers compare apples to apples. The block tells the tester: "Open **Profile** → scroll to the bottom → confirm the version footer matches what the dev team gave you. If it's older, report immediately — do not test."
   - **Device coverage matrix** — a checkbox table the tester ticks off per device. Columns: iPhone phone, Android phone, iPad/Android tablet (rail), Web Chrome, Web Safari. Rows: each major test section.

3. **Section structure** — the guide must include, in this order, sections for every v1 surface:
   - **§0 Pre-flight setup + onboarding**: Install TestFlight or Android internal-track build. On first launch, the **5-page onboarding** appears: Welcome → Plan Events Together → Stay in Sync → Split Costs Fairly → Privacy (with a data opt-in toggle the tester must exercise both ways) → terracotta **Get Started** button on the final page. Test forward swipe + page indicator dots + back swipe. Verify the privacy opt-in persists per the actual contract (drafter must read `lib/app/features/onboarding/presentation/onboarding_screen.dart` + `lib/app/features/onboarding/application/onboarding_provider.dart` and document the observed behavior — onboarding complete is a one-shot per device via secure storage key `onboarding_complete`).
   - **§1 Authentication**: Email sign-up + verification, Email sign-in, Google sign-in (provider sheet on phone via `signInWithProvider`; popup on web via `signInWithPopup`), Apple sign-in (provider sheet on iOS phone; popup on web; not surfaced on Android because Apple Auth Provider requires iOS native context), suggest-provider snackbar (signing in with email that's actually a Google account), sign-out, delete account (destructive — exercise on a throwaway account, fires the `deleteUserAccount` cloud function).
   - **§2 Profile**: Hero card, edit profile (display name, photo from gallery, photo from camera), payment method picker + handle, Privacy Dashboard, legal pages (Privacy Policy / Terms of Service markdown renderer), Notifications row (currently no-op — note this), stats triplet values.
   - **§3 Dashboard (Home)**: Greeting (morning / afternoon / evening based on device clock), date subtitle, Upcoming / Past pill split (equalWidth: true — both pills 50/50), Create Event CTA, Join Event tooltip, empty state, error state retry.
   - **§4 Event lifecycle**: Create event (drafter must verify actual form fields against `create_event_screen.dart` — at minimum: title, optional description, start date, optional end date, event type emoji selector; note that currency may default to USD without a UI selector — drop "currency selector" from the test step if no selector exists), Edit event (owner-only — verify a non-owner cannot reach the settings gear), Archive event (sets `isArchived: true`; verify the actual user-visible effect by reading `event_dashboard_screen.dart:559` — note that Upcoming/Past is partitioned by date, not by archive state, so archived events do NOT automatically move between filters), Leave event (member-not-owner flow), Delete event (owner-only destructive — fires the `deleteEvent` cloud function), Members screen (count badge, add member by code, remove member, regenerate code, copy code to clipboard, **Promote to admin** (owner-only — verify "Promoted to admin" snackbar; promoted user now appears with "Admin" role label), **Demote admin** (owner-only — verify "Demoted to member" snackbar; demoted user retains member access).

     **Role permission matrix** (owner / admin / member × actions). Add this as a single table at the head of §4 and have testers tick off each cell as they verify. Actions to cover at minimum: edit event details, archive event, delete event, regenerate invite code, remove member, promote member to admin, demote admin to member, edit any task (vs only own / assigned), delete any task, change any task status (vs only own / assigned via `Only the assignee or an admin can change this` snackbar), edit any expense, delete any expense, view Privacy Dashboard.
   - **§5 Tasks — event-scoped**: Create task (title, description, assignee, priority, due date, budget estimate, checklist items), Status cycle (todo → doing → done; verify unauthorized non-assignee gets the "Only the assignee or an admin can change this" snackbar), Edit task, Duplicate task (verify " (copy)" suffix + checklist copied), Delete task (owner/creator only), Checklist editor (add up to 25 items, edit text, delete), Filter bar (search, status chips, Mine / Overdue / HasBudget toggles), Sort (Due date / Priority / Created / Title), Group (Status / Assignee / Due window), Group headers, Empty states (no tasks, no matches), Export PDF tooltip (verify the file downloads / shares).
   - **§6 My Tasks — cross-event**: All / To Do / Doing / Done segmented filter (default scroll layout), independent Overdue badge toggle (with count), progress summary strip, grouped list by event, adaptive empty states (no tasks vs no events), sign-in-required state.
   - **§7 Chat — event-scoped**: Send message, urgent / critical-alert modal (verify the urgent icon + terracotta accent), Settlement dispute sheet (only appears on settlement messages), Send-failed inline error + retry, empty state.
   - **§7.5 Push notifications + deep-link**: V1 wires FCM end-to-end via `lib/app/core/services/{fcm_service,fcm_handler,fcm_gateway}.dart` plus the `onUrgentMessageCreated` cloud function. The function fires a push to all event members (minus the sender) whenever a message is flagged `isHighPriority`, with payload `data.deepLink: /dashboard/event/{eventId}/chat`. Tests:
     - **Permission grant on first run** — verify the iOS / Android system prompt appears at the right moment and the result is honored (no grant → notifications never arrive; grant → token is written to `users/{uid}.fcmTokens`).
     - **Urgent message → push arrives** — from a second staging account, open the event chat, send a critical-alert message. On the first account's device (signed out of the app or app backgrounded), the push notification arrives within ~30 s.
     - **Tap from background** — tap the notification while the app is in background → app foregrounds + deep-links to the correct event chat.
     - **Tap from killed state** — fully terminate the app, tap the notification → app cold-starts and deep-links to the correct event chat.
     - **Non-urgent messages do NOT trigger a push** — send a normal (non-critical) message; no notification arrives on the recipient's device.
     - **Web** — push notifications are not in v1 scope for web (`firebase_messaging` web support is limited and not configured). Tester verifies no errors on web, then marks this section N/A for web.
   - **§8 Chat inbox — cross-event**: Inbox app bar, conversation tile rows (verify they are wrapped in elevated Cards), unread pill (cap at 99+), URGENT badge + terracotta highlight, last-message preview with "You: ..." prefix when sender is current user, timestamp formatting (now / Nm / Nh / Yesterday / Nd / Mon D), tap → opens event chat, adaptive empty states.
   - **§9 Budget — event-scoped**: Hero (event budget total + remaining), Add expense (amount, description, splits with member checkboxes, optional receipt photo, donation flag, payment flag), Edit expense (owner/creator only), Delete expense, Receipt viewer (tap photo → full-screen), Export PDF tooltip, Export CSV tooltip, snackbar copy ("Copied — paste it where you settle").
   - **§10 Budget ledger — cross-event**: Hero BalanceTile (You are owed / You owe split + multi-currency disclaimer when applicable), Debts breakdown (DebtTile cards, Settle Up button per debt, "all settled" chip when zero), Recent expenses feed (RecentExpenseTile cards), Settle Up deep-link paths — exercise all four:
     - Venmo (paymentMethod = `venmo`) → opens `venmo://` URI on iOS/Android; tester confirms Venmo opens with prefilled amount + handle.
     - Cash App (`cashapp`) → opens `https://cash.app/$handle/amount`.
     - Zelle (`zelle`) → falls back to the sheet (no universal Zelle URI).
     - PayPal (`paypal`) → opens `https://paypal.me/handle/amount`.
     - Fallback sheet (no paymentMethod set, or `other`, or `cash`) → Copy amount + Copy handle + Mark paid.
   - **§11 Responsive shell**: Resize the simulator / browser through 840 px and observe the bottom NavigationBar → NavigationRail transition. Verify route stack survives the resize. On rail, confirm the sign-out trailing button works.
   - **§12 Accessibility**: Dynamic Type at 200% on every primary tab — verify no overflow and all text readable. VoiceOver / TalkBack pass on Dashboard + Tasks tabs (semantic labels announced for ProgressRing, urgent badge, status badges). 320 px viewport stress (Safari responsive mode) — verify ConversationTile + EventTile + DebtTile + TaskTile do not visually overflow.
   - **§13 Offline + sync**: Airplane-mode the device while on Tasks tab. Toggle a task status. Verify the "Will sync when online" Wi-Fi-off badge appears on the task detail. Re-enable network and verify status syncs (≤ 10 s after reconnect).
   - **§14 Bug-report template** (the copyable block — see requirement 6 below).

4. **Per-test format** — every numbered test must have:
   - `Test ID` in the form `<SECTION>-<MNEMONIC>-<NN>` (e.g., `EV-CRE-01` for "Event — Create — first test").
   - `Pre-conditions` — bulleted state required before starting (e.g., "Signed in", "At least 1 event exists").
   - `Steps` — numbered list, each step a single action. Quote real UI labels from `app_strings.dart` so the tester sees the same text on screen. Use `**bold**` for the literal label and `_italics_` for the user's input.
   - `Expected` — bullet list of observable outcomes after the steps. Use absolutes ("Snackbar **Event created** appears", "Tile shows progress ring **3/6**"). No "should" / "may" hedging.
   - `Edge cases to try` — 1-3 micro-tests appended as sub-bullets (e.g., "Cancel mid-form", "Submit with title at exactly 120 chars", "Submit while offline").
   - `Known limitations` — optional bullet, only if a behavior is intentional-but-surprising (e.g., "Web does not support `signInWithProvider`; uses popup — different UX").
   - `Devices` — pills/badges naming the device(s) where this test is meaningful (e.g., `iOS only`, `Web only`, `All devices`).

5. **Device coverage matrix table** at the top of the file. Format:
   ```
   | Section | iPhone | Android | Tablet rail | Web Chrome | Web Safari |
   |---------|:------:|:-------:|:-----------:|:----------:|:----------:|
   | §1 Auth |   ☐    |   ☐     |     ☐       |     ☐      |     ☐      |
   | ...     |  ...   |  ...    |    ...      |    ...     |    ...     |
   ```
   The tester ticks off each cell as they complete the section on that device. Web Safari is its own column because OAuth popup + IndexedDB behave differently from Chrome.

6. **Bug-report template** — copyable block at `§14`. Tester pastes once per bug into the shared spreadsheet / email:
   ```
   BUG REPORT
   ----------
   Date / Time:      <when you observed it>
   Tester name:      <your name>
   Device:           <e.g. iPhone 15 Pro, iOS 18.2>
   App build:        <from Profile → version footer>
   Network:          <Wi-Fi / cellular / airplane>

   Test ID:          <e.g. EV-CRE-03 — copy from the guide>
   Steps to reproduce:
     1. ...
     2. ...
     3. ...

   Expected:         <what the guide said should happen>
   Actual:           <what really happened>

   Frequency:        <every time / intermittent / once>
   Severity:         <blocker / major / minor / cosmetic>

   Attachments:      <screenshot file names, screen recording link if any>
   Notes:            <anything else — recent actions, suspected trigger>
   ```

**Functional — content quality:**

7. **Quote real labels.** Every literal in the guide that names a UI element must match `app_strings.dart` exactly. If the guide says the tester should tap **Create Event**, the button must actually read "Create Event" in the app. Reviewer enforces this by spot-checking 5 labels picked at random.

8. **No phantom features.** Every test must exercise a feature that exists on the current `main` branch. If a feature is partially shipped, list it under `Known limitations` instead of testing it.

9. **Sequence the destructive tests last.** Delete-account and delete-event tests live at the end of their sections, so a tester who exits mid-section doesn't accidentally nuke the staging data they were about to use.

10. **Time estimates.** Each section header includes an approximate duration (e.g., "§4 Event lifecycle — ~25 min"). Total document expected to fit in a 2-3 hour test session per device.

11. **Screenshots are optional, not required.** The guide may reference `docs/qa/screenshots/<test-id>.png` paths but must read clearly even without them. Screenshots are nice-to-have; the test steps must work standalone.

**Functional — appendix (technical):**

12. **Appendix A — Reading device logs.** One short subsection per platform:
   - iOS: open Xcode → Window → Devices and Simulators → select phone → click "Open Console".
   - Android: `flutter logs` (preferred — connects to the attached device and shows Flutter output cleanly) OR `adb logcat *:E flutter:V` to see Flutter errors plus verbose flutter-tagged output. Note: `grep -i crewpoint` returns nothing because Flutter log tags do not include the app package name — the relevant tag is `flutter` plus any per-call `developer.log(name: ...)` value (see "What to look for" below).
   - Web: DevTools console + Network tab.
   - What to look for: red exception traces, Firebase 4xx/5xx responses, `developer.log` lines tagged `chat.inbox` / `budget.ledger` / `fcm` / `tasks.myTasks` (grep these tag names in iOS Console or filter by them in Android Studio's Logcat).

13. **Appendix B — Firebase staging console.** Link placeholder + a short "what to check": Authentication users, Firestore `events/`, `events/{id}/tasks/`, `events/{id}/messages/`, `events/{id}/expenses/`, `users/`. Note: testers without console access should skip this appendix and report observed app behavior only.

14. **Appendix C — Settle Up deep-link reference.** Spell out, per provider, BOTH the native-scheme URI AND the https web-fallback URI, plus the rule the app uses to pick between them. Source of truth: `lib/app/features/budget/data/pay_link_builder.dart` — quote this exact path; the drafter must read it before writing the appendix. At minimum document:
    - Venmo: `venmo://paycharge?txn=pay&recipients=<handle>&amount=<x.xx>&note=<...>` (native) + `https://venmo.com/<handle>?txn=pay&amount=...&note=...` (web fallback).
    - Cash App: `https://cash.app/$<handle>/<amount>` (universal link — no separate native scheme).
    - Zelle: no universal URI scheme — the controller always falls back to the in-app sheet.
    - PayPal: `https://paypal.me/<handle>/<amount>`.

15. **Appendix D — Known v1 limitations.** A single list of intentional gaps the tester should NOT report as bugs:
   - Notifications row in Profile is a no-op tile (the tap is bound to `() {}` in `profile_screen.dart`). It is visible on purpose so the slot is reserved; tapping does nothing.
   - Onboarding strings ("Get Started") and event-page snackbars are still hardcoded English (deferred to a future i18n round).
   - Relative timestamp abbreviations (`m`/`h`/`d`/`yesterday`) are English-only.
   - `Duration(...)` constants (animation durations, snackbar duration) live inline; an `AppDurations` token file exists but has no production callers yet — not a regression.
   - The pre-existing `TableMigration` analyzer warning is expected (not introduced by recent work).
   - Translated strings for non-English locales — out of scope (`flutter_localizations` not wired yet).
   - Web Safari Private Mode disables IndexedDB; Firestore persistence falls back to memory-only. Test in normal browsing mode unless explicitly verifying private-mode behavior.

**Error Handling:**

16. **Tester encounters a feature that doesn't exist as described.** Guide says: "Stop, flag the test ID in the bug report under `Notes: \"Feature drift from guide — guide describes <X> but app shows <Y>\"`." This catches stale-guide / stale-build mismatches early.

17. **Tester cannot complete a pre-condition.** Each test's `Pre-conditions` block must name a recovery action (e.g., "If no event exists yet, complete `EV-CRE-01` first").

18. **Sign-in fails repeatedly.** Auth tests include a `Recovery` sub-bullet: "If sign-in fails > 3 times in a row, capture the snackbar text and the Auth console error code, then ask the dev team — do not keep retrying (rate-limit).".

**Edge Cases (the guide must call these out explicitly):**

19. **iPhone SE small-screen (320 px width).** Dedicated mini-section under §12 Accessibility: open the Tasks / Chat / Budget tabs on iPhone SE (1st gen) or in Safari responsive mode at 320 px width. Verify URGENT badge + long event title in chat row do not overflow. Verify Dashboard's Upcoming/Past pills still split 50/50 (equalWidth-mode adaptive fallback).

20. **Long event titles + long member display names.** Specific test (`UI-OVR-01`) asks the tester to create an event with a 60-character title and verify it ellipses correctly on every surface (Dashboard tile, Chat inbox row, Budget ledger debts, member list).

21. **Multi-currency disclaimer.** Create two events with different currencies (USD + EUR), each with a small expense. Open Budget tab. Verify the disclaimer "Totals are approximate when events use different currencies." appears below the hero.

21a. **Greeting first-name edge cases.** Test ID `HOME-GRT-02`. Set the display name in Edit Profile to each of: `Émile 😀`, `A`, `Mary-Anne Schmidt-Williams`, `<empty string>`, `   ` (whitespace only). For each, return to Home and verify the greeting renders gracefully without exception or layout overflow. Greeting routes through `greetingFirstName(displayName)` in `lib/app/features/dashboard/domain/greeting_first_name.dart` — drafter should quote the file path so a technical tester can sanity-check the function.

22. **Settle Up with no paymentMethod set.** Counterparty profile has no payment method → tapping **Settle Up** opens the fallback sheet (Copy amount + Copy handle + Mark paid). Tester verifies the sheet, not the absence of an action.

23. **Resume from cold start mid-flow.** Specific test (`SYNC-RES-01`): create a task while offline, kill the app, restore network, reopen. Task should sync within 10 s without re-creation.

24. **Web popup blocking.** Web-only test: sign in with Google in a browser with popups blocked → expected: error snackbar with the wording from `ErrorStrings.popupBlocked` ("Pop-ups are blocked - please allow pop-ups for this site and try again."). Unblock popups, retry, succeed.

25. **Web does not support `signInWithProvider`.** Documented as a Known limitation, not a bug.

26. **Rail mode + breakpoint transition.** Resize Chrome from 1200 px → 700 px while on the Tasks tab. The nav switches bar → rail without losing the current task list scroll position. Verify by scrolling halfway down before the resize.

**Validation (of the guide itself — see `<validation>` below):**

27. **Self-test pass:** A reviewer who has never seen the app should be able to read the guide and execute every test in §1-§14 without asking the dev team a single question (clarifying questions about the staging credential or build link don't count; substantive product / flow questions do).

28. **Label spot-check:** 5 random labels picked from the guide must match `app_strings.dart` byte-for-byte.

29. **Time-boxing:** Each section's stated duration is within 50% of a real timing measurement on at least one device.
</requirements>

<boundaries>
Edge cases the guide must address (see also requirements 19-26):
- **Small-screen overflow** (320 px): Dedicated audit section; ConversationTile + EventTile + DebtTile + TaskTile must not visually overflow.
- **Rail mode transition**: scroll position survives breakpoint crossing.
- **Offline + sync**: airplane mode → pending writes → reconnect within 10 s.
- **Web OAuth popup**: blocked vs unblocked.
- **Multi-currency events**: disclaimer appears.
- **Settle Up missing paymentMethod**: fallback sheet.

Error scenarios the guide must cover:
- **Sign-in repeated failure**: Recovery sub-bullet; do not keep retrying past 3 attempts.
- **Network failure mid-write**: confirm "Will sync when online" badge appears on task detail.
- **Pop-up blocked (web)**: snackbar copy from `ErrorStrings.popupBlocked`.
- **Deep link to uninstalled payment app**: fallback sheet appears — this is PASS, not a bug.
- **Permission denied for non-owner**: snackbar copy from `Only the assignee or an admin can change this`.

Limits the guide must state:
- Task title max 120 chars (validator copy from `create_task_screen.dart`).
- Checklist items max 25 per task (`ChecklistEditor.maxItems`).
- Unread pill caps at `99+`.
- Settle Up deep link requires non-empty `paymentMethod` on the counterparty's user doc.
- Email-password sign-up requires password ≥ 6 characters (`AuthStrings.validatorPasswordTooShort`).

Explicitly out of scope for the guide (do not write tests for these):
- Production Firebase data. The guide explicitly targets the staging project.
- Source-code inspection beyond Appendices A-C. The guide is for testers, not auditors.
- Performance benchmarking (frames-per-second, cold-start time). Tester reports gross perception ("felt sluggish"), not measured timings.
- Cloud Function internals. Tester verifies the user-facing outcome, not the function's internal state.
- Non-English locales — `flutter_localizations` is not wired in v1; English labels only.
- Push notification delivery. `firebase_messaging` is wired but no specific notification flows are part of v1; mention in Known Limitations.
- Web Safari Private Mode + Firestore persistence quirks (IndexedDB unavailable) — out of scope; document as limitation if encountered.
</boundaries>

<implementation>
Files to create:
- `docs/qa/v1-tester-handoff-guide.md` — the deliverable.
- `docs/qa/screenshots/.gitkeep` — placeholder so the directory exists for optional screenshot drops.

Files to read while drafting (sources of truth):
- `lib/app/core/i18n/app_strings.dart` — every literal label quoted by the guide.
- `lib/app/core/router/app_router.dart` — full route inventory.
- `lib/app/features/auth/presentation/**` — auth flows + provider sheet behavior.
- `lib/app/features/dashboard/presentation/**` — Home tab + event lifecycle.
- `lib/app/features/tasks/presentation/**` — both event-scoped and cross-event Tasks.
- `lib/app/features/chat/presentation/**` — both event-scoped and inbox Chat.
- `lib/app/features/budget/presentation/**` + `lib/app/features/budget/data/pay_link_builder.dart` — Budget + Settle Up deep links (note: `data/`, not `application/`).
- `lib/app/core/services/{fcm_service,fcm_handler,fcm_gateway}.dart` + `functions/src/events/onUrgentMessageCreated.ts` — FCM push notification wiring for §7.5.
- `lib/app/features/onboarding/presentation/onboarding_screen.dart` + `lib/app/features/onboarding/application/onboarding_provider.dart` — onboarding flow + `onboarding_complete` secure-storage key for §0.
- `lib/app/features/dashboard/presentation/member_management_screen.dart` + `functions/src/events/{promoteToAdmin,demoteAdmin}.ts` — admin role transitions for §4.
- `lib/app/features/dashboard/domain/greeting_first_name.dart` — greeting parsing for `HOME-GRT-02`.
- `lib/app/features/dashboard/domain/models/event.dart` — `isOwner`/`isAdmin`/`isMember` role checks driving the §4 permission matrix.
- `lib/app/features/profile/presentation/**` — Profile, edit, delete, privacy dashboard, legal pages.
- `lib/app/core/widgets/responsive_shell.dart` — rail/bar breakpoint = 840 px.
- `ai_specs/*-spec.md` — the prior specs anchor the v1 scope.

Conventions to follow:
- Use Markdown with GitHub-flavored extensions (tables, task lists `- [ ]`, code fences). No HTML.
- Heading hierarchy: `# CrewPoint v1 — Tester Handoff Guide` (H1, once), `## §<N> <Section name>` (H2 per section), `### <Test ID> — <One-line description>` (H3 per test), `**Pre-conditions** / **Steps** / **Expected** / **Edge cases to try** / **Devices**` as bold labels followed by lists.
- Inline literal app labels in **bold**; user input in _italics_; technical paths / commands in `monospace`.
- Test IDs are stable. Section mnemonics: `AUTH`, `PROF`, `HOME`, `EV` (event lifecycle), `TASK`, `MYT` (My Tasks), `CHAT`, `INBOX`, `BUD` (event budget), `LED` (ledger), `SHELL`, `A11Y`, `SYNC`, `UI` (UI / overflow).
- Time estimates next to each section header.
- One blank line between every test for readability.

What to avoid:
- Do not paraphrase UI labels. Quote them exactly. A guide that says "tap the Add button" when the app shows **Create Event** will produce false bug reports.
- Do not include speculative or in-progress features. If a feature is half-built, list it under §Known limitations, not in a test.
- Do not include performance assertions ("must load in < 200 ms") — `flutter test` doesn't measure that and testers can't either, reliably. State only observable user-facing outcomes.
- Do not nest tests inside other tests. Each test is self-contained; `Pre-conditions` names a recovery action if state is needed.
- Do not write a wall of prose. The guide is a checklist with structured tests; testers scan, they don't read.
- Do not include screenshots inline as binary blobs in the markdown. If screenshots are added, reference them by relative path (`![EV-CRE-01 expected state](screenshots/ev-cre-01.png)`).
</implementation>

<validation>
Baseline validation outcomes (the guide is documentation, not code — so "validation" means quality checks, not test runs):

**Logic / content correctness:**
- Label spot-check: Pick 5 random literal labels quoted in the guide. Each one must match `app_strings.dart` byte-for-byte. If any drifts, fix the guide before publishing.
- Scope coverage: cross-reference every shipped `ai_specs/*-spec.md` with the guide's table of contents. Every spec must be represented by at least one test section in the guide. Missing surfaces are blocking.
- No phantom features: pick 5 random tests, grep the codebase for the feature each one exercises. If any test names a feature that doesn't exist, delete or move the test under `Known limitations`.

**UI / behavior verification (during the dev-team dry-run, before handoff):**
- Dry-run the entire guide on one device (iPhone phone width) end to end. Total time should be 2-3 hours.
- Update each section's `~Nmin` estimate based on observed timing within ±50% tolerance.
- Update the device coverage matrix template with any tests that turn out to be platform-specific (e.g., Apple sign-in is iOS-only on phone, web popup on browsers).
- Confirm at least one settler-side test data setup exists in the staging Firebase project (a second user account with `paymentMethod: venmo` and a populated `paymentHandle`).

**Critical journeys covered (must explicitly exist as tests in the guide):**
- Sign up new user → verify email → create event → invite second user → second user joins → both see event.
- Create task → assign → other user changes status → urgent push (Cloud Function-driven, if wired) → task detail reflects change.
- Owner adds expense → splits with both users → ledger shows debt → counterparty taps Settle Up → deep link or fallback fires.
- Create critical alert in chat → URGENT badge surfaces in inbox → tap → opens event chat → other user marks read.

**Tester-facing self-test:**
- Hand the draft guide + a TestFlight invite + staging credentials to one person inside the team who has not contributed to the v1 work. Ask them to execute §0 + §1 + one randomly-chosen section. Capture every question they ask and classify each one:
  - **Critical question** = blocks the tester from completing a step (ambiguous instruction, missing prerequisite, broken link, wrong label). Each critical question is a guide bug — patch and re-run.
  - **Non-critical clarification** = preference / curiosity / out-of-scope ("why does this work this way?"). Track these as polish items for v1.1 of the guide; they do not block sign-off.
- Sign-off threshold: **zero critical questions on the second dry-run.** Non-critical clarifications may remain.

**No-code test types do not apply** (TDD / robot tests / widget tests). This deliverable is a markdown document; the validation gates are content review + dry-run, not automated test coverage. The guide REFERENCES the existing 641-test suite (analyzer + custom_lint + flutter test) as the developer-side green gate the tester does not need to re-run.

**Cross-device explicit matrix:**
- The device coverage matrix at the top of the guide enumerates which tests must be repeated on which device. Default: every § runs on every device. Exceptions explicitly called out in each test's `Devices` line (e.g., Apple sign-in on phone is iOS-only; web popup tests are web-only; rail mode is tablet/web-only).

**No screenshots required for V1 sign-off.** Optional screenshots in `docs/qa/screenshots/` may be added later; the guide must read clearly without them.
</validation>

<done_when>
1. `docs/qa/v1-tester-handoff-guide.md` exists, opens cleanly in a GitHub markdown preview, and the table of contents links resolve.
2. `docs/qa/screenshots/.gitkeep` is committed so the directory exists for future screenshot drops.
3. The guide contains all §0-§14 sections in the order listed under requirement 3.
4. Every shipped `ai_specs/*-spec.md` surface is covered by at least one test in the guide.
5. The device coverage matrix appears at the top, with one row per section and five device columns.
6. The bug-report template appears verbatim at §14 and is copy-pasteable as a single code block.
7. Each test has the required fields (Test ID, Pre-conditions, Steps, Expected, Edge cases, Devices).
8. Label spot-check passes (5 random labels match `app_strings.dart`).
9. Phantom-feature audit passes (5 random tests reference real code paths).
10. One dry-run on iPhone phone width has been completed and section time estimates updated.
11. Tester-facing self-test on one non-contributing team member yields zero substantive questions on the second pass.
12. The Known Limitations list (Appendix D) is complete and matches the actual v1 surface — no surprises.
13. `git status` is clean after committing the guide and the empty screenshots directory.
</done_when>
