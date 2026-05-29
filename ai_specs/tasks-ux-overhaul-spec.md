<goal>
Overhaul the Tasks experience and ship a reusable form widget kit the rest of the app can adopt.

Three intertwined deliverables:

1. **A reusable form widget kit** — `AppTextField`, `AppDropdown<T>`, `AppDateField` (modal on mobile / inline on wide web), `AppRadioGroup<T>`, `AppSwitchTile`, `AppCheckboxTile`, `AppFormSection`, `AppCurrencyField`. Lives under `lib/app/core/widgets/forms/` and replaces ad-hoc form widgets across the project over time. Web-specific variants for the controls where it matters (date inline calendar, dropdown row padding, text-field focus ring). `AppMultiSelect<T>` is intentionally deferred — no V1 consumer.
2. **A redesigned Tasks screen** — keeps the existing `taskListProvider` stream but layers search, filter chips (status / assignee / overdue / has-budget), a sort menu (due / priority / created / title), and a grouping toggle (status / assignee / due-window). `TaskTile` gains a linear progress bar tied to checklist completion, an "Overdue" badge, and a priority pill. Empty states adapt to the active filter with a Clear-filters CTA.
3. **Modernised Create / Edit task forms** — three `AppFormSection`s (Details / Assignment / Timing & Budget), a new Priority `AppRadioGroup<int>` (None / Low / Medium / High) wired to the existing `TaskModel.priority` field, and a Duplicate action on the detail overflow menu that opens Create pre-filled with `" (copy)"` suffix.

Beneficiaries: event admins, creators, and assignees who today see a stub Tasks list and a flat form. After this lands, the Tasks screen scales to dozens of tasks (search/filter/group), the tile communicates progress at a glance, and any future feature (Budget edit, Profile edit, Member invite) can pull from the same form kit instead of reinventing widgets.

Task events themselves continue to live independently of the parent event document — no activity log, no chat post (deferred to a separate spec when prioritised).
</goal>

<background>
**Tech stack & conventions** (established):

- Flutter 3.11.5 / Dart 3.x; Riverpod 3 (`riverpod_annotation` codegen).
- `intl` 0.20 for locale-aware number/date rendering. No `flutter_localizations` dependency today.
- Layering: feature-first under `lib/app/features/<feature>/{data,domain,application,presentation}`; shared widgets under `lib/app/core/widgets/`.
- Existing reusable widgets in `lib/app/core/widgets/`: `CustomTextField`, `PrimaryButton`, `DestructiveButton`, `FormCardShell`, `ContentMaxWidth`, `DialogOverlay`, `LoadingAnimation`, `NetworkImageWithPlaceholder`, `ResponsiveShell`, `EventGuard`.
- Web behaviour: there is no Drift persistence on web (Wasm in-memory); `kIsWeb` checks already exist in repos. Breakpoints helper lives at `lib/app/core/constants/breakpoints.dart` (`screenHorizontalPadding`, mobile/tablet/desktop thresholds — confirm and reuse).
- Brand palette in `lib/app/core/constants/app_colors.dart`: `sage`/`sageDark`/`sageLight` for progress + positive; `terracotta` for destructive / overdue; `cream` background; `charcoal` text; `mediumGrey` muted.

**Files to examine before implementing:**

- @lib/app/core/widgets/custom_text_field.dart — current text-field convention. New `AppTextField` should be a superset; `CustomTextField` becomes a thin alias to keep the 20+ existing call sites green.
- @lib/app/core/widgets/form_card_shell.dart — the existing card wrapper for forms. Keep it; `AppFormSection` composes inside (or alongside) the shell, not replacing it.
- @lib/app/features/tasks/presentation/widgets/budget_estimate_field.dart — already locale-aware; generalise into `AppCurrencyField` (takes any `currencyCode`) and have `BudgetEstimateField` re-export the new widget so existing call sites compile.
- @lib/app/features/tasks/presentation/widgets/assignee_picker.dart — current Material `DropdownButton` usage. After `AppDropdown<T>` lands, refactor `AssigneePicker` internals to use it (keeping the existing public API for orphan-aware behaviour).
- @lib/app/features/tasks/presentation/create_task_screen.dart and edit_task_screen.dart — current Create/Edit forms; both get the three-section restructure + priority field.
- @lib/app/features/tasks/presentation/task_list_screen.dart — current single-status filter; this is the file the search/filter/sort/group overhaul lives in.
- @lib/app/features/tasks/presentation/widgets/task_tile.dart — current tile (stripe + budget + checklist count); needs progress bar, overdue badge, priority pill.
- @lib/app/features/tasks/domain/models/task.dart — `priority: int` already exists; this spec exposes it in the UI without changing the model.
- @lib/app/features/tasks/presentation/event_tasks_page.dart — Consumer wrapper; spec adds filter/sort/group state to this page state.
- @lib/app/features/tasks/presentation/event_task_detail_page.dart — Duplicate action wires from here.
- @lib/app/core/constants/breakpoints.dart — confirm wide-web threshold (≥600px likely) used by `AppDateField`.

**Out of scope** (defer to `ai_specs/todo.md` or a future spec):

- Activity log / event chat post on task changes (user chose "tasks live independently").
- Bulk multi-select on task tiles + bulk actions.
- Drag-to-reorder priority within a group.
- Kanban view (already in `todo.md`).
- Task attachments file storage (already in `todo.md`).
- Due-date reminders + push (already in `todo.md`).
- Recurring tasks / task templates (already in `todo.md`).
- Migrating every existing `CustomTextField` callsite to `AppTextField` (deprecation wrapper only — opportunistic migration in follow-up PRs).
- Persisting user filter/sort/group preferences across navigation (session-only in this PR).
- `AppMultiSelect<T>` widget (no consumer yet — see req 5).
- User-toggleable sort direction (req 17a fixes direction per sort key; ascending/descending toggle deferred).
- Per-assignee filter chips beyond `onlyMine` (req 21a; reintroduces `AppMultiSelect<T>` when prioritised).
</background>

