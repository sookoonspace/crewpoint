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

### Phase 3: Event detail Edit Event tile (req 2) ✓

- **Goal**: Admin-only `Edit Event` tile, discoverable, above `Invite Members`.
- [x] TDD (3 cases): admin uid → tile renders + `'Edit Event'` label visible; non-admin uid → absent; null uid → absent. RED on the present case before source edit.
- [x] `test/app/features/dashboard/presentation/event_dashboard_screen_admin_edit_tile_test.dart` — new test file using `ProviderScope.overrides` for `currentUserIdProvider`. `creatorId` field on `EventModel` drives `isAdmin`.
- [x] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart:67-94` — inserted new admin-gated `Consumer + _QuickLinkCard` directly above the existing `Invite Members` tile. Icon: `AppIcons.actionEdit`. Label: `'Edit Event'`. Subtitle: `'Update title, dates, or details'`. Color: `AppColors.sage` (neutral, distinguishes from the terracotta `Invite Members`). Key: `eventDashboard.editEvent.tile`. Tap → `context.push('/dashboard/event/${event.id}/edit')`.
- [x] Verified: `flutter analyze` clean; `flutter test` 820 / 820 passing (was 817; +3 new admin-tile tests).

### Phase 4: BalanceTile divider stretches (req 3) ✓

- **Goal**: Divider spans label + amount, not just label height.
- [x] Added a stable Key `balance.tile.divider` to the divider Container (so the test can locate it). RED via `dividerHeight > 50` for `owedToYou: 0, youOwe: 333.33` — failed at 40 px on the pre-fix state.
- [x] `lib/app/core/widgets/balance_tile.dart:95-159` — wrapped inner Row in `IntrinsicHeight`, switched `crossAxisAlignment` to `stretch`, replaced the fixed-height Container with `VerticalDivider(width: AppSpacing.md * 2 + 1, thickness: 1, color: theme.colorScheme.outline)` carrying the same Key.
- [x] Verified: `flutter analyze` clean; `flutter test` 821 / 821 passing (was 820).

### Phase 5: Per-event Budget polish — FAB clearance + AppBar + first-row pad (req 4, 5 Budget, B3) ✓

- **Goal**: Last expense row's 3-dot ≥ 16 px above FAB top; AppBar shows up to 2-line title without clipping; first row not flush with AppBar.
- [x] TDD (AppBar): extended `budget_screen_test.dart` — assert `Text.maxLines == 2` and `AppBar.toolbarHeight >= 72`. RED before source edit.
- [x] TDD (FAB clearance): structural assertion `ListView.padding.bottom >= 88` (= FAB diameter 56 + endFloat margin 16 + breathing 16). Switched from spatial test after discovering the iOS-target default bouncing scroll physics overshoots and bounces back from `maxScrollExtent`, leaving the list ~80 px short of true end and producing false negatives. The structural test pins the contract; the Scaffold FAB position is constant.
- [x] `lib/app/features/budget/presentation/budget_screen.dart:68-78` — AppBar title swapped to `Text(appBarTitle ?? 'Budget', style: titleMedium w600, maxLines: 2, overflow: ellipsis)` + `toolbarHeight: kToolbarHeight + 16` (= 72).
- [x] `lib/app/features/budget/presentation/budget_screen.dart:111-119` — ListView `padding: EdgeInsets.fromLTRB(lg, lg, lg, xxxl + xl + lg)` (top 16 carries bonus B3; bottom 88 carries the FAB-clearance fix).
- [x] Verified: `flutter analyze` clean; `flutter test` 823 / 823 passing (was 821; +2 new tests).

### Phase 6: Chat AppBar mirror (req 5 Chat) ✓

- **Goal**: Chat detail AppBar follows Budget detail shape — `titleMedium` weight 600, `maxLines: 2`, `toolbarHeight: 72`.
- [x] TDD: extended `chat_screen_appbar_title_test.dart` with the same shape assertion used for Budget (maxLines == 2, toolbarHeight >= 72). RED before source edit.
- [x] `lib/app/features/chat/presentation/chat_screen.dart:102-115` — swapped AppBar title to `titleMedium w600`, `maxLines: 2`, `toolbarHeight: kToolbarHeight + 16`. Symmetric with `budget_screen.dart`.
- [x] Verified: `flutter analyze` clean; `flutter test` 824 / 824 passing (was 823).

### Phase 7: ReservedCheckmarkChip widget + TasksFilterBar predicate chips (req 6a) ✓

- **Goal**: Six predicate chips have fixed widths; ✓ fades in/out in reserved 22-px slot.
- [x] `lib/app/core/widgets/reserved_checkmark_chip.dart` — new shared widget. API: `(label, selected, onChanged, selectedColor?)`. Private const `_reservedSlotWidth = 22.0` (= `IconTheme.iconSize` 18 + `AppSpacing.xs` 4). Structure: `InkWell + Container + Row(min) + SizedBox(22) + Visibility(maintainSize,maintainAnimation,maintainState, child: Icon(Icons.check)) + Flexible(Text)`.
- [x] TDD (5 slices): width parity selected vs unselected (± 0.5 px); ✓ visible-vs-invisible-but-maintain-size; tap fires `onChanged(!selected)`; long label ellipsizes at narrow constraint; no overflow at `MediaQuery.textScaler 1.3`. All 5 GREEN.
- [x] `test/app/core/widgets/reserved_checkmark_chip_test.dart` — 5 tests, one per contract slice.
- [x] `lib/app/features/tasks/presentation/widgets/tasks_filter_bar.dart:117-158` — replaced all six Material `FilterChip` calls with `ReservedCheckmarkChip`. Keys preserved verbatim (`tasks.list.filterChip.{mine,overdue,hasBudget,todo,inProgress,done}`). Callback names normalised from `onSelected: ...` → `onChanged: ...` per the new widget's API.
- [x] Verified: `flutter analyze` clean; `flutter test` 829 / 829 passing (was 824; +5 new chip tests). Journey test `tasks_filter_sort_group_journey_test.dart` survives the swap unchanged — Key-by-Key selection confirms the contract holds.

### Phase 8: SegmentedButton width-locking for group toggle (req 6b) ✓

- **Goal**: Status/People/Due segments stay equal-width across selection. Material visual preserved.
- [x] TDD: extended `tasks_filter_bar_groupby_overflow_test.dart` — cycled all 3 `TasksGroupBy` selection states, captured each segment's width by Key, asserted per-slot widths within 0.5 px. RED before source edit (60.33 vs 90.33 spread = 30 px).
- [x] **Approach pivot from the spec**: tried the spec's `SizedBox(width: widest + 22)` first; Material's `showSelectedIcon: true` still allocates the ✓ slot OUTSIDE the SizedBox, so the segment intrinsic width still differed by ~30 px between selected/unselected. Switched to: `SegmentedButton(showSelectedIcon: false)` + a new private `_GroupSegmentLabel` widget that renders our own ✓ via `Visibility(maintainSize)` inside a fixed-width `SizedBox`, same shape as `ReservedCheckmarkChip` from Phase 7. Material's connected-pill visual is preserved (segments stay touching with a single border) — only the ✓ delivery mechanism changes.
- [x] `lib/app/features/tasks/presentation/widgets/tasks_filter_bar.dart` — added `_groupSegmentSlotWidth(context, strings)` helper (TextPainter-measures widest label at `labelLarge` style, returns `widest + 22`). Each `ButtonSegment.label` now wraps `_GroupSegmentLabel(label, selected, width)`. Keys moved from inner Text to outer `_GroupSegmentLabel`. Journey test taps by Key → continues to work.
- [x] Verified: `flutter analyze` clean (sole pre-existing warning); `flutter test` 830 / 830 passing (was 829; +1 width-parity test). Journey test `tasks_filter_sort_group_journey_test.dart` passes unchanged.

### Phase 9: Task list empty-state Lottie bypass (req 7, bonus B1) ✓

- **Goal**: Per-event Tasks tab empty states show the tasks icon, not the generic Lottie blob.
- [x] TDD (filter-empty): extended `test/app/features/tasks/task_list_screen_test.dart` — pump with `TasksFilter(onlyMine: true)` + empty groups; assert `find.byIcon(AppIcons.navTasks)` and `find.byKey(Key('emptyState.lottie'))` absent. RED before source edit.
- [x] TDD (no-tasks-yet): same assertion shape with `TasksFilter()` (default).
- [x] `lib/app/features/tasks/presentation/task_list_screen.dart:77-94` — both `EmptyStatePlaceholder` call-sites updated: added `lottieAsset: null`, changed `iconFallback: AppIcons.statusDone` → `AppIcons.navTasks`. Mirrors Phase 8 of the 2026-06-08 plan for the global Tasks tab.
- [x] Verified: `flutter analyze` clean; `flutter test` 832 / 832 passing (was 830; +2 new icon-bypass tests).

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
