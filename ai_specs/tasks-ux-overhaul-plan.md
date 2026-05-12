## Overview

Tasks UX overhaul: form-kit foundation → remaining kit widgets → data-layer fix + pure functions → tile redesign → screen overhaul → form redesign + Duplicate. Phase 1 = `AppFormSection` + `AppTextField` end-to-end through one Tasks screen, proving the wrapper-keeps-29-callsites-intact contract before scaling.

**Spec**: `ai_specs/tasks-ux-overhaul-spec.md` (numbered refs below match spec)

## Context

- **Structure**: feature-first under `lib/app/features/<feature>/{data,domain,application,presentation}`. New kit at `lib/app/core/widgets/forms/`.
- **State management**: Riverpod 3. Page state for filter/sort/group is plain `setState` on `EventTasksPage` (session-only per spec).
- **Reference implementations**:
  - `lib/app/core/widgets/custom_text_field.dart` — current text-field shape; preserve every parameter.
  - `lib/app/features/budget/application/pending_settlement_notifier.dart` — `clock.now()` injection pattern.
  - `lib/app/features/tasks/data/task_repository.dart` — Firestore-Write / Drift-Read pattern + `WriteBatch` will plug in.
  - `lib/app/core/i18n/app_strings.dart` — `AppStrings` + sub-object pattern (`AuthStrings`, `ErrorStrings`). Add `TasksStrings`.
- **User critical instructions (non-negotiable)**:
  - CI1: **Zero edits to 29 existing `CustomTextField` callsites.** Wrapper class only. `flutter analyze` must stay clean on all 29 files without touching them.
  - CI2: **`AppDateField` uses `LayoutBuilder` + `Breakpoints.compactMax`** for inline-vs-modal cutover. NEVER `kIsWeb` — web at narrow widths must still get the modal.
  - CI3: **`clock.now()` for every overdue / due-window calc** so `withClock(Clock.fixed(...))` freezes time in tests.
- **Assumptions/Gaps**:
  - `TaskChecklistItemsDao` already mirrors items locally (v4 migration); just needs an `itemsByEventId(String)` batched fetch helper.
  - `TasksStrings` is net-new in `app_strings.dart` (no existing tasks sub-object). Add as a peer of `AuthStrings`/`ErrorStrings` with `_EnglishTasksStrings` impl.
  - `Breakpoints.compactMax = 600.0` already exists — reuse, do NOT add `wideMin`.

## Plan

### Phase 1: Form-kit foundation slice ✓

- **Goal**: Ship `AppFormSection` + `AppTextField` + the deprecated `CustomTextField` wrapper end-to-end. Prove zero churn on 29 callsites by analyzing the whole repo after the wrapper lands.
- [x] `lib/app/core/widgets/forms/app_form_section.dart` — `title`, optional `helperText`, `child` column; spacing scaled via `AppSpacing.xs`/`AppSpacing.md` between title/helper/child (spec req 9)
- [x] `lib/app/core/widgets/forms/app_text_field.dart` — `StatelessWidget` composed via `Focus` + `Builder` reading `Focus.of(ctx).hasFocus`; superset of `CustomTextField` params + additive `labelText/helperText/errorText/maxLength/autofocus`; subtle sage 2-px outer outline only when `kIsWeb` AND focused (spec req 2)
- [x] `lib/app/core/widgets/custom_text_field.dart` — converted to `StatelessWidget` thin wrapper delegating to `AppTextField`; `@Deprecated('Use AppTextField from lib/app/core/widgets/forms/app_text_field.dart')`; every existing constructor param + default preserved (spec req 3, CI1)
- [x] `lib/app/core/i18n/app_strings.dart` — added `abstract class TasksStrings` + `_EnglishTasksStrings` peer with three V1 section-title fields (Details / Assignment / Timing & Budget) (boundary i18n contract)
- [x] TDD: `AppTextField` renders validator error after `Form.validate()`
- [x] TDD: `AppTextField` accepts every `CustomTextField` legacy parameter without compile or runtime error (regression)
- [x] TDD: `AppTextField` renders the new `labelText` + `helperText` + `errorText` additive params
- [x] TDD: `CustomTextField` wrapper delegates to exactly one nested `AppTextField` instance, preserving the visual surface
- [x] TDD: `AppFormSection` renders title + child; helper appears only when provided
- [x] Verify: `flutter analyze` clean (zero new errors); `flutter test` 360 pass

