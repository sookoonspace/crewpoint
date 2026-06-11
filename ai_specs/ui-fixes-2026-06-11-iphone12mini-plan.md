# Plan — iPhone 12 mini UI fixes (2026-06-11)

## Overview

Eight UI polish fixes (5 reported + 3 bonus) from the 2026-06-11 QA pass. Continuation of the 2026-06-08 plan (PR #13) — reuse `lottieAsset: null` empty-state bypass, AppBar-title param pattern (Phase 5), key-stable test selectors.

**Spec**: `ai_specs/ui-fixes-2026-06-11-iphone12mini.md` (read for full requirements).

## Context

- **Structure**: feature-first `lib/app/features/{dashboard,tasks,budget,chat}/`. Shared widgets in `lib/app/core/widgets/`. NEW: `lib/app/core/format/` for the date helper (one file).
- **State management**: Riverpod 3 via `ProviderScope.overrides` in tests. No state changes in this pass — pure presentation.
- **Reference implementations**:
    - 2026-06-08 plan / commits (`afbf1ea`–`404842f`) — pattern bank for AppBar-title swap (Phase 5 commit `6b28712`), Lottie bypass (Phase 8 commit `62652b6`), `_QuickLinkCard` shape.
    - `lib/app/features/dashboard/presentation/event_dashboard_screen.dart:67-100` — existing admin-gated `_QuickLinkCard('Invite Members')`. New Edit tile follows this shape verbatim.
    - `lib/app/core/widgets/segmented_filter_bar.dart:138-145` — `_measureText` TextPainter pattern. Reused in Phase 8 (SegmentedButton width lock).
    - `lib/app/core/widgets/event_tile.dart:28-35` (home) + `lib/app/features/dashboard/presentation/event_dashboard_screen.dart:153,277-305` (event detail) — both date-render call sites.
    - `test/app/features/budget/budget_screen_test.dart` (AppBar title test from Phase 5) + `test/app/features/chat/presentation/chat_screen_appbar_title_test.dart` — extend with `toolbarHeight` assertion.
- **Assumptions/Gaps**:
    - `AppIcons.actionEdit` = `Icons.edit` — verified.
    - No existing `event_dashboard_screen_test.dart` — new test file for admin Edit tile.
    - `task_list_screen.dart` has two `EmptyStatePlaceholder` call-sites at lines 78-89; both flip together.
    - SegmentedButton `showSelectedIcon` is `true` by default (Material 3). Confirmed in `tasks_filter_bar.dart:245`.

## Plan

### Phase 1: Thin slice — date-format helper + both consumers (req 8) ✓

- **Goal**: New `core/format/` helper + both call-sites + tests, end-to-end. Proves new layer, dependency direction (`core/widgets/` ← `core/format/`).
- [x] `lib/app/core/format/event_date_range.dart` - new pure function `formatEventDateRange(DateTime? start, DateTime? end, {DateTime? now})`. En-dash with spaces, year appended only when needed.
- [x] TDD: same-year both set → `'May 22 – Sep 30'`.
- [x] TDD: cross-year → `'Dec 22, 2026 – Jan 5, 2027'`.
- [x] TDD: same-day collapse → `'May 22'`.
- [x] TDD: null end → single endpoint.
- [x] TDD: null both → empty string.
- [x] TDD: prior-year (`now.year != range.year`) → year appended on both ends.
- [x] `lib/app/core/widgets/event_tile.dart:28-29` - replaced `_dateRange()` body with helper call; dropped `intl` import.
- [x] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart:152,275-292` - deleted `DateFormat.yMMMd()` + the 3-Text em-dash render; replaced with a single Text containing the helper output (calendar icon + sage style preserved). Dropped `intl` import.
- [x] Existing event_tile date-row test - no assertions on date string, no update needed (verified via Grep).
- [x] Verified: `flutter analyze` clean (sole pre-existing warning); `flutter test` 816 / 816 passing (was 810; +6 helper tests).

### Phase 2: Home Upcoming/Past pill centring (req 1) ✓

- **Goal**: Labels visually centred inside equal-width pills.
- [x] TDD: pumped `SegmentedFilterBar(equalWidth: true)` at 375 px; assert `tester.getCenter(find.byKey(pillKey)).dx` matches `tester.getCenter(find.text(label)).dx` within ±1 px for both segments. RED confirmed on the start-aligned state.
- [x] `lib/app/core/widgets/segmented_filter_bar.dart:174` — added `alignment: Alignment.center` to the outer `Container` in `_Pill.build`. Row's `mainAxisSize: min` left untouched (preserves label+count clustering).
- [x] Verified: `flutter analyze` clean; `flutter test` 817 / 817 passing (was 816).

### Phase 3: Event detail Edit Event tile (req 2)

- **Goal**: Admin-only `Edit Event` tile, discoverable, above `Invite Members`.
- [ ] TDD: pump `EventDashboardScreen` with admin uid → `find.byKey(Key('eventDashboard.editEvent.tile'))` resolves; tap → `context.push` reaches `/dashboard/event/<id>/edit` (verify via router seam or navigator spy).
- [ ] TDD: pump with non-admin uid → tile absent.
- [ ] `test/app/features/dashboard/presentation/event_dashboard_screen_admin_edit_tile_test.dart` - new test file.
- [ ] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` - insert new `_QuickLinkCard` above `Invite Members` Consumer (around line 67). Same admin Consumer pattern. Icon `AppIcons.actionEdit`, label `'Edit Event'`, key `eventDashboard.editEvent.tile`, tap → `context.push('/dashboard/event/${event.id}/edit')`.
- [ ] Verify: `flutter analyze` && `flutter test`.

### Phase 4: BalanceTile divider stretches (req 3)

- **Goal**: Divider spans label + amount, not just label height.
- [ ] TDD: extend `test/app/core/widgets/balance_tile_test.dart` — assert divider `RenderBox` height equals parent Row's height (±1 px) for `owedToYou: 0, youOwe: 333.33` case. RED at current 40 px.
- [ ] `lib/app/core/widgets/balance_tile.dart:95-154` - wrap inner Row in `IntrinsicHeight`. Replace lines 125-130 with `VerticalDivider(width: AppSpacing.md * 2 + 1, thickness: 1, color: Theme.of(context).colorScheme.outline)`.
- [ ] Verify: `flutter analyze` && `flutter test`.

### Phase 5: Per-event Budget polish — FAB clearance + AppBar + first-row pad (req 4, 5 Budget, B3)

- **Goal**: Last expense row's 3-dot ≥ 16 px above FAB top; AppBar shows up to 2-line title without clipping; first row not flush with AppBar.
- [ ] TDD: extend `test/app/features/budget/budget_screen_test.dart` AppBar test — assert `title.style.fontSize` matches `titleMedium` + `weight w600`, `maxLines: 2`, `AppBar.toolbarHeight >= 72`.
- [ ] TDD: new test (same file) — render `BudgetScreen` with 10 expenses at iPhone 12 mini viewport, scroll to bottom, assert last `Key('budget.expense.tile.<id>.overflow')` `RenderBox` bottom is ≥ 16 px above FAB `RenderBox` top.
- [ ] `lib/app/features/budget/presentation/budget_screen.dart` - AppBar title swap to `Text(appBarTitle ?? 'Budget', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)`.
- [ ] `lib/app/features/budget/presentation/budget_screen.dart` - AppBar `toolbarHeight: kToolbarHeight + 16`.
- [ ] `lib/app/features/budget/presentation/budget_screen.dart:101-102` - ListView `padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl + AppSpacing.xl + AppSpacing.lg)` (top 16, bottom 88).
- [ ] Verify: `flutter analyze` && `flutter test`.

### Phase 6: Chat AppBar mirror (req 5 Chat)

- **Goal**: Chat detail AppBar follows Budget detail shape — `titleMedium` weight 600, `maxLines: 2`, `toolbarHeight: 72`.
- [ ] TDD: extend `test/app/features/chat/presentation/chat_screen_appbar_title_test.dart` — same three assertions (style, maxLines, toolbarHeight).
- [ ] `lib/app/features/chat/presentation/chat_screen.dart` - swap AppBar title style + add `toolbarHeight: kToolbarHeight + 16`.
- [ ] Verify: `flutter analyze` && `flutter test`.

### Phase 7: ReservedCheckmarkChip widget + TasksFilterBar predicate chips (req 6a)

- **Goal**: Six predicate chips have fixed widths; ✓ fades in/out in reserved 22-px slot.
- [ ] TDD: pump bare `ReservedCheckmarkChip(label: 'Mine', selected: false)` then re-pump `selected: true` — assert chip's `RenderBox` width equal (±0.5 px).
- [ ] TDD: selected → `find.byIcon(Icons.check)` resolves with the chip's foreground colour; unselected → ✓ exists in widget tree (`Visibility` maintainSize) but is not visible (assert via `Visibility.visible == false`).
- [ ] TDD: tap fires `onChanged(!selected)`.
- [ ] TDD: long label ellipsizes; chip width capped at parent constraint.
- [ ] TDD: textScaler 1.3 — pump in `MediaQuery(textScaler: TextScaler.linear(1.3))`; assert no `RenderFlex` exception.
- [ ] `lib/app/core/widgets/reserved_checkmark_chip.dart` - new widget. API per spec. Private const `_reservedSlotWidth = 22.0`. Wraps `InkWell + Container + Row(min) + Visibility(maintainSize,maintainAnimation,maintainState, child: Icon(Icons.check)) + Flexible(Text)`.
- [ ] `test/app/core/widgets/reserved_checkmark_chip_test.dart` - new test file with the five TDD slices above.
- [ ] `lib/app/features/tasks/presentation/widgets/tasks_filter_bar.dart:117-158` - replace each of the six `FilterChip(key, label, selected, onSelected, selectedColor)` calls with `ReservedCheckmarkChip(key: <same>, label: <same>, selected: <same>, onChanged: <same callback shape>, selectedColor: <same>)`. Keys preserved verbatim.
- [ ] Verify: `flutter analyze` && `flutter test` (including `tasks_filter_sort_group_journey_test.dart` — keys preserve, journey stays green).

### Phase 8: SegmentedButton width-locking for group toggle (req 6b)

- **Goal**: Status/People/Due segments stay equal-width across selection. Material visual preserved.
- [ ] TDD: extend `tasks_filter_bar_groupby_overflow_test.dart` — measure each segment's width while cycling `TasksGroupBy` selection. Assert all three widths equal (±0.5 px) for every selection state. RED on current state (Material grows the selected segment to fit the ✓).
- [ ] `lib/app/features/tasks/presentation/widgets/tasks_filter_bar.dart` - extract `_measureText` from `segmented_filter_bar.dart:138-145` OR inline. Pre-compute widest of the three labels at the SegmentedButton's text style. Wrap each `ButtonSegment.label`'s `Text` in `SizedBox(width: widestLabel + 22)` so the Material ✓ slot fits inside the shared width.
- [ ] Verify: `flutter analyze` && `flutter test`.

### Phase 9: Task list empty-state Lottie bypass (req 7, bonus B1)

- **Goal**: Per-event Tasks tab empty states show the tasks icon, not the generic Lottie blob.
- [ ] TDD: extend `test/app/features/tasks/presentation/task_list_screen_test.dart` (or analogue — verify via Glob) — pump filter-empty state, assert `find.byIcon(AppIcons.navTasks)` resolves AND `find.byKey(Key('emptyState.lottie'))` is absent.
- [ ] TDD: same for no-tasks-yet state.
- [ ] `lib/app/features/tasks/presentation/task_list_screen.dart:78-84` - filter-empty branch: add `lottieAsset: null`, change `iconFallback: AppIcons.statusDone` → `AppIcons.navTasks`.
- [ ] `lib/app/features/tasks/presentation/task_list_screen.dart:85-89` - no-tasks-yet branch: same swap.
- [ ] Verify: `flutter analyze` && `flutter test`.

## Risks / Out of scope

- **Risks**:
    - Phase 4's `IntrinsicHeight` introduces an extra layout pass on every BalanceTile rebuild. Acceptable — only 2 columns + 1 divider. Don't expand the wrap.
    - Phase 8's `TextPainter` measurement on every build of `TasksFilterBar` is cheap (3 short strings) but happens on every keystroke in the search field. If the suite gets sluggish, hoist into a `late final` field.
    - Phase 5's `toolbarHeight: 72` makes the Budget AppBar visibly taller — if the design owner objects, fall back to single-line ellipsizing title (spec req 5 alternative path).
    - Phase 7's six `FilterChip` → `ReservedCheckmarkChip` swap changes how Material's chip selectedColor + outline interact. Visual side-by-side test on iPhone 12 mini sim required before PR opens (manual step in `<done_when>` item 9).
- **Out of scope**:
    - Permission-model change for event editing (admin-only stays; spec finding 6 explicit).
    - New AppColors tokens.
    - i18n string changes (other than no-op string literal usage — no key renames).
    - The Phase 6.1 daily-digest preview-tile mentioned in `ai_specs/todo.md` — separate spec.
    - Bonus B1 also affecting global MyTasksScreen — Phase 8 of the 2026-06-08 plan already shipped that fix. Don't re-touch `my_tasks_screen.dart`.
