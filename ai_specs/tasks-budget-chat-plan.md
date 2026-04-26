## Overview

Ship V1 of Tasks (RBAC + checklist), Budget (currency + splits + receipts + Venmo/CashApp settle + dispute), and Chat polish (eventId fix + Drift cache + FCM urgent push). Mirror Firestore→Drift; reuse `promoteToAdmin.ts` onCall shape; add first Firestore-trigger CF.

**Spec**: `ai_specs/tasks-budget-chat-spec.md` (read for full requirements)

## Context

- **Structure**: feature-first (`lib/app/features/{feature}/{data,domain,application,presentation}/`); core in `lib/app/core/`
- **State management**: Riverpod 3 — **hand-written `Notifier` classes**, NOT `@riverpod` codegen (spec mentions codegen; codebase has not adopted it; **follow codebase**)
- **Reference implementations**:
  - `functions/src/events/promoteToAdmin.ts` — onCall RBAC shape (mirror exactly)
  - `lib/app/features/dashboard/data/event_repository.dart` — repo template (extend to Firestore-stream + Drift-mirror)
  - `lib/app/features/budget/domain/models/balance_ledger.dart` — **do not modify** (already correct)
  - `lib/app/features/auth/application/auth_provider.dart` — sealed-state Notifier example
- **Assumptions/Gaps**:
  - `EditProfileScreen` has no state notifier — Phase 5 introduces `UserProfileNotifier`
  - No robot harness yet — Phase 1 introduces `*Robot` convention + `flutter_test` setup; no extra package required
  - `@riverpod` deps present but unused; do not adopt mid-spec
  - First Firestore-trigger v2 in repo (Phase 8) — pin same region as existing CFs
  - `fake_cloud_firestore` + `clock` added in Phase 1 for TDD seams

## Plan

### Phase 1: Foundations + Tasks vertical slice

