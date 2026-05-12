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

### Phase 1: Form-kit foundation slice

- **Goal**: Ship `AppFormSection` + `AppTextField` + the deprecated `CustomTextField` wrapper end-to-end. Prove zero churn on 29 callsites by analyzing the whole repo after the wrapper lands.
- [ ] `lib/app/core/widgets/forms/app_form_section.dart` — `title`, optional `helperText`, `child` column; `AppSpacing.xl` between sections (spec req 9)
- [ ] `lib/app/core/widgets/forms/app_text_field.dart` — `StatelessWidget` composed with `Focus`/`FocusableActionDetector`; superset of `CustomTextField` params + additive `labelText/helperText/errorText/maxLength/autofocus`; sage 2-px focus outline only on `kIsWeb` AND when focused (spec req 2)
- [ ] `lib/app/core/widgets/custom_text_field.dart` — convert to `StatelessWidget` thin wrapper delegating to `AppTextField`; `@Deprecated('Use AppTextField from lib/app/core/widgets/forms/app_text_field.dart')`; preserve every constructor param + default (spec req 3, CI1)
- [ ] `lib/app/core/i18n/app_strings.dart` — add `abstract class TasksStrings` + `_EnglishTasksStrings` peer; field for at least one V1 label (placeholder; expand in later phases as needed) (boundary i18n contract)
- [ ] TDD: `AppTextField` renders error text from validator; focus outline appears only on `kIsWeb` when focused
- [ ] TDD: `AppTextField` accepts every `CustomTextField` param shape (regression — golden tree assertion)
- [ ] TDD: `CustomTextField` wrapper produces an identical rendered tree to `AppTextField` for identical params
- [ ] TDD: `AppFormSection` renders title + optional helper + child column with the spec'd spacing
- [ ] Verify: `flutter analyze` (zero new errors on any of the 29 files importing `CustomTextField`); `flutter test`

### Phase 2: Remaining form-kit widgets

- **Goal**: Ship `AppDropdown`, `AppRadioGroup`, `AppSwitchTile`, `AppCheckboxTile`, `AppCurrencyField`, `AppDateField` (responsive). All `StatelessWidget` + `FocusableActionDetector` where focus visuals matter.
- [ ] `lib/app/core/widgets/forms/app_dropdown.dart` — `AppDropdown<T>` built on `DropdownButtonFormField<T>` (NOT `DropdownButton` + `InputDecorator`); `AppDropdownItem<T>` with `value/label/enabled`; web styling = +8 px vertical row padding on `kIsWeb` (spec req 4)
- [ ] `lib/app/core/widgets/forms/app_radio_group.dart` — `AppRadioGroup<T>` (`int` + enum-friendly); vertical or horizontal; `AppRadioOption<T>` with `value/label/subtitle?` (spec req 7)
- [ ] `lib/app/core/widgets/forms/app_switch_tile.dart` — `SwitchListTile` wrapper with title/subtitle/key (spec req 8)
- [ ] `lib/app/core/widgets/forms/app_checkbox_tile.dart` — `CheckboxListTile` wrapper with title/subtitle/key (spec req 8)
- [ ] `lib/app/core/widgets/forms/app_currency_field.dart` — generalise `parseBudgetEstimate` into a reusable field; accepts `currencyCode`, `allowZero`, `allowEmpty`; locale fallback to `en_US` when `Localizations` absent (spec req 10)
- [ ] `lib/app/core/widgets/forms/app_date_field.dart` — `LayoutBuilder` cutover at `Breakpoints.compactMax`: inline `CalendarDatePicker` when allotted width ≥ 600, `showDatePicker` otherwise; `firstDate: DateTime(2000)`; `clearable` exposes `Icons.clear` → `onChanged(null)` (spec req 6, CI2)
- [ ] `lib/app/features/tasks/presentation/widgets/budget_estimate_field.dart` — re-implement as a thin wrapper passing `currencyCode` + label to `AppCurrencyField` (spec req 10)
- [ ] TDD: `AppDropdown` selecting an item fires `onChanged` with typed value; disabled item is non-selectable; underlying widget is `DropdownButtonFormField`
- [ ] TDD: `AppRadioGroup<int>` highlights the current value; tapping another option fires `onChanged`
- [ ] TDD: `AppSwitchTile` / `AppCheckboxTile` toggle correctly and respect `key`
- [ ] TDD: `AppCurrencyField` validates `en_US` + `de_DE` inputs; locale fallback works without a `Localizations` ancestor
- [ ] TDD: `AppDateField` modal path — `tester.view.physicalSize = Size(360, 800)` + `resetPhysicalSize` cleanup → tapping opens `showDatePicker`
- [ ] TDD: `AppDateField` inline path — `tester.view.physicalSize = Size(1200, 800)` → renders `CalendarDatePicker`; tapping a date fires `onChanged`
- [ ] Verify: `flutter analyze && flutter test`

### Phase 3: Data layer fix + pure logic

