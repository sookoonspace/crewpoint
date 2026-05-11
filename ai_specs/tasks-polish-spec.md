<goal>
Polish the Tasks feature so it stops looking like a stub and ships as a usable V1.5, and round out CrewPoint's "edit anything you can create" story so admins can fix mistakes instead of delete-and-recreate.

Concretely:

1. **Tasks — assignee names + budget + edit screen + color stripe.** Replace truncated UIDs with hydrated display names, add an optional per-task budget estimate (display-only, event currency), ship a full `EditTaskScreen` mirroring `CreateTaskScreen`, and give each tile a 4px left-edge status color stripe.
2. **Events — full editability.** Owner/admin can edit every field on an event after creation (title, description, dates, eventType, archive status), reachable from the existing-but-dead settings icon in `EventDashboardScreen`. Reuses the existing create-event form shell.
3. **Budget — expense edit + delete UI.** Repository already supports `updateExpense` / `deleteExpense`; wire an overflow menu (⋮) on each `ExpenseTile` with Edit (opens existing `ExpenseModal` pre-filled) and Delete, RBAC = payer OR event owner/admin.
4. **Events audit doc.** A short companion report (`ai_specs/events-gaps-audit.md`) listing other event gaps (notifications, settings, audit log, etc.) that are NOT in this spec — captured for later prioritization.

This work targets the existing `crewpoint_app` Flutter codebase. No new packages required.

Beneficiaries: event admins and creators who need to correct typos, fix dates, or change task assignment/budget without rebuilding state; members who today stare at truncated UIDs in the assignee dropdown.
</goal>

<background>
**Tech stack & conventions** (established in `tasks-budget-chat-plan.md` and `core-event-management-plan.md`):

- Flutter 3.11.5 / Dart 3.x; Riverpod 3 (`riverpod_annotation` codegen); `go_router` 14.
- Firebase: `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`.
- Drift 2.25 (offline cache); current `schemaVersion` is **5** → this spec bumps to **6**.
- Layering per feature: `data/` (repositories, services), `domain/` (models, repository interfaces), `application/` (Riverpod providers/notifiers), `presentation/` (screens, widgets).
- Brand palette in `@lib/app/core/constants/app_colors.dart` — `terracotta` for destructive/urgent, `sage`/`sageDark` for progress, `lightGrey`/`mediumGrey` for muted, `charcoal` text.
- Existing `usersByIdProvider` (`@lib/app/features/chat/application/users_by_id_provider.dart`) is the canonical UID→display-name resolver; reuse it (do NOT create a parallel one).

**Files to examine before implementing:**

- @lib/app/features/tasks/presentation/widgets/assignee_picker.dart — currently shows truncated UIDs; comment on line 8 even mentions the planned `usersByIdProvider` hydration.
- @lib/app/features/tasks/presentation/create_task_screen.dart — pattern for the edit screen; copy structure, accept an existing `TaskModel` for pre-fill.
- @lib/app/features/tasks/presentation/task_detail_screen.dart — `_AssigneeRow` also shows truncated UID at lines 144–148; add pencil action in app bar next to existing delete.
- @lib/app/features/tasks/presentation/widgets/task_tile.dart — add color stripe.
- @lib/app/features/tasks/domain/models/task.dart — add `budgetEstimate` field + `copyWith`.
- @lib/app/features/tasks/data/task_repository.dart — `_toFirestore`, `_fromFirestore`, `_upsertDrift`, `_toDomain` all need budget plumbing.
- @lib/app/core/database/app_database.dart — schema v5; bump to v6 with `addColumn` migration for `tasks.budgetEstimate`.
- @lib/app/features/dashboard/presentation/event_dashboard_screen.dart — settings icon at line 189–197 is a no-op `onPressed: () { /* Event settings */ }`; route it to the new edit screen.
- @lib/app/features/dashboard/presentation/create_event_screen.dart — extract a reusable form widget; reuse from edit screen.
- @lib/app/features/dashboard/domain/models/event.dart — `EventModel`, `EventType`, `EventStatus`, `isOwner`/`isAdmin` helpers.
- @lib/app/features/dashboard/data/event_repository.dart — already Firestore-Write / Drift-Read on create (`createEvent` writes Firestore + the listener mirrors to Drift). The only gap is `updateEvent`, which doesn't exist yet. The `todo.md` "EventRepository write path doesn't reach Firestore" line is stale and is being removed in `events-gaps-audit.md`.
- @lib/app/features/budget/presentation/widgets/expense_tile.dart — add overflow menu.
- @lib/app/features/budget/presentation/widgets/expense_modal.dart — extend to accept an existing expense for edit mode; do not duplicate the form.
- @lib/app/features/budget/data/expense_repository.dart — `updateExpense` / `deleteExpense` already exist; just call them.
- @firestore.rules — current state: `events/{id}` update allows owner/admin and locks `memberIds`/`adminIds`/`creatorId` (line 28–33); task update allows owner/admin/assignee with `eventId`/`createdBy` locked (line 74–79); `expenses/{id}` update is **`allow update: if false;`** (line 117) and expense delete excludes admins (line 113–115, payer OR creator only). This spec ships rule changes — see requirements 18 + 18a.