### Phase 2: Remaining form-kit widgets ✓

- **Goal**: Ship `AppDropdown`, `AppRadioGroup`, `AppSwitchTile`, `AppCheckboxTile`, `AppCurrencyField`, `AppDateField` (responsive). All `StatelessWidget` + `FocusableActionDetector` where focus visuals matter.
- [x] `lib/app/core/widgets/forms/app_dropdown.dart` — `AppDropdown<T>` built on `DropdownButtonFormField<T>`; `AppDropdownItem<T>` with `value/label/enabled`; web row padding via `kIsWeb` (spec req 4)
- [x] `lib/app/core/widgets/forms/app_radio_group.dart` — `AppRadioGroup<T>` using Flutter 3.32+ `RadioGroup<T>` ancestor; `AppRadioOption<T>` with `value/label/subtitle?`; vertical + horizontal layouts (spec req 7)
- [x] `lib/app/core/widgets/forms/app_switch_tile.dart` — `SwitchListTile` wrapper with title/subtitle/key, sage active colour (spec req 8)
- [x] `lib/app/core/widgets/forms/app_checkbox_tile.dart` — `CheckboxListTile` wrapper with title/subtitle/key, sage active colour (spec req 8)
- [x] `lib/app/core/widgets/forms/app_currency_field.dart` — pure `parseCurrencyInput(raw, locale:)` + `AppCurrencyField` widget; locale resolved via `Localizations.maybeLocaleOf(context) ?? 'en_US'` (spec req 10)
- [x] `lib/app/core/widgets/forms/app_date_field.dart` — `LayoutBuilder` cutover at `Breakpoints.compactMax` (NOT `kIsWeb`); inline `CalendarDatePicker` when allotted width ≥ 600 else `showDatePicker`; `firstDate: DateTime(2000)`; clearable suffix (spec req 6, **CI2**)
- [x] `lib/app/features/tasks/presentation/widgets/budget_estimate_field.dart` — thin wrapper over `AppCurrencyField`; `parseBudgetEstimate` kept as an alias to `parseCurrencyInput` so existing call sites + the validator unit test compile unchanged
- [x] TDD: `AppDropdown` selecting fires `onChanged`; disabled item non-selectable; underlying `DropdownButtonFormField<T>` asserted
- [x] TDD: `AppRadioGroup<int>` highlights value, tapping fires `onChanged`, label + helper render
- [x] TDD: `AppSwitchTile` / `AppCheckboxTile` toggle correctly and respect `key`
- [x] TDD: `AppCurrencyField` widget validator accepts/rejects per spec; pure `parseCurrencyInput` covered for `en_US` + `de_DE` (including 3-decimal comma rejection)
- [x] TDD: `AppDateField` modal path — `Size(360, 800)` viewport → tap trigger opens `DatePickerDialog`
- [x] TDD: `AppDateField` inline path — `Size(1200, 800)` viewport → `CalendarDatePicker` renders without tap; modal trigger absent
- [x] TDD: `AppDateField` clearable — clear icon fires `onChanged(null)`
- [x] Verify: `flutter analyze` clean; `flutter test` 374 pass

### Phase 3: Data layer fix + pure logic ✓

