# v1 QA Handoff Guide — Implementation Plan

## Overview

Produce `docs/qa/v1-tester-handoff-guide.md` end-to-end. Pure markdown; no Dart changes. Drafter reads each cited source file before quoting labels.

**Spec**: `ai_specs/v1-qa-handoff-guide-spec.md` (read for full requirements — orientation block, per-test format, label spot-check rule, role-permission matrix, §7.5 push, etc.).

**Caller-injected directive (mandatory):** Orientation block in Phase 1 MUST include a Web App Staging URL placeholder (`<Insert Web Firebase Hosting URL here>`) alongside TestFlight + Android internal-track placeholders so web testers know where to land.

## Context

- **Deliverable type**: pure docs. Zero Dart code edits expected. New paths: `docs/qa/v1-tester-handoff-guide.md` + `docs/qa/screenshots/.gitkeep`.
- **Style contract deviation**: TDD / robot tests / `flutter test` do not apply (nothing to test). Verify step per phase = (a) `flutter analyze` smoke check (proves no accidental Dart touch), (b) label spot-check vs `lib/app/core/i18n/app_strings.dart`, (c) GitHub markdown render check (open the file on github.com after push or `gh pr view` and confirm rendering + ToC anchors resolve).
- **Sources of truth the drafter must open and quote from**:
  - `lib/app/core/i18n/app_strings.dart` — every UI label.
  - `lib/app/core/router/app_router.dart` — route inventory.
  - `lib/app/features/auth/data/firebase_auth_service.dart` — `signInWithProvider` vs `signInWithPopup` split.
  - `lib/app/features/onboarding/presentation/onboarding_screen.dart` + `lib/app/features/onboarding/application/onboarding_provider.dart` — 5-page flow + `onboarding_complete` storage key.
  - `lib/app/features/dashboard/presentation/{dashboard_screen,event_dashboard_screen,create_event_screen,member_management_screen}.dart` — dashboard, event lifecycle, archive (`isArchived` flag, not a Past filter), member admin promote/demote snackbars.
  - `lib/app/features/dashboard/domain/{models/event,greeting_first_name}.dart` — role checks + greeting parsing.
  - `lib/app/features/tasks/presentation/**` + `lib/app/features/tasks/application/**` — tasks (event-scoped + cross-event).
  - `lib/app/features/chat/presentation/**` + `lib/app/core/services/{fcm_service,fcm_handler,fcm_gateway}.dart` + `functions/src/events/onUrgentMessageCreated.ts` — chat + push.
  - `lib/app/features/budget/presentation/**` + `lib/app/features/budget/data/pay_link_builder.dart` (note `data/`, not `application/`) — budget + Settle Up URIs.
  - `lib/app/features/profile/presentation/**` — profile (incl. `appVersionLabel` format `CrewPoint v<v> (<b>)`).
  - `lib/app/core/widgets/responsive_shell.dart` — 840 px breakpoint.
  - `functions/src/index.ts` — confirmed exports: `deleteUserAccount`, `generateInviteCode`, `joinEvent`, `removeEventMember`, `deleteEvent`, `promoteToAdmin`, `demoteAdmin`, `markTaskComplete`, `disputeSettlement`, `onUrgentMessageCreated`.