**Out of scope** (captured separately or deferred):

- Anything in `ai_specs/events-gaps-audit.md` — settings-screen feature, notification preferences, audit log, transfer ownership, event templates, real archive-toggle-from-list-view, calendar export.
- Multi-currency display per task (task budget renders in the event currency only).
- Recurring tasks, task templates, task attachments (already in `todo.md`).
- Expense receipt OCR or per-line splits beyond what `ExpenseModal` already supports.
- Web platform polish for the new screens — they inherit the existing responsive shell; no special handling.
</background>

<user_flows>

## Tasks

**Primary — see a real assignee name and a budget estimate:**

1. Open Tasks tab on any event → list renders tiles. Each tile has a 4px left-edge color stripe: grey for To Do, sage for In Progress, sageDark for Done.
2. Tap "+" FAB → `CreateTaskScreen`. The Assignee dropdown shows **"Bo Lyons"** instead of `MgFqg21h7…`. Below the due-date picker is a new optional "Budget Estimate" field with the event's currency symbol (e.g. `$`) as prefix. Enter `50` → save.
3. Tile shows assignee initials/name and `$50` chip.
4. Tap tile → `TaskDetailScreen` shows `Assigned to Bo Lyons` and `Estimate: $50` rows.

**Primary — edit a task (creator/owner/admin):**

1. From `TaskDetailScreen`, tap the new pencil icon in the app bar (left of the existing delete icon).
2. `EditTaskScreen` opens pre-filled with current values.
3. Change assignee from "Bo" to "Pat", add description, bump budget to `75` → Save.
4. Repository persists to Firestore + Drift; list updates live; detail screen pops back with updated values.

**Alternative — non-creator non-admin opens a task:**

- App bar shows neither pencil nor delete icon. Detail body is read-only (status toggle still respects existing `canChangeStatus` for assignees).

**Error:**

- Edit save with network failure → keep form open, terracotta snackbar "Could not save changes", do not navigate back.
- Display-name fetch fails for some UIDs → fall back to "Unknown member (`Mg…`)" using the existing 8-char truncation convention.
- Budget estimate entered as negative or non-numeric → form validation rejects with `"Estimate must be a non-negative number"`.

## Events

**Primary — admin edits an event:**

1. From `EventDashboardScreen`, tap the settings gear (top-right). Today it's a no-op; this spec wires it to `EditEventScreen`.
2. `EditEventScreen` opens pre-filled. All fields editable: title, description, start/end dates, eventType, archived/active toggle.
3. Save → `EventRepository.updateEvent` writes to Firestore (also Drift mirror); dashboard refreshes via the existing event stream.

**Alternative — non-admin opens dashboard:**

- Settings gear is hidden (already gated by `event.isAdmin(event.creatorId)` at line 188 — keep gate, but also gate on `currentUserIdProvider` so members never see it).

**Alternative — admin shifts dates past existing task due dates:**

- No auto-adjustment. Tasks with `dueDate` outside the new range remain unchanged. Spec explicitly defers any "shift tasks too?" UX to a future iteration.

**Error:**

- Update Firestore call fails → keep form open, terracotta snackbar "Could not save event", values retained.
- Validation: title required (1–200 chars); end date must not precede start date (existing rule from `CreateEventScreen` — reuse the same validator).

## Budget

**Primary — edit an expense:**

1. In `EventBudgetPage`, tap the ⋮ overflow menu on any `ExpenseTile` → menu shows Edit, Delete (and Cancel on mobile).
2. Edit → `ExpenseModal` opens pre-filled with description, amount, payer, splits, receipt.
3. Adjust amount → Save → `ExpenseRepository.updateExpense` writes; ledger re-computes live.

**Primary — delete an expense:**