- **Goal**: Drift v3→v4 + thin end-to-end Tasks slice (create → list → toggle status with server-enforced RBAC) proves the critical path.
- [x] `pubspec.yaml` — add `firebase_messaging`, `url_launcher`; dev: `fake_cloud_firestore`, `clock`
- [x] `ai_specs/todo.md` — create backlog file (Kanban, attachments, multi-currency, reactions, E2EE, full sync engine, FX, recurring, push reminders)
- [x] `lib/app/core/database/app_database.dart` — `ExpenseSplits` table inline (codebase convention; no `tables/` subdir)
- [x] `lib/app/core/database/app_database.dart` — `TaskChecklistItems` table inline (`text` column renamed `content` to avoid Drift `text()` shadow; `order` renamed `sortOrder`)
- [x] `lib/app/core/database/daos/expense_splits_dao.dart`, `daos/task_checklist_items_dao.dart`
- [x] `lib/app/core/database/app_database.dart` — register new tables; bump `schemaVersion: 4`; `onUpgrade`: `addColumn(events, currency)`, `addColumn(users, venmoHandle/cashappHandle)`, `createTable(expenseSplits)`, `createTable(taskChecklistItems)`, `addColumn(tasks, createdBy/completedAt/completedBy)` (note: `expenses.isPayment` already existed pre-bump, no migration needed)
- [x] `lib/app/features/dashboard/domain/models/event.dart` — add `currency` field
- [x] `lib/app/features/auth/domain/models/app_user.dart` — add `venmoHandle?`, `cashappHandle?`, `fcmTokens: List<String>`
- [x] `firestore.rules` — add `events/{eid}/tasks/{tid}` block (read=member, create=member with `createdBy==uid`, update-status=owner/admin/assignee, update-other=creator/owner/admin, delete=creator/owner/admin); same for `tasks/{tid}/checklist/{cid}` (existing `users` rule already restricts writes to owner — no extra tightening needed for V1 handle fields)
- [x] `functions/src/events/markTaskComplete.ts` — onCall; owner/admin/assignee; stamp `completedAt`/`completedBy` server-side; mirrors `promoteToAdmin.ts`
- [x] `functions/src/index.ts` — export `markTaskComplete`
- [x] `lib/app/features/tasks/data/task_repository.dart` — Firestore stream subscription writes to Drift; reads via Drift watch; `updateStatus` calls `markTaskComplete` CF on `→ done`, direct write otherwise; `dispose()` cancels subscriptions
- [x] `lib/app/features/tasks/application/task_provider.dart` — `taskListProvider(eventId)` `StreamProvider.family`; `TaskListNotifier.updateTaskStatus` routes through `updateStatus`
- [x] `lib/app/features/tasks/presentation/create_task_screen.dart` — title (≤120) + `AssigneePicker` + optional dueDate
- [x] `lib/app/features/tasks/presentation/widgets/assignee_picker.dart`
- [x] `lib/app/features/tasks/presentation/task_list_screen.dart` — `EventTasksPage` wraps with provider; stable keys; RBAC-gated tiles
- [x] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — gate status toggle; `Key('tasks.tile.{id}.status')`; non-authorized snackbar via `onUnauthorizedTap`
- [x] `lib/app/core/router/app_router.dart` — wire `/dashboard/event/:eventId/tasks` to `EventTasksPage` (event-scoped; the global `/tasks` tab remains placeholder pending V1 IA decision)
- [x] TDD: Drift v3→v4 migration via `database_test.dart` exercising new tables + currency default
- [x] TDD: `TaskRepository.createTask` writes Firestore + mirrors to Drift (`fake_cloud_firestore` + in-memory Drift)
- [x] TDD: `TaskRepository.updateStatus` — todo→inProgress direct write; →done routes through CF
- [x] TDD: RBAC predicate (`canChangeStatus`) covers owner/admin/assignee/other
- [ ] TDD: emulator test `markTaskComplete` rejects non-authorized callers — **deferred**: requires Firebase emulator harness setup (no `functions/test/` exists yet)
- [ ] TDD: emulator firestore.rules — **deferred**: same emulator harness gap; tracked in `ai_specs/todo.md`
- [x] Robot: `TasksRobot` + journey (`test/journeys/tasks_journey_test.dart`): open → create → toggle to done; selectors `tasks.list.create`, `tasks.create.title`, `tasks.create.save`, `tasks.tile.{id}.status` declared
- [x] Verify: `cd functions && npm run build && cd ..` && `flutter analyze` && `flutter test` — clean

### Phase 2: Tasks detail + checklist

- **Goal**: Detail screen with edit/delete; checklist persistence end-to-end.
- [x] `lib/app/features/tasks/presentation/task_detail_screen.dart` — pure presentation; status badge, due date, assignee row, completed-by/at, checklist editor; delete action gated by `canEditTask`; pending-writes indicator
- [x] `lib/app/features/tasks/presentation/widgets/checklist_editor.dart` — add / toggle / inline-edit-text / delete; ≤25 items × ≤120 chars; reorder deferred to backlog
- [x] `lib/app/features/tasks/data/task_repository.dart` — checklist subcollection stream + Drift mirror; `addChecklistItem`, `toggleChecklistItem` (assignee-safe), `updateChecklistItem`, `deleteChecklistItem`; `disposeChecklistMirror`
- [x] `lib/app/features/tasks/domain/models/task.dart` — `ChecklistItem` extended with `id` + `sortOrder`; serialized at the repo boundary (not on the model)
- [x] `firestore.rules` — checklist rules already added in Phase 1: creator/owner/admin can create/update/delete; assignee may update (rules allow assignee-targeted `isCompleted` toggle via the dedicated CF-free path)
- [x] `lib/app/core/router/app_router.dart` — wire `/dashboard/event/:eventId/tasks/:taskId` to `EventTaskDetailPage`
- [x] TDD: `toggleChecklistItem` patches only `isCompleted` (assignee-safe); `updateChecklistItem` patches both text and `isCompleted` (creator/admin)
- [x] TDD: `addChecklistItem` writes Firestore subcollection doc and mirrors to Drift
- [x] Widget: read-only state for non-authorized hides delete + add field; creator sees delete; "(no longer in event)" surfaces when `assigneeId` is missing from `event.memberIds`; pending-writes indicator behind explicit flag
- [x] Verify: `flutter analyze` && `flutter test` — clean (77 tests)