- **Assumptions/Gaps**:
  - Currency selector existence in Create Event is uncertain — drafter resolves in Phase 3 by reading `create_event_screen.dart` and either documenting the field or dropping it from the test (per spec Minor #10 fix).
  - Archive event user-visible effect must be observed live in Phase 3 before the test is finalized (sets `isArchived: true`, but Upcoming/Past partitioning is date-based — actual visual treatment for archived events needs verification).
  - Staging Firebase project name + web hosting URL + TestFlight / Android internal-track invite links are unknown; the guide ships with placeholders the dev team fills before sending to testers.

## Plan

### Phase 1: Skeleton + orientation + §0 + bug template (thin vertical slice)

- **Goal**: full document structure in place; one complete section + bug template prove the format end-to-end.
- [ ] `docs/qa/v1-tester-handoff-guide.md` — H1 + ToC linking to every §0-§14 anchor (anchors as placeholders for sections filled in later phases).
- [ ] `docs/qa/screenshots/.gitkeep` — empty file so the directory exists.
- [ ] Top-of-file orientation block: "What you're testing" 1-paragraph; "How to use this guide" 3-bullet; **Build info block** with TestFlight invite placeholder + Android internal-track placeholder + **Web App Staging URL placeholder `<Insert Web Firebase Hosting URL here>`** + staging-Firebase test-account placeholder + version-footer expectation quoting actual format `CrewPoint v<version> (<build>)`.
- [ ] Device coverage matrix table (5 columns: iPhone, Android, Tablet rail, Web Chrome, Web Safari × 1 row per § as checkboxes).
- [ ] §0 Pre-flight setup + onboarding — install build, 5-page onboarding (Welcome / Plan Events Together / Stay in Sync / Split Costs Fairly / Privacy with `_dataOptIn` toggle / Get Started), swipe + indicator dots, `onboarding_complete` persistence verification.
- [ ] §14 Bug-report template — copy-pasteable code block per spec §14 (Date, Tester, Device, Build, Network, Test ID, Steps, Expected, Actual, Frequency, Severity, Attachments, Notes).
- [ ] Per-test format established: `Test ID` (`SECTION-MNEMONIC-NN`) + Pre-conditions + Steps + Expected + Edge cases + Devices.
- [ ] Add "~Nmin" duration estimate to each section header (initial guess; refined in Phase 7 dry-run).
- [ ] Label spot-check: every literal in §0 matches `app_strings.dart` byte-for-byte (drafter reads `_EnglishStrings`, `_EnglishAuthStrings`, related sub-objects).
- [ ] Verify: `flutter analyze` (smoke — confirms no Dart touch); manually open the file in GitHub preview / VS Code markdown preview and confirm ToC anchors resolve; bug template renders as one ` ``` ` block.

### Phase 2: §1 Authentication + §2 Profile

- **Goal**: every auth provider + sign-out + delete-account + profile surface covered.
- [ ] §1 Authentication tests: Email sign-up → email verification banner (`AuthStrings.verifyBannerTitle`), Email sign-in, Google sign-in (provider sheet on phone via `signInWithProvider`; popup on web via `signInWithPopup` — quote both code paths from `firebase_auth_service.dart:78-86`), Apple sign-in (iOS phone provider sheet + web popup; mark "not surfaced on Android" per `firebase_auth_service.dart:97-103`), suggest-provider snackbar (`AuthStrings.suggestProvider`), sign-out, delete account (fires `deleteUserAccount` cloud function).
- [ ] Auth recovery sub-bullet: ">3 sign-in failures → capture snackbar + error code, ask dev team, do not retry (rate-limit)".
- [ ] Web popup-blocked test (`AUTH-WEB-01`): block popups in browser → Google sign-in → expect `ErrorStrings.popupBlocked` snackbar "Pop-ups are blocked - please allow pop-ups for this site and try again."
- [ ] §2 Profile tests: Hero card (avatar + display name + email), Edit Profile (display name, photo from gallery, photo from camera, payment method picker + handle), Privacy Dashboard, legal markdown pages (Privacy Policy + Terms of Service), Notifications row (no-op tap — verify nothing happens, document under Known Limitations not as a bug), stats triplet (Events / Tasks / Owed) live values via `currentUserDocProvider` + `dashboardEventsProvider` + `myAssignedTasksProvider` + `globalBalanceLedgerProvider`.
- [ ] Drafter quotes every label from `_EnglishAuthStrings`, `_EnglishErrorStrings`, `_EnglishProfileStrings`.
- [ ] Verify: `flutter analyze` smoke; label spot-check 5 random quotes in §1+§2 against `app_strings.dart`; GitHub render check.

### Phase 3: §3 Dashboard + §4 Event lifecycle + role-permission matrix

- **Goal**: every event-lifecycle action covered including the often-missed admin role transitions; role matrix at top of §4.
- [ ] §3 Dashboard tests: Greeting + date subtitle (clock-driven morning / afternoon / evening), Upcoming / Past pills (`equalWidth: true` — verify both pills are 50/50 at standard width and fall back to scroll at 320 px with long i18n labels), Create Event CTA (label `Create Event`), Join Event tooltip (label `Join Event`), empty state (`DashboardStrings.noEventsTitle/Subtitle/joinWithCode`), error state retry (label `Try again` from `DashboardStrings.retryCta`).
- [ ] `HOME-GRT-02` greeting first-name edge cases: set display name to `Émile 😀` / `A` / `Mary-Anne Schmidt-Williams` / `<empty>` / `<whitespace>` → greeting renders gracefully, no overflow, no exception. Drafter cites `lib/app/features/dashboard/domain/greeting_first_name.dart` so technical testers can sanity-check the function.
- [ ] **Role permission matrix table** at the head of §4 — rows = ~10 actions (edit event, archive, delete, regenerate code, remove member, promote/demote admin, edit any task, delete any task, change any task status, view Privacy Dashboard), columns = owner / admin / member. Each cell = ☐ allowed / ☐ denied; tester ticks off as they verify. Derive expected allow/deny from `EventModel.isOwner/isAdmin/isMember` in `lib/app/features/dashboard/domain/models/event.dart`.
- [ ] §4 Event lifecycle tests: Create event — drafter opens `create_event_screen.dart`, lists ACTUAL form fields (title, optional description, start date, optional end date, event type emoji selector). If a currency selector is NOT present, drop "currency selector" from the test step entirely (do not test a non-existent field).
- [ ] §4 Edit event (owner-only); Leave event (member-not-owner flow); Delete event (owner-only — fires `deleteEvent` cloud function); Members screen (count badge, add member by code, remove member, regenerate code, copy code to clipboard with snackbar text "Code copied to clipboard"); **Promote to admin** (owner-only — snackbar "Promoted to admin" per `member_management_screen.dart:185`); **Demote admin** (owner-only — snackbar "Demoted to member").
- [ ] §4 Archive event — drafter opens `event_dashboard_screen.dart:559` and writes the test against the observed user-visible effect of setting `isArchived: true`. Explicitly note "Upcoming / Past is date-based, NOT archive-based — archived events do NOT automatically move between filters" so testers don't file phantom bugs.
- [ ] Destructive tests (Delete event, Delete account) ordered last in their sections.
- [ ] Verify: `flutter analyze` smoke; label spot-check 5 random quotes in §3+§4; GitHub render check; role matrix table renders correctly (3 columns, ~10 rows).

### Phase 4: §5 Tasks event-scoped + §6 My Tasks cross-event

- **Goal**: every task surface covered — create flow, status cycle, edit/duplicate/delete, checklist, filter bar, sort, group, exports, cross-event aggregation.
- [ ] §5 Tasks (event-scoped): Create task (title, description, assignee, priority, due date, budget estimate, checklist items up to 25 per `ChecklistEditor.maxItems`; validators: empty title rejected, > 120 char title rejected with the actual validator message), Status cycle todo → doing → done, Unauthorized non-assignee snackbar (label "Only the assignee or an admin can change this" — quoted from `event_tasks_page.dart:81`), Edit task, Duplicate task (` (copy)` suffix + checklist copied), Delete task (owner / creator), Checklist editor (add / edit text / delete), Filter bar (search, status chips, Mine / Overdue / HasBudget toggles per `TasksStrings.filterChipMine/Overdue/HasBudget`), Sort (Due date / Priority / Created / Title per `TasksStrings.sortDueDate/Priority/Created/Title`), Group (Status / Assignee / Due window), Empty states (`TasksStrings.emptyNoTasksYet/Help/NoMatch`), Export PDF tooltip (label `Export PDF` per `TasksStrings.exportPdfTooltip`).
- [ ] §6 My Tasks (cross-event): segmented filter All / To Do / Doing / Done (default scroll layout — drafter notes that `equalWidth: false` is intentional to support i18n widening), independent Overdue badge toggle with count, progress summary strip recomputes per filter, grouped list by event, adaptive empty states (`TasksStrings.myTasksEmptyTitle/Subtitle/SubtitleNoEvents`), sign-in-required state (`TasksStrings.signInRequiredTitle` "Sign in to view your tasks").
- [ ] Drafter quotes every label from `_EnglishTasksStrings`.
- [ ] Verify: `flutter analyze` smoke; label spot-check 5 random quotes in §5+§6; GitHub render check.

### Phase 5: §7 Chat + §7.5 Push notifications + §8 Chat inbox

- **Goal**: event-scoped chat, cross-event inbox, AND the previously-missed FCM push notification + deep-link flow.
- [ ] §7 Chat (event-scoped): Send message, urgent / critical-alert modal (verify icon + terracotta accent), Settlement dispute sheet (only on settlement messages — fires `disputeSettlement` cloud function), Send-failed inline error (`ChatStrings.sendFailedHint` "Send failed — tap Send again to retry") + retry, empty state (`ChatStrings.chatEmptyMessage` "No messages yet — be the first to say something.").
- [ ] §7.5 Push notifications + deep-link: drafter quotes `lib/app/core/services/fcm_service.dart` + `fcm_handler.dart` + `functions/src/events/onUrgentMessageCreated.ts` as the wiring. Tests:
  - Permission grant on first run (iOS / Android system prompt — accept → token written to `users/{uid}.fcmTokens`; deny → no notifications arrive).
  - Urgent message → push arrives — two-account setup; second account sends a critical-alert; first account's device (signed in, app backgrounded) receives the push within ~30 s.
  - Tap from background → app foregrounds + deep-links to `/dashboard/event/{eventId}/chat`.
  - Tap from killed state → cold-start lands on the same event chat.
  - Non-urgent messages do NOT trigger a push.
  - Web: N/A — drafter states FCM web is out of v1 scope, tester marks the section N/A and confirms no errors.
- [ ] §8 Chat inbox (cross-event): Inbox app bar (`ChatStrings.inboxAppBarTitle` "Chat"), conversation tile rows wrapped in elevated `Card`s (verify the new Phase-6 polish), unread pill (cap "99+"), URGENT badge (`ChatStrings.urgentBadge` "URGENT") + terracotta highlight, last-message preview "You: <text>" when sender is current user (per `ChatStrings.inboxLastMessagePrefix`), timestamp formatting (now / Nm / Nh / Yesterday / Nd / Mon D), tap → opens event chat, adaptive empty states (`ChatStrings.inboxEmptyTitle/Subtitle/NoEventsSubtitle/ErrorTitle`).
- [ ] Verify: `flutter analyze` smoke; label spot-check 5 random quotes in §7-§8; GitHub render check; cross-reference §7.5 against actual FCM wiring (drafter reads at least one of the three FCM service files to confirm).

### Phase 6: §9 Budget event-scoped + §10 Budget ledger + Settle Up

- **Goal**: every budget action + the 4 Settle Up deep-link paths + the fallback sheet.
- [ ] §9 Budget (event-scoped): Add expense (amount, description, splits with member checkboxes, optional receipt photo, donation flag, payment flag), Edit expense (owner / creator), Delete expense, Receipt viewer (tap photo → full-screen), Export PDF tooltip, Export CSV tooltip ("Export PDF" / "Export CSV" labels from `budget_screen.dart`), snackbar text "Copied — paste it where you settle" (from `event_budget_page.dart:119`).
- [ ] §10 Budget ledger (cross-event): Hero `BalanceTile` (You are owed / You owe split — quote labels `BudgetStrings.balanceTileYouAreOwedLabel/YouOweLabel`), multi-currency disclaimer (verify by creating two events with USD + EUR + small expenses), Debts breakdown (`DebtTile` cards, Settle Up button per debt with label `BudgetStrings.ledgerSettleUpCta` "Settle Up"), "all settled" chip (`BudgetStrings.ledgerAllSettledMessage`), Recent expenses feed (`RecentExpenseTile` cards).
- [ ] **Settle Up — 4 deep-link paths + fallback** (drafter cross-checks against `lib/app/features/budget/data/pay_link_builder.dart` — note `data/`, NOT `application/`):
  - Venmo (`paymentMethod = 'venmo'`) → opens `venmo://paycharge?txn=pay&recipients=<handle>&amount=<x.xx>&note=<...>` (native) → if app not installed, falls through to `https://venmo.com/<handle>?txn=pay&amount=...&note=...` (web fallback).
  - Cash App (`cashapp`) → opens universal link `https://cash.app/$<handle>/<amount>`.
  - Zelle (`zelle`) → no universal URI; always falls back to the in-app sheet.
  - PayPal (`paypal`) → opens `https://paypal.me/<handle>/<amount>`.
  - Fallback sheet (no paymentMethod set, or `other`, or `cash`) → `SettleUpFallbackSheet` with Copy amount + Copy handle + Mark paid (labels `BudgetStrings.settleUpFallbackCopyAmount/CopyHandle/MarkPaid`).
- [ ] Multi-currency disclaimer test (`BUD-CUR-01`): two events different currencies → ledger shows `BudgetStrings.multiCurrencyDisclaimer` "Totals are approximate when events use different currencies."
- [ ] Verify: `flutter analyze` smoke; label spot-check 5 random quotes in §9-§10 + Appendix C URIs; GitHub render check.

### Phase 7: §11-§13 + Appendices A-D + final validation

- **Goal**: ship-ready guide. All sections complete, dry-run completed on iPhone, time estimates updated, self-test signed off.
- [ ] §11 Responsive shell: bar at < 840 px, rail at ≥ 840 px (per `responsive_shell.dart:31`), resize through breakpoint + verify route stack survives (tester scrolls halfway down Tasks tab before resize), web-shell sign-out tooltip on rail (`NavStrings.signOutTooltip` "Sign out").
- [ ] §12 Accessibility: Dynamic Type at 200% on every primary tab — no overflow, all text readable; VoiceOver / TalkBack pass on Dashboard + Tasks tabs (announce `ProgressRing` semantics, urgent badge, status badges); 320 px viewport stress (`ConversationTile` + `EventTile` + `DebtTile` + `TaskTile` no overflow — verify the Phase-6 fix in `conversation_tile.dart`).
- [ ] §13 Offline + sync: airplane mode → toggle task status → "Will sync when online" badge appears on task detail (text quoted from `task_detail_screen.dart:115`) → restore network → status syncs within ~10 s. `SYNC-RES-01` cold-start resume: create task offline, kill app, restore network, reopen → sync within 10 s without re-creation.
- [ ] Appendix A — Reading device logs: iOS Console; Android `flutter logs` OR `adb logcat *:E flutter:V` (NOT `grep -i crewpoint` — call out the foot-gun explicitly); Web DevTools console + Network; `developer.log` tag list (`chat.inbox`, `budget.ledger`, `fcm`, `tasks.myTasks`).
- [ ] Appendix B — Firebase staging console: link placeholder + "what to check": Authentication users, Firestore `events/`, `events/{id}/tasks`, `events/{id}/messages`, `events/{id}/expenses`, `users/`. Note testers without console access skip.
- [ ] Appendix C — Settle Up deep-link reference: both native + web-fallback URIs per provider (Venmo, Cash App, Zelle, PayPal); cite `lib/app/features/budget/data/pay_link_builder.dart` (`data/`, not `application/`); pick-rule (try native → fall back to https).
- [ ] Appendix D — Known v1 limitations: Notifications row no-op (`profile_screen.dart` `onTap: () {}`), onboarding "Get Started" still hardcoded English, relative-time abbreviations English-only, `AppDurations` has no production callers (forward-looking), pre-existing `TableMigration` analyzer warning, no `flutter_localizations` wiring, Web Safari Private Mode disables IndexedDB.
- [ ] Bug-report template (§14) already in place from Phase 1 — verify it's at the bottom of the file.
- [ ] **Self-test handoff** (per spec): hand a draft + TestFlight invite + staging credentials to one team member who hasn't contributed to v1. They run §0 + §1 + one random section. Capture critical (blocks step completion) vs non-critical (curiosity) questions. Patch critical questions; non-critical → v1.1 polish backlog.
- [ ] **Dry-run on iPhone phone width** end-to-end, time each section, update the `~Nmin` headers to within ±50% of measured time.
- [ ] **Label spot-check** (final pass): pick 5 random labels from anywhere in the guide → confirm byte-for-byte match with `app_strings.dart`.
- [ ] **Phantom-feature audit**: pick 5 random tests → grep the codebase for each feature → no test names a non-existent feature.
- [ ] Verify: `flutter analyze` smoke (no Dart touched across all 7 phases); ToC anchors resolve in GitHub markdown preview; `git status` clean after committing `docs/qa/` directory.

## Risks / Out of scope

- **Risks**:
  1. **Label drift between draft and production string** — `app_strings.dart` is the source of truth; drafter must read it for every quote, not paraphrase. Mitigation: spot-check at every phase + a final 5-label random audit in Phase 7.
  2. **Phantom features** — easy to over-describe. Mitigation: drafter MUST read the cited file before writing each test. Phase 3 currency selector and Phase 3 archive behavior are the highest-risk spots — both have explicit "drafter verifies in code first" callouts.
  3. **FCM testing requires real devices + two accounts** — §7.5 needs an iOS device + an Android device + two staging accounts. Simulator push notifications are unreliable. Mitigation: spec the test environment requirements at the top of §7.5; if real devices aren't available during dry-run, mark §7.5 as "pending real-device handoff" rather than skipping.

- **Out of scope** (per spec):
  - Source-code audit beyond Appendices A-C.
  - Performance benchmarking (frame rate, cold start time).
  - Cloud Function internals.
  - Non-English locales.
  - Web push notifications.
  - Web Safari Private Mode + Firestore persistence — documented as a limitation, not tested.
  - Production Firebase data — staging only.