1. Tap ⋮ → Delete → confirmation dialog "Delete this expense? It will be removed for everyone and balances will update."
2. Confirm → `ExpenseRepository.deleteExpense`; tile disappears; ledger updates.

**Alternative — non-payer non-admin:**

- Overflow menu is hidden entirely (cleaner than greyed-out items per existing convention).

**Error:**

- Update/delete fails → terracotta snackbar; tile stays as-is.
- Edit attempts to set negative amount or empty description → existing `ExpenseModal` validators reject.

</user_flows>

<requirements>

**Functional — Tasks:**

1. `AssigneePicker` accepts a `Map<String, String> displayNames` (uid → "First Last") parameter; dropdown items render `displayNames[uid] ?? '${uid.substring(0, 8)}…'` with `Unknown member` prefix when the map has no entry.
2. `CreateTaskScreen` and `EditTaskScreen` watch `usersByIdProvider(event.memberIds)` and pass the resolved map to `AssigneePicker`. Loading state shows a single shimmer/placeholder row so the picker isn't empty for one frame.
3. `TaskDetailScreen._AssigneeRow` accepts the resolved name as a constructor param (`String? assigneeName`) so the screen stays pure-presentation and Riverpod-free. `event_task_detail_page.dart` (the Consumer wrapper) reads `usersByIdProvider([...event.memberIds, if (task.assigneeId != null) task.assigneeId!])`, resolves the name, and passes it down. Keeps the existing "(no longer in event)" italic when the assignee is no longer in `event.memberIds`.
4. `TaskModel` gains `final double? budgetEstimate;` (nullable, non-negative). `copyWith` accepts it. Persisted in Firestore as `budgetEstimate` (number) and Drift as `budget_estimate REAL NULL`.
5. Drift schema bump: `schemaVersion = 6`. Migration adds `tasks.budgetEstimate` as a nullable real column. Existing rows default to `null`.
6. `CreateTaskScreen` and `EditTaskScreen` show a "Budget Estimate" `TextFormField` with `keyboardType: TextInputType.numberWithOptions(decimal: true)`. Prefix = event's currency symbol (use `intl`'s `NumberFormat.simpleCurrency(name: event.currency).currencySymbol`). Empty input persists as `null`.
7. `TaskTile` renders a 4px-wide leading stripe colored by status — todo `AppColors.lightGrey`, inProgress `AppColors.sage`, done `AppColors.sageDark`. Implementation: set `Card.clipBehavior: Clip.antiAlias` so the existing 12-px radius clips the stripe; wrap the existing inner content in a `Row` whose first child is `Container(width: 4, color: <statusColor>)` *outside* the `Padding(EdgeInsets.all(AppSpacing.md))` (i.e., the stripe must reach the card's left edge, not sit inside the padding). Widget test asserts the stripe is flush with the card edge.
8. `TaskTile` shows the budget next to the existing checklist count when `task.budgetEstimate != null`, using the same `Text` styling as the checklist count (no Material `Chip` — matches existing visual rhythm). Format: `NumberFormat.simpleCurrency(name: event.currency).format(task.budgetEstimate)`; key `tasks.tile.${task.id}.budget`.
9. New `EditTaskScreen` widget: same form fields and validators as `CreateTaskScreen`, plus pre-fill from a `TaskModel` constructor arg and an `onSubmit(TaskModel updated)` callback. Save button label: `Save changes`.
10. `TaskDetailScreen` app bar shows a pencil icon (`Icons.edit_outlined`, key `tasks.detail.edit`) when `canEditTask`; tap pushes `EditTaskScreen` and on return calls `TaskRepository.updateTask`.

**Functional — Events:**

11. New `EditEventScreen` widget: pre-filled form with **title, description, start date, end date, eventType, archived/active switch**. Editable fields are exactly that set. **Currency is NOT editable** (see boundary note) and `memberIds`/`adminIds`/`creatorId` are server-gatekept (Cloud Functions only). Title required, max 200 chars (reuse the existing `CreateEventScreen` title validator).
11a. End-date is a new field — it does NOT exist on `CreateEventScreen` (which only collects `_startDate`). `EditEventScreen` introduces it as an optional `ListTile`+`showDatePicker` row mirroring the start-date row. Validator: `endDate == null || startDate == null || !endDate.isBefore(startDate)`; error message `'End date must be on or after start date'`. Out of scope: backfilling end-date onto `CreateEventScreen` (defer).
11b. Both date pickers on `EditEventScreen` override `CreateEventScreen`'s `firstDate: DateTime.now()` clamp. Use `firstDate: DateTime(2000)` (or whatever's earlier than the pre-filled value) so admins can correct back-dated events. Keep `lastDate: DateTime.now().add(Duration(days: 365 * 2))` from create.
12. `EventRepository` gains `Future<bool> updateEvent(EventModel updated)` that calls Firestore `_eventsRef.doc(updated.id).update({...})` (NOT `set()` — avoid blanking unset fields). Mirror picks up the change automatically via the existing listener. Strip `createdAt` from the payload; let `updatedAt: FieldValue.serverTimestamp()` move. Return `false` on caught exception per the existing repo convention (`createEvent` currently throws — `updateEvent` should follow the rest-of-app pattern of bool-returning mutations).
13. `event_dashboard_screen.dart` settings IconButton (line 192) `onPressed` routes to `EditEventScreen` via `context.push('/dashboard/event/${event.id}/edit')`. Add the corresponding `GoRoute` nested under the existing `event/:eventId` route at @lib/app/core/router/app_router.dart:138 (alongside `members`, `budget`, `chat`, `tasks`).
14. Settings IconButton visibility gates on `currentUserIdProvider != null && event.isAdmin(currentUid)` — replace the current `event.isAdmin(event.creatorId)` check, which only works coincidentally when the creator is viewing.
15. Archive toggle on the dashboard (lines 542–558) is now redundant — leave it for backward affordance but wire its `onChanged` to the same `updateEvent` path with only `status` changed. Both surfaces converge on `updateEvent`.

