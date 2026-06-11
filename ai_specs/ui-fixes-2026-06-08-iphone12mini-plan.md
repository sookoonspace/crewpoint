# Plan — iPhone 12 mini UI fixes (2026-06-08, pre-tester polish)

## Overview

Fix the four P0 blockers and five P1 polish items identified by the
2026-06-08 QA pass over 36 iPhone 12 mini screenshots in
`docs/ui_screenshots/iphone_12_mini_06_08_2026/` so the build is safe to
hand to TestFlight + Internal Testing. The QA pass is the source of
truth for what's in scope; see the chat transcript above for the
prioritized findings.

P0 = anything that misleads testers (stale copy from the critical-alert
removal, visible word-breaking in core nav controls, multi-line form
fields where the icon and placeholder appear disconnected, and the
unintentional debug banner). P1 = visible polish that costs us trust on
first impression. P2 items are tracked here for completeness but
deferred to a follow-up so this PR stays scoped.

## Context

- **Structure**: feature-first `lib/app/features/{tasks,budget,chat,dashboard}/{application,data,domain,presentation}`.
- **Strings**: routed through `context.strings.<scope>` from
  `lib/app/core/i18n/app_strings.dart` (single English implementation
  today; structure already in place for future locales).
- **Reference implementations / files this plan touches**:
  - `lib/app/features/dashboard/presentation/widgets/mute_event_sheet.dart:84-85`
    — the stale "critical opt-in" subtitle (Phase 4 was withdrawn in
    PR #12; Option B suppression in
    `functions/src/notifications/suppress.ts` now silences chat_urgent
    too when the event is muted).
  - `lib/app/features/tasks/presentation/widgets/tasks_filter_bar.dart:217-246`
    — the `SegmentedButton<TasksGroupBy>` whose three labels
    ("Status", "Assignee", "Due window") overflow at 375 px once the
    selected segment gains its checkmark.
  - `lib/app/core/i18n/app_strings.dart:135-138, 720-727` — the
    `groupStatus / groupAssignee / groupDueWindow` getters that supply
    those labels.
  - `lib/app/features/tasks/presentation/create_task_screen.dart:152-158`
    — `AppTextField(maxLines: 3, prefixIcon: Icon(...))`: the
    Material `InputDecorator` vertically centers the prefix icon in the
    full multi-line height, so the icon ends up below the hint —
    visible in `Create_task_screen_01.PNG`.
  - `lib/app/features/budget/presentation/widgets/expense_modal.dart:215-219`
    — same shape with `CustomTextField` (which delegates to
    `AppTextField`); see `Budget_add_expense_card.PNG`.
  - `lib/app/core/widgets/forms/app_text_field.dart:116` — where the
    prefix is forwarded into `InputDecoration`; the fix should live in
    the call-sites, not here, so single-line fields keep their icons.
  - `lib/app/features/tasks/presentation/create_task_screen.dart` form
    body — Due Date row is the last field and the persistent bottom
    nav is occluding it at the iPhone 12 mini viewport.
  - `lib/app/features/chat/presentation/event_chat_page.dart` — owns
    the chat detail `AppBar`; currently passes a generic "Chat" title
    instead of the event name.
  - `lib/app/features/budget/presentation/budget_screen.dart` /
    related per-event detail screen — owns the "Budget" title; same
    issue.
  - `lib/app/features/budget/presentation/budget_ledger_screen.dart`
    (global Budget tab) — owns the "$0.00 — all settled" hero +
    "You're all settled up." card duplication.
  - `lib/app/features/budget/presentation/widgets/recent_expense_tile.dart`
    + `lib/app/features/budget/presentation/budget_screen.dart` — the
    "Donated" expense row that currently looks identical to a
    cost-shared expense.
  - `lib/app/features/tasks/presentation/event_tasks_page.dart` (or
    sibling) — the empty state with the tent-shaped icon and the
    "Open Dashboard" CTA whose label disagrees with the nav tab name.