<user_flows>

## Tasks screen

**Primary — open Tasks, see what's relevant:**

1. Tap Tasks from event dashboard → `EventTasksPage` renders the list with the default grouping (by status) and no active filters.
2. Tap the search icon → search bar slides down → typing filters the visible tiles in real time over title + description (case-insensitive).
3. Tap a filter chip ("Mine", "Overdue", "Todo", "Has budget") → list narrows; chip turns sage with check icon.
4. Tap the sort menu (top-right, `Icons.sort`) → sheet with Due date, Priority, Created, Title. Selecting one re-orders within each group, with a secondary asc/desc toggle for Due date and Created.
5. Tap the grouping toggle (segmented control) → list re-groups by Status / Assignee / Due-window.
6. Tap a tile → standard `EventTaskDetailPage` (unchanged).

**Primary — at-a-glance progress on a tile:**

- Tile shows: stripe (existing), title, optional description, optional Overdue pill (terracotta), optional Priority pill (sage for Low, charcoal for Medium, terracotta for High), optional budget text, optional "3/5" checklist count + a linear progress bar below the title scaled to the tile width. Bar hidden when checklist empty. Bar tinted by status (todo grey, inProgress sage, done sageDark).

**Primary — create a task with the new form:**

1. FAB → CreateTaskScreen with three `AppFormSection`s:
   - **Details**: `AppTextField` title, `AppTextField` description (multiline).
   - **Assignment**: `AssigneePicker` (internally now an `AppDropdown<String?>`), `AppRadioGroup<int>` Priority (None / Low / Medium / High).
   - **Timing & Budget**: `AppDateField` due date, `AppCurrencyField` budget.
2. Save → returns to list with the new task on top.

**Primary — edit a task:**

- Same three-section form, pre-filled. `firstDate: DateTime(2000)` on the date picker so back-dated edits work (already shipped; reaffirmed).

**Primary — duplicate a task:**

1. Open detail → tap overflow menu → Duplicate.
2. CreateTaskScreen opens pre-filled: title = `"<original> (copy)"`, description / assignee / due date / budget / priority / checklist items preserved; new id; status reset to `todo`; `createdBy` set to current user; no `completedAt` / `completedBy`.
3. Edit the title or save as-is. Save creates a new task with a fresh checklist (each item gets a new id).

**Alternative — non-creator non-admin opens detail:**

- Pencil + delete actions hidden. Overflow menu still shows Duplicate (any member can duplicate a visible task — they become `createdBy` on the new task).

**Alternative — web (≥600px viewport):**

- `AppDateField` renders an inline `CalendarDatePicker` instead of opening a modal.
- `AppDropdown` shows a keyboard-navigable popup with larger row hit targets.
- `AppTextField` shows a 2-px sage focus ring when focused.

**Error flows:**

- Empty search query (cleared) → list returns to the previous filter+sort state.
- Active filter produces zero results → empty state reads "No tasks match this filter" + a `Clear filters` button that resets the filter set.
- No tasks at all → existing "No tasks yet" empty state.
- Form validation failure → in-field error text (`AppTextField` exposes a standard error slot); save button reports first-failure to the user via the focused field.
- Duplicate fails on Firestore write → terracotta snackbar; user stays on the pre-filled Create form.

</user_flows>

<requirements>

**Functional — Form kit:**

1. New files under `lib/app/core/widgets/forms/`:
   `app_text_field.dart`, `app_dropdown.dart`, `app_date_field.dart`, `app_radio_group.dart`, `app_switch_tile.dart`, `app_checkbox_tile.dart`, `app_form_section.dart`, `app_currency_field.dart`. One widget per file. Each file `library` doc comment names the widget's contract + which legacy widget it supersedes (if any). **`AppMultiSelect<T>` is intentionally deferred** — no consumer in this PR (see `<boundaries>` / Out of scope).
