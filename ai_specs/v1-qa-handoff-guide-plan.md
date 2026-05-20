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

### Phase 1: Skeleton + orientation + §0 + bug template (thin vertical slice) ✅ COMPLETE

- **Goal**: full document structure in place; one complete section + bug template prove the format end-to-end.
- [x] `docs/qa/v1-tester-handoff-guide.md` — H1 + ToC linking to every §0-§14 anchor (anchors as placeholders for sections filled in later phases).
- [x] `docs/qa/screenshots/.gitkeep` — empty file so the directory exists.
- [x] Top-of-file orientation block: "What you're testing" 1-paragraph; "How to use this guide" 3-bullet; **Build info block** with TestFlight invite placeholder + Android internal-track placeholder + **Web App Staging URL placeholder `<Insert Web Firebase Hosting URL here>`** + staging-Firebase test-account placeholder + version-footer expectation quoting actual format `CrewPoint v<version> (<build>)`.
- [x] Device coverage matrix table (5 columns: iPhone, Android, Tablet rail, Web Chrome, Web Safari × 1 row per § as checkboxes; §7.5 marks Web N/A; §11 marks iPhone/Android phone N/A; §13 marks Web N/A).
- [x] §0 Pre-flight setup + onboarding — install build (PRE-INST-01), 5-page onboarding swipe forward (PRE-OB-01), skip-to-end (PRE-OB-02), data opt-in toggle + `onboarding_complete` secure-storage persistence note (PRE-OB-03), first sign-in (PRE-AUTH-01), build-number verification (PRE-BUILD-01).
- [x] §14 Bug-report template — copy-pasteable code block + severity rubric (blocker / major / minor / cosmetic) + useful-info-to-capture sub-list.
- [x] Per-test format established: `Test ID` + Pre-conditions + Steps + Expected + Edge cases + Devices.
- [x] Section duration estimates added (§0 marked "~10 min"; finer estimates refined in Phase 7 dry-run).
- [x] Label spot-check (10 labels verified byte-for-byte): onboarding 9 (`Plan Events Together`, `Stay in Sync`, `Split Costs Fairly`, `Your Data, Your Rules`, `Your crew, organized.`, `Allow anonymous usage data`, `Get Started`, `Skip`, `Continue`) + auth 1 (`or continue with email` dividerLabel + `Continue with Google` + `Continue with Apple` + `Email` + `Password` + `Sign In`) + version footer format `CrewPoint v<v> (<build>)`.
- [x] Verify: `flutter analyze` smoke confirms zero Dart touch (only the pre-existing TableMigration warning remains). ToC anchors resolve in standard GitHub markdown rendering.

### Phase 2: §1 Authentication + §2 Profile ✅ COMPLETE

