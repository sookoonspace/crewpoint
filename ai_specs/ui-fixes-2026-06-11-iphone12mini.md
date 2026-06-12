<goal>
Land the second UI polish pass on iPhone 12 mini before the next tester drop. Eight small fixes derived from the 2026-06-11 QA screenshots in `docs/ui_screenshots/iphone12mini_06_11_2026/` — five reported by the product owner plus three I spotted while reviewing the same screenshots. Each fix is small in isolation; together they remove a visible round of friction (lopsided pills, missing affordances, partially-clipped rows) that testers will otherwise report as bugs.

Beneficiaries: testers (cleaner first impression), product owner (fewer trivial tickets), engineering (consistent chip / segment behavior across surfaces — one widget instead of two).
</goal>

<background>
- Stack: Flutter / Dart 3 / Riverpod 3 / go_router; feature-first `lib/app/features/{dashboard,budget,tasks,chat}/{application,data,domain,presentation}`. Tests live alongside under `test/`.
- This pass continues directly from `ai_specs/ui-fixes-2026-06-08-iphone12mini-plan.md` (merged via PR #13). Reuse the patterns landed there — `EmptyStatePlaceholder.lottieAsset: null` to bypass the Lottie, `AppSpacing` tokens, key-stable test selectors, descendant-scoped AppBar finders.
- Files to examine:
    - @docs/ui_screenshots/iphone12mini_06_11_2026/ (all six PNGs).
    - @lib/app/core/widgets/segmented_filter_bar.dart — owns the Upcoming/Past pills used on the home dashboard. `equalWidth: true` is already set; the alignment issue is inside `_Pill`.
    - @lib/app/features/dashboard/presentation/event_dashboard_screen.dart — the per-event hub. Admin-only gear at lines 225-241; need a discoverable body-level entry too.
    - @lib/app/core/widgets/balance_tile.dart:125-130 — fixed-height (40 px) Container divider that the user wants extended.
    - @lib/app/features/budget/presentation/budget_screen.dart:101-173 — per-event Budget body + FAB; needs bottom padding for FAB clearance + AppBar title size adjustment.
    - @lib/app/features/tasks/presentation/widgets/tasks_filter_bar.dart:110-249 — `FilterChip` block + `SegmentedButton` group toggle that both jitter widths on selection.
    - @lib/app/features/chat/presentation/chat_screen.dart — AppBar title shape mirrors Budget; same `Text(appBarTitle ?? ...)` to update for the 2-line wrap (+ `toolbarHeight`).
    - @lib/app/features/tasks/presentation/task_list_screen.dart:76-90 — owns the two `EmptyStatePlaceholder` call-sites the per-event Tasks surface actually renders (the `EventTasksPage` wrapper just hosts state). Both call-sites pass `iconFallback: AppIcons.statusDone` today.
    - @lib/app/features/tasks/presentation/event_tasks_page.dart — wrapper only; no empty-state code here, but worth a read for the `TaskListScreen` plumbing.
    - @lib/app/core/widgets/empty_state_placeholder.dart — for reference, no edit; understand the Lottie + iconFallback fall-through path.
- Date-format current state:
    - Home tile renders `May 22–Sep 30` (en-dash, no year, no comma) — formatter is `_dateRange()` in `lib/app/core/widgets/event_tile.dart:28-35` (NOT under `features/dashboard/`; the tile lives in `core/widgets/`).
    - Event detail card renders `May 22, 2026 — Sep 30, 2026` (em-dash, year, comma) — formatter is in `_EventHero` inside `event_dashboard_screen.dart:153` (`DateFormat.yMMMd()` rendered per-endpoint with a literal `Text('—')` separator at lines 277-305).
- Confirmed by Q&A round 1:
    - Edit permission stays **admin-only** (no permission change). Discoverability fix only.
    - Filter chips / SegmentedButton use a **reserved checkmark slot** (✓ fades in/out at fixed width) — applies to both the predicate-chip block AND the group-by SegmentedButton; build one shared widget.
    - AppBar event title: **smaller font + maxLines: 2**, applied to Budget detail + Chat detail.
    - Three bonus items confirmed in scope: per-event Tasks empty state Lottie, date-separator inconsistency, event Expenses first-row clip.
- Assumptions / gaps:
    - The "scroll-clip" on the event Expenses screen looks like a `ListView` content-padding shortfall; will confirm during plan that no `SliverAppBar` is in play.
    - Existing widget-test files (`tasks_filter_bar_test.dart`, `tasks_filter_bar_groupby_overflow_test.dart`, `budget_screen_test.dart`, `chat_screen_appbar_title_test.dart`) need new assertions, not new files in most cases. The reserved-checkmark behavior may warrant a new `reserved_checkmark_chip_test.dart`.
</background>

<user_flows>
Primary flow (tester walking the build):
1. Open app → Home dashboard.
2. Toggle between Upcoming / Past pills — text is centred, widths stay equal, no visual jitter.
3. Tap an event tile → Event detail screen.
4. As admin: see the explicit "Edit event" body tile under the member preview; tap → existing `EditEventScreen` route opens. As non-admin: tile is hidden (unchanged).
5. Save edits → land back on event detail with terracotta snackbar on failure (unchanged repo path).
6. Open Budget detail for the event → AppBar shows the full event title across up to 2 lines; the BalanceTile vertical divider spans the full label+amount block.
7. Scroll to the bottom of the Expenses list → the last row's 3-dot menu is fully visible above the FAB.
8. Open Tasks for the event → filter chips and Status/People/Due segments have fixed widths; tapping a chip flips its leading ✓ on/off without resizing.
9. Apply filters until empty → empty state shows the tasks icon (not the generic Lottie blob) + "Clear filters" CTA.

Alternative flows:
- Tester opens chat detail → AppBar follows the same 2-line/smaller-font shape as Budget detail.
- Tester is the event owner (admin by definition) → both the existing gear icon AND the new body-level edit tile are visible; either entry navigates to the same `/dashboard/event/:eventId/edit` route.
- Long event titles (`"Q3 leadership offsite Nov 2026"`) wrap to 2 lines in the AppBar without overflow exceptions.

Error flows:
- Edit-event submit fails → existing `_EditEventRouteScreen` terracotta snackbar (unchanged).
- Date-format `null` startDate or endDate → the renamed `formatEventDateRange` helper returns the existing fallback (e.g., empty string or "No date"); covered by a unit test pinning the null-input shape.
</user_flows>

<requirements>
**Functional:**

1. **Home Upcoming/Past pills — centred text inside fixed-width pills.** `_Pill` inside `lib/app/core/widgets/segmented_filter_bar.dart` must centre its label horizontally when the parent uses `equalWidth: true`. Pill widths remain equal (already correct); label sits in the middle of the pill, not flush-left. **Implementation choice**: set `alignment: Alignment.center` on the outer `Container` (smallest diff; preserves the existing `Row(mainAxisSize: min)` clustering between label + optional count). Do NOT mutate the Row's `mainAxisSize` / `mainAxisAlignment` — that path requires two changes to achieve what `Container.alignment` does in one.

2. **Event detail — admin-discoverable "Edit event" body tile.** Add a `_QuickLinkCard`-shaped tile in `event_dashboard_screen.dart`, gated on `event.isAdmin(uid)` (same Consumer pattern as the existing `Invite Members` tile at lines 67-100). Tap navigates to `/dashboard/event/${event.id}/edit`. Keep the existing top-right gear icon — they're additive, not alternatives.
    - **Order**: Edit Event tile renders **above** Invite Members (manage existing config → then invite new people).
    - **Icon**: `AppIcons.actionEdit` (the project's edit-pencil token).
    - **Label**: `'Edit Event'`.
    - **Stable Key**: `eventDashboard.editEvent.tile`.

3. **Budget BalanceTile — divider stretches to content height.** In `lib/app/core/widgets/balance_tile.dart`, replace the fixed-height (40 px) Container divider at lines 125-130 with a layout that wraps the parent Row in `IntrinsicHeight` and uses a `VerticalDivider` (or stretched Container) so the line spans the full content from the label down through the amount row. No spacing / colour changes.

4. **Per-event Expenses — FAB no longer occludes the last row's 3-dot menu.** Add bottom padding to the body `ListView` in `budget_screen.dart` of `AppSpacing.xxxl + AppSpacing.xl + AppSpacing.lg = 48 + 24 + 16 = 88 px`. Math: standard Material `FloatingActionButton` is 56 px diameter; default `endFloat` floats it 16 px above the Scaffold body bottom → FAB top edge sits at `scaffold_bottom − 72 px`. 88 px of ListView padding clears the FAB top by 16 px, matching the breathing-room buffer used elsewhere. Anything less than 72 px would silently re-introduce the bug.

5. **Per-event AppBar title — smaller font + 2-line wrap.** In `BudgetScreen.appBar` and `ChatScreen.appBar`:
    - Title widget: `Text(appBarTitle ?? '<default>', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)`.
    - `AppBar.toolbarHeight: kToolbarHeight + 16` (≈ 72 px). Material's default `kToolbarHeight = 56` will clip the second line of a wrapped title; explicit `toolbarHeight` is required, NOT optional. Verified by computing `titleMedium` 2-line height (~48 px) + AppBar vertical insets (~16 px) > 56 px.
    - Apply this shape symmetrically to both surfaces so the chrome stays consistent.

6. **Tasks filter chips + group-by segments — reserved-checkmark layout.** Two surfaces, two implementations:

    **6a — Predicate chips (Mine / Overdue / Has budget / To Do / In Progress / Done):**
    Build a shared `ReservedCheckmarkChip` widget in `lib/app/core/widgets/` used in place of the Material `FilterChip` calls in `TasksFilterBar:117-158`. Each chip always reserves a leading-icon slot of fixed width:
    - **Reserved-slot width**: `IconTheme.iconSize` (default 18 px on the project's theme) + `AppSpacing.xs` (4 px) gap = **22 px**. Express as a named private const inside the widget (`static const _reservedSlotWidth = 22.0;`).
    - Selected: solid `Icons.check` in the foreground colour.
    - Unselected: invisible placeholder of the same width via `Visibility(visible: selected, maintainSize: true, maintainAnimation: true, maintainState: true, child: Icon(Icons.check))`.
    - Chip width stays constant across selected/unselected for the same label.

    **6b — Group toggle (Status / People / Due):**
    KEEP Material's `SegmentedButton` (preserves the connected-pill visual the screenshot shows). Lock segment widths by wrapping each segment's label in a `SizedBox(width: <measured>)` so the implicit checkmark slot growth is absorbed by the label box, not the segment. Concretely:
    - Pre-measure the widest label at the SegmentedButton's text style via `TextPainter` (same `_measureText` helper pattern that already exists in `SegmentedFilterBar:138-145` — extract or duplicate).
    - Wrap each `ButtonSegment.label` in `SizedBox(width: measuredWidest + _reservedSlotWidth)` so all three segments share the same label-box width regardless of selection.
    - Keep `SegmentedButton.showSelectedIcon: true` (default); Material draws the ✓ inside the now-reserved slot.

    All existing test keys are preserved verbatim (`tasks.list.filterChip.{mine, overdue, hasBudget, todo, inProgress, done}` + `tasks.list.groupToggle{,.status,.assignee,.dueWindow}`). The journey test `test/journeys/tasks_filter_sort_group_journey_test.dart` taps segments by **Key** (verified at line 129), not by text — so the chip + segment changes preserve compatibility automatically.

7. **Per-event Tasks empty state — bypass the generic Lottie.** In `lib/app/features/tasks/presentation/task_list_screen.dart`, BOTH `EmptyStatePlaceholder` call-sites (lines 78-84 for the filter-empty case AND lines 85-89 for the no-tasks-yet case) pass `lottieAsset: null` and `iconFallback: AppIcons.navTasks` — same shape as Phase 8 used for `my_tasks_screen.dart`. The wrapper `event_tasks_page.dart` is not the right edit point; it has no empty-state code of its own.

8. **Date-format consistency across Home tile + event detail card.** Introduce a single `formatEventDateRange(DateTime? start, DateTime? end, {DateTime? now})` helper at `lib/app/core/format/event_date_range.dart`. **The helper MUST live under `core/` not `features/dashboard/`** because one of the two consumers (`lib/app/core/widgets/event_tile.dart`) is itself in `core/widgets/`; a `features/` import would violate the layered dependency direction (`core/` cannot depend on `features/`).
    The returned shape matches the home tile today: `"MMM d – MMM d"` (en-dash, no year, no comma) when both endpoints are in the same calendar year as `now`; appends `", yyyy"` only when the range spans years OR the year ≠ `now.year`. Both the home `event_tile.dart` formatter and the `event_dashboard_screen.dart` `_EventHero` formatter (which currently renders an em-dash separator + per-endpoint `yMMMd`) call this helper. Removes the per-surface divergence.

9. **Event Expenses screen — first row no longer clips under the AppBar.** Add top padding (`AppSpacing.lg` = 16 px) to the scrollable body in the relevant `budget_screen.dart` ListView so the first row's top edge sits below the AppBar shadow boundary on initial scroll position. Confirm during plan that this is a `ListView` padding shortfall rather than a `SliverAppBar` over-extension.

**Error Handling:**

10. **Edit-event submit failure** unchanged — `_EditEventRouteScreen` already surfaces a terracotta snackbar on `updateEvent` returning false.
11. **Reserved-checkmark chip with very long labels** must still ellipsize the label, not the checkmark slot. `Text(..., maxLines: 1, overflow: TextOverflow.ellipsis)` and `Flexible` over the label; the icon slot is non-flex.
12. **Date formatter on null/partial inputs** — when both endpoints are null returns the empty string; when only `start` is set returns `"From <MMM d>"` (or whatever shape matches today's home-tile fallback — pin during plan via the existing test of `event_tile.dart`'s date row).

**Edge Cases:**

13. **Cross-year ranges** (`May 22, 2026 – Jan 5, 2027`) — helper appends `, yyyy` to both endpoints. Lock with a unit test.
14. **Same-day ranges** (`May 22 – May 22`) — helper collapses to single date (`"May 22"`). Lock with a unit test.
15. **Reserved-checkmark chip layout under text scaling** — chip must not overflow at `MediaQuery.textScaler.scale(1.3)`. Lock with a widget test pumping the bar at that scale and asserting no exceptions.
16. **Long event title (≥ 25 chars)** in AppBar — wraps to exactly 2 lines, ellipsizes after; no `RenderFlex` overflow exception.
17. **Edit tile visibility race** — the `Consumer(builder: ...)` reading `currentUserIdProvider` may briefly return `null` during sign-in flow; tile renders `SizedBox.shrink()` (same pattern as the gear icon).

**Validation:**

18. **Input constraints** — none new; all changes are pure presentation. Test inputs are existing model fixtures + the new date formatter's pure-function inputs.
</requirements>

<boundaries>
Edge cases:
- BalanceTile under `IntrinsicHeight` with mixed-currency disclaimer below: the disclaimer is OUTSIDE the IntrinsicHeight wrapper; its layout must not be affected (already-passing `balance_tile_test.dart` cases must stay green).
- ReservedCheckmarkChip at 320 px ultra-narrow viewport (older iPhone SE simulations): chips wrap to multiple rows via the existing `Wrap` — width remains fixed per chip but layout may stack vertically; widget test covers this.
- Event detail edit tile placement when there's NO event description: the existing `if (event.description != null && event.description!.isNotEmpty) ...` block is skipped; the edit tile still renders directly under the Members preview. Verify by pumping with a null-description event.
- Date-range helper called with a `start` that's later than `end` (data anomaly): helper still returns the formatted range — order preserved as given; don't validate in the formatter.

Error scenarios:
- `updateEvent` fails after the new edit-tile tap → existing terracotta snackbar covers it.
- Layout exception while wrapping AppBar title to 2 lines: caught by widget test pumping the screen at iPhone 12 mini viewport with a 40-char title.
- Reserved-checkmark chip layout under heavy text-scaling: caught by the textScaler widget test.

Limits:
- AppBar title — capped at 2 lines via `maxLines`. 3-line+ titles ellipsize. Toolbar height pinned at `kToolbarHeight + 16` (= 72 px) so the second line is never clipped.
- Reserved-checkmark slot — fixed width `_reservedSlotWidth = 22.0` (= default `IconTheme.iconSize` 18 + `AppSpacing.xs` 4). Expressed as a private static const inside `ReservedCheckmarkChip`. Never grows with label length.
- SegmentedButton group toggle — labels share width via `SizedBox(width: measuredWidest + 22)`; widths are stable across selection and across translated labels (re-measured on each build via `TextPainter`).
- IntrinsicHeight has a one-pass intrinsic measurement cost. Acceptable here because the BalanceTile has only 2 children (label-column + divider + amount-column). Don't propagate to deeper trees.
</boundaries>

<implementation>
Files to create:

- `lib/app/core/widgets/reserved_checkmark_chip.dart` — shared chip widget consumed by `TasksFilterBar` predicate chips (req 6a; not used by the group toggle, which keeps Material's `SegmentedButton` per req 6b). Public API: `ReservedCheckmarkChip({required Key key, required String label, required bool selected, required ValueChanged<bool> onChanged, Color? selectedColor})`. Uses `InkWell + Container + Row + Visibility(maintainSize: true, child: Icon(Icons.check)) + Flexible(Text)`. Private const `_reservedSlotWidth = 22.0` (= default IconTheme.iconSize 18 + AppSpacing.xs 4).

- `lib/app/core/format/event_date_range.dart` — pure function `String formatEventDateRange(DateTime? start, DateTime? end, {DateTime? now})`. `now` for testability via `clock` / explicit injection. Lives under `core/`, NOT `features/dashboard/`, so the `lib/app/core/widgets/event_tile.dart` consumer doesn't import across layers.

- `test/app/core/widgets/reserved_checkmark_chip_test.dart` — selected vs unselected width parity, checkmark visibility, tap callback firing, label ellipsis, textScaler 1.3 no-overflow.

- `test/app/core/format/event_date_range_test.dart` — current-year shape, cross-year shape, same-day collapse, null-end fallback, null-both fallback, `now`-year boundary.

Files to modify:

- `lib/app/core/widgets/segmented_filter_bar.dart` — `_Pill` build: add `alignment: Alignment.center` to the outer `Container`. **Do not** mutate the Row's `mainAxisSize` / `mainAxisAlignment`; one-line Container fix is sufficient and preserves the existing label+count clustering. Keep default scrolling-mode behavior unchanged.

- `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — insert `_QuickLinkCard` for `Edit Event` directly **above** the existing `Invite Members` tile (lines 67-100). Same admin Consumer pattern. Icon: `AppIcons.actionEdit`. Label: `'Edit Event'`. Key: `eventDashboard.editEvent.tile`. Tap: `context.push('/dashboard/event/${event.id}/edit')`.

- `lib/app/core/widgets/balance_tile.dart:95-154` — wrap inner Row in `IntrinsicHeight`; replace lines 125-130 with a stretched divider (`VerticalDivider(width: AppSpacing.md * 2 + 1, thickness: 1, color: Theme.of(context).colorScheme.outline)`).

- `lib/app/features/budget/presentation/budget_screen.dart` — (a) bottom-pad the body ListView by `AppSpacing.xxxl + AppSpacing.xl + AppSpacing.lg = 88 px` (FAB-clearance math in req 4); (b) add top padding of `AppSpacing.lg` if it's missing (bonus B3); (c) AppBar title → `titleMedium` weight 600 with `maxLines: 2`; (d) AppBar `toolbarHeight: kToolbarHeight + 16` (= 72 px) so the wrapped second line isn't clipped.

- `lib/app/features/chat/presentation/chat_screen.dart` — AppBar title + `toolbarHeight` mirroring Budget detail.

- `lib/app/features/tasks/presentation/widgets/tasks_filter_bar.dart:110-249` — replace the six Material `FilterChip` calls (lines 117-158) with `ReservedCheckmarkChip` (keys preserved). KEEP the `SegmentedButton<TasksGroupBy>` (lines 217-246) but wrap each `ButtonSegment.label` in a `SizedBox(width: <pre-measured widest + reserved slot>)` so segment widths stay constant across selection. Keys for the three segments stay `tasks.list.groupToggle.{status,assignee,dueWindow}`.

- `lib/app/features/tasks/presentation/task_list_screen.dart:78-89` — both `EmptyStatePlaceholder` call-sites (filter-empty + no-tasks-yet) pass `lottieAsset: null` and `iconFallback: AppIcons.navTasks`.

- The two date-render call sites — `lib/app/core/widgets/event_tile.dart:28-35` (home tile `_dateRange()`) and `lib/app/features/dashboard/presentation/event_dashboard_screen.dart:153,277-305` (`_EventHero` formatter + the in-row em-dash separator) — both call the new `formatEventDateRange` helper. Inline formatters deleted; the em-dash literal `Text('—')` in `_EventHero` is replaced by the single-string return from the helper. Existing tests updated to the new shared shape.

Patterns to reuse:

- `Visibility(maintainSize: true, ...)` for reserved-icon slots — standard Material pattern.
- Phase 5 + Phase 8 patterns from the 2026-06-08 PR (descendant-scoped AppBar finders; `lottieAsset: null` empty-state bypass; key-stable assertions).
- `IntrinsicHeight + VerticalDivider` for stretched dividers — standard Flutter idiom.

What to avoid (and why):

- Don't extend `Material FilterChip` with workarounds — its checkmark behavior is hard-coded. Build a thin custom widget instead.
- Don't touch the `TasksGroupBy` enum or any of the `tasks.list.*` keys — journey tests and the Phase 2 overflow test depend on them.
- Don't propagate `IntrinsicHeight` into the parent BalanceTile card — only wrap the inner `Row`. Wider use risks N² intrinsic computations.
- Don't introduce a new `AppColors` token for the chip's "unselected-but-reserved-slot" state — reuse `colorScheme.onSurfaceVariant` (or transparent) for the placeholder.
- Don't make the Edit Event tile a destructive action (terracotta) — it's a navigation seam; reuse the same neutral chrome as the existing `_QuickLinkCard` family.
- Don't widen the date-range helper into a generic date utility — keep it scoped to event ranges; new shapes get their own helpers.
</implementation>

<validation>
Baseline automated coverage required (logic + UI + critical journeys):

- **Logic / pure functions:** `formatEventDateRange` covered by `date_range_format_test.dart` — six behaviors: same-year both set; cross-year; same-day collapse; null end; null both; year-equal-to-`now`.year vs prior year.
- **Widget behavior:**
    - `reserved_checkmark_chip_test.dart` — width parity selected vs unselected (within 0.5 px); checkmark `find.byIcon(Icons.check)` matches `findsOneWidget` when selected, `findsNothing` when not (assert on the `Icon` itself, not on hidden / Visibility states); tap callback fires with the inverted `selected` value; label ellipsizes when constrained narrow; no overflow at `MediaQuery.textScaler` factor 1.3.
    - `balance_tile_test.dart` — extend with an `IntrinsicHeight`-driven assertion that the divider's render-box height equals the parent Row's height (within ±1 px), AND that the existing single-line "all settled" hero case still renders. RED → GREEN: assert divider height first to confirm the current 40 px state fails the new contract.
    - `tasks_filter_bar_test.dart` — extend the existing `'group toggle changes groupBy'` test with a width assertion: select Status, capture width of the People segment; select People, recapture the same segment's width; they must match (Phase 2's bar-level test stays, but this adds a per-segment assertion).
    - `budget_screen_test.dart` — extend the existing AppBar-title test with: title style is `titleMedium`-weighted (assert via `Text` widget's resolved style), `maxLines: 2`, AND `AppBar.toolbarHeight ≥ 72`. New widget test for FAB clearance — render with a long expense list, scroll to bottom, assert the last `Key('budget.expense.tile.<id>.overflow')` `RenderBox` bottom edge sits ≥ 16 px above the FAB's `RenderBox` top edge (matches the 88-px ListView bottom-pad math in req 4).
    - `chat_screen_appbar_title_test.dart` — mirror the Budget title-style assertions.
    - New `event_dashboard_admin_edit_tile_test.dart` — pump the screen with an admin uid → tile renders; with a non-admin uid → `SizedBox.shrink` (tile absent).
- **Journey coverage:** `tasks_filter_sort_group_journey_test.dart` runs unchanged. The reserved-checkmark chip swap MUST NOT break the existing journey. New journey test NOT required — the existing journey + the new widget tests for the chip cover the contract together. **Pre-verified compatibility**: the journey taps segments by Key (`find.byKey(Key('tasks.list.filterChip.overdue'))` at `test/journeys/tasks_filter_sort_group_journey_test.dart:105` and `Key('tasks.list.groupToggle.assignee')` at line 129), not by text. Since req 6 preserves all `tasks.list.*` keys verbatim, the journey survives the chip + segment changes automatically. Document this verification in the plan.

TDD-first slices (vertical RED → GREEN → REFACTOR, one behavior at a time):

- Slice 1 (pure logic): `formatEventDateRange` same-year-both-set → cross-year → null-end → null-both → same-day. One RED per behavior; minimal pure-function code to GREEN.
- Slice 2 (widget): `ReservedCheckmarkChip` selected vs unselected width equality → tap callback → ellipsis under narrow constraint → no-overflow at textScale 1.3.
- Slice 3 (widget): BalanceTile divider stretches with content (single failing assertion → IntrinsicHeight wrap).
- Slice 4 (widget): BudgetScreen + ChatScreen AppBar titleMedium + maxLines: 2 (paired tests, one RED at a time per surface).
- Slice 5 (widget): admin-only Edit Event tile presence / absence (RED on presence first; permission gate added with the source change).
- Slice 6 (widget): SegmentedFilterBar `_Pill` centred label — RED via a layout-position assertion on the label's `RenderBox` centre; GREEN via the `MainAxisAlignment.center` change.
- Slice 7 (presentation glue): Tasks filter bar uses `ReservedCheckmarkChip` for all six predicates + three group segments; covered by the existing `tasks_filter_bar_test.dart` once chips are swapped (preserve keys; tests stay structurally green after the swap).
- Slice 8 (presentation glue): Date-format helper consumed by both call-sites; the existing event-tile date-row test updates to the new shape.
- Slice 9 (presentation glue): Event Tasks empty-state Lottie bypass — covered by extending `event_tasks_page_test.dart` (verify name during plan) with an `find.byIcon(AppIcons.navTasks)` assertion analogous to Phase 8.

Testability seams (must be in place before implementation):

- `formatEventDateRange` takes an explicit `now` named parameter so cross-year tests are deterministic; production callers pass `DateTime.now()`.
- `ReservedCheckmarkChip` exposes `onChanged: ValueChanged<bool>` (boolean toggle) so widget tests assert the callback shape without needing a model.
- Admin-edit-tile reads `currentUserIdProvider` via the existing `Consumer` builder pattern; widget tests override the provider value (existing pattern in `event_dashboard_screen_test.dart` if present, else new test follows the same shape as Phase 5's chat AppBar test).

Mocking policy:

- Prefer fakes over mocks throughout. No external boundaries are crossed in these changes (no Firestore writes, no CFs). All providers overridden in widget tests via `ProviderScope.overrides` — existing project pattern.

Test-type mapping (default):

- **Robot/journey:** none new. The existing `tasks_filter_sort_group_journey_test.dart` happy path covers the cross-screen Tasks flow and must remain green after the chip swap.
- **Widget tests:** the per-screen edge cases, AppBar style, chip-width parity, admin-tile visibility, divider stretch, FAB clearance, empty-state icon.
- **Unit tests:** `formatEventDateRange`.

Exceptions / deviations from strict TDD:

- The visual-only `MainAxisAlignment.center` change on the home pills can land with one positional widget-test assertion rather than a full RED → GREEN cycle, since the contract is "label rendered at the centre of the pill box" and the assertion shape is the same as the failing state's shape.
- The date-format consolidation has TWO call-sites; the second call-site swap is plumbing (no new behavior), so a single shared-helper test covers both. Document this in the plan.
</validation>

<done_when>

1. All requirements 1-9 implemented and committed on a feature branch (`fix/ui-polish-2026-06-11`).
2. `flutter analyze` clean (sole pre-existing `experimental_member_use` warning permitted).
3. `flutter test` 100% passing (current baseline 810 / 810; expect modest growth from new widget + unit tests).
4. `tasks_filter_sort_group_journey_test.dart` passes unchanged after the chip swap.
5. New widget tests for: reserved-checkmark chip, admin edit tile, BalanceTile divider stretch, FAB clearance.
6. New unit tests for: `formatEventDateRange` (five behaviors minimum).
7. The `ai_specs/todo.md` P2 backlog updated to reflect any items that surface during implementation but get deferred (e.g., the BalanceTile fix may surface a related ratio-bar-spacing question — record, don't expand scope).
8. Plan file references this spec via the `**Spec**:` header so the `/act:workflow:work` tooling can pick it up.
9. Manual verification (recorded in the PR description's Test Plan) at iPhone 12 mini sim, dark mode:
    - Home: Upcoming/Past pills equal-width, text centred (via `Container.alignment`).
    - Event detail (as admin): `Edit Event` tile renders **above** the `Invite Members` tile, both gated by `event.isAdmin(uid)`; tap → form opens. Icon = `AppIcons.actionEdit`.
    - Event detail (as non-admin): neither Edit Event nor Invite Members tile renders; gear icon also absent.
    - Budget detail: AppBar shows full event title on up to 2 lines; second line is NOT clipped (toolbar height ≥ 72 px). BalanceTile divider spans full content height. Bottom-most expense row's 3-dot menu sits ≥ 16 px above the FAB top edge.
    - Chat detail: same AppBar shape as Budget detail.
    - Tasks: filter chip widths stay constant on tap; ✓ flips visibility via reserved slot. SegmentedButton (Status / People / Due) widths stay constant across selection via `SizedBox`-wrapped labels.
    - Tasks empty state (apply filters until empty): tasks icon (not Lottie blob); "Clear filters" CTA. Same behavior on the no-tasks-yet empty state.
    - Home tile + event detail card show the same date-range format (`MMM d – MMM d` with year only when needed).
10. Bonus item B3 (Expenses first-row clip) verified resolved with the body padding fix at the same viewport.

</done_when>
