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
- [x] `lib/app/features/dashboard/presentation/create_event_screen.dart` — currency dropdown (USD/EUR/GBP/CAD/AUD/JPY/INR), `Key('events.create.currency')`, `defaultCurrency` parameter, helper text "Cannot be changed after creating the event."
- [x] `lib/app/features/budget/data/expense_repository.dart` — refactored to take `splitsDao` + `FirebaseFirestore`; Firestore stream + Drift mirror with reconciliation; splits round-tripped through `ExpenseSplits` table; fixed `_toDomain` regression (was returning `splits: []`); `dispose`/`disposeMirror` for cleanup
- [x] `lib/app/features/budget/domain/models/expense.dart` — model already had `splits` field; serialization lives at the repository boundary (no Firestore types in the domain layer)
- [x] `lib/app/core/providers.dart` — `expenseRepositoryProvider` + `expenseListProvider.family` with `ref.onDispose` cleanup
- [x] `lib/app/features/budget/presentation/budget_screen.dart` — `currency` parameter; symbol prepended to total / balances / settlements; `Key('budget.settle.{payeeId}')` on each settle button; `Key('budget.expense.create')` on FAB
- [x] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — `currencySymbol` parameter; `validateAmountInput` checks min 0.01 / max 10M; `validateSplitSum` (within $0.01); stable `Key('budget.expense.amount')`, `Key('budget.expense.save')`
- [x] `lib/app/features/budget/presentation/event_budget_page.dart` — new wrapper that subscribes to `expenseListProvider`, opens `ExpenseModal` with the right currency symbol, and routes mutations through `expenseRepositoryProvider`
- [x] `lib/app/core/router/app_router.dart` — `/dashboard/event/:eventId/budget` wired to `EventBudgetPage`; event dashboard quick-link wired
- [x] `lib/app/features/dashboard/data/event_repository.dart` — `currency` round-tripped through Drift companion + domain mapper
- [x] TDD: `ExpenseRepository.getExpensesByEventId` hydrates splits from `ExpenseSplits` DAO (regression test for the previous empty-list bug)
- [x] TDD: `ExpenseModal.validateAmountInput` (empty / non-numeric / below min / above max / valid)
- [x] TDD: `ExpenseModal.validateSplitSum` (accepts within tolerance; rejects mismatch)
- [x] TDD: `ExpenseRepository.createExpense` writes splits array to Firestore
- [x] TDD: `ExpenseRepository` Firestore stream mirrors incoming docs (and their splits) into Drift
- [x] Widget: Budget screen empty state; currency symbol from event; settlement-row stable key
- [x] Verify: `flutter analyze` && `flutter test` — clean (90 tests)
- [x] Existing `BalanceLedger` tests still green — algorithm untouched per spec

### Phase 4: Receipt upload

- **Goal**: image_picker → Storage → display; expense save resilient to upload failure.
- [x] `storage.rules` — `events/{eventId}/receipts/{filename}`: read=event member (via `firestore.get`), write=event member with image content-type and ≤5MB
- [x] `lib/app/features/budget/data/expense_repository.dart` — `uploadReceipt(eventId, expenseId, file)` injects `IImageService`; returns download URL on success, `null` on failure (caller persists expense regardless)
- [x] `lib/app/features/budget/domain/models/expense.dart` — `copyWith` supporting receiptPath updates (and explicit drop)
- [x] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — `onPickReceipt` callback (parent supplies `IImageService.pickFromGallery(quality: 70)`); inline thumbnail preview + clear; `onSubmit(expense, file?)` signature
- [x] `lib/app/features/budget/presentation/widgets/expense_tile.dart` — thumbnail when `receiptPath` is set; tap opens viewer; threaded `currencySymbol`
- [x] `lib/app/features/budget/presentation/widgets/receipt_viewer.dart` — full-screen `InteractiveViewer` with tap-to-dismiss + error/loading states
- [x] `lib/app/features/budget/presentation/event_budget_page.dart` — orchestrates upload-then-save; failure snackbar, expense saves anyway
- [x] `lib/app/core/providers.dart` — `expenseRepositoryProvider` injects `imageServiceProvider`
- [x] TDD: `uploadReceipt` returns URL on success and writes to expected path
- [x] TDD: `uploadReceipt` returns null on failure; subsequent `createExpense` persists with `receiptPath: null` (resilience contract)
- [x] Widget: tile renders thumbnail with stable `Key('budget.expense.tile.{id}.thumbnail')`; default icon when no receipt; tile honors `currencySymbol`
- [x] Widget: modal hides "Add receipt" button when `onPickReceipt` is null; tap pulls picker → preview rendered; submit forwards picked file
- [x] Verify: `flutter analyze` && `flutter test` — clean (98 tests)

