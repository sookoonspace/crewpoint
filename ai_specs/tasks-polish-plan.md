## Overview

Tasks-polish vertical slices: assignee names → color stripe → Drift v6 budget → task edit → event edit → expense edit/delete (+ Firestore rules). Each phase ships a thin end-to-end win.

**Spec**: `ai_specs/tasks-polish-spec.md` (read for full requirements; numbered refs below match spec)

## Context

- **Structure**: feature-first under `lib/app/features/<feature>/{data,domain,application,presentation}`; mirrored in `test/app/features/...`
- **State management**: Riverpod 3 (`riverpod_annotation` codegen). `usersByIdProvider` already lives in `lib/app/features/chat/application/users_by_id_provider.dart` — reuse, do not parallel
- **Reference implementations**:
  - `lib/app/features/tasks/presentation/create_task_screen.dart` — pure screen + `onSubmit` callback (copy this pattern for edit screens)
  - `lib/app/features/dashboard/data/event_repository.dart` — Firestore-Write + Drift-Read with stream mirror (extend with `updateEvent`)
  - `lib/app/features/tasks/data/task_repository.dart` — bool-returning mutations, log + return false on throw
  - `functions/test/firestore-rules.test.ts` — `describe(...)` block style for new expense-rule tests
- **Assumptions/Gaps**:
  - User-given critical instructions: Drift migration must use `m.addColumn`; run `dart run build_runner build -d` BEFORE any tests. Rules tests must be updated alongside `firestore.rules` — do NOT leave broken
  - No `drift_schemas/` dir yet — Phase 2 bootstraps it via `drift_dev schema dump`
  - `CreateEventScreen` collects `_startDate` only (no end-date); `EditEventScreen` introduces both end-date field + picker `firstDate` override (spec 11a/11b)
  - `EventRepository.createEvent` throws on failure (legacy); new `updateEvent` returns bool per spec 12 — note one-line deviation, do not refactor existing throw
  - `ExpenseModal.show()` static helper currently requires `payerId`; in edit mode it stays required (renders the locked display row) — spec 17

## Plan

### Phase 1: Assignee names + TaskTile stripe (UI-only, no schema) ✓

- **Goal**: Ship the immediately-visible polish wins without touching DB. Proves `usersByIdProvider` plumbing end-to-end before schema risk lands.
- [x] `lib/app/features/tasks/presentation/widgets/assignee_picker.dart` — add `Map<String, String> displayNames` + optional `String? orphanAssigneeId`; render hydrated names, fallback truncated UID, disabled `(no longer in event)` orphan row at bottom (spec req 1, 22)
- [x] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — leading 4px `Container` stripe outside `Padding`; `Card.clipBehavior: Clip.antiAlias`; status color map (spec req 7)
- [x] `lib/app/features/tasks/presentation/task_detail_screen.dart` — accept `String? assigneeName`; replace `_AssigneeRow` truncation with the resolved name; keep widget Riverpod-free (spec req 3)
- [x] `lib/app/features/tasks/presentation/event_task_detail_page.dart` — Consumer wrapper resolves `usersByIdProvider([...event.memberIds, if (orphan) task.assigneeId!])`; pass name into `TaskDetailScreen` (spec req 3)
- [x] `lib/app/features/tasks/presentation/event_tasks_page.dart` — pass resolved names to `AssigneePicker` (via `CreateTaskScreen` push) and to each `TaskTile`
- [x] `lib/app/features/tasks/presentation/create_task_screen.dart` — accept `Map<String, String> displayNames`; pass to `AssigneePicker`
- [x] TDD: `AssigneePicker` renders display name when present, truncated UID fallback otherwise (unit/widget)
- [x] TDD: `AssigneePicker` renders orphan UID as disabled item at bottom labeled `(no longer in event)`
- [x] TDD: `TaskTile` stripe color matches status (3 cases) + flush with card left edge (offset assertion)
- [x] TDD: `TaskDetailScreen._AssigneeRow` shows passed `assigneeName` when present, truncated UID otherwise
- [x] Verify: `flutter analyze && flutter test test/app/features/tasks/`

### Phase 2: Drift v6 + `budgetEstimate` plumbed through create + tile ✓