2. `AppTextField` — supersedes `CustomTextField`. `StatelessWidget` composed with `Focus`/`FocusableActionDetector` for focus visuals (no internal `FocusNode` lifecycle — `Focus.onFocusChange` carries the signal without a `dispose`). API MUST be a **strict superset** of `CustomTextField`'s current parameters: `key, hintText, controller, obscureText = false, keyboardType?, onChanged?, validator?, prefixIcon?, suffixIcon?, maxLines = 1, enabled = true, label?` (every existing parameter, same names, same defaults). Plus additive optional params: `labelText?, helperText?, errorText?, maxLength?, autofocus = false`. Visual: same fill, border, padding as `CustomTextField` today. On `kIsWeb` AND when the field is focused, render a 2-px sage outer border (use `FocusableActionDetector`'s focus state, not a `FocusNode` listener).
3. `CustomTextField` is replaced with a **thin wrapper `StatelessWidget`** that delegates to `AppTextField` (no typedef — Dart's class typedef doesn't allow forwarding constructors with different defaults). Marked `@Deprecated('Use AppTextField from lib/app/core/widgets/forms/app_text_field.dart')`. All **29** existing call sites compile unchanged — verified via `flutter analyze` in `<done_when>`. Don't migrate call sites in this PR.
4. `AppDropdown<T>` — generic single-select. Built on `DropdownButtonFormField<T>` (NOT `DropdownButton` + `InputDecorator` — the current `AssigneePicker` pattern). API: `value: T?, items: List<AppDropdownItem<T>>, onChanged: ValueChanged<T?>, hintText?, labelText?, prefixIcon?, enabled = true, keyName?`. `AppDropdownItem` has `value: T, label: String, enabled: bool = true`. Web styling on `kIsWeb`: 8 px extra vertical padding per row; keyboard navigation comes free with `DropdownButtonFormField`.
5. **`AppMultiSelect<T>` is out of scope.** Add to `ai_specs/todo.md`: "Build when first consumer materialises (e.g., per-assignee filter chips, tag-based filters)." Removed from `lib/app/core/widgets/forms/` file list above.
6. `AppDateField` — date picker field. API: `value: DateTime?, onChanged: ValueChanged<DateTime?>, labelText?, hintText?, firstDate = DateTime(2000), lastDate? (defaults to today + 2 years), clearable = true`. On `LayoutBuilder` width ≥ **`Breakpoints.compactMax`** (the existing constant = `600.0`), renders an inline `CalendarDatePicker` in an `OutlineInputBorder`-styled container. Below that threshold, tapping the field opens `showDatePicker`. Both paths emit the same `onChanged` callback.
7. `AppRadioGroup<T>` — vertical radio list. API: `value: T?, options: List<AppRadioOption<T>>, onChanged: ValueChanged<T?>, labelText?, helperText?, direction = Axis.vertical`. `AppRadioOption` carries `value: T, label: String, subtitle?: String`. Uses Material `Radio` per option in a `ListTile` for tappability.
8. `AppSwitchTile` + `AppCheckboxTile` — `SwitchListTile` / `CheckboxListTile` wrappers with consistent padding, title-style, subtitle slot, and `key` parameter for tests. Replaces ad-hoc usages in `event_dashboard_screen.dart` archive switch and `edit_event_screen.dart` archive toggle.
9. `AppFormSection` — visual grouping. API: `title: String, helperText?, child: Widget, padding?`. Renders: section title in `labelLarge` charcoal, optional helper in `bodySmall` mediumGrey, then the child column (caller supplies `Column(children: [...])`). Spec'd default vertical spacing between sections = `AppSpacing.xl`.
10. `AppCurrencyField` — generalisation of `BudgetEstimateField`. API: `controller, currencyCode, labelText?, helperText?, allowZero = true, allowEmpty = true, validator? (additional layered validator)`. Locale-aware parsing same as today's `parseBudgetEstimate`. `BudgetEstimateField` is re-implemented as a thin wrapper passing `labelText: 'Budget Estimate (optional)'`.

**Functional — TaskTile redesign:**

