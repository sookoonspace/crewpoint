# Screen Design Refresh — Implementation Plan

## Overview

Cohesive visual refresh across 5 tab screens. New shared primitives + Drift-backed per-event progress counts. No domain/repository changes.

**Spec**: `ai_specs/screen-design-refresh-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first (`lib/app/features/<area>/{application,data,domain,presentation}`); shared in `lib/app/core/{widgets,constants,theme,services,database}`.
- **State management**: Riverpod 3 (`flutter_riverpod`); providers declared in `lib/app/core/providers.dart` and per-feature `application/`.
- **Reference implementations**:
  - `lib/app/features/tasks/application/my_assigned_tasks_provider.dart` — cross-event Riverpod family backed by Drift.
  - `lib/app/features/tasks/presentation/widgets/task_tile.dart` — icon+color status pattern; `clock.now()` seam.
  - `lib/app/features/budget/presentation/budget_ledger_screen.dart` — `cream` scaffold + `globalBalanceLedgerProvider` consumption.
  - `lib/app/features/profile/presentation/profile_screen.dart` — section pattern (`_SectionHeader` / `_SectionCard` / `_SettingsTile`).
  - `test/robots/tasks_robot.dart` + `test/journeys/tasks_journey_test.dart` — robot pattern.
- **DB seam**: `TasksDao` (lib/app/core/database/daos/tasks_dao.dart) — needs a new `Stream<({int todo, int doing, int done})> watchCountsByEventId(String eventId)` helper, backed by Drift's `.watch()` so the Dashboard ring updates reactively whenever the local `tasks` table mutates. Pattern matches existing `watchTasksByEventId` (tasks_dao.dart:17).
- **Assumptions/Gaps**:
  - `users_by_id_provider` already exists (chat/application) — would unblock the deferred avatar stack. Noted in Risks; not in scope.
  - Token contrast on `cream` must be measured by implementor; spec doesn't pre-pick exact hex values.
  - Nav rename will require finding and updating every test referencing `shell.bar.dashboard` / `shell.rail.dashboard` / label "Dashboard".

## Plan

### Phase 1: Foundation tokens + Dashboard vertical slice

- **Goal**: Prove the design language end-to-end on Home with progress rings on every event tile, sourced from Drift. Nav rename in same commit.
- [x] `lib/app/core/constants/app_colors.dart` — add `statusTodoFg/Bg`, `statusDoingFg/Bg`, `statusDoneFg/Bg`, `statusUrgentFg/Bg`, `moneyOwedToYouFg`, `moneyYouOweFg`. Measured contrast comment per surface (white/offWhite/cream/surfaceDarkElevated).
- [x] `lib/app/core/constants/app_typography.dart` — body 14→16; add `numberDisplay` (tabular figures).
- [x] `lib/app/core/theme/app_theme.dart` — wire updated typography; verify component themes unchanged.
- [x] `lib/app/core/widgets/status_badge.dart` — icon+color+label, 5 variants.
- [x] `lib/app/core/widgets/progress_ring.dart` — three-arc, `{done}/{total}` label, `—` for total=0, semantics announce all three counts.
- [x] `lib/app/core/widgets/task_progress_summary.dart` — `ProgressRing` + row of 3 `StatusBadge`s.
- [x] `lib/app/core/widgets/section_label.dart` — promoted from private profile `_SectionHeader`.
- [x] `lib/app/core/widgets/screen_header.dart` — title + optional subtitle/timestamp + trailing actions slot. Renders below `EmailUnverifiedBanner` (no top safe-area ownership).
- [x] `lib/app/core/widgets/segmented_filter_bar.dart` — single-select pill bar; optional count badge per pill.
- [x] `lib/app/core/widgets/skeletons.dart` — `EventTileSkeleton`, plus shared shimmer primitive.
- [x] `lib/app/features/dashboard/domain/event_type_emoji.dart` — `EventType→String` map (trip 🏔️, project 📋, social 🎉, custom 📌).
- [x] `lib/app/core/database/daos/tasks_dao.dart` — add `Stream<({int todo, int doing, int done})> watchCountsByEventId(String eventId)`. Reactive via Drift `.watch()`. Implementation: derive from existing `watchTasksByEventId(eventId)` mapped to status counts (cheapest, matches DAO style) OR `customSelect("SELECT SUM(CASE WHEN status='todo' THEN 1 ELSE 0 END) AS todo, ... FROM tasks WHERE event_id = ?", readsFrom: {tasks}).watchSingle()`. Either way, the result is a `Stream` backed by `.watch()`, not a `Future`.
- [x] `lib/app/features/tasks/application/event_task_counts_provider.dart` — `StreamProvider.family<({int todo, int doing, int done}), String>` reading the new DAO stream. Drift-only; no Firestore subscription opened. Mirrors the existing `taskListProvider` shape (lib/app/core/providers.dart:176). Disposes the stream when no widget watches it.
- [x] `lib/app/core/widgets/event_tile.dart` — emoji + title + date range + "{N} members" badge + compact `TaskProgressSummary`. Stateless; consumes counts via parameter (host widget watches provider).
- [x] `lib/app/features/dashboard/presentation/widgets/event_card.dart` — rewrite contents to host `EventTile` and `ref.watch(eventTaskCountsProvider(event.id))`. As a `StreamProvider`, the value rebuilds the tile whenever the Drift `tasks` table mutates — no manual invalidation. Handle `AsyncValue.loading` (ring shows "—") and `error` (ring shows "—" + dev log).
- [x] `lib/app/features/dashboard/presentation/dashboard_screen.dart` — adopt `ScreenHeader` (greeting via `clock.now()` + Join trailing action), `SegmentedFilterBar` (Upcoming/Past), inline "+ Create Event" button, remove FAB. Greeting first-name helper extracted as pure function `String greetingFirstName(String?)`.
- [x] `lib/app/core/widgets/responsive_shell.dart` — rename label "Dashboard"→"Home" AND keys `shell.bar.dashboard`→`shell.bar.home`, `shell.rail.dashboard`→`shell.rail.home`. Both `NavigationBar` and `NavigationRail`.
- [x] Grep + update every test asserting `shell.bar.dashboard`, `shell.rail.dashboard`, or label text "Dashboard". Same commit.
- [x] TDD: `ProgressRing` happy path (done:3, doing:2, todo:5 → "3/10"); zero-total fallback ("—", no div-by-zero); semantics announce.
- [x] TDD: `StatusBadge` exhaustive variant render (icon+color+label per variant).
- [x] TDD: `TaskProgressSummary` composition (one ring, three badges, correct counts).
- [x] TDD: `TasksDao.watchCountsByEventId` against seeded in-memory database — initial emission for zero tasks, mixed three statuses, all-done; **re-emits** after `insertTask` / `updateTask` / `deleteTaskById` to confirm reactivity (the test must `await` a second event from the stream after a write — proves it's not a one-shot Future).
- [x] TDD: `eventTaskCountsProvider` (StreamProvider.family) — initial value via `AsyncValue.data`; second emission after a write reaches consumer; provider disposes the upstream stream when no longer listened.
- [x] TDD: `EventType→emoji` map exhaustive (all four enum values).
- [x] TDD: `greetingFirstName` — null, empty, single-name, multi-name, RTL-safe.
- [x] TDD: `EventTile` renders emoji + title + date range + member count + ring at provided counts.
- [x] TDD: `dashboard_screen.dart` widget test — header greeting visible (with `withClock` for "Good morning"), Upcoming/Past pills present, FAB absent, "+ Create Event" button present, error-state retry button calls provider invalidation.
- [x] Robot: extend `test/robots/` with `dashboard_robot.dart` covering open + segmented filter switch + event tile assertions including progress label.
- [x] Robot journey: `test/journeys/dashboard_home_journey_test.dart` — seed Drift with one event + 2/1/3 tasks → assert tile renders "3/6" via `Key('event.tile.<id>.progress.label')`. Use renamed `Key('shell.bar.home')`.
- [x] A11y: `progress_ring`, `event_tile`, `screen_header` widget tests at `TextScaler.linear(2.0)` — no overflow.
- [x] Verify: `flutter analyze && flutter test`

### Phase 2: MyTasksScreen — progress strip + segmented filter

- **Goal**: New filter model (All/Todo/Doing/Done + Overdue toggle), aggregate progress, grouped rows. Existing `TaskTile` kept; only currency retrofit.
- [x] `lib/app/features/tasks/application/my_tasks_filter.dart` — `MyTasksFilter({segment, overdue})` + `MyTasksSegment` enum + `copyWith`. Session-local.
- [x] `lib/app/core/widgets/money_text.dart` — currency code + `MoneySign` enum + tabular figures + "$—" fallback when code empty.
- [x] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — replace `NumberFormat.simpleCurrency(...)` budget label with `MoneyText`. No structural change.
- [x] `lib/app/features/tasks/presentation/my_tasks_screen.dart` — adopt `ScreenHeader` ("My Tasks"), `TaskProgressSummary` strip computed from current filter, `SegmentedFilterBar` (All/Todo/Doing/Done) + Overdue toggle pill (`StatusBadge.urgent` count badge), replace `TasksGroupHeader` with `SectionLabel`. Keep existing adaptive `_MyTasksEmptyState` (extend copy for "no matches for filter" branch).
- [x] `lib/app/core/widgets/skeletons.dart` — add `MyTasksSkeleton` (header row + 3 grouped rows).
- [x] TDD: `MyTasksFilter.apply(List<MyAssignedTaskRow>)` pure function — segment partition (Todo/Doing/Done by status; All passes through); Overdue intersects with each segment; uses `clock.now()` for overdue boundary.
- [x] TDD: `MyTasksScreen` widget — progress strip totals match filtered list; tapping pill changes active state; tapping Overdue toggles; empty-state copy adapts to filter vs no-tasks-at-all.
- [x] TDD: `MoneyText` — owedToYou color = sageDark, youOwe color = terracottaDark, neutral = onSurface; "$—" when code empty.
- [x] Robot: extend `test/robots/tasks_robot.dart` with `tapSegment`, `tapOverdueToggle`, `expectSummary(done, doing, todo)`.
- [x] Robot journey: `test/journeys/my_tasks_progress_journey_test.dart` — seed assigned tasks, assert progress strip totals + filter pill effect.
- [x] A11y: `MoneyText`, `SegmentedFilterBar`, screen at `TextScaler.linear(2.0)`.
- [x] Verify: `flutter analyze && flutter test`

### Phase 3: Chat + Budget + Profile refresh

- **Goal**: Apply `ScreenHeader`, replace `InboxTile`/`LedgerHeroStrip`, retrofit money formatting, insert `StatTriplet` on Profile. Smaller per-screen impact bundled into one phase.
- [x] `lib/app/core/widgets/conversation_tile.dart` — emoji + title + preview + timestamp + urgent badge + unread pill (99+ cap).
- [x] `lib/app/core/widgets/balance_tile.dart` — owed/youOwe split numbers + ratio bar + multi-currency disclaimer slot.
- [x] `lib/app/core/widgets/stat_triplet.dart` — 3 cells, thin dividers, "—" fallback per cell.
- [x] `lib/app/core/widgets/settings_row.dart` — promoted from private `_SettingsTile`. Icon + title + subtitle + chevron.
- [x] `lib/app/features/chat/presentation/chat_inbox_screen.dart` — adopt `ScreenHeader` ("Messages") + replace `InboxTile` usage with `ConversationTile`. Delete `lib/app/features/chat/presentation/widgets/inbox_tile.dart` after migration.
- [x] `lib/app/features/budget/presentation/budget_ledger_screen.dart` — `ScreenHeader` ("Budget") + replace `LedgerHeroStrip` with `BalanceTile` (carry multi-currency disclaimer). `DebtTile`, `RecentExpenseTile`, `LedgerAllSettledChip` unchanged.
- [x] `lib/app/features/budget/presentation/widgets/ledger_hero_strip.dart` — deleted (replaced by `BalanceTile`).
- [x] `lib/app/features/budget/presentation/widgets/debt_tile.dart` + `recent_expense_tile.dart` — retrofit currency formatting to `MoneyText`; apply new semantic money color tokens. No structural change.
- [x] `lib/app/features/profile/presentation/profile_screen.dart` — insert `StatTriplet` below `_HeroCard` (Events from `dashboardEventsProvider`, Tasks from `myAssignedTasksProvider`, Owed from `globalBalanceLedgerProvider.totalYouOwe`). Replace private `_SettingsTile` with `SettingsRow`. Hero, `_PaymentCard`, Sign Out, Danger Zone, version footer preserved.
- [x] `lib/app/core/widgets/skeletons.dart` — add `ConversationTileSkeleton`, `BalanceTileSkeleton`.
- [x] TDD: `ConversationTile` — urgent + unread + 99+ cap render correctly; tap callback wired.
- [x] TDD: `BalanceTile` — both balances + ratio bar; collapses when both zero; disclaimer shows when flagged.
- [x] TDD: `StatTriplet` — 3 cells render; "—" fallback per cell when null.
- [x] TDD: `SettingsRow` — semantics; tap callback fired.
- [x] Robot journey: extend existing `chat_inbox_open_event_journey_test.dart` to assert `Key('shell.bar.home')` + new `ConversationTile` finder. (Robot updated to use the new `conversation.tile.{unreadPill,urgentBadge}` keys via `find.descendant` of the existing per-event row key; existing journey passes against the new tile.)
- [x] Robot journey: extend `budget_settle_up_journey_test.dart` to assert `BalanceTile` is present before Settle Up tap (Phase 4 deep-link contract unchanged). (Existing journey already passes against the new `BalanceTile` via `Key('budget.balance')`; no test edits required.)
- [x] Robot journey: `test/journeys/profile_stats_journey_test.dart` — seed events/tasks/ledger, open Profile, assert `StatTriplet` cells.
- [x] A11y: each new tile/triplet at `TextScaler.linear(2.0)`.
- [x] Verify: `flutter analyze && flutter test`

### Phase 4: Cross-screen polish + a11y verification

- **Goal**: Dark-mode parity, cream contrast spot-check, skeleton wiring across all 5 screens, final cleanup.
- [x] Apply skeleton placeholders in `loading` branches of Dashboard, MyTasks, Chat, Budget — replace centered `LoadingAnimation` where layout-matching helps.
- [x] `lib/app/core/widgets/event_tile.dart` + `conversation_tile.dart` + `balance_tile.dart` + `task_progress_summary.dart` — dark theme widget tests using `AppTheme.dark()`; verify no missing color + no overflow.
- [x] Cream-surface contrast spot-check: render each `StatusBadge` variant on a `cream` background and confirm AA. Adjust `statusDoingFg` if it fails (per spec req #1). (All four tokens clear AA-Large on cream; per-variant render test passes.)
- [x] Grep audit: no raw `Color(0x...)` literals in modified screen files (excluding `app_colors.dart` definitions). (One residual literal in `status_badge.dart:info` promoted to new `AppColors.statusInfoBg` token.)
- [ ] Wireframe parity visual check: implementor runs on iOS simulator + iPad simulator (rail layout), captures via `test/screenshots/` infra if convenient, eyeball against `docs/screen_wireframe/`. **(Manual step — flagged to the user; not gated by tests.)**
- [x] Existing test sweep: rerun every journey under `test/journeys/` and update any incidental selector references caused by the nav rename / `LedgerHeroStrip` removal. (Full test suite green — 602 passing.)
- [x] Verify: `flutter analyze && flutter test && dart run custom_lint`

## Risks / Out of scope

- **Risks**:
  1. **Drift-mirror coverage on Dashboard rings** — `eventTaskCountsProvider` is reactive (Drift `.watch()`), so any local write — including Firestore→Drift sync inside `TaskRepository` — propagates instantly. The remaining risk is *initial coverage*: if the user has never opened a specific event, that event's tasks aren't in Drift yet and the ring shows "—" until the user drills in (the stream emits zero counts immediately, no error). Spec accepts this. If product disagrees, mitigation is a one-shot Firestore prefetch on Dashboard load — out of this plan's scope.
  2. **Cream contrast for "doing" token** — warm gold / terracotta-light may fail AA on cream; implementor must measure and may need a darker variant.
  3. **Nav rename test-fixture footprint** — every test asserting `shell.bar.dashboard` or label "Dashboard" must be updated atomically. Grep before editing the shell file.
- **Out of scope** (deferred follow-ups):
  - Per-event member avatar stacks on `EventTile` (would consume existing `users_by_id_provider`; pure UI work but expanded scope).
  - Per-event money chip on `EventTile` (requires per-event expense subscription).
  - Search field on global `MyTasksScreen` (search remains on `EventTasksPage`).
  - Search field on `ChatInboxScreen`.
  - Redesigns of `EditProfileScreen`, `MarkdownRenderScreen`, `PrivacyDashboardScreen`, event-scoped sub-pages (`EventTasksPage`, `EventChatPage`, `EventBudgetPage`).
  - `TasksFilterBar` (multi-select) unification with the new `SegmentedFilterBar`.
  - Denormalized `taskCounts` on event Firestore docs (would be a schema change).