- **Goal**: Populate `TaskModel.checklistItems` in list path (fixes pre-existing X/Y bug), add `createTaskWithChecklist` for Duplicate, add `TasksFilter`/`applyTasksFilter`/`groupTasks`/`_startOfDay`/`TaskModel.duplicate` factories.
- [x] `lib/app/core/database/daos/task_checklist_items_dao.dart` — `Future<Map<String, List<TaskChecklistItem>>> itemsByTaskIds(List<String>)` (single batched SELECT with `IN`)
- [x] `lib/app/features/tasks/data/task_repository.dart` — `watchTasksByEventId` + `getTasksByEventId` both flow through `_hydrate(rows)` which calls `itemsByTaskIds` and merges into each `_toDomain(row, items)` (spec req 11a/11b)
- [x] `lib/app/features/tasks/data/task_repository.dart` — `Future<bool> createTaskWithChecklist(TaskModel task, List<ChecklistItem> items)` using Firestore `WriteBatch` (parent task doc + N checklist children atomic); on success mirrors to Drift via existing daos (spec req 28)
- [x] `lib/app/features/tasks/domain/models/task.dart` — `TaskModel.duplicate({required String currentUserId, required List<ChecklistItem> checklist})` with grapheme-aware `title.characters.take(113).toString() + ' (copy)'`, preserved fields, fresh checklist UUIDs, status=todo, completedAt/By=null (spec req 27)
- [x] `lib/app/features/tasks/application/tasks_filter.dart` — `TasksFilter` value object (no `sortAscending`), `TasksSortKey`, `TasksGroupBy`, `TasksGroup`; `startOfDay(DateTime)` helper; pure `applyTasksFilter` + `groupTasks` functions; time-aware predicates take `now:` parameter (spec req 15–18, **CI3** seam)
- [x] `pubspec.yaml` — `characters: ^1.4.0` declared explicitly (was transitive)
- [x] TDD: `startOfDay` zeroes time component; same-day midnight is identity
- [x] TDD: `applyTasksFilter` — each predicate independently + composition; null fields don't throw
- [x] TDD: `applyTasksFilter` — sort direction per `TasksSortKey` per req 17a; tie-break `id` asc; nulls last; stability check
- [x] TDD: `applyTasksFilter` — overdue flips at start-of-day (same-day at 02:00 UTC and 23:00 UTC both NOT overdue; next-day IS overdue). `clock.now()` not needed at the function level — `now:` parameter is the seam (CI3 satisfied)
- [x] TDD: `groupTasks` — status / assignee / dueWindow buckets in spec'd order; empty buckets omitted; orphan-assignee handled with truncated UID fallback
- [x] TDD: `TaskModel.duplicate` — new id, `(copy)` suffix grapheme-truncated to ≤120 chars (rocket emoji boundary test confirms no surrogate split), preserved fields, fresh checklist UUIDs, status reset
- [x] TDD: `TaskRepository.watchTasksByEventId` returns `TaskModel`s with `checklistItems` populated (regression covers latent X/Y bug); empty checklist still emits empty list
- [x] TDD: `TaskRepository.createTaskWithChecklist` writes parent + N children atomically; success mirrors to Drift; empty checklist valid
- [x] Verify: `flutter analyze` clean; `flutter test` 405 pass (374→405, +31 new)

### Phase 4: TaskTile redesign ✓

- **Goal**: Tile gets progress bar (gated on data + `status != done`), overdue badge (`clock.now()`), priority pill.
- [x] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — `clock` import; new `_ProgressBar` widget below title row (height 3, foreground = stripe colour, background `lightGrey` at 30 % alpha); hidden when `checklistItems.isEmpty` OR `status == done` (spec req 11, 14, CI3)
- [x] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — Overdue pill via `startOfDay(dueDate) < startOfDay(clock.now()) && status != done`; key `tasks.tile.${id}.overdueBadge`; terracotta bg, white text, `labelSmall` (spec req 12)
- [x] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — Priority pill for `priority > 0`; key `tasks.tile.${id}.priorityBadge`; labels Low/Medium/High via `context.strings.tasks.priorityLow/Medium/High`; colours sageLight/charcoal/terracotta (spec req 13)
- [x] `lib/app/core/i18n/app_strings.dart` — added `overdueBadge` + `priorityNone/Low/Medium/High` to `TasksStrings` and `_EnglishTasksStrings`
- [x] TDD: progress bar visible only when `checklistItems.isNotEmpty && status != done`; bar fraction equals `completed/total` (asserted via `FractionallySizedBox.widthFactor`)
- [x] TDD: progress bar hidden when `status == done` even with partial checklist (edge case 33b)
- [x] TDD: overdue badge — 4 cases (null dueDate, same-day late at 23:30, yesterday with todo, yesterday with done) under `withClock(Clock.fixed(...))`; badge appears only for past-due + non-done
- [x] TDD: priority pill — absent for `priority == 0`; present with correct label for 1/2/3
- [x] Verify: `flutter analyze` clean; `flutter test` 416 pass (405→416, +11 new)

