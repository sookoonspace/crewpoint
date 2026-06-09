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

### Phase 4: Create Task — Due Date row no longer hidden by bottom nav

- **Goal**: At the iPhone 12 mini viewport, the Due Date field is
  fully visible without scrolling past the persistent bottom nav.
- [ ] Locate the scroll view that wraps the Create Task form (the
  current implementation in
  `lib/app/features/tasks/presentation/create_task_screen.dart`
  uses an outer `SingleChildScrollView`/`ListView`). Confirm
  current padding.
- [ ] TDD: add a widget test that pumps the screen inside a
  `MediaQuery(size: Size(375, 812), ...)` and a `Padding` mimicking
  the bottom-nav viewInsets. Assert the bottom of the Due Date
  field's `RenderBox` is above the nav's `top` edge after one full
  scroll-to-end (use `tester.dragUntilVisible(...)` + assert no
  exception).
- [ ] Update the scroll view's `padding` to include
  `EdgeInsets.only(bottom: 96 + MediaQuery.viewPaddingOf(context).bottom)`
  (or pull the magic number from `AppSpacing` if a `xxl` exists; if
  not, add a named constant locally with a short comment explaining
  it matches the persistent nav height). Do **not** thread the
  bottom-nav height through providers — derive locally.
- [ ] Verify: `flutter analyze && flutter test`. Manual: open Create
  Task on iPhone 12 mini sim, scroll to the bottom, confirm the Due
  Date row clears the nav and there's room to tap.

### Phase 5: Chat & Budget detail — show the event name in the AppBar

- **Goal**: Users in multiple events can identify which thread or
  ledger they're inside.
- [ ] `lib/app/features/chat/presentation/event_chat_page.dart` —
  change the `AppBar.title` from the literal/generic string to the
  resolved event name (the page already has the event in scope via
  the route argument or provider). Keep the title as `Text(event.name)`
  with `overflow: TextOverflow.ellipsis`; drop the subtitle row.
- [ ] Same swap for the per-event Budget detail screen
  (`lib/app/features/budget/presentation/budget_screen.dart` or the
  equivalent — verify by grep before editing).
- [ ] TDD: extend the existing chat page test (or add a tiny test)
  that pumps the page with a known event name and asserts
  `find.text(eventName)` is hit, while `find.text('Chat')` is **not**
  in the AppBar.
- [ ] Verify: `flutter analyze && flutter test`. Manual: open chat
  and budget for an event named "Weekend getaway", confirm the
  AppBar reflects that.

### Phase 6: Budget global tab — collapse the duplicated "settled" copy

- **Goal**: Only one settled-state message appears on the global
  Budget tab when there's nothing to settle.
- [ ] Locate the duplicate. The hero `BalanceTile` already renders
  `$0.00 — all settled`; the "You're all settled up." card is a
  separate widget in `budget_ledger_screen.dart` (or sibling).
- [ ] Decide which to drop. Recommendation: keep the hero, drop the
  redundant card. If product wants a CTA in that vertical space
  later, add a follow-up task — don't widen scope here.
- [ ] TDD: add an assertion in the existing
  `budget_ledger_screen_test.dart` that, in the empty/settled
  state, `find.textContaining('all settled')` resolves to exactly
  **one** match.
- [ ] Verify: `flutter analyze && flutter test`. Manual: confirm
  visually on iPhone 12 mini.

### Phase 7: Donated expenses — visible badge in the list

- **Goal**: A donation-mode expense reads as "donated" in the
  expense row, so the zero balances next to a non-zero expense
  total stop being confusing.
- [ ] Confirm the data model already carries the donation flag (e.g.
  `Expense.donated` / `isDonation`). If not present, this phase is
  blocked — surface that in the plan rather than silently extending
  the model.
- [ ] Extend `lib/app/features/budget/presentation/widgets/recent_expense_tile.dart`
  (and the per-event expense tile if separate) to render a small
  "Donated" pill (use the existing `AppColors.sage` accent + the
  existing pill style from the priority chips on the Tasks list for
  visual consistency).
- [ ] TDD: extend the existing widget test for the expense tile —
  with `donated: true`, assert the pill is rendered; with
  `donated: false`, assert it's absent.
- [ ] Verify: `flutter analyze && flutter test`. Manual: confirm
  visually with the existing "Let's keep it affordable" $1,000
  donated expense.

### Phase 8: Tasks empty state — icon + CTA alignment

- **Goal**: The empty state on the Tasks tab reads as "no tasks" and
  the CTA text matches the bottom-nav tab name.
- [ ] Swap the empty-state icon from the current tent-shaped icon
  to `Icons.checklist_outlined` (or the equivalent already exposed
  via `AppIcons`). Keep size + tint untouched.
- [ ] Rename the CTA label from "Open Dashboard" to "Go to Home" so
  it matches the bottom-nav tab. The bottom nav stays "Home"; the
  CTA aligns to it (smaller diff, no terminology churn elsewhere).
- [ ] TDD: extend
  `test/app/features/tasks/presentation/event_tasks_page_test.dart`
  (or the empty-state test) — assert `find.byIcon(Icons.checklist_outlined)`
  resolves and the button text is `'Go to Home'`.
- [ ] Verify: `flutter analyze && flutter test`. Manual: navigate to
  Tasks with no assigned tasks and confirm the new copy + icon.

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