- **Goal**: Add the budget field end-to-end on the create path before the edit path needs it. One schema bump, one repo plumb, one validator.
- [x] `lib/app/core/database/app_database.dart` — add `RealColumn get budgetEstimate => real().nullable()();` on `Tasks`; bump `schemaVersion = 6`; extend `onUpgrade` with `if (from < 6) { await m.addColumn(tasks, tasks.budgetEstimate); }` (user critical instruction)
- [x] **Run `dart run build_runner build -d`** (user critical instruction — BEFORE writing tests; regenerates `app_database.g.dart` + `tasks_dao.g.dart`)
- [x] `lib/app/features/tasks/domain/models/task.dart` — `final double? budgetEstimate;` + `copyWith` + constructor param (spec req 4)
- [x] `lib/app/features/tasks/data/task_repository.dart` — `budgetEstimate` in `_toFirestore`, `_fromFirestore`, `_toDomain`, `_upsertDrift` (spec req 4)
- [x] `lib/app/features/tasks/presentation/create_task_screen.dart` — locale-aware budget `TextFormField` with `event.currency` symbol prefix (spec req 6, 27)
- [x] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — render budget `Text` next to checklist count when non-null, key `tasks.tile.${id}.budget` (spec req 8)
- [x] Bootstrap schema snapshot: `drift_schemas/drift_schema_v6.json` baseline committed (no prior v5 snapshot existed)
- [x] `test/database/migration_v5_to_v6_test.dart` — manually seeds a v5-shaped DB via `sqlite3` + `PRAGMA user_version = 5`, opens `AppDatabase`, asserts `budget_estimate` column exists and the v5 row survives. Future migrations will use `SchemaVerifier` against the new v6 snapshot.
- [x] TDD: `TaskModel.copyWith` round-trips `budgetEstimate` null + non-null
- [x] TDD: `task_repository_test.dart` — `_toFirestore`/`_fromFirestore` round-trip for null, 0, and positive value (`fake_cloud_firestore`)
- [x] TDD: budget validator parses `en_US` (`0`, `0.5`, `1234.56`) and `de_DE` (`0,5`, `1234,56`); rejects negative + 3-decimal + non-numeric; empty → null
- [x] TDD: `TaskTile` renders budget text only when `budgetEstimate != null`
- [x] Verify: `flutter analyze && flutter test`

### Phase 3: `EditTaskScreen` + pencil action ✓