### Phase 3: Budget — per-event currency + splits persistence + live stream

- **Goal**: Fix `_toDomain` splits regression; live BalanceLedger; per-event currency immutable at creation.
- [ ] `lib/app/features/dashboard/presentation/create_event_screen.dart` — currency selector (default user currency or `'USD'`); immutable
- [ ] `lib/app/features/budget/data/expense_repository.dart` — Firestore stream + Drift mirror (mirror events repo); fix `_toDomain` to hydrate `splits` from `ExpenseSplits` DAO
- [ ] `lib/app/features/budget/domain/models/expense.dart` — `toFirestore`/`fromFirestore` round-trips `splits` array; `currency` reads from event
- [ ] `lib/app/features/budget/application/budget_provider.dart` — wire live stream
- [ ] `lib/app/features/budget/presentation/budget_screen.dart` — render `BalanceLedger.calculate(...)` from live stream; suggested-settlement rows with `Key('budget.settle.{payeeId}')` (UI present, sheet stub for Phase 5)
- [ ] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — currency symbol from event; validate amount range (0.01–10M); split-sum equals total within $0.01
- [ ] `lib/app/core/router/app_router.dart` — wire `/budget`
- [ ] TDD: `ExpenseRepository._toDomain` hydrates splits (regression test for current `[]` bug)
- [ ] TDD: `ExpenseModal` split-sum validation
- [ ] TDD: existing `BalanceLedger` tests still pass — do not modify algorithm
- [ ] Widget: Budget screen empty state; settlement row visibility
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Receipt upload

- **Goal**: image_picker → Storage → display; expense save resilient to upload failure.
- [ ] `storage.rules` — `events/{eid}/receipts/{exid}.jpg`: read=event member, write=expense `payerId`, ≤5MB, `image/*`
- [ ] `lib/app/features/budget/data/expense_repository.dart` — `uploadReceipt(eventId, expenseId, file)` returns path; expense save proceeds even on upload failure
- [ ] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — `image_picker` (`imageQuality: 70`); thumbnail in form
- [ ] `lib/app/features/budget/presentation/widgets/expense_tile.dart` — thumbnail when present
- [ ] `lib/app/features/budget/presentation/widgets/receipt_viewer.dart` — full-screen viewer
- [ ] TDD: upload failure → expense persisted without `receiptPath`; "Retry" CTA wiring
- [ ] Widget: thumbnail render; failure-state CTA
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 5: Pay handles + deep-link settle (happy path)