### Phase 5: Pay handles + deep-link settle (happy path)

- **Goal**: Profile handles; pure `PayLinkBuilder`; lifecycle-aware confirm; settlement notice posted.
- [x] `lib/app/features/profile/presentation/edit_profile_screen.dart` — added Venmo + CashApp fields with `^[A-Za-z0-9_-]{1,30}$` validation; reuses existing `userRepositoryProvider` instead of introducing a new `UserProfileNotifier` (the existing wiring already persists, so the notifier was unnecessary indirection)
- [x] `lib/app/features/profile/data/firestore_user_repository.dart` + `i_user_repository.dart` — `saveProfile` / `getUser` round-trip the new handles
- [x] `lib/app/features/auth/domain/models/app_user.dart` — already had `venmoHandle` / `cashappHandle` (Phase 1 foundation)
- [x] `lib/app/features/budget/data/pay_link_builder.dart` — pure utility (no Flutter/Firebase); `venmo`, `venmoWebFallback`, `cashApp`; throws `ArgumentError` on invalid handle
- [x] `lib/app/core/services/url_launcher_service.dart` — `IUrlLauncher` + `UrlLauncherService` (LaunchMode.externalApplication)
- [x] `lib/app/core/services/app_lifecycle_source.dart` — `WidgetsAppLifecycleSource` (production) + `FakeAppLifecycleSource` (test)
- [x] `lib/app/features/budget/application/pending_settlement_notifier.dart` — `confirmWindow = Duration(seconds: 30)`; takes `Clock + IUrlLauncher + AppLifecycleSource`; in-memory pending state (drops on app kill); `onConfirmRequested` callback fires only on resume within window
- [x] `lib/app/features/budget/presentation/widgets/settle_sheet.dart` — rewritten: Venmo + CashApp buttons enabled per handle availability; "Copy details" fallback always present; stable `Key('budget.settle.{venmo|cashapp|copy}')`
- [x] `lib/app/features/budget/data/expense_repository.dart` — `recordSettlement(payerId, payeeId, amount)` writes `isPayment: true` expense with `splits: [(payeeId, -amount)]`; returns the doc id (used as the chat-notice id for idempotency)
- [x] `lib/app/core/services/i_chat_service.dart` + `firestore_chat_service.dart` + `chat_repository.dart` — `postSettlementNotice(eventId, messageId, senderId, text)`; uses caller-supplied `messageId` for idempotency (same id as the expense); writes `kind: 'settlement'`
- [x] `lib/app/features/chat/domain/models/chat_message.dart` — added `ChatMessageKind` enum + `kind` field
- [x] `lib/app/features/chat/presentation/widgets/message_bubble.dart` — settlement variant: outlined sage border, "Settlement" label, center-aligned, optional `onTapSettlement` (Phase 6 hook); stable `Key('chat.message.{id}')`
- [x] `lib/app/features/budget/presentation/event_budget_page.dart` — owns `PendingSettlementNotifier` + `WidgetsAppLifecycleSource` lifecycle; `onSettlePressed` shows `SettleSheet`, launches deep link via `PendingSettlementNotifier`, prompts confirm dialog on resume, records settlement + posts chat notice
- [x] `lib/app/core/providers.dart` — `chatServiceProvider`, `chatRepositoryProvider`, `urlLauncherProvider`
- [x] `ios/Runner/Info.plist` — `LSApplicationQueriesSchemes: ['venmo', 'cashme']`
- [x] TDD: `PayLinkBuilder.venmo` (params + 2dp amount + invalid handle + 60-char note truncation + web fallback); `PayLinkBuilder.cashApp` (URL shape + invalid handle)
- [x] TDD: `PendingSettlementNotifier` — `launchAndPrepare` records pending and launches; resume within 30s fires confirm; resume after 30s drops pending; `clearPending` drops state
- [x] TDD: `recordSettlement` writes `isPayment: true` with single negative split addressed to payee
- [x] Widget: `SettleSheet` Venmo enabled with handle / disabled without; both disabled with no handles; Copy stays available; currency symbol applied
- [ ] Robot: `BudgetRobot` settle-via-Venmo journey — **deferred**: requires deeper test harness (Riverpod overrides for `IUrlLauncher`, `AppLifecycleSource`, faked Firestore + fake auth, and a stable settle-row Key matching the family payee id). The pure-unit + widget tests cover the contract; tracked in `ai_specs/todo.md`
- [x] Verify: `flutter analyze` && `flutter test` — clean (113 tests)