- **Assumptions / Gaps**:
  - Tester build will be invoked with
    `flutter build ios --release --flavor stg` (matches the deploy
    guide added in `docs/firebase-full-deploy-guide.md`). The visible
    DEBUG ribbon in `docs/ui_screenshots/iphone_12_mini_06_08_2026/`
    is a side-effect of the screenshots being captured from a debug
    build; nothing in the code needs to change unless TestFlight
    upload uses the wrong target. Phase 0 verifies this rather than
    blindly editing the runner config.
  - `groupStatus / groupAssignee / groupDueWindow` are
    English-only today. Updates land in the single English
    implementation in `app_strings.dart`; no other locales to keep
    in lockstep.
  - "Open Dashboard" vs "Home" tab: nav already calls the
    destination "Home" — we'll align the empty-state CTA with the
    nav rather than the other way around (one-line change vs
    renaming the bottom-nav label everywhere).

## Plan

### Phase 0: Verify release build flips off the DEBUG banner ✓

- **Goal**: Confirm that the visible "DEBUG" ribbon in the QA
  screenshots is purely a debug-mode artefact and that the tester
  build (`--release`) is clean. No code change expected.
- [x] Code-side inspection of `lib/main.dart:318-326` — `MaterialApp.router`
  does not override `debugShowCheckedModeBanner`. Flutter's default is
  `true`, but the framework strips the banner in `--release` and
  `--profile` builds. No source change required.
- [x] Grep across `lib/` confirms zero occurrences of
  `debugShowCheckedModeBanner` — nothing forces the banner on.
- [ ] (User-side verification, deferred) Run
  `flutter build ios --release --flavor stg` against the staging
  configuration in `docs/firebase-full-deploy-guide.md`, install on
  iPhone 12 mini sim/device, open Home, confirm no `DEBUG` ribbon
  paints in the top-right. If it does paint in release mode, file a
  follow-up to set `debugShowCheckedModeBanner: false` on the root
  `MaterialApp`; otherwise nothing further to do.

### Phase 1: Mute Event sheet copy — drop the "critical opt-in" reference ✓

- **Goal**: The Mute Event bottom sheet describes current behavior
  (Option B suppression) instead of the withdrawn Phase 4 critical-
  alert opt-in.
- [x] TDD: extended `test/app/features/dashboard/presentation/widgets/mute_event_sheet_test.dart`
  with a `MuteEventSheet — copy` group asserting
  `find.textContaining('critical opt-in')` is absent and
  `find.textContaining('Pause all notifications')` is present in the
  inactive subtitle. Confirmed RED before the source edit.
- [x] `lib/app/features/dashboard/presentation/widgets/mute_event_sheet.dart:84-86`
  — replaced the `else` branch subtitle with:
  `'Pause all notifications for this event for the selected window. You\'ll still see messages when you open the chat.'`.
  Also corrected the stale class-doc reference to `suppress.ts` /
  Option B (was pointing at `sendPush.ts` + the withdrawn
  `criticalOptIn` clause).
- [x] Verified: `flutter analyze` (clean, sole pre-existing
  `experimental_member_use` warning) + `flutter test` (799 / 799
  passing).

### Phase 2: Tasks group-by SegmentedButton — kill the word-break ✓

- **Goal**: At 375 px viewport, all three segment labels render on a
  single line; no `Assign\nee`-style breaks.
- [x] Chose **option A** (shortened labels) over option B
  (scrollable chip row) — smaller diff, no test-key churn, no
  custom widget.
- [x] TDD: added
  `test/app/features/tasks/widgets/tasks_filter_bar_groupby_overflow_test.dart`.
  Pumps `TasksFilterBar` inside a `SizedBox(width: 375)` for each of
  the three `TasksGroupBy` values and asserts the SegmentedButton's
  overall height stays below the single-row cap (50 px). When any
  label wraps, the segment grows and the whole button passes the
  threshold (RED confirmed at 60 px with the original labels). The
  per-Text height heuristic I tried first was unreliable because
  Material gives every ButtonSegment label slot the segment's full
  tap-target height; the bar-level height is the honest signal.
- [x] Updated `groupAssignee` → `People` and `groupDueWindow` → `Due`
  in `lib/app/core/i18n/app_strings.dart:720-727`. Test keys
  (`tasks.list.groupToggle.{status,assignee,dueWindow}`) and the
  `TasksGroupBy` enum values stay; only the rendered labels changed.
- [x] No escape hatch needed (text wrapping stayed off after the
  rename). Existing `VisualDensity.compact` style on the button
  retained.