**Functional — Budget:**

16. `ExpenseTile` gains a trailing `PopupMenuButton<_ExpenseAction>` (icon `Icons.more_vert`). RBAC lives in the parent (`EventBudgetPage`); the tile takes new nullable callbacks `VoidCallback? onEdit, VoidCallback? onDelete`. The menu renders only when at least one callback is non-null. Hidden items: omit `Edit` when `expense.isPayment == true` (settlement payments can only be Deleted — that path already powers the chat dispute flow; editing one would desync the pinned chat notice). Key the menu `budget.expense.${id}.overflow`, items `budget.expense.${id}.edit` / `budget.expense.${id}.delete`.
17. `ExpenseModal` accepts an optional `ExpenseModel? initial` constructor param. When non-null: pre-fills description, amount, splits, receipt; **locks `payerId` (display-only — no payer dropdown in edit mode)**; reuses `initial.id` on submit; emits `initial.copyWith(...)` rather than minting a new model; Save button label is `Save changes`. The existing required `payerId` constructor param remains required (used to render the locked display row).
18. Edit submission calls `ExpenseRepository.updateExpense`; Delete invokes a `showDialog` confirmation ("Delete this expense? It will be removed for everyone and balances will update.") then calls `ExpenseRepository.deleteExpense`. Both return `bool`; UI surfaces a terracotta snackbar on `false`.
18a. **Firestore rules (`firestore.rules`)**: replace the current `allow update: if false;` for `/events/{eventId}/expenses/{expenseId}` (line 117) with a rule that permits the payer, event creator, OR event admins to update, while locking `payerId`, `eventId`, and `id`. Concretely: `allow update: if request.auth != null && (resource.data.payerId == request.auth.uid || get(/databases/$(database)/documents/events/$(eventId)).data.creatorId == request.auth.uid || request.auth.uid in get(/databases/$(database)/documents/events/$(eventId)).data.adminIds) && request.resource.data.payerId == resource.data.payerId && request.resource.data.eventId == resource.data.eventId;`. **Widen the existing expense-delete rule (line 113–115) to include admins** so it matches the new update path: add `|| request.auth.uid in get(...).data.adminIds`. Update `functions/test/` (or wherever the rules tests live per `tasks-budget-chat-plan.md` Phase 1) with positive + negative cases for payer/admin/creator/random-member edit + delete.

**Error Handling:**

19. All save paths (`updateTask`, `updateEvent`, `updateExpense`, `deleteExpense`) return `bool`; UI shows a terracotta `SnackBar` on `false` and keeps the form open / tile in place.
20. Display-name resolution failure for any UID → fall back to `'${uid.substring(0, 8)}…'` rather than throwing; never block render on the future.
21. Drift migration failure (v5→v6) → log via `developer.log(name: 'db')` and propagate; do not silently swallow.

**Edge Cases:**