**Deviation note**: skipped the explicit `UserProfileNotifier` — `EditProfileScreen` already calls `userRepositoryProvider.saveProfile` directly with `ref.read`. Adding a notifier wrapper would have been pure indirection without test or feature benefit.

### Phase 6: Dispute path

- **Goal**: Payee or payer can dispute; settlement expense + notice rolled back.
- [x] `functions/src/events/disputeSettlement.ts` — onCall; verifies caller is `payerId` or first-split `userId` (the payee); deletes settlement expense; rewrites chat notice with `kind: 'settlement_disputed'`; mirrors `promoteToAdmin.ts` shape
- [x] `functions/src/index.ts` — export `disputeSettlement`
- [x] `lib/app/features/chat/presentation/widgets/dispute_sheet.dart` — bottom sheet; "All good — keep it" cancels, "Dispute this settlement" fires `onDispute`
- [x] `lib/app/features/chat/presentation/widgets/message_bubble.dart` — settlement variant + `onTapSettlement` already wired in Phase 5
- [x] `lib/app/features/chat/presentation/chat_screen.dart` — `onTapSettlement` callback; only settlement bubbles are interactive
- [x] `lib/app/core/providers.dart` — `DisputeSettlementCall` typedef + `disputeSettlementCallableProvider` (default wraps `FirebaseFunctions.instance`; tests override)
- [ ] TDD: emulator integration — **deferred**: same `functions/test/` harness gap as Phase 1 / Phase 2 CFs (tracked in todo.md). Logic is straightforward and mirrors the verified `promoteToAdmin.ts` shape; manual smoke required pre-deploy
- [x] Widget: DisputeSheet renders summary; Cancel does not fire `onDispute`; Dispute confirm fires and closes
- [x] Widget: ChatScreen — tapping a settlement bubble fires `onTapSettlement`; tapping a normal one does not
- [x] Verify: `cd functions && npm run build && cd ..` && `flutter analyze` && `flutter test` — clean (117 tests)

### Phase 7: Chat polish + Drift cache

- **Goal**: Fix `eventId` bug; sender-name hydration; instant cold-start render; auto-scroll discipline.
- [x] `lib/app/features/chat/data/firestore_chat_service.dart` — fixed `eventId: ''` bug; passes eventId through `_fromFirestore`; reads `kind` field
- [x] `lib/app/core/services/i_chat_service.dart` — `ChatMessage.kind` field
- [x] `lib/app/core/database/daos/chat_messages_dao.dart` — new DAO with `watchByEventId`, `insertOrReplace`, `evictOldestIfNeeded(maxRows)`
- [x] `lib/app/features/chat/data/chat_repository.dart` — Firestore stream → Drift mirror per event; reads via Drift watch; `disposeMirror`/`dispose` cleanup; `maxCachedRows: 200` default
- [x] `lib/app/features/chat/application/users_by_id_provider.dart` — `FutureProvider.family<Map<String,AppUser>,List<String>>` for sender-name hydration via existing `userRepositoryProvider`
- [x] Composer in-flight state lives on `EventChatPage` (no separate notifier needed): `_isSending` + `_lastSendFailed` flags drive ChatScreen UI
- [x] `lib/app/features/chat/presentation/chat_screen.dart` — empty state copy "No messages yet — be the first to say something."; reverse-list auto-scroll only when offset < 80px; Send button disabled while `isSending`; `lastSendFailed` shows retry hint; resolves sender name via `memberNames` map; stable `Key('chat.composer.send')`, `Key('chat.composer.input')`, `Key('chat.list.empty')`, `Key('chat.list')`
- [x] `lib/app/features/chat/presentation/event_chat_page.dart` — new wrapper: subscribes to `chatMessagesProvider(eventId)` + `usersByIdProvider(memberIds)`; routes send + dispute through providers; opens `DisputeSheet` on settlement tap
- [x] `lib/app/core/providers.dart` — `chatRepositoryProvider` injects DAO + dispose hook; `chatMessagesProvider.family` with onDispose cleanup
- [x] `lib/app/core/router/app_router.dart` — `/dashboard/event/:eventId/chat` wired to `EventChatPage`; event-dashboard quick-link wired
- [x] TDD: `ChatRepository` mirror — incoming Firestore message persists to Drift and surfaces through `watchMessages`
- [x] TDD: 200-cap eviction — only newest `maxCachedRows` remain in Drift
- [x] Widget: empty state copy; in-flight Send disabled with spinner; `lastSendFailed` surfaces retry hint; `memberNames` resolves UID to display name
- [x] Verify: `flutter analyze` && `flutter test` — clean (123 tests)