11. `TaskTile` keeps the existing 4-px status stripe, title, description, status icon, budget text. Adds beneath the title row a `Container` linear progress bar (height 3, width matches text column) showing `completedItems / totalItems` for `task.checklistItems`. Bar hidden when `checklistItems.isEmpty` **OR `task.status == TaskStatus.done`** (the done state implies task-level completion; rendering a partial bar under the done icon is inconsistent — edge case 33b below). Bar foreground colour matches `stripeColor()` (todo → lightGrey, inProgress → sage). Bar background = `lightGrey` at 30 % alpha.
11a. **Data source: `TaskModel.checklistItems` MUST be populated in the list path.** Currently `TaskRepository._toDomain` and `_fromFirestore` leave `checklistItems` defaulted to `const []`, which is why the existing X/Y text never renders. Fix by joining `TaskChecklistItemsDao.byTaskId(row.id)` (sync method) inside `_toDomain`'s caller `watchTasksByEventId`: replace the simple `rows.map(_toDomain).toList()` with a path that fetches checklist rows per task in one batched query (e.g. `TaskChecklistItemsDao.allItemsByEventId(eventId)` returning `Map<String, List<TaskChecklistItem>>`) and merges them into each `TaskModel`. Add the batched query to the dao if missing. Fixes the latent X/Y bug as a side effect.
11b. `_fromFirestore` symmetry: when mirroring snapshots from Firestore into Drift, no change is needed — the checklist subcollection is mirrored separately by `_ensureChecklistMirror`. The list view reads from Drift, which holds both tables locally; the join happens at read time.
12. `TaskTile` shows an "Overdue" pill (key `tasks.tile.${id}.overdueBadge`) when `task.dueDate != null && _startOfDay(task.dueDate!).isBefore(_startOfDay(clock.now())) && task.status != TaskStatus.done`. `_startOfDay(DateTime d) => DateTime(d.year, d.month, d.day)` is a shared helper under `lib/app/features/tasks/application/tasks_filter.dart` (alongside the filter functions). Pill: terracotta background, white text, `labelSmall`, 8 px horizontal padding, 12 px radius. Tests freeze time via `withClock(Clock.fixed(...))`.
13. `TaskTile` shows a Priority pill (key `tasks.tile.${id}.priorityBadge`) when `task.priority > 0`. Labels: `1 → Low (sageLight)`, `2 → Medium (charcoal)`, `3 → High (terracotta)`. `priority == 0` (None) renders no pill.
14. The existing X/Y checklist text is preserved (per the user's "linear bar + fraction" choice). Same visibility rules as the bar: hidden when `checklistItems.isEmpty` OR `status == done`.

**Functional — Tasks screen overhaul:**

15. Introduce `TasksFilter` value object under `lib/app/features/tasks/application/tasks_filter.dart`. Fields: `Set<TaskStatus> statuses`, `bool onlyMine`, `bool onlyOverdue`, `bool onlyWithBudget`, `String query`, `TasksSortKey sortKey`, `TasksGroupBy groupBy`. **No `sortAscending` in V1** — direction is fixed per sort key (see req 17a). Defaults: all empty/false, sort = `TasksSortKey.dueDate`, groupBy = `TasksGroupBy.status`. Has `copyWith`, `==`, `hashCode`. Includes a `bool get hasActiveFilters` returning true when any of statuses/onlyMine/onlyOverdue/onlyWithBudget/query is non-default.
16. `TasksSortKey` enum: `dueDate, priority, created, title`. `TasksGroupBy` enum: `status, assignee, dueWindow`.
17. New pure function `applyTasksFilter(List<TaskModel>, TasksFilter, {required String currentUserId, required DateTime now}) → List<TaskModel>`. Order: filter → sort. Filtering rules:
    - `statuses.isNotEmpty` → keep tasks whose status is in the set.
    - `onlyMine` → keep tasks where `assigneeId == currentUserId`.
    - `onlyOverdue` → keep tasks where `dueDate != null && _startOfDay(dueDate).isBefore(_startOfDay(now)) && status != done` (uses the same `_startOfDay` as req 12).
    - `onlyWithBudget` → keep tasks where `budgetEstimate != null`.
    - `query.isNotEmpty` → case-insensitive substring against `title` OR `description ?? ''` after trimming the query.
17a. Sort direction per key (no user toggle in V1):
    - `dueDate` → ascending, nulls last.
    - `created` → descending (newest first), nulls last.
    - `priority` → descending (High → None first).
    - `title` → ascending, case-insensitive.
    Tie-break for all sorts: `id` ascending (deterministic).
18. New pure function `groupTasks(List<TaskModel>, TasksGroupBy, {required DateTime now, required Map<String,String> assigneeNames}) → List<TasksGroup>`. `TasksGroup` carries `label: String, key: String, tasks: List<TaskModel>`. Grouping rules:
    - `status` → groups in order Todo / In Progress / Done. Empty groups omitted.
    - `assignee` → groups by `assigneeId` (Unassigned bucket last), label uses `assigneeNames[uid]` falling back to truncated UID. Empty buckets omitted.
    - `dueWindow` → Overdue / Today / This week / Later / No due date. All comparisons use `_startOfDay(...)` from req 12. "This week" = days in `[startOfDay(now) + 1 day, startOfDay(now) + 7 days]`. "Later" = beyond 7 days. Empty buckets omitted.
19. `EventTasksPage` keeps a single `TasksFilter` in its state (session-only). All filter chips, search bar, sort menu, group toggle write through `setState(() => _filter = _filter.copyWith(...))`. The page passes the filtered+grouped lists down to `TaskListScreen` as `List<TasksGroup>`. Status grouping is the default; the result is always grouped — there is no flat-list back-compat path.
20. `TaskListScreen`'s API is collapsed: **drop** `selectedFilter: TaskStatus?` and `onFilterChanged: ValueChanged<TaskStatus?>?` (single caller, easy to update). **Add** `filter: TasksFilter, onFilterChanged: ValueChanged<TasksFilter>, groups: List<TasksGroup>`. The screen gains: a search row (`AppTextField` with leading `Icons.search`), a horizontal `Wrap` of filter chips (Mine, Overdue, Has budget, plus one per status), a sort `PopupMenuButton<TasksSortKey>` keyed `tasks.list.sortMenu` (header items keyed `tasks.list.sortMenu.${key}`), and a segmented group toggle `SegmentedButton<TasksGroupBy>` keyed `tasks.list.groupToggle`. Groups render as `_TasksGroupHeader` (`labelMedium` charcoal, faint sage line below) + tiles.
21. Empty-state behaviour:
    - `groups.isEmpty && !filter.hasActiveFilters` → existing "No tasks yet" empty state.
    - `groups.isEmpty && filter.hasActiveFilters` → new "No tasks match this filter" empty state with `Clear filters` button (key `tasks.list.emptyState.clear`) that resets to default `TasksFilter`.
21a. **Multi-assignee filtering is explicitly deferred to a future spec.** V1 ships `onlyMine: bool` only. When a per-assignee filter chip becomes a priority, `AppMultiSelect<T>` lands alongside (see req 5).

**Functional — Create / Edit task redesign:**

22. `CreateTaskScreen` and `EditTaskScreen` reshape their body as three `AppFormSection`s in this order: Details (title, description), Assignment (`AssigneePicker`, `AppRadioGroup<int>` priority), Timing & Budget (`AppDateField`, `AppCurrencyField`). The existing `FormCardShell` + `ContentMaxWidth` wrappers remain.
23. Priority field uses `AppRadioGroup<int>` with options `(0, 'None')`, `(1, 'Low')`, `(2, 'Medium')`, `(3, 'High')`. Defaults to `task.priority` on edit, `0` on create. Writes the int through the existing `TaskModel.priority` path — no schema change.
24. Migrate the existing due-date `InkWell`+`showDatePicker` to `AppDateField`. On wide web layouts, the inline calendar appears inside the same `FormCardShell` (clipped to its max-width).
25. `AssigneePicker` is refactored internally to use `AppDropdown<String?>` (built on `DropdownButtonFormField<String?>` per req 4) but keeps its current public API (`memberIds`, `displayNames`, `orphanAssigneeId`, `selected`, `onChanged`). The disabled "(no longer in event)" orphan row stays. The existing `Key('tasks.create.assignee')` MUST survive the refactor — pinned in a regression widget test (see `<validation>`).

**Functional — Duplicate action:**

26. `TaskDetailScreen` app bar gains a `PopupMenuButton<_DetailAction>` (key `tasks.detail.overflow`) when at least one of `onEdit` / `onDelete` / `onDuplicate` is non-null. Items in order: Edit (existing pencil action moves into the menu — drop the standalone icon), Duplicate, Delete (terracotta). RBAC: Edit + Delete only when `canEditTask`; Duplicate visible to any member (any member with read access can spawn a copy under their own `createdBy`).
27. `event_task_detail_page.dart` already watches `taskChecklistProvider((eventId, taskId))`. Pass the resolved checklist `List<ChecklistItem>` into a new factory `TaskModel.duplicate({required String currentUserId, required List<ChecklistItem> checklist})` that returns: new UUID, same `eventId`, **title built via grapheme-aware truncation**: `'${task.title.characters.take(113).toString()} (copy)'` (max 120 chars total; `characters` ships with Flutter — no new dep), same `description / assigneeId / dueDate / budgetEstimate / priority`, `checklistItems` = the passed list with each item re-uuid'd (preserve text / sortOrder / isCompleted), `createdBy = currentUserId`, `status = TaskStatus.todo`, `completedAt = null`, `completedBy = null`.
28. `TaskRepository` gains `Future<bool> createTaskWithChecklist(TaskModel task, List<ChecklistItem> items)` — uses a Firestore `WriteBatch`: parent task doc + N checklist subcollection docs in one atomic commit, then mirrors to Drift. The duplicate flow calls this; the existing `createTask` is unchanged (FAB-driven creates have no pre-filled checklist). Failure → terracotta snackbar; partial writes are impossible (batch is all-or-nothing).

**Error Handling:**

29. Every `bool`-returning mutation (`createTask`, `updateTask`, `deleteTask`) surfaces failures via terracotta `SnackBar` and keeps the form open. Already shipped — no regression.
30. Search input debounce: none in V1 (client-side filter, list size is small). If a future event has > 200 tasks, revisit.
31. `applyTasksFilter` / `groupTasks` never throw on null fields — null `dueDate`, null `description`, null `assigneeId` flow through without `!`-bang errors.

**Edge Cases:**

32. Task with no checklist items → progress bar absent. Tile renders compact.
33. Task with all checklist items completed but `status != done` → progress bar still 100 %; status icon shows whatever the status actually is (in-progress or todo). Do NOT auto-flip status — the user controls status.
34. Task `dueDate == today` (same day) → NOT overdue per requirement 12 (`isBefore(today)`). The day-of is still on-time.
35. Group-by-assignee when the assignee left the event → bucket label uses the resolved name from `usersByIdProvider` if available, else truncated UID. Already-orphan tasks sit in a bucket the user can edit to re-assign.
36. Sort-by-dueDate when many tasks have null due dates → nulls sort to the end regardless of ascending/descending.
37. Web wide-layout date picker selecting a date → state updates via the same `onChanged` callback path; no extra confirmation step (inline calendar acts as a continuous input).
38. Duplicate of a task whose checklist has 30 items → all 30 copied; each gets a fresh UUID; assignment + ordering preserved.

**Validation:**

39. `AppTextField` exposes `validator`; default form-level validation runs on save. Title validator (max 120 chars, required) is reused from the existing `CreateTaskScreen`.
40. Priority radio value is always one of `{0, 1, 2, 3}` — no `null`. UI never offers an unchecked state once initialised.
41. Search query is trimmed before comparing — leading/trailing whitespace ignored.
42. `clearable: true` on `AppDateField` provides a clear (`Icons.clear`) button when `value != null`; emits `onChanged(null)`.

</requirements>

<boundaries>

**Edge cases:**

- **Form kit dependency creep**: the new kit MUST NOT add any new pub package (no `flutter_form_builder`, no `reactive_forms`, no `material_design_icons`). Build on `flutter/material.dart` + the existing `intl` package only.
- **Responsive threshold**: `Breakpoints.compactMax` (= `600.0`, already defined in `lib/app/core/constants/breakpoints.dart`) is the single source of truth for the date-field inline/modal cutover and any future kit widget. Do not invent a parallel constant.
- **Locale parsing on `AppCurrencyField`**: when `Localizations.localeOf(context)` is unavailable (rare in tests), fall back to `'en_US'`. Today's `BudgetEstimateField` should be re-exercised on a test that does not set up a `Localizations` widget to confirm the fallback path.
- **Web hover/focus polish**: every kit widget MUST visually reflect focus and hover on web. No animations needed beyond Flutter's default Material transitions.
- **Search interaction on web**: keyboard focus on the search bar must NOT block other shortcuts (Tab to next field). The search row is rendered as a normal `Focus` node, not a `FocusScope` trap.
- **Pre-fill and dispose**: `EditTaskScreen` controllers must be disposed; the same applies to the new Duplicate-driven `CreateTaskScreen` push (already handled — Flutter disposes on route pop).
- **i18n contract**: all user-facing strings introduced by this PR (filter chip labels, sort/group menu labels, empty-state copy, "(copy)" suffix, priority labels) MUST route through `lib/app/core/i18n/app_strings.dart` as new fields on a `TasksStrings` (or equivalent) sub-object. Do NOT hardcode literals in widget files — the existing `app_strings.dart` migration path (see header comment in that file) breaks otherwise.

**Error scenarios:**

- **Firestore offline during sort/filter changes**: filtering/sorting/grouping is purely client-side, so the offline state is invisible to the user. Existing offline indicators in the detail screen still apply.
- **Inline calendar focus loss on web**: clicking outside the calendar must not throw; the picker is just a stateless widget reflecting `value`. Adding an `AnimatedSwitcher` is out of scope.
- **Grouping by assignee while `usersByIdProvider` is still loading**: group headers fall back to truncated UID until the future resolves; once resolved, the page rebuilds with names. No flash of "Unknown" — the loading state simply shows the UID prefix.
- **Sort stability**: when two tasks have identical sort-key values, the secondary order is `task.id` ascending so renders are deterministic across rebuilds.

**Limits:**

- **Maximum filter chip count**: 8 chips fit comfortably on a 360-px width without wrapping. If a future PR adds more, switch to a horizontal `ListView`.
- **Maximum tasks per group**: no hard cap. List uses `ListView.builder` already; performance is fine to ~500 tasks per event.
- **Title length on Duplicate**: appending `" (copy)"` may push the new title past 120 chars. Truncate the original to `113` chars and append `" (copy)"` so the result is ≤ 120.
- **No persisted preferences in V1**: filter/sort/group reset on each navigation. Deferred to a future spec.

</boundaries>

<implementation>

**Files to create:**

- `lib/app/core/widgets/forms/app_text_field.dart`
- `lib/app/core/widgets/forms/app_dropdown.dart`
- `lib/app/core/widgets/forms/app_date_field.dart`
- `lib/app/core/widgets/forms/app_radio_group.dart`
- `lib/app/core/widgets/forms/app_switch_tile.dart`
- `lib/app/core/widgets/forms/app_checkbox_tile.dart`
- `lib/app/core/widgets/forms/app_form_section.dart`
- `lib/app/core/widgets/forms/app_currency_field.dart`
- (`app_multi_select.dart` deferred — see req 5)
- `lib/app/features/tasks/application/tasks_filter.dart` — `TasksFilter`, `TasksSortKey`, `TasksGroupBy`, `TasksGroup` value objects + pure `applyTasksFilter` / `groupTasks` functions
- `lib/app/features/tasks/presentation/widgets/tasks_filter_bar.dart` — search row, chips, sort menu, group toggle
- `lib/app/features/tasks/presentation/widgets/task_progress_bar.dart` — the linear bar widget
- `test/app/core/widgets/forms/` — one test file per kit widget covering its contract
- `test/app/features/tasks/tasks_filter_test.dart` — pure-function coverage of filter/sort/group
- `test/app/features/tasks/widgets/task_progress_bar_test.dart`
- `test/journeys/tasks_filter_sort_group_journey_test.dart` — robot journey

**Files to modify:**

- `lib/app/core/widgets/custom_text_field.dart` — keep as a thin `StatelessWidget` wrapper delegating to `AppTextField`. `@Deprecated('Use AppTextField from lib/app/core/widgets/forms/app_text_field.dart')`. Constructor signature preserved exactly so existing call sites compile.
- `lib/app/features/tasks/presentation/widgets/budget_estimate_field.dart` — keep public API; internals delegate to `AppCurrencyField`.
- `lib/app/features/tasks/presentation/widgets/assignee_picker.dart` — render `AppDropdown<String?>` internally; preserve `displayNames` + `orphanAssigneeId` behaviour.
- `lib/app/features/tasks/presentation/widgets/task_tile.dart` — progress bar + overdue + priority pills; `clock` import.
- `lib/app/features/tasks/presentation/task_list_screen.dart` — **breaking API change** (one caller): replace `selectedFilter` / `onFilterChanged` with `filter: TasksFilter` + `onFilterChanged: ValueChanged<TasksFilter>` + `groups: List<TasksGroup>`. Render filter bar + group headers + per-filter empty state. Update the single caller (`event_tasks_page.dart`).
- `lib/app/features/tasks/presentation/event_tasks_page.dart` — hold `TasksFilter` state; compute filtered+grouped lists; thread to `TaskListScreen`.
- `lib/app/features/tasks/presentation/create_task_screen.dart` and `edit_task_screen.dart` — three `AppFormSection`s + priority field; `AppDateField`; `AppCurrencyField`.
- `lib/app/features/tasks/presentation/task_detail_screen.dart` — replace edit/delete icons with `PopupMenuButton<_DetailAction>`; add Duplicate option.
- `lib/app/features/tasks/presentation/event_task_detail_page.dart` — wire `onDuplicate`.
- `lib/app/features/tasks/domain/models/task.dart` — add `TaskModel.duplicate({required String currentUserId, required List<ChecklistItem> checklist})` factory (grapheme-aware `(copy)` truncation per req 27).
- `lib/app/features/tasks/data/task_repository.dart` — fix `watchTasksByEventId` to populate `TaskModel.checklistItems` via a batched join with `TaskChecklistItemsDao` (req 11a). Add `Future<bool> createTaskWithChecklist(TaskModel task, List<ChecklistItem> items)` using a Firestore `WriteBatch` (req 28).
- `lib/app/core/database/daos/task_checklist_items_dao.dart` — add `Future<Map<String, List<TaskChecklistItem>>> itemsByEventId(String eventId)` (or equivalent) so the join in `watchTasksByEventId` is a single query, not N queries.
- `lib/app/core/i18n/app_strings.dart` — extend with a `TasksStrings` sub-object (or add fields to an existing sub-object) for every new user-facing label introduced by this PR. New fields ride the existing migration path.
- `lib/app/core/constants/breakpoints.dart` — **no change**; `compactMax` already covers the responsive cutover (req 6).

**Patterns to use:**

- Form-kit widgets are `StatelessWidget` composed via `Focus` / `FocusableActionDetector` — no internal `FocusNode` lifecycle in the widgets we ship (`FocusableActionDetector` exposes hover + focus state without owning a node). No third-party state libraries.
- Pure functions for `applyTasksFilter` / `groupTasks` (no Riverpod, no async). The page wires them; the functions stay testable in isolation.
- `clock.now()` from the existing `clock: ^1.1.1` dependency so `withClock(...)` test setups can freeze time for overdue + due-window calculations.
- `kIsWeb` (from `flutter/foundation.dart`) guards web-only visual variants. Do NOT add any new package for platform detection.
- `LayoutBuilder` for `AppDateField`'s inline-vs-modal split. Not `MediaQuery.sizeOf(context)` — the widget responds to its allotted width, not the screen.

**What to avoid:**

- Do NOT introduce a forms-builder package (`flutter_form_builder` / `reactive_forms`). The kit covers our use cases and the project rule is one pattern per task.
- Do NOT churn every existing `CustomTextField` call site. Alias only.
- Do NOT add server-side sort / filter / group logic. All three are client-side; the existing Drift watcher emits the full list.
- Do NOT auto-flip task status to Done when checklist hits 100 % (edge case 33). The user chose to keep status user-controlled.
- Do NOT add chat / activity log writes when tasks change. Out of scope per the user's "tasks live independently" choice.
- Do NOT block the inline-calendar render on web behind a `kIsWeb` check alone — base the decision on the layout-allotted width via `LayoutBuilder` so the same widget works in a 400-px-wide form card on a desktop browser.

</implementation>

<validation>

**Required automated coverage outcomes** (each item must be a passing test before merge):

- **Unit tests — pure logic:**
  - `applyTasksFilter` filters by each predicate independently (statuses, onlyMine, onlyOverdue, onlyWithBudget, query) AND composes them.
  - `applyTasksFilter` is stable: identical input ⇒ identical output ordering.
  - `applyTasksFilter` sorts by each `TasksSortKey` with the fixed direction in req 17a; nulls sort last; tie-break is `id` ascending.
  - `groupTasks` returns groups in the spec'd order per `TasksGroupBy`; empty groups omitted; orphan assignees handled.
  - `_startOfDay`-driven: `overdue` predicate flips at start of day, not at the due-date timestamp; same-day due date is NOT overdue regardless of time-of-day.
  - `withClock(Clock.fixed(...))` test: `applyTasksFilter` with `onlyOverdue` at 02:00 UTC vs 23:00 UTC on the same day produces the same result for a same-day-due task.
  - `TaskModel.duplicate(currentUserId, checklist)` returns the expected shape: new id, `(copy)` suffix via grapheme-aware truncation (≤120 chars, no half-emoji), preserved fields, fresh checklist item UUIDs, status reset, `completedAt`/`completedBy` null.
  - `parseBudgetEstimate` regressions still pass (`en_US`, `de_DE`).

- **Widget tests — form kit (per file):**
  - `AppTextField` renders error text when validator returns non-null. Focus ring appears only on `kIsWeb` when focused (use `debugDefaultTargetPlatformOverride` or a `kIsWeb` shim — document the seam in the test header).
  - `AppTextField` accepts every parameter `CustomTextField` ships today (`hintText, controller, obscureText, keyboardType, onChanged, validator, prefixIcon, suffixIcon, maxLines, enabled, label`) — golden regression test asserts the rendered tree.
  - `CustomTextField` (the deprecated wrapper) delegates to `AppTextField` with identical visual output for the same parameters.
  - `AppDropdown` renders items; selecting fires `onChanged` with the typed value; disabled items don't. Built on `DropdownButtonFormField` — assert the underlying widget type in a test.
  - `AppDateField` (modal path / `LayoutBuilder` width < `Breakpoints.compactMax`) opens `showDatePicker` on tap. Test sets `tester.view.physicalSize = const Size(360, 800)` + `resetPhysicalSize` cleanup.
  - `AppDateField` (inline path / width ≥ `Breakpoints.compactMax`) renders `CalendarDatePicker` inline; tapping a date fires `onChanged`. Test sets `tester.view.physicalSize = const Size(1200, 800)` + cleanup.
  - `AppRadioGroup` highlights the current value; tapping another option fires `onChanged`; supports `int` and `enum` type parameters.
  - `AppSwitchTile` / `AppCheckboxTile` toggle correctly and surface `key`/title/subtitle.
  - `AppFormSection` renders title + optional helper + child column; padding is spec'd.
  - `AppCurrencyField` renders currency symbol, validates same as `BudgetEstimateField`, exposes the same error path. Locale fallback to `en_US` test: pump without a `Localizations` ancestor; parsing still works.

- **Widget tests — Tasks UI:**
  - `TaskTile` shows a progress bar when checklist non-empty AND status != done; bar fraction matches `completed/total` (width-ratio assertion against the `Container.constraints`); bar absent when checklist empty OR status == done.
  - `TaskTile` shows the "Overdue" pill only when `_startOfDay(dueDate) < _startOfDay(clock.now())` AND `status != done`. Frozen-clock test for all three statuses at three dates (yesterday, today, tomorrow) × three statuses.
  - `TaskTile` shows the priority pill only when `priority > 0`; pill colour matches level.
  - `AssigneePicker` regression: existing `Key('tasks.create.assignee')` survives the `AppDropdown`-internal refactor; orphan disabled-item behaviour intact (the Phase 1 widget tests continue to pass without modification).
  - `TaskRepository.watchTasksByEventId` returns `TaskModel`s whose `checklistItems` is populated (covers the data-source fix in req 11a).
  - `TaskRepository.createTaskWithChecklist` writes the parent + N children in one `WriteBatch`; failure (e.g., mocked Firestore throw) leaves nothing written; on success the Drift mirror reflects both task and items.
  - `TaskListScreen` renders the filter bar widgets; tapping a chip propagates `TasksFilter` changes via `onFilterChanged`.
  - `TaskListScreen` empty-state copy differs when filters are active vs not; `Clear filters` resets to default `TasksFilter`.
  - `CreateTaskScreen` and `EditTaskScreen` render three `AppFormSection`s in the spec'd order; priority radio defaults to None on create and `task.priority` on edit.
  - `TaskDetailScreen` overflow menu shows Edit + Delete for creator/admin and Duplicate for everyone; tapping Duplicate fires the callback.

- **Robot journey tests:**
  - `TasksJourneyRobot.searchFilterSortGroup` — open Tasks → search "lunch" → activate "Overdue" chip → switch sort to Priority → switch group to Assignee → assert visible tiles' titles + group headers. Uses `withClock(Clock.fixed(...))` for deterministic overdue calculation.
  - `TasksJourneyRobot.duplicateTask` — open detail → overflow → Duplicate → Create form opens pre-filled with " (copy)" suffix → save → list now has 2 tasks; Firestore reflects both.

**TDD expectations** (per `flutter-tdd` skill):

- Build slices one cycle at a time: RED test → GREEN minimal impl → REFACTOR. Order: pure functions (filter/sort/group) → form-kit widgets bottom-up → TaskTile additions → TaskListScreen filter bar → page wiring → Duplicate flow.
- Required seams:
  - `clock.now()` for time-dependent code so tests use `withClock(Clock.fixed(...))` rather than mocking `DateTime`.
  - `applyTasksFilter` / `groupTasks` accept `now: DateTime` and `currentUserId: String` parameters — never read them from globals.
  - `TaskTile` accepts an optional `now` override for test determinism, defaulting to `clock.now()`.
  - `AppCurrencyField` accepts an optional `localeOverride: String?` for tests that don't set up `Localizations`.
- Mocking policy: prefer fakes; mock only at the `usersByIdProvider`, Firestore, and `IUserRepository` boundaries (existing pattern).
- Justified exceptions: golden tests for the progress bar render are optional — a width-ratio assertion against the underlying `Container.constraints` is sufficient and avoids golden brittleness.

**Robot testing baseline** (per `flutter-robot-testing` skill):

- Stable selectors to add now (keys must be in the final code):
  - `tasks.list.search`, `tasks.list.search.field`, `tasks.list.sortMenu`, `tasks.list.sortMenu.${TasksSortKey.name}`, `tasks.list.groupToggle`, `tasks.list.filterChip.${name}`, `tasks.list.emptyState`, `tasks.list.emptyState.clear`, `tasks.list.groupHeader.${groupKey}`.
  - `tasks.tile.${id}.progressBar`, `tasks.tile.${id}.overdueBadge`, `tasks.tile.${id}.priorityBadge`.
  - `tasks.detail.overflow`, `tasks.detail.overflow.edit`, `tasks.detail.overflow.duplicate`, `tasks.detail.overflow.delete`.
  - `tasks.create.priority`, `tasks.edit.priority`, `tasks.create.section.details`, `tasks.create.section.assignment`, `tasks.create.section.timing` (mirrored on edit).
  - Form-kit per-widget: `forms.text`, `forms.dropdown`, `forms.multiSelect`, `forms.date`, `forms.radio`, `forms.switchTile`, `forms.checkboxTile`, `forms.currency`. Suffix `.${name}` per usage when the parent declares multiple instances.
- Deterministic seams in robot tests: `withClock(Clock.fixed(DateTime.utc(2026, 6, 15)))`, fake Firestore, override `usersByIdProvider` and `currentUserIdProvider`.
- Known testing risks:
  - The web-inline `AppDateField` test path requires the test viewport to be ≥600 wide; document in the test setup.
  - `SegmentedButton<TasksGroupBy>` taps may need `ensureVisible` on small test viewports.

**Default test-type mapping:**

- **Robot**: search → filter → sort → group cross-screen flow; Duplicate flow.
- **Widget**: empty state copy per filter, overflow menu visibility, form section ordering, validator error rendering, individual form-kit widgets.
- **Unit**: filter/sort/group pure functions, `TaskModel.duplicate`, `parseBudgetEstimate` regressions.

**Manual smoke** (before declaring done):

- Run on iOS simulator, Android emulator, and Chrome at 1200 × 800. Verify: inline calendar on Chrome, modal on mobile; sort menu opens; group toggle re-groups; Overdue pill renders when expected; Duplicate creates a new task with " (copy)" suffix.

</validation>

<done_when>

- All requirements 1–42 (plus 11a, 11b, 17a, 21a) implemented and covered by the tests in `<validation>`.
- `flutter analyze` clean (only the pre-existing `TableMigration` experimental warning remains).
- `flutter test` green with all new files included; full suite passes.
- `npm --prefix functions test` green (this PR does not change rules, but the suite must still pass).
- New form-kit widgets all live under `lib/app/core/widgets/forms/` (8 files; `AppMultiSelect` deferred), one widget per file, each with a unit/widget test.
- **All 29 existing `CustomTextField` call sites compile unchanged** — verified via `flutter analyze` with zero new errors on any of the 29 files (grep `import .*custom_text_field` to enumerate). Any deprecation warnings are acceptable.
- `TaskModel.checklistItems` is non-empty for tasks with checklists in the list-view path (regression check covers the pre-existing X/Y bug fix).
- Tasks screen renders search + chips + sort + group toggle on a 360-px-wide viewport without layout overflow; renders an inline calendar in `AppDateField` on a 1200-px-wide viewport.
- TaskTile renders progress bar (hidden when status == done), overdue badge, and priority pill per requirements 11–14 with `withClock`-deterministic tests.
- Duplicate path produces a Firestore document with a fresh id and `(copy)`-suffixed title, with all checklist items copied via the new `WriteBatch` path.
- All new user-facing strings live in `app_strings.dart` — no hardcoded literals in widget files (spot-check by greping for the literal labels).
- Branch suggestion: continue work on `task` (already exists, currently at the same head as `main`). No new branch needed.

</done_when>