- **Goal**: Populate `TaskModel.checklistItems` in list path (fixes pre-existing X/Y bug), add `createTaskWithChecklist` for Duplicate, add `TasksFilter`/`applyTasksFilter`/`groupTasks`/`_startOfDay`/`TaskModel.duplicate` factories.
- [ ] `lib/app/core/database/daos/task_checklist_items_dao.dart` — add `Future<Map<String, List<TaskChecklistItem>>> itemsByEventId(String eventId)` (single SELECT joining tasks→items, returning a `task_id`→items map) (spec req 11a)
- [ ] `lib/app/features/tasks/data/task_repository.dart` — `watchTasksByEventId` now joins via `itemsByEventId(eventId)` before `_toDomain`; `_toDomain` accepts the items list (spec req 11a/11b)
- [ ] `lib/app/features/tasks/data/task_repository.dart` — `Future<bool> createTaskWithChecklist(TaskModel task, List<ChecklistItem> items)` using Firestore `WriteBatch` (parent task doc + N checklist children atomic); on success mirror to Drift via existing daos (spec req 28)
- [ ] `lib/app/features/tasks/domain/models/task.dart` — `TaskModel.duplicate({required String currentUserId, required List<ChecklistItem> checklist})`: new UUID, grapheme-aware truncation `title.characters.take(113).toString() + ' (copy)'`, preserved fields, fresh checklist UUIDs, status=todo, completedAt/By=null (spec req 27)
- [ ] `lib/app/features/tasks/application/tasks_filter.dart` — `TasksFilter` value object (no `sortAscending`), `TasksSortKey`, `TasksGroupBy`, `TasksGroup`; `_startOfDay(DateTime)` helper; pure `applyTasksFilter` + `groupTasks` functions; `clock.now()` injected via the `now:` param (spec req 15–18, CI3)
- [ ] TDD: `_startOfDay` zeroes time component
- [ ] TDD: `applyTasksFilter` — each predicate independently + composition; null fields don't throw
- [ ] TDD: `applyTasksFilter` — sort direction per `TasksSortKey` per req 17a; tie-break `id` asc; nulls last; stability check (identical input ⇒ identical output)
- [ ] TDD: `applyTasksFilter` with `withClock(Clock.fixed(...))` — overdue predicate flips at start-of-day, not at the dueDate timestamp; same-day at 02:00 UTC == same result as 23:00 UTC
- [ ] TDD: `groupTasks` — status / assignee / dueWindow buckets in spec'd order; empty buckets omitted; orphan-assignee handled
- [ ] TDD: `TaskModel.duplicate` — new id, ` (copy)` suffix grapheme-truncated to ≤120 chars (test with an emoji at boundary), preserved fields, fresh checklist UUIDs, status reset
- [ ] TDD: `TaskRepository.watchTasksByEventId` returns `TaskModel`s with `checklistItems` populated (regression covers latent X/Y bug)
- [ ] TDD: `TaskRepository.createTaskWithChecklist` writes parent + N children atomically; mocked Firestore failure leaves nothing written; success mirrors to Drift
- [ ] Verify: `flutter analyze && flutter test`

### Phase 4: TaskTile redesign

- **Goal**: Tile gets progress bar (gated on data + `status != done`), overdue badge (`clock.now()`), priority pill.
- [ ] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — add `import 'package:clock/clock.dart';`; new `Container` linear progress bar below title row (height 3, foreground = stripe colour, background = `lightGrey` at 30 % alpha); hidden when `checklistItems.isEmpty` OR `status == done` (spec req 11, 14, CI3)
- [ ] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — Overdue pill via `_startOfDay(dueDate) < _startOfDay(clock.now()) && status != done`; key `tasks.tile.${id}.overdueBadge`; terracotta bg, white text, `labelSmall` (spec req 12)
- [ ] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — Priority pill for `priority > 0`; key `tasks.tile.${id}.priorityBadge`; labels Low/Medium/High; colours sageLight/charcoal/terracotta (spec req 13)
- [ ] `lib/app/core/i18n/app_strings.dart` — add fields for Overdue, Low, Medium, High labels to `TasksStrings`
- [ ] TDD: progress bar visible only when `checklistItems.isNotEmpty && status != done`; bar fraction equals `completed/total` (width-ratio assertion via `Container.constraints`)
- [ ] TDD: progress bar hidden when `status == done` even with partial checklist (edge case 33b)
- [ ] TDD: overdue badge — 3 statuses × 3 dates (yesterday / today / tomorrow) under `withClock(Clock.fixed(...))`; badge appears only for `dueDate < startOfDay(now) && status != done`
- [ ] TDD: priority pill — absent for `priority == 0`; present with correct label/colour for 1/2/3
- [ ] Verify: `flutter analyze && flutter test`

### Phase 5: Tasks screen overhaul