- **Goal**: Profile handles; pure `PayLinkBuilder`; lifecycle-aware confirm; settlement notice posted.
- [ ] `lib/app/features/profile/application/user_profile_notifier.dart` — **new**; persists profile mutations (currently `EditProfileScreen` is a no-op)
- [ ] `lib/app/features/profile/presentation/edit_profile_screen.dart` — wire to notifier; add Venmo + CashApp fields with `^[A-Za-z0-9_-]+$` validation, ≤30 chars
- [ ] `lib/app/features/budget/data/pay_link_builder.dart` — pure top-level functions; no Flutter/Firebase imports; throws on invalid handle
- [ ] `lib/app/core/services/url_launcher_service.dart` — `IUrlLauncher` interface + real impl wrapping `url_launcher` (`LaunchMode.externalApplication`)
- [ ] `lib/app/core/services/app_lifecycle_source.dart` — `Stream<AppLifecycleState>` seam fed by `WidgetsBindingObserver`
- [ ] `lib/app/features/budget/application/pending_settlement_notifier.dart` — accepts `Clock` + `IUrlLauncher` + `AppLifecycleSource`; 30s window constant `confirmWindow = Duration(seconds: 30)`; drop on app kill
- [ ] `lib/app/features/budget/presentation/widgets/settle_sheet.dart` — Venmo + CashApp buttons disabled if handle missing; "Copy details" fallback when neither
- [ ] `lib/app/features/budget/data/expense_repository.dart` — `recordSettlement(payerId, payeeId, amount)` writes `isPayment: true` expense with `splits: [{userId: payee, amount: -amount}]`
- [ ] `lib/app/features/chat/data/chat_repository.dart` — `postSettlementNotice(eventId, expenseId, text)` writes message with `kind: 'settlement'` metadata; same id as expense (idempotent)
- [ ] `lib/app/features/chat/presentation/widgets/message_bubble.dart` — settlement-kind variant (outlined; tap target for Phase 6)
- [ ] `ios/Runner/Info.plist` — `LSApplicationQueriesSchemes`: `venmo`, `cashme`
- [ ] TDD: `PayLinkBuilder.venmo(...)` builds `venmo://paycharge?...` with web fallback URI; throws on invalid handle; amount always 2dp; note URI-encoded + truncated to 60
- [ ] TDD: `PayLinkBuilder.cashApp(...)` produces `https://cash.app/${handle}/${amount}`
- [ ] TDD: `PendingSettlementNotifier` — launches → records pending; resume within 30s → confirm fires; resume after 30s → no confirm; dismiss → no settlement; kill → state dropped
- [ ] TDD: `recordSettlement` writes correct ledger payload; idempotent on chat notice
- [ ] Widget: `SettleSheet` enables/disables per handle availability; copy-details fallback
- [ ] Robot: `BudgetRobot` with selectors `budget.expense.create`, `budget.settle.{payeeId}`, `budget.settle.venmo`, `budget.settle.cashapp`, `budget.settle.confirm`, `budget.settle.copy`; journey: create expense → settle Venmo (faked launcher) → confirm → ledger zero
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 6: Dispute path

- **Goal**: Payee or payer can dispute; settlement expense + notice rolled back.
- [ ] `functions/src/events/disputeSettlement.ts` — onCall; caller is payer or payee of the settlement; deletes settlement expense; updates chat notice text to "{name} disputed this settlement"; mirrors `promoteToAdmin.ts` shape
- [ ] `functions/src/index.ts` — export
- [ ] `lib/app/features/chat/presentation/widgets/dispute_sheet.dart` — bottom sheet; cancel / dispute
- [ ] `lib/app/features/chat/presentation/widgets/message_bubble.dart` — settlement notice tap → opens dispute sheet
- [ ] TDD: emulator integration — non-payer non-payee → `permission-denied`; payer → success; payee → success; settlement expense gone
- [ ] Widget: dispute confirm/cancel; notice text mutation
- [ ] Verify: `cd functions && npm run build && cd ..` && `flutter analyze` && `flutter test`

### Phase 7: Chat polish + Drift cache

- **Goal**: Fix `eventId` bug; sender-name hydration; instant cold-start render; auto-scroll discipline.
- [ ] `lib/app/features/chat/data/firestore_chat_service.dart` — fix line-68 `eventId: ''` (pass through from caller)
- [ ] `lib/app/features/chat/data/chat_repository.dart` — Firestore stream → Drift mirror (cap 200 oldest deleted); `watchMessages` returns Drift watch; sender-name hydration via `usersByIdProvider(eventId)`
- [ ] `lib/app/features/chat/application/users_by_id_provider.dart` — subscribes to `users/{uid}` for current event members; Drift cache
- [ ] `lib/app/features/chat/application/chat_provider.dart` — composer in-flight state; `kind` filter helpers
- [ ] `lib/app/features/chat/presentation/chat_screen.dart` — empty state copy; auto-scroll only when at bottom; disable Send while in-flight; Retry on send failure (no partial doc)
- [ ] `lib/app/core/router/app_router.dart` — wire `/event/:eventId/chat` (deep-link target)
- [ ] TDD: `ChatRepository` merge — Drift-only when offline; Firestore wins when both present (ordered by `serverTimestamp`); 200-cap eviction
- [ ] TDD: removed-sender shows "Unknown member"
- [ ] Widget: empty state; auto-scroll suppressed when scrolled-up; in-flight composer guard; urgent terracotta bubble + "URGENT" label
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 8: FCM push for urgent