- **Goal**: every auth provider + sign-out + delete-account + profile surface covered.
- [x] §1 Authentication tests authored: `AUTH-SIGNUP-01` (Email sign-up + 4 validator edge cases), `AUTH-VERIFY-01` (banner Resend + I've verified), `AUTH-IN-01` (Email sign-in + 3 error snackbar variants), `AUTH-GOOGLE-01` (Google — phone provider sheet vs web popup), `AUTH-APPLE-01` (iOS + web; N/A on Android), `AUTH-SUGG-01` (suggest-provider snackbar with the actual `suggestProvider` template text), `AUTH-WEB-01` (popup-blocked recovery — quotes `ErrorStrings.popupBlocked` exactly), `AUTH-RATE-01` (too-many-attempts), `AUTH-NETERR-01` (network failure), `AUTH-OUT-01` (sign-out sheet — quotes `Sign out of CrewPoint?` title + `Your local data will be preserved for next time.` body), `AUTH-DEL-01` (multi-step delete account dialog with re-auth — quotes warning copy + processing-step text + email/Google/Apple re-auth labels), `AUTH-LEGAL-01` (legal footer links).
- [x] Recovery sub-bullet added at the top of §1: ">3 sign-in failures → stop, capture snackbar + error code, ask dev team; rate-limit also covered as `AUTH-RATE-01`".
- [x] `AUTH-WEB-01` web-popup-blocked test authored with verbatim `ErrorStrings.popupBlocked` ("Pop-ups are blocked - please allow pop-ups for this site and try again.").
- [x] §2 Profile tests authored: `PROF-HERO-01` (gradient hero + avatar glow + Edit Profile pill + "User" displayName fallback), `PROF-EDIT-01` (display name + Venmo payment method + handle + Cash App $cashtag + Save Changes flow + Profile updated! Lottie + 3 validator edge cases), `PROF-PHOTO-01` (gallery picker), `PROF-PHOTO-02` (camera + permission + Web N/A note), `PROF-PRIV-01` (Privacy Dashboard 4 section labels + Privacy Policy + Terms of Service markdown pages), `PROF-NOTIF-01` (Notifications row no-op — explicitly documented as NOT a bug), `PROF-STATS-01` (stats triplet Events/Tasks/Owed cell rendering + "—" loading placeholder), `PROF-VER-01` (version footer reverification).
- [x] Quoted every label byte-for-byte from `_EnglishAuthStrings`, `_EnglishErrorStrings`, `_EnglishProfileStrings`, and the source files for sheets/dialogs (`sign_out_sheet.dart`, `delete_account_dialog.dart`, `edit_profile_screen.dart`, `privacy_dashboard_screen.dart`).
- [x] Verify: `flutter analyze` smoke (clean against this commit alone — stashed the pre-existing dirty `app_icons.dart` modification to confirm; only the pre-existing `TableMigration` warning remains, zero Dart touch by Phase 2). Label spot-check passed (5 random labels matched byte-for-byte: `Don't have an account? Sign Up`, `Verify your email so this sign-in stays active`, `Your local data will be preserved for next time.`, `How others see you`, `DATA WE COLLECT`).

### Phase 3: §3 Dashboard + §4 Event lifecycle + role-permission matrix ✅ COMPLETE

- **Goal**: every event-lifecycle action covered including the often-missed admin role transitions; role matrix at top of §4.
- [x] §3 Dashboard tests authored: `HOME-GRT-01` (time-of-day greeting + first-name parsing rules + day-of-week date subtitle), `HOME-GRT-02` (greeting first-name edge cases — diacritics + emoji + single char + hyphens + empty + whitespace; fallback to `there` per `greeting_first_name.dart:8`), `HOME-FILT-01` (Upcoming/Past equalWidth pill verification + 320 px fallback hint), `HOME-CRE-01` (Create Event CTA), `HOME-JOIN-01` (Join Event tooltip + bottom sheet + 6-character code field with hint `------` + success snackbar `You joined the event!`), `HOME-EMPTY-01` (No events yet placeholder + Join with Code CTA), `HOME-ERR-01` (error state + retry button `Try again`), `HOME-LIST-01` (section header `<N> UPCOMING EVENTS` / `<N> PAST EVENTS` with the known singular/plural i18n caveat).
- [x] **Role permission matrix** authored at the head of §4 — 12 actions × owner/admin/member columns. Each cell is a ticked checkbox. Three permission anchors documented: `EventModel.isOwner/isAdmin/isMember` for event actions, `canChangeStatus` on `TaskModel`, and the settings-gear visibility rule (`event.isAdmin(uid)` — corrects the spec's earlier "owner-only" framing since owner satisfies isAdmin too).
- [x] §4 Event lifecycle tests authored: `EV-CRE-01` (Create event — quotes ACTUAL form fields from `create_event_screen.dart`: ChoiceChips for event type Trip/Project/Social/Custom NOT emoji picker, currency dropdown WITH 7 supported codes + helper text `Cannot be changed after creating the event.`, snackbar `Event created` + `Share invite` action; explicit note that NO end-date field exists in Create), `EV-EDIT-01` (Edit Event via settings gear — owner+admin, NOT owner-only; verified by reading `event_dashboard_screen.dart:193` `event.isAdmin(uid)` gate), `EV-ARCH-01` (Archive Event SwitchListTile with verbatim subtitles `Archive to make read-only` / `Event is archived (read-only)`, terracotta `Archived` pill, explicit warning that **archive does NOT move event to Past — Past is date-based** so testers don't file phantom bugs), `EV-LEAVE-01` (Leave Event dialog with verbatim body + `removeEventMember` cloud function + failure snackbar `Failed to leave event`; owner cannot leave), `EV-MEM-01` (Members screen with role labels Owner/Admin/Member + FAB visibility), `EV-MEM-02` (Add member sheet with `Generating code...` loader + `Copy` button + `Code copied to clipboard` snackbar + `Generate New Code` button), `EV-MEM-03` (Remove member with verbatim dialog text + `Member removed` / `Failed to remove member` snackbars), `EV-MEM-04` (Promote to admin / Demote admin — OWNER ONLY, NOT admin — with snackbars `Promoted to admin` / `Demoted to member` / `Failed to promote` / `Failed to demote admin`), `EV-DEL-01` (Delete Event — owner only, 2-step destructive dialog with verbatim Step 1 + Step 2 copy + `deleteEvent` cloud function).
- [x] Destructive `EV-DEL-01` placed last in §4 with a 🚨 callout.
- [x] Verify: `flutter analyze` smoke clean (stashed pre-existing dirty `app_icons.dart` to confirm; only the pre-existing `TableMigration` warning remains). Label spot-check passed (5 random labels matched byte-for-byte: `Couldn't create event — try again`, `Archive to make read-only`, `Enter the 6-character code shared by the event organizer`, `Generating code...`, `Promoted to admin`).

### Phase 4: §5 Tasks event-scoped + §6 My Tasks cross-event ✅ COMPLETE

- **Goal**: every task surface covered — create flow, status cycle, edit/duplicate/delete, checklist, filter bar, sort, group, exports, cross-event aggregation.
- [x] §5 Tasks (event-scoped) authored: `TASK-CRE-01` (3-section Create form: Details / Assignment / Timing & Budget, ChoiceChips priority, validator edge cases `Please enter a title` + `Title must be 120 characters or fewer`, snackbar `Failed to create task`), `TASK-CRE-02` (placeholder for checklist-on-create — flagged for drafter follow-up; checklist editor is post-create), `TASK-STAT-01` (status cycle todo → doing → done with stripe color flip + group re-compute + auto-hide of progress bar when Done; `Could not update status` failure), `TASK-PERM-01` (verbatim `Only the assignee or an admin can change this` snackbar from `event_tasks_page.dart:81`), `TASK-DET-01` (status badge + assignee row + due/completed rows + overflow menu + "(no longer in event)" annotation), `TASK-EDIT-01` (Edit Task screen + `Save changes` button + `Could not save changes` snackbar), `TASK-DUP-01` ( (copy) suffix per `TaskModel.duplicate` + checklist carried over + `Could not duplicate task` snackbar), `TASK-DEL-01` (verbatim `Delete this task?` dialog + body + Cancel/Delete), `TASK-CHK-01` (checklist editor with 25-item cap + 120-char-per-item cap + role-based affordance hiding per `canEdit`), `TASK-FILT-01` (4-zone TasksFilterBar with multi-select chips Mine/Overdue/HasBudget/Todo/InProgress/Done), `TASK-SORT-01` (Sort by Due date/Priority/Created/Title with ordering rules), `TASK-GRP-01` (Status/Assignee/Due window grouping), `TASK-EMPTY-01` (`No tasks yet` + `Tap + to create your first task` + `No tasks match this filter` + `Clear filters` reset CTA), `TASK-EXP-01` (Export PDF tooltip + `Couldn't generate report` failure snackbar).
- [x] §6 My Tasks (cross-event) authored: `MYT-LAYOUT-01` (ScreenHeader **My Tasks** + TaskProgressSummary strip + SegmentedFilterBar **All/To Do/Doing/Done** default scroll layout + independent **Overdue** badge + grouped list by event), `MYT-FILT-01` (segment switching narrows list AND progress strip together; verifies `equalWidth: false` is intentional for i18n widening — drafter cites the 320 px / 200% scale stress as PASS, not bug), `MYT-OVR-01` (Overdue badge opacity 0.55 off → 1.0 on; intersection with segment), `MYT-EMPTY-01` (3 paths: A=no tasks with events, B=no events at all, C=no match — with verbatim `No tasks assigned to you` / `Open an event from the Dashboard to view or create tasks.` / `Create an event from the Dashboard to get started.` / `Open Dashboard` / `Create an event` strings), `MYT-SIGN-01` (`Sign in to view your tasks` placeholder during sign-out flicker), `MYT-NAV-01` (tap row → opens Task Detail; My Tasks tile has `canChangeStatus: false` — no inline status flips from cross-event view).
- [x] Every label quoted from `_EnglishTasksStrings`, `event_tasks_page.dart`, `event_task_detail_page.dart`, `tasks_filter_bar.dart`, `task_tile.dart`, `task.dart` (TaskStatus labels), `my_tasks_screen.dart`.
- [x] Verify: `flutter analyze` smoke clean (stashed pre-existing dirty `app_icons.dart` to confirm; only the pre-existing `TableMigration` warning remains). Label spot-check passed (5 random labels matched byte-for-byte: `Only the assignee or an admin can change this`, `Delete this task?`, `Couldn't generate report`, `Open Dashboard`, `Create an event`).

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