- **Goal**: Replace single-status filter with `TasksFilter` end-to-end; ship search + chips + sort menu + group toggle + per-filter empty state.
- [ ] `lib/app/features/tasks/presentation/widgets/tasks_filter_bar.dart` — search row (`AppTextField` + `Icons.search` prefix), filter chips `Wrap`, sort `PopupMenuButton<TasksSortKey>` (no asc/desc toggle), `SegmentedButton<TasksGroupBy>`; all keyed per spec (spec req 20)
- [ ] `lib/app/features/tasks/presentation/task_list_screen.dart` — **breaking API change**: drop `selectedFilter` / `onFilterChanged: ValueChanged<TaskStatus?>?`; add `filter: TasksFilter, onFilterChanged: ValueChanged<TasksFilter>, groups: List<TasksGroup>`; render `_TasksGroupHeader` + tiles per group (spec req 19, 20)
- [ ] `lib/app/features/tasks/presentation/event_tasks_page.dart` — own `TasksFilter` state; compute filtered+grouped via `applyTasksFilter` + `groupTasks` with `clock.now()` + resolved `assigneeNames` from existing `usersByIdProvider`; thread to `TaskListScreen`
- [ ] `lib/app/features/tasks/presentation/task_list_screen.dart` — per-filter empty state: "No tasks yet" when no filters active vs "No tasks match this filter" + `Clear filters` button (key `tasks.list.emptyState.clear`) resetting to default `TasksFilter` (spec req 21)
- [ ] `lib/app/core/i18n/app_strings.dart` — add labels for Mine, Overdue, Has budget, Todo, In Progress, Done, Today, This week, Later, No due date, Sort by, Group by, search hint, empty-state copy, Clear filters
- [ ] TDD: `TaskListScreen` tapping a chip calls `onFilterChanged` with updated `TasksFilter`
- [ ] TDD: `TaskListScreen` empty-state copy differs when filters active; Clear filters resets state
- [ ] TDD: `TaskListScreen` renders a group header per non-empty `TasksGroup`
- [ ] Robot: `test/journeys/tasks_filter_sort_group_journey_test.dart` — `withClock(Clock.fixed(DateTime.utc(2026, 6, 15)))`, seed 4 tasks with varied statuses/dueDates/budgets; pump `EventTasksPage`; flow: search "lunch" → toggle Overdue chip → switch sort to Priority → switch group to Assignee. Assert visible titles + group headers at each step
- [ ] Verify: `flutter analyze && flutter test`

### Phase 6: Create/Edit form redesign + Duplicate

- **Goal**: Three `AppFormSection`s on Create + Edit, Priority radio, `AppDateField` + `AppCurrencyField`, Duplicate action wired through `createTaskWithChecklist`.
- [ ] `lib/app/features/tasks/presentation/widgets/assignee_picker.dart` — refactor internals to `AppDropdown<String?>` (built on `DropdownButtonFormField`); preserve public API + `Key('tasks.create.assignee')` (spec req 25)
- [ ] `lib/app/features/tasks/presentation/create_task_screen.dart` — restructure into three `AppFormSection`s (Details / Assignment / Timing & Budget); add Priority `AppRadioGroup<int>`; replace due-date `InkWell` with `AppDateField`; replace `BudgetEstimateField` import with `AppCurrencyField` direct usage (spec req 22–24)
- [ ] `lib/app/features/tasks/presentation/edit_task_screen.dart` — same restructure as create; priority defaults to `task.priority`
- [ ] `lib/app/features/tasks/presentation/task_detail_screen.dart` — replace standalone edit + delete `IconButton`s with `PopupMenuButton<_DetailAction>` keyed `tasks.detail.overflow`; items Edit / Duplicate / Delete; visibility rules per RBAC (spec req 26)
- [ ] `lib/app/features/tasks/presentation/event_task_detail_page.dart` — wire `onDuplicate`: read checklist from already-watched `taskChecklistProvider`, call `TaskModel.duplicate(currentUserId, checklist)`, push `CreateTaskScreen` pre-filled, on submit call `taskRepositoryProvider.createTaskWithChecklist(...)` (spec req 27, 28)
- [ ] `lib/app/core/i18n/app_strings.dart` — add labels for None, Low, Medium, High (priority), section titles, Duplicate action, " (copy)" suffix
- [ ] TDD: `AssigneePicker` regression — `Key('tasks.create.assignee')` still present; orphan disabled-item behaviour intact (existing Phase 1 tests must pass unchanged)
- [ ] TDD: `CreateTaskScreen` / `EditTaskScreen` render exactly three `AppFormSection`s in spec'd order
- [ ] TDD: Priority radio defaults to None on create, `task.priority` on edit; selecting Medium fires `onChanged` propagating to the saved model
- [ ] TDD: `TaskDetailScreen` overflow menu — Edit + Delete only when `canEditTask`; Duplicate visible for every viewer
- [ ] Robot: `test/journeys/duplicate_task_journey_test.dart` — seed task with 3 checklist items in fake Firestore; pump detail page; overflow → Duplicate → assert pre-filled title ends `(copy)` and create form opens; tap Save; assert Firestore has 2 task docs + 3+3 checklist docs; both `createdBy` reflect the current user
- [ ] Verify: `flutter analyze && flutter test`

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