22. Task assignee left the event after assignment: `AssigneePicker` accepts an optional `String? orphanAssigneeId` param (the current `task.assigneeId` when it's not in `event.memberIds`). The picker's parent calls `usersByIdProvider([...event.memberIds, if (orphanAssigneeId != null) orphanAssigneeId])` so the name resolves. The dropdown renders the orphan as a disabled `DropdownMenuItem` (label `'<name> (no longer in event)'`) pinned to the bottom of the list, and `selected == orphanAssigneeId` keeps it as the picker's value until the user picks a different one. Once cleared or reassigned, the orphan cannot be re-selected (the disabled item stays in the list but never becomes selectable through `onChanged`).
23. Editing event eventType from `trip` to `project` doesn't migrate any derived data; `EventType.fromString` already defaults unknown values to `custom`, so downgrading remains safe.
24. Editing event archived → unarchived flips `status` only; `updatedAt` server timestamp moves; nothing else.
25. Concurrent edits: last-write-wins (no optimistic locking in V1 — match existing repo convention).
26. Task budget = 0 is a valid value distinct from `null` ("estimated free / TBD" vs "unspecified"). Tile shows `$0` chip; detail shows `Estimate: $0.00`.

**Validation:**

27. Budget input: locale-aware parse via `NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).tryParse(raw.trim())` so the input matches what `NumberFormat.simpleCurrency` renders (e.g. `50,00` in `de_DE`, `50.00` in `en_US`). Reject when parse returns null, value is negative, or value has more than 2 fractional digits (test via `(value * 100).round() != value * 100` with a small epsilon). Error: `"Estimate must be a non-negative number with up to 2 decimals"`. Empty string is valid and persists as `null`.
28. Edit-task title: same `min 1 / max 120` validator as `CreateTaskScreen`.
29. Edit-event title: same `min 1 / max 200` validator as `CreateEventScreen`.
30. Date range: `endDate == null || startDate == null || !endDate.isBefore(startDate)`.

</requirements>

<boundaries>

**Edge cases:**

- **Empty member list for assignee picker:** dropdown shows only `Unassigned`; no error.
- **`usersByIdProvider` still loading on first build:** picker shows current selection as `Loading…` placeholder; switch to hydrated names when resolved (re-build via `ref.watch`).
- **Task whose `assigneeId` UID is not in the resolved map (rare race):** show `Unknown member (Mg…)` rather than empty.
- **Currency symbol unavailable for `event.currency`:** fall back to the literal `event.currency` code (e.g. `USD 50.00`) — never crash.
- **Schema migration on app upgrade:** existing Drift DB at v5 must successfully add the `budget_estimate` column without data loss. Verify by running app from a v5 backup before merging.
- **Currency change is forbidden** (data-integrity boundary, not just a missing feature): `EditEventScreen` does NOT expose a currency control; the existing "Cannot be changed after creating the event" helper text on `CreateEventScreen` remains the truth. Reason: `ExpenseModel.amount` carries no currency tag; changing `event.currency` after any expense exists would silently re-label balances and corrupt the `BalanceLedger`. Multi-currency support is in `todo.md` for a future iteration — until then, the only path to change currency is to delete and recreate the event.
- **Editing a settlement (`isPayment: true`) expense**: Edit menu item is hidden; only Delete is available. Reason: settlement payments are anchored to the chat pinned dispute notice (see `tasks-budget-chat-spec.md` Budget Dispute flow). Editing one would desync the notice; the user-facing path to undo a settlement is the dispute flow, not the overflow menu.

**Error scenarios:**

- **Firestore offline during edit:** writes queue via Firestore SDK's offline persistence; UI optimistically reflects the change and a `cloud_off` icon appears (mirror the existing pattern from `TaskDetailScreen` `hasPendingWrites`).
- **`updateExpense` violates a Firestore rule:** repository catches, logs, returns `false`; UI shows snackbar `"Could not update expense — only the payer or an admin can edit"`.
- **`deleteExpense` mid-settlement-confirmation:** if the expense being deleted is an `isPayment: true` settlement, current `pendingSettlementNotifier` should not block (audit during implementation; flag if a race emerges).

**Limits:**

- **Budget magnitude:** no explicit upper limit, but display formats up to `NumberFormat.simpleCurrency`'s defaults. Numbers > 1e9 render as scientific notation — acceptable per existing app behavior; do not introduce a custom clamp.
- **Edit history:** none in V1. No audit log. Captured in `events-gaps-audit.md` for a future iteration.

</boundaries>

<implementation>

**Files to create:**

- `lib/app/features/tasks/presentation/edit_task_screen.dart` — mirror `create_task_screen.dart`.
- `lib/app/features/dashboard/presentation/edit_event_screen.dart` — mirror `create_event_screen.dart`. If `CreateEventScreen` has substantial reusable form innards, extract them into `lib/app/features/dashboard/presentation/widgets/event_form.dart` and use from both screens.
- `ai_specs/events-gaps-audit.md` — short companion report (see structure note below).

**Files to modify:**

- `lib/app/features/tasks/presentation/widgets/assignee_picker.dart` — add `displayNames` param.
- `lib/app/features/tasks/presentation/widgets/task_tile.dart` — left stripe + budget chip.
- `lib/app/features/tasks/presentation/create_task_screen.dart` — add budget field; pass hydrated names to picker.
- `lib/app/features/tasks/presentation/task_detail_screen.dart` — pencil action; accept `String? assigneeName` constructor param so the screen stays Riverpod-free.
- `lib/app/features/tasks/presentation/event_tasks_page.dart` — wire `EditTaskScreen` push; pass `usersByIdProvider` resolved names to `AssigneePicker` and `TaskTile`.
- `lib/app/features/tasks/presentation/event_task_detail_page.dart` — **this is the Riverpod consumer for `TaskDetailScreen`**. Reads `usersByIdProvider([...event.memberIds, if (task.assigneeId != null && !event.memberIds.contains(task.assigneeId)) task.assigneeId!])`, hands the resolved name into `TaskDetailScreen`, and wires the pencil action onto `EditTaskScreen` followed by `TaskRepository.updateTask` on return.
- `lib/app/features/tasks/domain/models/task.dart` — `budgetEstimate` field + `copyWith`.
- `lib/app/features/tasks/data/task_repository.dart` — budget plumbing in `_toFirestore`, `_fromFirestore`, `_toDomain`, `_upsertDrift`.
- `lib/app/core/database/app_database.dart` — schema bump to 6, migration step, `RealColumn get budgetEstimate => real().nullable()();` on `Tasks` table.
- `lib/app/core/database/daos/tasks_dao.dart` — `tasks_dao.g.dart` regenerates via build_runner.
- `lib/app/features/dashboard/data/event_repository.dart` — add `updateEvent(EventModel)` using Firestore `update()` (not `set()`). Mirror picks it up via the existing listener. Existing create/listener plumbing is correct; do not refactor it.
- `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — settings-icon route + archive-toggle wiring.
- `lib/app/core/router/app_router.dart` — register `edit` as a nested `GoRoute` under the existing `event/:eventId` route (line ~138), alongside `members`, `budget`, `chat`, `tasks`. Use `EventGuard` like the siblings.
- `lib/app/features/budget/presentation/widgets/expense_tile.dart` — add nullable `onEdit` / `onDelete` callbacks; render `PopupMenuButton` only when at least one is non-null; omit `Edit` item when `expense.isPayment == true`.
- `lib/app/features/budget/presentation/widgets/expense_modal.dart` — accept optional `ExpenseModel? initial`; lock `payerId` display when present; preserve `initial.id`; emit `initial.copyWith(...)`.
- `lib/app/features/budget/presentation/event_budget_page.dart` — compute per-tile `onEdit` / `onDelete` (null when forbidden by RBAC: payer-OR-creator-OR-admin), pass to `ExpenseTile`. Wire edit submission to `ExpenseRepository.updateExpense`; wire delete to `deleteExpense` after dialog confirm.
- `firestore.rules` — **add `allow update` for `/events/{eventId}/expenses/{expenseId}`** (payer/creator/admin with `payerId`+`eventId` locked) and widen the existing `allow delete` to include admins. See requirement 18a for the exact rule shape. Run `npm --prefix functions test` after.

**Patterns to use:**

- For display-name hydration, **reuse** `usersByIdProvider`; do not create a parallel provider.
- For form pre-fill, accept the existing domain model as a constructor arg (matches `TaskDetailScreen` pattern).
- For RBAC checks, reuse `TaskModel.canEditOrDelete` / `EventModel.isAdmin` / payer check helpers; never re-implement.
- For overflow menus, follow Material `PopupMenuButton<T>` convention already used elsewhere — search the codebase for an existing instance before adding a new style.

**What to avoid:**

- Do not introduce a new state-management abstraction for the edit screens — they are plain `StatefulWidget` per existing convention.
- Do not write per-task currency overrides — task budget is always in `event.currency`.
- Do not store `budgetEstimate` as a string in Firestore. It is a number.
- Do not add a "track actual vs estimate" report — explicitly out of scope (we chose "Estimate only" semantics).
- Do not auto-adjust task `dueDate`s when event dates shift — call this out in the edit-event snackbar `"Existing task due dates were not changed."` only if any task lies outside the new range.

**`events-gaps-audit.md` structure:**

Produce a short Markdown file (no XML) at `./ai_specs/events-gaps-audit.md` with these sections:

1. **Summary** — one paragraph, current state of the events feature.
2. **Closed in this spec** — bullet list of gaps fixed by `tasks-polish-spec.md` (settings icon wired, edit-event screen, archive toggle convergence, expense edit/delete UX, hydrated assignee names, task budget, task edit screen, task color stripe).
3. **Open gaps** — bullet list of remaining events gaps with brief evidence (file:line where possible), e.g.:
   - Event-level notification preferences (mute, urgent-only) — no UI, no storage.
   - Transfer ownership — function exists for admin promote/demote but not full ownership transfer; verify.
   - Settings screen (vs ad-hoc dashboard switches) — currently scattered across dashboard switches and the soon-to-be-wired settings gear.
   - Event templates / duplicate event — none.
   - Audit log / change history — none for any entity.
   - Calendar export (ICS) — none.
   - Cover image — `eventType` badge only.
   - Per-event timezone — events use device local time everywhere; cross-timezone trips will display dates inconsistently.
   - Recurring events — none.
4. **Recommended next pick** — one or two of the above the user could spec next, with rough effort sizing.

Keep the audit doc under 200 lines. It is a report, not a spec.

</implementation>

<validation>

**Required automated coverage outcomes** (baseline — failing any of these blocks the merge):

- **Logic / model unit tests:**
  - `TaskModel.budgetEstimate` round-trips through `copyWith` (null and non-null cases).
  - Drift migration v5→v6 verified via `SchemaVerifier` from `drift_dev`. Generate a v5 schema snapshot with `dart run drift_dev schema dump lib/app/core/database/app_database.dart drift_schemas/` (commit the snapshot under `drift_schemas/`), then write `test/database/migration_v5_to_v6_test.dart` that calls `verifier.startAt(5)` → `runMigrationSteps(toVersion: 6, ...)` → `verifySelf` and asserts the `budget_estimate` column exists as nullable real. Document the snapshot path + regeneration command in the test header.
  - `_toFirestore` / `_fromFirestore` round-trip preserves `budgetEstimate` for null, 0, and a positive value.
  - `EventRepository.updateEvent` writes the expected Firestore doc shape with `fake_cloud_firestore` (cover each editable field: title, description, dates, eventType, status); negative test asserts `currency`, `memberIds`, `adminIds`, `creatorId` are NOT in the update payload.
  - Budget validator (locale-aware): parses valid `en_US` inputs (`0`, `0.5`, `12`, `1234.56`) and valid `de_DE` inputs (`0,5`, `1234,56`); rejects (`-1`, `abc`, `1.234`/`1,234` 3-decimal); empty string → null (valid).

- **Widget tests:**
  - `AssigneePicker` renders display names when `displayNames` map populated; falls back to truncated UID otherwise; renders an `orphanAssigneeId` as a disabled item at the bottom labeled `(no longer in event)`.
  - `TaskTile` shows stripe in correct color per status (3 cases), stripe is flush with the card's left edge (golden or width/offset assertion).
  - `TaskTile` renders the budget `Text` only when `budgetEstimate != null` (no Material `Chip`).
  - `EditTaskScreen` pre-fills all fields from a `TaskModel`; tapping Save returns an updated `TaskModel` via the `onSubmit` callback.
  - `EditEventScreen` pre-fills; end-date validator rejects end-before-start; pickers accept past dates (regression for the `DateTime.now()` clamp).
  - `EditEventScreen` does NOT render a currency control (negative assertion — currency immutability is part of the contract).
  - `ExpenseTile` renders no overflow menu when both callbacks are null; renders Edit+Delete when both non-null; hides Edit when `expense.isPayment == true`.
  - `ExpenseModal` in edit mode pre-fills, locks the payer row, Save button label flips to `Save changes`, and submission preserves `initial.id`.

- **Critical user-journey (robot) tests:**
  - `TaskRobot.editAssigneeBudgetAndSave` — from `EventTasksPage`, open detail, tap edit, change assignee + budget, save, verify list reflects updates and tile shows new chip. Uses faked `usersByIdProvider`, fake Firestore.
  - `EventRobot.editTitleAndDate` — owner edits event title and start date from the settings gear, returns to dashboard, sees new values.
  - `BudgetRobot.editAndDeleteExpense` — payer edits an expense (changes amount), saves, then deletes another expense; both reflect in the balance ledger.

**TDD expectations** (per `flutter-tdd` skill):

- Write tests behavior-first in this order for each slice: model unit → repository round-trip → widget → robot journey.
- One vertical slice at a time; commit at the end of each green RED→GREEN→REFACTOR cycle.
- **Required seams** (constructor-injectable so tests can override deterministically):
  - `TaskRepository` already takes `FirebaseFirestore` + DAOs — keep that surface; pass `fake_cloud_firestore` instances in tests.
  - `EventRepository.updateEvent` accepts an injected `FirebaseFirestore`.
  - `usersByIdProvider` overridable via Riverpod test override; do not hit network.
  - `EditTaskScreen` / `EditEventScreen` accept callbacks (`onSubmit`) rather than calling repos directly — same pattern as `CreateTaskScreen`.
- **Mocking policy:** prefer `fake_cloud_firestore` + `firebase_auth_mocks` (already in `dev_dependencies`). Mock only true external boundaries (`MarkTaskCompleteCall` etc.). No mocking of own domain models.
- **Justified exceptions:** Drift migration tests run against an in-memory `NativeDatabase.memory()` rather than a full integration harness — acceptable because the migration touches a single nullable column.

**Robot testing baseline** (per `flutter-robot-testing` skill):

- Critical happy-path cross-screen flows above → robot.
- Screen-level edge cases (validation errors, RBAC-hidden buttons, save-failure snackbar) → widget tests.
- Pure logic (validators, balance ledger) → unit tests.
- **Stable selectors required** (add Keys if missing):
  - `tasks.create.budget`, `tasks.edit.budget`, `tasks.edit.save`, `tasks.detail.edit`.
  - `tasks.tile.${id}.stripe`, `tasks.tile.${id}.budgetChip`.
  - `event.dashboard.settingsIcon`, `event.edit.save`.
  - `budget.expense.${id}.overflow`, `budget.expense.${id}.edit`, `budget.expense.${id}.delete`.
- **Deterministic seams:** seed Firestore + Drift via test setup; freeze `clock.now()` via the `clock` package (already in `pubspec.yaml`); seed `usersByIdProvider` with a `Map<String, AppUser>`.

**Known risks to flag in implementation PR:**

- Drift migrations are not run in widget tests by default; ship the dedicated migration test (`test/database/migration_v5_to_v6_test.dart`) and the schema snapshot regeneration commit *before* any other v6-dependent test lands.
- `EventRepository` already writes Firestore on create — `updateEvent` is a straight addition. Implementer must NOT scope-creep into the stream-rewrite work that's still parked in `todo.md`.
- Firestore rules changes (expense update + delete widening) require corresponding tests in the existing rules-test harness; merging the Flutter code without the rules patch will produce permission-denied snackbars in production.

**Manual smoke** (before declaring done):

- Install v5 build → upgrade to v6 build on a real device → confirm no data loss.
- iOS + Android + web (Chrome): open Tasks list, see stripes, edit a task, see name + budget; open event settings, change title, see dashboard refresh; edit + delete an expense, see balance update.

</validation>

<done_when>

- All requirements 1–30 (plus 11a, 11b, 18a) implemented and covered by tests at the levels described in `<validation>`.
- `flutter analyze` clean; `dart test` and `flutter test` green; `npm --prefix functions test` green (rules tests).
- Drift migration v5→v6 verified by both the migration test and a manual real-device upgrade smoke.
- `ai_specs/events-gaps-audit.md` exists, lists at least the gaps enumerated under the implementation note, and identifies a recommended next pick.
- New `EditTaskScreen` and `EditEventScreen` reachable from their respective entry points; settings gear no longer dead.
- `ExpenseTile` overflow menu enables edit + delete for payer + admin; `ExpenseModal` edits round-trip; ledger updates correctly.
- No regressions in existing task / event / budget widget + robot tests.
- Branch name: `tasks-polish` (not `tasks` — work spans Tasks + Events edit + Budget edit). Branched from latest `main` after `event` merges.

</done_when>