- [x] Verified: `flutter analyze` clean (sole pre-existing
  experimental warning); `flutter test` 800/800 passing — including
  `tasks_filter_sort_group_journey_test.dart` whose Key-based
  selection survives the label change unchanged.

### Phase 3: Description fields — drop prefixIcon for multi-line inputs ✓

- **Goal**: The multi-line description input no longer renders an
  icon centred in the middle of the field, disconnected from the
  hint at the top.
- [x] TDD: added `test/app/features/tasks/create_task_screen_test.dart`
  with a single test that pumps `CreateTaskScreen` (under a tall
  view to bypass scroll) and asserts the `AppTextField` keyed
  `tasks.create.description` has `prefixIcon == null`. Confirmed
  RED before the source edit.
- [x] `lib/app/features/tasks/presentation/create_task_screen.dart:152-158`
  — dropped `prefixIcon: const Icon(AppIcons.description)` from
  the multi-line description `AppTextField`. The single-line title
  field above keeps its `navTasksFilled` icon; `AppIcons` import
  stays.
- [x] **Also fixed** the matching bug in
  `lib/app/features/tasks/presentation/edit_task_screen.dart:147-153`
  — same `maxLines: 3` + `prefixIcon` pattern, same visual
  disconnection. The existing
  `test/app/features/tasks/edit_task_screen_test.dart` continues
  to pass; one more focused assertion was not added because the
  pattern + fix are identical and the Create-side test already
  documents the rationale.
- [x] **Did not** touch
  `lib/app/features/budget/presentation/widgets/expense_modal.dart`
  — the Description `CustomTextField` there is single-line (no
  explicit `maxLines`, so default = 1), which means the prefix
  icon centres correctly on the one line and is visually
  consistent with the `$` icon on the Amount field above. Dropping
  it would be churn without a fix. Plan scope tightened.
- [x] Left `lib/app/core/widgets/forms/app_text_field.dart`
  untouched; the shared widget stays neutral about line count.
- [x] Verified: `flutter analyze` clean (sole pre-existing
  experimental warning); `flutter test` 801 / 801 passing.

### Phase 4: Create Task — comfortable bottom padding under the CTA ✓

- **Goal**: At the iPhone 12 mini viewport the Create Task CTA at
  the form tail has breathing room above the persistent
  ResponsiveShell NavigationBar — previously the button rendered
  ~10 px above the nav and read as visually cramped, even though
  nothing was actually clipped.
- [x] Scope re-evaluated. Initial plan called for
  `EdgeInsets.only(bottom: 96 + viewPadding.bottom)` plus a
  `dragUntilVisible` widget test. Closer reading of
  `responsive_shell.dart` showed the NavigationBar sits in the
  outer Scaffold's `bottomNavigationBar` slot — it never overlays
  the body, so safe-area maths is unnecessary. The real fix is
  just doubling the existing bottom padding so the CTA isn't flush
  with the nav.
- [x] TDD: extended `create_task_screen_test.dart` with a structural
  assertion — find the `SingleChildScrollView`, cast `padding` to
  `EdgeInsets`, and assert `padding.bottom >= 40`. RED confirmed
  at 24 px (the previous `AppSpacing.xl`).
- [x] `lib/app/features/tasks/presentation/create_task_screen.dart:112-117`
  — swapped `EdgeInsets.symmetric(vertical: AppSpacing.xl)` for
  `EdgeInsets.fromLTRB(h, AppSpacing.xl, h, AppSpacing.xxxl)`
  (top 24 → bottom 48). Pulled the named tokens from the existing
  `AppSpacing` table; no magic numbers introduced.
- [x] Applied the same change to
  `lib/app/features/tasks/presentation/edit_task_screen.dart:107-114`
  — Edit Task has the identical Scaffold + SingleChildScrollView
  shell and the Save CTA at the form tail. Keeping the two in
  lockstep avoids one drifting under the next polish pass.
- [x] Verified: `flutter analyze` clean (sole pre-existing
  experimental warning); `flutter test` 802 / 802 passing.

### Phase 5: Chat & Budget detail — show the event name in the AppBar ✓

- **Goal**: Users in multiple events can identify which thread or
  ledger they're inside.