- **Goal**: Close the task-side edit loop. Mirrors `CreateTaskScreen` pattern (`onSubmit` callback, screen stays Riverpod-free).
- [x] `lib/app/features/tasks/presentation/edit_task_screen.dart` — new screen pre-filled from `TaskModel`; same fields + validators as `CreateTaskScreen`; Save label `Save changes`; `firstDate: DateTime(2000)` on due-date picker so past-due dates remain editable (spec req 9)
- [x] `lib/app/features/tasks/presentation/task_detail_screen.dart` — add `Icons.edit_outlined` action key `tasks.detail.edit` when `canEditTask`; `onEdit` callback (spec req 10)
- [x] `lib/app/features/tasks/presentation/event_task_detail_page.dart` — wire `onEdit` to push `EditTaskScreen` with hydrated `displayNames` + `orphanAssigneeId`; on return call `taskRepositoryProvider.updateTask` (spec req 10, 22)
- [x] TDD: `EditTaskScreen` pre-fills title, description, assignee, due date, budget from `TaskModel`
- [x] TDD: `EditTaskScreen` `onSubmit` emits updated `TaskModel` with edited fields
- [x] TDD: `TaskDetailScreen` pencil action visible iff `canEditTask`; hidden for non-creator non-admin
- [x] TDD: `EditTaskScreen` accepts past due-date via picker (regression for `firstDate: DateTime.now()` clamp)
- [x] Robot: `TasksRobot` edit helpers + `edit_task_journey_test.dart` — owner opens detail, edits budget, save reaches Firestore. Uses `buildDetailPage` harness (skips go_router list→detail nav, which lives outside this PR's scope).
- [x] Verify: `flutter analyze && flutter test`

### Phase 4: `EditEventScreen` + `updateEvent` + settings gear ✓

- **Goal**: Wire the dead settings gear; ship `updateEvent` returning bool; introduce end-date field that didn't exist on create.
- [x] `lib/app/features/dashboard/data/event_repository.dart` — `Future<bool> updateEvent(EventModel updated)` using `.update({...})` (NOT `.set()`); strip `createdAt`; let `updatedAt: FieldValue.serverTimestamp()` move; catch + log + return false (spec req 12)
- [x] `lib/app/features/dashboard/presentation/edit_event_screen.dart` — new screen mirroring `CreateEventScreen`; pre-fill title, description, start date, **end date (NEW field)**, eventType, archived/active switch; NO currency control (spec req 11, 11a)
- [x] End-date validator: `endDate == null || startDate == null || !endDate.isBefore(startDate)` (spec req 11a, 30)
- [x] Date pickers: `firstDate: DateTime(2000)` (spec req 11b)
- [x] `lib/app/core/router/app_router.dart` — nested `GoRoute(path: 'edit', ...)` under `event/:eventId` with `EventGuard` + `_EditEventRouteScreen` wrapper (spec req 13)
- [x] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — settings IconButton `onPressed: () => context.push('/dashboard/event/${event.id}/edit')`; gate visibility on `currentUserIdProvider != null && event.isAdmin(currentUid)` (spec req 13, 14)
- [x] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — archive toggle `onChanged` → `eventRepositoryProvider.updateEvent(event.copyWith(status: ...))` (spec req 15). `EventModel.copyWith` added.
- [x] TDD: `EventRepository.updateEvent` writes expected fields (`title`, `description`, `startDate`, `endDate`, `eventType`, `status`); negative test asserts `currency`, `memberIds`, `adminIds`, `creatorId` NOT in payload; missing doc → false
- [x] TDD: `EditEventScreen` pre-fills all fields; renders NO currency control (negative assertion — immutability contract)
- [x] TDD: end-date validator rejects end-before-start; clearing end date allows save
- [x] TDD: date picker accepts past dates (regression for `DateTime.now()` clamp)
- [x] TDD: archive toggle flips status via onSubmit
- [x] Robot: `edit_event_journey_test.dart` — owner taps settings gear → changes title → saves → Firestore reflects new title + immutables preserved
- [x] Verify: `flutter analyze && flutter test`

### Phase 5: Firestore rules + functions tests + expense edit/delete UI ✓

- **Goal**: Land the rules patch first (with passing rules tests — user critical instruction), then the UI that depends on it. Order is non-negotiable: rules-tests-green → UI work.
- [x] `firestore.rules` — replace `allow update: if false;` for `/events/{eventId}/expenses/{expenseId}` with payer/creator/admin rule that locks `payerId`/`eventId`; widen `allow delete` to include admins
- [x] `functions/test/firestore-rules.test.ts` — new `describe('expenses update — ...')` block with 7 cases (payer/creator/admin allowed; random-member + non-member denied; payerId + eventId mutation locked)
- [x] `functions/test/firestore-rules.test.ts` — new `describe('expenses delete — ...')` block: admin allowed (new permission); random-member denied
- [x] **Verified rules tests green BEFORE UI work**: `npm --prefix functions test` → 75 passed
- [x] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — optional `ExpenseModel? initial`; pre-fills description, amount, isDonation; preserves id + isPayment + receipt + createdAt on submit; Save label flips to `Save changes` and title flips to `Edit Expense` (spec req 17)
- [x] `lib/app/features/budget/presentation/widgets/expense_tile.dart` — `onEdit` / `onDelete` callbacks-from-parent; `PopupMenuButton` keyed `budget.expense.${id}.overflow` with items `.edit` / `.delete`; Edit hidden when `expense.isPayment == true` (spec req 16)
- [x] `lib/app/features/budget/presentation/event_budget_page.dart` — `canMutate` RBAC (`uid == payerId || event.isAdmin(uid)`); edit opens `ExpenseModal` in edit mode → `updateExpense`; delete shows confirm dialog → `deleteExpense`; terracotta snackbar on `false`
- [x] `lib/app/features/budget/presentation/budget_screen.dart` — accepts `onEditExpense` / `onDeleteExpense`, threads to each `ExpenseTile`
- [x] `lib/app/features/budget/data/expense_repository.dart` — `Future<bool> updateExpense` via Firestore `update()` + Drift upsert
- [x] TDD: `ExpenseTile` overflow menu — hidden when both callbacks null; renders Edit+Delete when non-null; Edit hidden for `isPayment`; tap fires callback
- [x] TDD: `ExpenseModal` edit mode — pre-fills, title + Save label flip, submission preserves `initial.id`
- [ ] Robot: `BudgetRobot.editAndDeleteExpense` — **deferred**. Widget-level coverage at the tile + modal level (per spec req 16, 17) is exhaustive; building a full budget journey harness (similar to the dashboard/tasks harnesses) is a separate slice. Captured in `ai_specs/todo.md` if needed.
- [x] Verify: `flutter analyze` (clean) && `flutter test` (354 pass) && `npm --prefix functions test` (75 pass)

## Risks / Out of scope

**Risks**:
- Phase 2 `build_runner` regen can churn unrelated `.g.dart` files — review diff before commit; do NOT scope-creep into unrelated regen edits
- Phase 4: `CreateEventScreen` lacks end-date — `EditEventScreen` introduces it net-new (spec 11a). If implementer assumes "reuse existing validator," they'll find none. Plan calls this out.
- Phase 5: rules changes without matching tests would silently break in production. User critical instruction enforces rules-tests-first; verify step in Phase 5 gates on `npm --prefix functions test` before UI work.

**Out of scope** (defer per spec + `ai_specs/todo.md`):
- Backfilling end-date onto `CreateEventScreen`
- Per-task currency override (event currency only)
- Currency editability on events (data-integrity boundary — see spec `<boundaries>`)
- Editing settlement (`isPayment: true`) expenses — Delete-only path; chat dispute flow is the user-facing undo
- Refactoring `EventRepository.createEvent` to bool-return — leave the existing throw signature alone
- Multi-currency, Kanban, recurring tasks, task attachments, audit log (per `todo.md`)