### Phase 5: Tasks screen overhaul ✓

- **Goal**: Replace single-status filter with `TasksFilter` end-to-end; ship search + chips + sort menu + group toggle + per-filter empty state.
- [x] `lib/app/features/tasks/presentation/widgets/tasks_filter_bar.dart` — search row (`TextField` + leading `Icons.search` inside a `KeyedSubtree` so widget tests can find the field by row key), `Wrap` of filter chips (Mine, Overdue, Has budget, Todo, In Progress, Done), sort `PopupMenuButton<TasksSortKey>`, `SegmentedButton<TasksGroupBy>`. All keys match spec (`tasks.list.search`, `tasks.list.filterChip.<name>`, `tasks.list.sortMenu`/`.<key>`, `tasks.list.groupToggle`/`.<value>`). Sort + group toggle live in a `Wrap` so the segmented button reflows on narrow viewports instead of overflowing.
- [x] `lib/app/features/tasks/presentation/task_list_screen.dart` — **breaking API change** applied: dropped `selectedFilter` / `onFilterChanged: ValueChanged<TaskStatus?>?`; added `filter: TasksFilter, onFilterChanged: ValueChanged<TasksFilter>, groups: List<TasksGroup>`. Renders the filter bar at the top, then `_GroupHeader` (`tasks.list.groupHeader.<key>`) + `TaskTile` per group.
- [x] `lib/app/features/tasks/presentation/event_tasks_page.dart` — owns a single `TasksFilter` in state (session-only); computes `applyTasksFilter(tasks, _filter, currentUserId, now: clock.now())` → `groupTasks(filtered, _filter.groupBy, now: clock.now(), assigneeNames: ...)` and threads `groups` + `filter` + `onFilterChanged` into `TaskListScreen`. Uses `usersByIdProvider` for assigneeNames (already wired).
- [x] `lib/app/features/tasks/presentation/task_list_screen.dart` — `_EmptyState`: "No tasks yet" when no filters active; "No tasks match this filter" + Clear-filters button (key `tasks.list.emptyState.clear`) resetting to default `TasksFilter` (spec req 21)
- [x] `lib/app/core/i18n/app_strings.dart` — added 21 new fields covering Mine, Overdue, Has budget, status labels, sort menu items, group toggle items, due-window labels, Unassigned, search hint, empty-state copy, Clear filters. `_EnglishTasksStrings` provides the English values.
- [x] `test/robots/tasks_robot.dart` — updated `expectEmptyState` to look up the new `tasks.list.emptyState` key (was the legacy `tasks.list.empty`).
- [x] TDD: `TasksFilterBar` — search typing emits onFilterChanged.query; chip taps toggle predicate + status flags; sort menu selecting Priority updates sortKey; group toggle changes groupBy
- [x] TDD: `TaskListScreen` — chip taps propagate updated `TasksFilter`; empty-state copy differs by `filter.hasActiveFilters`; Clear filters resets to default; group header keyed per non-empty `TasksGroup`
- [x] Robot: `test/journeys/tasks_filter_sort_group_journey_test.dart` — `withClock(Clock.fixed(DateTime(2026, 6, 15, 12, 0)))`, seeds 4 tasks varying statuses/dueDates/priorities in fake Firestore; pumps `EventTasksPage`; walks search "lunch" → Overdue chip → sort Priority → group Assignee. Asserts visible titles + group headers + that Overdue narrows to the single past-due task.
- [x] Verify: `flutter analyze` clean; `flutter test` 426 pass (416→426, +10 new)

### Phase 6: Create/Edit form redesign + Duplicate ✓