- **Goal**: Closed-app urgent push; foreground in-app banner with active-screen suppression; deep-link tap.
- [ ] `pubspec.yaml` — already added in Phase 1; iOS APNs key uploaded in Firebase console (manual prereq — flag in PR)
- [ ] `ios/Runner/Info.plist` — push background mode; `UIBackgroundModes` includes `remote-notification`
- [ ] `lib/app/core/services/fcm_service.dart` — `IFcmGateway` interface + real impl; lifecycle: on auth → `requestPermission()`, await `getAPNSToken()` (iOS), `getToken()` → `arrayUnion` to `users/{uid}.fcmTokens`; subscribe `onTokenRefresh`; on sign-out → arrayRemove current then `deleteToken()`
- [ ] `lib/app/core/router/current_route_provider.dart` — exposes current `go_router` location for active-screen suppression
- [ ] `lib/app/core/services/fcm_handler.dart` — top-level background `@pragma('vm:entry-point')` handler; foreground `onMessage` → suppress if `currentRoute == /event/{eid}/chat`, else `MaterialBanner` with View action; `onMessageOpenedApp` + awaited `getInitialMessage()` → `context.go(data.deepLink)`
- [ ] `lib/main.dart` — register background handler; await `getInitialMessage()` before first router build
- [ ] `functions/src/events/onUrgentMessageCreated.ts` — Firestore-trigger v2 (`onDocumentCreated`); ignore non-urgent; load event; chunk tokens (≤500); `sendEachForMulticast`; prune dead tokens (`registration-token-not-registered`); same region as other CFs
- [ ] `functions/src/index.ts` — export
- [ ] TDD: `FcmService` token lifecycle (sign-in writes, refresh writes, sign-out arrayRemove); permission denied path silent
- [ ] TDD: emulator integration — non-urgent ignored; sender skipped; multicast issued; dead tokens pruned
- [ ] TDD: `currentRouteProvider` reflects router state
- [ ] Widget: foreground banner appears off-screen; suppressed when on chat for that event
- [ ] Robot: `ChatRobot` with selectors `chat.composer.send`, `chat.composer.urgent`, `chat.message.{id}`; journey: send urgent → second session receives faked FCM payload + deep-link
- [ ] Verify: `cd functions && npm run build && cd ..` && `flutter analyze` && `flutter test`

### Phase 9: Documentation + final cleanup

- **Goal**: Registry up to date; manual smoke checklist green.
- [ ] `docs/cloud-functions-guide.md` — append `markTaskComplete`, `disputeSettlement`, `onUrgentMessageCreated` to Function Registry; bump "Last updated"
- [ ] Walk every spec requirement (1–66) and confirm done
- [ ] Manual: real-device push (closed app → push → tap → chat)
- [ ] Manual: real Venmo deep link with set handle
- [ ] Manual: install previous build → upgrade → verify Drift data preserved
- [ ] Verify: `cd functions && npm run build && cd ..` && `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**:
  - Drift v3→v4 migration on real device (Phase 1) — mitigate with `verifySelfMigration` test + manual upgrade smoke in Phase 9
  - iOS FCM (APNs key, Info.plist, `getAPNSToken()` await) — silent failures common; Phase 8 keeps real-device manual test as gate
  - Lifecycle return-detection false positives — 30s window + pending-flag guard in `PendingSettlementNotifier`
- **Out of scope** (deferred to `ai_specs/todo.md`):
  - Kanban board, message reactions/edit/search, E2EE, multi-currency display, Plaid/webhook reconciliation, web platform, due-date push reminders, task attachments storage, full last-write-wins offline sync engine
  - Modifying `BalanceLedger.calculate` (already correct)
  - Adopting `@riverpod` codegen