**Deviations**: Removed-sender path defers to `usersByIdProvider` returning `null` (UI shows the UID label, no special "Unknown member" string yet — Phase 8 push-tap deep-link handler is the right place to coalesce). Tracked in `todo.md`.

### Phase 8: FCM push for urgent

- **Goal**: Closed-app urgent push; foreground in-app banner with active-screen suppression; deep-link tap.
- [x] `pubspec.yaml` — `firebase_messaging` added in Phase 1
- [x] `ios/Runner/Info.plist` — `UIBackgroundModes` now includes `remote-notification`
- [x] `lib/app/core/services/fcm_gateway.dart` — `IFcmGateway` + `FirebaseFcmGateway` real impl over `firebase_messaging`
- [x] `lib/app/core/services/fcm_service.dart` — `attach(uid)` requests permission, awaits APNs (iOS), gets token, calls `userRepository.addFcmToken`, listens for `onTokenRefresh` and upserts; `detach(uid)` arrayRemoves before `deleteToken()` so the rule layer still sees an authenticated owner
- [x] `lib/app/features/profile/data/firestore_user_repository.dart` + `i_user_repository.dart` — `addFcmToken` / `removeFcmToken` (idempotent via `arrayUnion` / `arrayRemove`)
- [x] `lib/app/core/router/current_route_provider.dart` — `Notifier<String?>` updated from `createRouter`'s redirect hook
- [x] `lib/app/core/services/fcm_handler.dart` — pure logic for foreground banner-vs-suppress decisions and tap deep-link routing; `currentRoute` / `showBanner` / `navigateTo` callbacks make the platform wiring testable
- [x] `lib/app/core/router/app_router.dart` — `onRouteChanged` callback parameter; `main.dart` plumbs it to `currentRouteProvider`
- [x] `functions/src/events/onUrgentMessageCreated.ts` — Firestore-trigger v2 (`onDocumentCreated`); ignores non-urgent; loads event; collects tokens skipping sender; chunks at 500; `sendEachForMulticast`; prunes `registration-token-not-registered` + `invalid-argument` tokens via batched `arrayRemove`; `retry: false`
- [x] `functions/src/index.ts` — export `onUrgentMessageCreated`
- [x] TDD: `FcmService` lifecycle — attach writes; permission-denied returns false silently; refresh upserts; detach arrayRemoves before deleteToken
- [x] TDD: `currentRouteProvider` reflects setter calls
- [x] Widget: `FcmHandler.handleForegroundMessage` — banner shown off-route, suppressed on matching event chat, still shown when on chat for a different event
- [x] Widget: `FcmHandler.handleTap` — deep-link navigation when present; no-op when missing
- [ ] TDD: emulator integration for `onUrgentMessageCreated` — **deferred**: same `functions/test/` harness gap as earlier CFs; tracked in `todo.md`
- [ ] Robot: `ChatRobot` urgent journey with faked FCM payload — **deferred**: same harness depth as the BudgetRobot deferral in Phase 5; tracked in `todo.md`
- [x] Verify: `cd functions && npm run build && cd ..` && `flutter analyze` && `flutter test` — clean (133 tests)

**Bootstrap deferral**: `main.dart` does not yet register `FirebaseMessaging.onBackgroundMessage`, subscribe `onMessage` / `onMessageOpenedApp`, or call `FcmService.attach` from the auth state listener. Those are platform wiring that requires a real device + uploaded APNs key to verify. The seams (`IFcmGateway`, `FcmService.attach/detach`, `FcmHandler`, `currentRouteProvider`) are all in place; bootstrap is mechanical and tracked in `todo.md` so Phase 9's manual smoke covers it.

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