- **Goal**: Three `AppFormSection`s on Create + Edit, Priority radio, `AppDateField` + `AppCurrencyField`, Duplicate action wired through `createTaskWithChecklist`.
- [x] `lib/app/features/tasks/presentation/widgets/assignee_picker.dart` — refactored internals to `AppDropdown<String?>` (built on `DropdownButtonFormField`); public API + `Key('tasks.create.assignee')` preserved; orphan disabled row label keeps `(no longer in event)` suffix (spec req 25)
- [x] `lib/app/features/tasks/presentation/create_task_screen.dart` — three `AppFormSection`s (Details / Assignment / Timing & Budget); new `AppRadioGroup<int>` priority field keyed `tasks.create.priority`; due-date row uses `AppDateField`; budget uses `AppCurrencyField` directly. Accepts optional `initial: TaskModel?` for the Duplicate pre-fill (carries id + checklist into the create flow).
- [x] `lib/app/features/tasks/presentation/edit_task_screen.dart` — same three-section restructure; priority defaults to `task.priority` on edit; uses `AppDateField` + `AppCurrencyField` instead of the old `InkWell` + `BudgetEstimateField`
- [x] `lib/app/features/tasks/presentation/task_detail_screen.dart` — dropped standalone edit + delete `IconButton`s; `_DetailOverflowMenu` keyed `tasks.detail.overflow` renders Edit / Duplicate / Delete (visibility per RBAC: Edit + Delete only when `canEditTask`; Duplicate visible when `onDuplicate` non-null) (spec req 26)
- [x] `lib/app/features/tasks/presentation/event_task_detail_page.dart` — wires `onDuplicate`: calls `task.duplicate(currentUserId: uid, checklist: items)` using the already-watched checklist stream, pushes `CreateTaskScreen(initial: duplicate, ...)`, then calls `repo.createTaskWithChecklist(edited, edited.checklistItems)` on submit (spec req 27, 28)
- [x] `lib/app/core/i18n/app_strings.dart` — added `detailEdit`, `detailDuplicate`, `detailDelete`, `fieldPriority` (priority section + Duplicate / Delete strings)
- [x] `test/robots/tasks_robot.dart` — `tapEditOnDetail` / `tapDuplicateOnDetail` go through the new overflow menu; bounded `_bounded()` pumps replace `pumpAndSettle` for paths that interact with the detail page's emitting Drift + Firestore mirrors
- [x] TDD: `AssigneePicker` regression — both existing Phase 1 tests pass unchanged through the `AppDropdown`-internal refactor (key + orphan disabled behaviour preserved)
- [x] TDD: `EditTaskScreen` — pre-fill, onSubmit round-trip, modal-path past-date picker (`firstDate=2000`), orphan row rendering all pass against the new three-section layout
- [x] TDD: `TaskDetailScreen` overflow menu — Edit absent for non-creator; menu hidden when no actions available; Duplicate item visible for any viewer with a non-null callback
- [x] Robot: `test/journeys/duplicate_task_journey_test.dart` — seeds a task + 3 checklist items in fake Firestore, pumps the detail page, taps overflow → Duplicate, asserts the create form pre-fills with " (copy)" suffix, saves, then asserts Firestore has 2 task docs and the new task has all 3 checklist children (texts preserved, fresh ids)
- [x] Verify: `flutter analyze` clean; `flutter test` 428 pass (426→428, +2 new tests)

## Risks / Out of scope

**Risks**:
- Phase 3 data-layer change touches `_toDomain` signature used by 7+ call sites inside `task_repository.dart`. The join must happen at watch time, not row-by-row, or every Drift stream emission triggers N queries. Use `itemsByEventId(eventId)` as a single Map fetch.
- Phase 5 breaking API change to `TaskListScreen` is one-caller — update `event_tasks_page.dart` in the same commit; do not stagger.
- `Phase 6` Duplicate flow: `createTaskWithChecklist` uses `WriteBatch` (atomic). If the user has already pushed the Create screen, navigating back before save shouldn't trigger any partial write — only the explicit Save button calls the repo.
- `clock.now()` requires the entire overdue path (filter, group, tile, journey tests) to consistently route through `clock` — a single direct `DateTime.now()` defeats the seam. Grep for `DateTime.now()` in any new task code before each phase-end commit.

**Out of scope** (deferred per spec):
- `AppMultiSelect<T>` (no consumer in this PR; added to `todo.md`).
- User-toggleable sort direction (direction fixed per sort key per req 17a).
- Per-assignee multi-select filter (req 21a defers to a future spec).
- Migrating any of the 29 existing `CustomTextField` call sites to `AppTextField` (CI1: wrapper only; zero edits outside Tasks + new forms kit).
- Persisting user filter/sort/group preferences across navigation (session-only in V1).
- Activity log / chat post on task changes (spec keeps tasks independent).