- [x] `ChatScreen` and `BudgetScreen` both grew an optional
  `String? appBarTitle` parameter. When supplied the AppBar paints
  it (with `TextOverflow.ellipsis` so long event names degrade
  gracefully); when null the screen falls back to the existing
  generic title (`Chat` from `context.strings.chat.chatAppBarTitle`
  / literal `'Budget'`) — keeps untouched callers backwards-
  compatible.
- [x] Wired both from the per-event parents:
  - `lib/app/features/budget/presentation/event_budget_page.dart:357`
    — passes `appBarTitle: widget.event.title` into `BudgetScreen`.
  - `lib/app/features/chat/presentation/event_chat_page.dart` —
    passes `appBarTitle: widget.event.title` into `ChatScreen` on
    the data branch, and updates the loading + error fallback
    `Scaffold`s to use `Text(widget.event.title)` instead of the
    hard-coded `'Chat'`.
- [x] TDD (Budget): extended
  `test/app/features/budget/budget_screen_test.dart` with two new
  tests — one asserting the supplied `appBarTitle` paints inside
  the `AppBar` subtree (descendant finder, so a body widget that
  happens to share the string can't satisfy the assertion) AND
  that `'Budget'` does **not** appear there; the other locking the
  fallback path for un-migrated callers. Compile-failure RED
  confirmed before the BudgetScreen ctor update.
- [x] TDD (Chat): added
  `test/app/features/chat/presentation/chat_screen_appbar_title_test.dart`
  mirroring the same shape — supplied-title path + fallback path,
  both scoped to the `AppBar` subtree.
- [x] Verified: `flutter analyze` clean (sole pre-existing
  experimental warning); `flutter test` 806 / 806 passing.

### Phase 6: Budget global tab — collapse the duplicated "settled" copy ✓

- **Goal**: Only one settled-state message appears on the global
  Budget tab when there's nothing to settle.
- [x] Located the duplicate at
  `lib/app/features/budget/presentation/budget_ledger_screen.dart:157`
  — the `else` branch of the debts block was rendering
  `LedgerAllSettledChip` ("You're all settled up.") on top of the
  `BalanceTile` hero ("$0.00 — all settled"). Same message twice.
- [x] Kept the hero, dropped the chip — matches the plan's
  recommendation.
- [x] TDD: flipped the existing
  `test/app/features/budget/presentation/budget_ledger_screen_test.dart`
  "all-settled state" case to assert the chip is gone AND that
  `find.textContaining('all settled')` resolves to exactly one
  widget (the hero). RED confirmed before the source edit.
- [x] Removed the now-orphan widget file
  (`lib/app/features/budget/presentation/widgets/ledger_all_settled_chip.dart`)
  and the unused `ledgerAllSettledMessage` getter from both the
  `AppStrings` abstract base and its English implementation in
  `lib/app/core/i18n/app_strings.dart`. No other production or
  test code referenced either.
- [x] Verified: `flutter analyze` clean (sole pre-existing
  experimental warning); `flutter test` 806 / 806 passing.

### Phase 7: Donated expenses — visible badge in the list ✓

- **Goal**: A donation-mode expense reads as "donated" in the
  expense row, so the zero balances next to a non-zero expense
  total stop being confusing.
- [x] Confirmed the model already carries the flag —
  `ExpenseModel.isDonation` defaults to `false` at
  `lib/app/features/budget/domain/models/expense.dart:10,22`. Not
  blocked.
- [x] Added a shared
  `lib/app/features/budget/presentation/widgets/donated_pill.dart`
  rendering a small sage-tinted "Donated" pill (background:
  `AppColors.sage.withValues(alpha: 0.15)`; text: `AppColors.sage`,
  600 weight). Keyed `budget.expense.donatedPill` for stable
  selector access. Both tiles import this one widget so the cue
  stays consistent across the per-event and global Budget surfaces.
- [x] Wired the pill into the cross-event row
  (`recent_expense_tile.dart`) — sits on the same Row as the event
  title with an `AppSpacing.sm` gap; the event title is wrapped in
  a `Flexible` so the pill doesn't shove it off-screen.
- [x] Upgraded the per-event row (`expense_tile.dart`) — replaced
  the plain `Text('Donated', ...)` subtitle with the shared
  `DonatedPill`. Visually stronger signal + one source of truth for
  the design.
- [x] TDD: extended both existing tile suites with two paired tests
  (donation present → pill renders + 'Donated' visible; donation
  absent → pill key not found). RED on the present case for
  `recent_expense_tile_test.dart` before the source edit; the
  `expense_tile_test.dart` pair used a key-based assertion that the
  pre-existing plain-text path could not satisfy.
- [x] Verified: `flutter analyze` clean (sole pre-existing
  experimental warning); `flutter test` 810 / 810 passing.

### Phase 8: Tasks empty state — icon + CTA alignment ✓

- **Goal**: The empty state on the Tasks tab reads as "no tasks" and
  the CTA text matches the bottom-nav tab name.
- [x] Renamed the shared `openDashboardCta` getter in
  `lib/app/core/i18n/app_strings.dart` from `'Open Dashboard'` to
  `'Go to Home'`. Updated the three sibling tests that pinned the
  literal — `my_tasks_screen_test.dart`,
  `budget_ledger_screen_test.dart`,
  `chat_inbox_screen_test.dart`. The Chat, Budget, and Tasks
  empty-state CTAs now agree with the bottom-nav tab name on every
  surface that uses this key.
- [x] Tasks empty state — discovered that the visible "tent-shaped"
  blob is actually the default `lottieEmptyState` animation, not
  the icon fallback. `EmptyStatePlaceholder` only renders
  `iconFallback` when Lottie fails to load, so the original plan's
  "swap iconFallback to checklist" wouldn't have changed what
  testers see on a working install.
  - Resolved by passing `lottieAsset: null` at the Tasks call-site
    (`lib/app/features/tasks/presentation/my_tasks_screen.dart:347-348`)
    so the placeholder always uses the icon path, and setting
    `iconFallback: AppIcons.navTasks` (`Icons.task_outlined`) — the
    same icon the bottom-nav tab uses, so the metaphor is
    consistent across the app.
- [x] TDD: extended the existing `empty-with-events branch` test in
  `my_tasks_screen_test.dart` with two new assertions — CTA text
  `'Go to Home'` and `find.byIcon(AppIcons.navTasks)` resolves to
  one widget. Confirmed RED in two steps (the CTA assertion failed
  first; the icon assertion failed after that) before each source
  edit.
- [x] Verified: `flutter analyze` clean (sole pre-existing
  experimental warning); `flutter test` 810 / 810 passing —
  including the three sibling i18n suites that needed the string
  flip.

### Phase 9: P2 items — defer

- **Goal**: Document deferred polish so it doesn't get lost.
- [ ] Add a brief follow-up note (in `ai_specs/todo.md`) listing:
  - Filter chip row on Tasks (consider horizontal scroll or
    overflow sheet).
  - Recent-expense title heavy truncation on the global Budget tab.
  - Vertical centering on empty-state widgets (Tasks + Chat).
  - Reduced min-height on multi-line Description fields.
- [ ] No source changes in this phase.

## Risks / Out of scope

- **Risks**:
  - Phase 2 option A renames the visible label on a control that
    journey tests may key on by text. Keys (`tasks.list.groupToggle.<value>`)
    stay stable, so the structural selectors are unchanged. Verify
    `flutter test` includes the tasks-list robot suite before
    landing.
  - Phase 4's `EdgeInsets.only(bottom: 96)` is a magic number tied
    to the persistent nav height. If the nav height changes later,
    this padding goes stale. Document the dependency inline.
  - Phase 5 changes a title that may appear in screenshots or
    snapshot tests. Re-run the snapshot suite (if any) and update
    goldens deliberately.
  - Phase 7 assumes the donation flag is already persisted on the
    `Expense` model. If not, the phase is blocked.
- **Out of scope**:
  - Filter chip row wrapping on the Tasks screen (P2, Phase 9).
  - Recent-expense title truncation on the global Budget tab (P2).
  - Empty-state vertical centering (P2).
  - Description field min-height tightening (P2).
  - Chat list (Inbox) layout — verified clean.
  - Privacy dashboard, Edit Profile, Settings, Notification settings
    — verified clean in the QA pass.
  - Bottom-nav label rename ("Home" → "Dashboard") — explicitly
    rejected in favour of aligning the empty-state CTA.
  - Anything that requires a new design token (`AppColors`,
    `AppSpacing`) — if a phase pulls one in, surface it for review
    rather than landing the token silently.
