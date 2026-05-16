## Overview

Ship cross-event Chat Global Inbox + Budget Financial Ledger; replace empty Chat/Budget tab placeholders. Mirrors the just-shipped `myAssignedTasksProvider` + `MyTasksScreen` pattern twice.

**Spec**: `ai_specs/chat-budget-tabs-spec.md` (numbered refs below match the spec)

## Context

- **Structure**: feature-first under `lib/app/features/<feature>/{data,domain,application,presentation}`; shared widgets at `lib/app/core/widgets/`; i18n at `lib/app/core/i18n/app_strings.dart`; test mirror under `test/app/...`, harnesses at `test/harness/`, robots at `test/robots/`, journeys at `test/journeys/`.
- **State management**: Riverpod 3, legacy syntax (no `@riverpod` codegen on aggregators). Canonical streams already exist:
  - `dashboardEventsProvider` (`lib/app/core/providers.dart:135`) — `StreamProvider<List<EventModel>>`. Reuse.
  - `chatMessagesProvider` (`lib/app/core/providers.dart:233`) — `StreamProvider.family<List<ChatMessageModel>, String>` keyed by `eventId`.
  - `expenseListProvider` (`lib/app/core/providers.dart:208`) — `StreamProvider.family<List<ExpenseModel>, String>` keyed by `eventId`.
  - `currentUserIdProvider` (`lib/app/core/providers.dart:114`) — `Provider<String?>`; nullable, short-circuit before family invocation.
  - `urlLauncherProvider` (`lib/app/core/providers.dart:241`) — `IUrlLauncher`, the boundary tests fake to capture deep links.
  - `userRepositoryProvider` (`lib/app/core/providers.dart:93`) — `IUserRepository`; used to look up counterparty's `paymentMethod` + `paymentHandle`.
- **Reference implementations** (copy these shapes verbatim):
  - `lib/app/features/tasks/application/my_assigned_tasks_provider.dart` — canonical cross-event aggregator: `Provider.family<AsyncValue<List<Row>>, String>`, manual `AsyncValue` fold, `events.value == null` short-circuit checking error/loading via `switch`, archived events NOT filtered (this PR filters for chat, keeps all for budget per req 17).
  - `lib/app/features/tasks/presentation/my_tasks_screen.dart` — five-branch ConsumerWidget (null-uid / loading / error / empty-adaptive-copy / non-empty), `onOpenX` test seams falling through to `context.push`/`context.go`.
  - `lib/app/features/tasks/presentation/widgets/tasks_group_header.dart` — shared widget pattern for cross-screen reuse.
  - `lib/app/core/widgets/empty_state_placeholder.dart:11–31` — exact constructor signature.
  - `lib/app/core/database/daos/tasks_dao.dart` — DAO file shape (mirror for `ChatReadsDao`).
  - `test/database/migration_v5_to_v6_test.dart` — migration test pattern (open v(N-1) DB via raw SQL → bump → assert new schema).
  - `test/harness/dashboard_harness.dart` + `test/harness/tasks_harness.dart` — `FakeFirebaseFirestore` + `NativeDatabase.memory()` + stub `AuthNotifier`.
  - `test/journeys/tasks_tab_empty_state_journey_test.dart` — screen-level robot journey shape (no full `StatefulShellRoute`).
  - `lib/app/features/budget/data/pay_link_builder.dart:1–72` — `PayLinkBuilder.venmo(handle, amount, note)`, `PayLinkBuilder.cashApp(handle, amount)`, `PayLinkBuilder.venmoWebFallback(...)`. Pure utility.
  - `lib/app/features/budget/domain/models/balance_ledger.dart:6–11` — `BalanceLedger { netBalances, settlements, totalExpenses }`; `Settlement { fromUserId, toUserId, amount }`; static `calculate({required expenses, required memberIds})`.
  - `lib/app/features/chat/presentation/event_chat_page.dart` — `ConsumerStatefulWidget`; add `initState` override to fire `markEventRead`.
- **Assumptions/Gaps**:
  - Aggregator providers live in feature folders (`features/chat/application/`, `features/budget/application/`), NOT re-exported from `core/providers.dart`. Mirrors `myAssignedTasksProvider` placement.
  - Lottie failures surface async via `errorBuilder`; widget tests pump ≥ 3 × 50 ms frames and avoid `pumpAndSettle` (lottie loops). Same constraint inherited from the just-shipped empty-state plan.
  - `flutter analyze` baseline: only the pre-existing `TableMigration` experimental warning is allowed.
  - `userRepositoryProvider` is read sync inside the SettleUpController (Phase 4). Confirmed it returns `IUserRepository` over Firestore; tests override with a seeded fake.
  - Firestore security rule for `users/{uid}/chatReads/{eventId}` is owner-only. Rule file location (in-repo `firestore.rules` or external) is not surveyed here; PR description must call it out for manual deploy if external.
  - Drift schema is currently v6 per the codebase survey; this PR bumps to v7 to add `chat_reads`.

## Plan

### Phase 1: Chat inbox thin slice — `globalInboxProvider` + `ChatInboxScreen` + route rewire (no unread yet)

- **Goal**: Ship cross-event chat composition end-to-end with the simplest possible row (event title + last sender + last message snippet + relative timestamp). Replace the `ChatTabPlaceholderScreen`. Prove the slice works before layering unread tracking on top.
- [x] `lib/app/features/chat/application/global_inbox_provider.dart` — `InboxRow { final EventModel event; final ChatMessageModel? lastMessage; }` (Phase 1 fields only). `final globalInboxProvider = Provider.family<AsyncValue<List<InboxRow>>, String>((ref, uid) {...})` per spec req 1–2: filter `event.status == active`, fold `dashboardEventsProvider` + `chatMessagesProvider(event.id)`, skip events with empty message lists, sort by `lastMessage.timestamp` desc, manual `AsyncValue` fold (loading-short-circuit, error-short-circuit, empty events → `AsyncData([])`).
- [x] `lib/app/features/chat/presentation/chat_inbox_screen.dart` — `ConsumerWidget` mirroring `MyTasksScreen` exactly: null-uid → `EmptyStatePlaceholder(title: signInRequiredTitle)`, no family invocation. Non-null → `globalInboxProvider(uid).when(...)`. Optional `onOpenChat` + `onOpenDashboard` seams (typedef `OpenChatCallback = void Function(BuildContext, InboxRow)`). Production fallthrough: `context.push('/dashboard/event/${row.event.id}/chat')` + `context.go(AppRoutes.dashboard)`. AppBar title `s.chat.inboxAppBarTitle` — no literals.
- [x] `lib/app/features/chat/presentation/widgets/inbox_tile.dart` — `StatelessWidget` Phase 1 shape: 40 px sage circle disc with first-letter avatar, event title (titleSmall, charcoal, w500), "{senderName}: {text trimmed to 60 chars}" subtitle, relative timestamp. Key: `Key('chat.inbox.tile.${row.event.id}')`. NO unread badge / urgent indicator yet (Phase 2).
- [x] `lib/app/core/i18n/app_strings.dart` — extend `ChatStrings` + `_EnglishChatStrings` with `inboxAppBarTitle`, `inboxEmptyTitle`, `inboxEmptySubtitle`, `inboxEmptyNoEventsSubtitle`, `inboxErrorTitle`, `inboxLastMessagePrefix(senderName, text)`. Existing `tabEmptyTitle`/`tabEmptySubtitle` fields removed in this phase (placeholder screen is its only consumer).
- [x] `lib/app/core/router/app_router.dart` — replace `/chat` branch's `ChatTabPlaceholderScreen` with `const ChatInboxScreen()`. Delete `ChatTabPlaceholderScreen` import.
- [x] Delete `lib/app/features/chat/presentation/chat_tab_placeholder_screen.dart` + `test/app/features/chat/chat_tab_placeholder_screen_test.dart` (req 27).
- [x] TDD: `globalInboxProvider` composition — 2 active + 1 archived event; assert archived excluded, rows sorted by last-message timestamp desc, `lastMessage` references the correct message
- [x] TDD: `globalInboxProvider` skips events with empty message lists (no row, no error)
- [x] TDD: `globalInboxProvider` loading propagation — any input `AsyncLoading` → `AsyncLoading`
- [x] TDD: `globalInboxProvider` error propagation — events error OR any per-event chat stream errors → `AsyncError`
- [x] TDD: `globalInboxProvider` empty events list → `AsyncData([])`, no inner family providers subscribed
- [x] TDD: `ChatInboxScreen` loading branch → `LoadingAnimation`; no list, no empty state
- [x] TDD: `ChatInboxScreen` empty-with-events → `inboxEmptySubtitle` + `openDashboardCta`
- [x] TDD: `ChatInboxScreen` empty-no-events → `inboxEmptyNoEventsSubtitle` + `createFromDashboardCta`
- [x] TDD: `ChatInboxScreen` null-uid → `signInRequiredTitle`; `globalInboxProvider` NEVER subscribed (counter-override)
- [x] TDD: `ChatInboxScreen` non-empty → one `InboxTile` per row; tap → `onOpenChat` seam fires with the right event
- [x] TDD: `InboxTile` renders title + sender prefix + snippet truncated; "You: ..." prefix when last message senderId == current uid
- [x] Verify: `flutter analyze` clean; `flutter test test/app/features/chat/ test/app/core/router/`

### Phase 2: Chat read tracking — Drift `chat_reads` + repo + unread + urgent + backfill

- **Goal**: Layer per-user read state on top of Phase 1's inbox: unread badges, urgent (terracotta + bell) highlight, first-launch backfill so existing users land at zero unread. Wire `EventChatPage.initState` to mark-read.
- [x] `lib/app/core/database/app_database.dart` — new `ChatReads` table (`eventId TEXT`, `uid TEXT`, `lastReadAt DATETIME`; PK `{eventId, uid}`). Bump `schemaVersion` 6 → 7. Migration step uses `CREATE TABLE IF NOT EXISTS` so it's safely idempotent across crash-tolerant migration retries.
- [x] `lib/app/core/database/daos/chat_reads_dao.dart` — `@DriftAccessor(tables: [ChatReads])` mirroring `tasks_dao.dart` shape: `Stream<DateTime?> watchLastReadAt({eventId, uid})`, `Future<int> upsert({eventId, uid, lastReadAt})`.
- [x] `lib/app/core/providers.dart` — new `chatReadsDaoProvider`; thread it + `firestoreProvider` into `chatRepositoryProvider` constructor.
- [x] `lib/app/features/chat/data/chat_repository.dart` — new constructor params `FirebaseFirestore? firestore` + `ChatReadsDao? chatReadsDao`; new methods:
  - `Stream<DateTime?> watchLastRead(String uid, String eventId)` — Drift-cached emission first; Firestore `users/{uid}/chatReads/{eventId}` doc snapshot listener mirrors values into Drift. Same mirror pattern as `watchMessages`.
  - `Future<void> markEventRead(String uid, String eventId)` — Firestore set with `lastReadAt: FieldValue.serverTimestamp()` (merge: true); on success upsert Drift; on Firestore failure swallow + `developer.log(name: 'chat.reads', level: 900)`. Fire-and-forget — never throws.
  - `Future<void> backfillReadStateForExistingEvents(String uid, List<EventModel> events)` — for each event whose Firestore read-doc does not exist, write `{lastReadAt: now()}`. Idempotent.
- [x] `lib/app/features/chat/application/global_inbox_provider.dart` — extend `InboxRow` with `unreadCount: int` + `hasUrgentUnread: bool`. New helper `eventChatReadStateProvider` (`StreamProvider.family<DateTime?, ({String uid, String eventId})>`) wrapping `chatRepository.watchLastRead`. `globalInboxProvider` computes `unreadCount = messages.where((m) => m.senderId != uid && (lastReadAt == null || m.timestamp.isAfter(lastReadAt))).length`; `hasUrgentUnread = unreadCount > 0 && unread.any((m) => m.isHighPriority)`.
- [x] `lib/app/features/chat/presentation/widgets/inbox_tile.dart` — bold title when `unreadCount > 0`; right-side badge circle 20 px (terracotta if `hasUrgentUnread`, sage otherwise) with "{count}" or "99+" text; bell icon (`Icons.notification_important_outlined`, terracotta) prepended to title when `hasUrgentUnread`. Keys: `Key('chat.inbox.tile.${id}.badge')`, `Key('chat.inbox.tile.${id}.urgent')`.
- [x] `lib/app/features/chat/presentation/chat_inbox_screen.dart` — converted to `ConsumerStatefulWidget` with `_didBackfill` guard; on first build with non-null uid + non-null events emission, fires `chatRepository.backfillReadStateForExistingEvents(uid, events)` once per session via `addPostFrameCallback`.
- [x] `lib/app/features/chat/presentation/event_chat_page.dart` — `initState` adds a `WidgetsBinding.instance.addPostFrameCallback` that fires `ref.read(chatRepositoryProvider).markEventRead(uid, widget.event.id)` after the first frame. Read uid via `ref.read(authProvider)`; short-circuits when not authenticated. Fire-and-forget.
- [x] `lib/app/core/i18n/app_strings.dart` — extend `ChatStrings` with `inboxUrgentBadgeLabel` (semantics label).
- [x] `firestore.rules` — added rule for `match /users/{uid}/chatReads/{eventId}`: owner-only `read, write`. Inside the existing `users/{userId}` subtree.
- [x] TDD: Drift migration v6 → v7 — open v6-shaped in-memory DB via raw SQL, stamp `PRAGMA user_version = 6`, open `AppDatabase` to trigger `onUpgrade`, assert `chat_reads` table exists with correct columns. Pattern: `test/database/migration_v5_to_v6_test.dart`. Idempotent retry case covered (chat_reads already exists pre-migration).
- [x] TDD: `ChatReadsDao.upsert` then `watchLastReadAt` emits the upserted timestamp + emits null when no row exists + replaces on duplicate key
- [x] TDD: `ChatRepository.markEventRead` happy path — writes Firestore doc + Drift row (via `FakeFirebaseFirestore` + in-memory Drift)
- [x] TDD: `ChatRepository.markEventRead` Firestore-null defensive path — swallows, does NOT throw
- [x] TDD: `ChatRepository.backfillReadStateForExistingEvents` writes per event when none exist + skips events whose read doc already exists (idempotent — verified via a string sentinel that survives the second call)
- [x] TDD: `ChatRepository.watchLastRead` — Drift emission first, then Firestore-write triggers re-emission with newer timestamp
- [x] TDD: `globalInboxProvider` `unreadCount` correctly excludes own-sent messages
- [x] TDD: `globalInboxProvider` `unreadCount == messages.length` when `lastReadAt == null` (counted only for other-sender messages)
- [x] TDD: `globalInboxProvider` `hasUrgentUnread` flips iff at least one unread message has `isHighPriority == true`; flips false when the urgent message predates `lastReadAt`
- [x] TDD: `InboxTile` unread state renders bold title + sage badge; urgent state renders terracotta badge + bell icon; read state hides badge
- [x] TDD: `InboxTile` badge text caps at "99+"
- [x] TDD: `EventChatPage` calls `markEventRead` on first frame after mount (verified end-to-end via `FakeFirebaseFirestore` doc existence)
- [x] TDD: `ChatInboxScreen` first-load backfill — uid + events emit → Firestore docs written for every event
- [x] Robot journey: `test/journeys/chat_inbox_open_event_journey_test.dart` — `ChatInboxRobot` (new `test/robots/chat_inbox_robot.dart`). Two active events (one urgent unread, one calm); pump screen → expect bell + badge on urgent row → tap → captured `onOpenChat` callback fires with the urgent event's id. Bounded pumps.
- [x] Verify: `flutter analyze` clean; `flutter test` 486 tests pass

### Phase 3: Budget ledger thin slice — `globalBalanceLedgerProvider` + `BudgetLedgerScreen` + route rewire (no Settle Up yet)

- **Goal**: Ship the cross-event balance composition with the hero strip, debts list (display only — no Settle Up button), recent expenses, and full five-branch consumer. Replace `BudgetTabPlaceholderScreen`. Phase 4 layers Settle Up on top.
- [x] `lib/app/features/budget/application/global_balance_ledger_provider.dart` — `DebtRow { counterpartyUid, event, amount, currency }`, `RecentExpenseRow { expense, event }`, `LedgerSummary { totalOwedToYou, totalYouOwe, debts, recentExpenses }`. `final globalBalanceLedgerProvider = Provider.family<AsyncValue<LedgerSummary>, String>((ref, uid) {...})` per spec req 16–18: NO archive filter (debts survive trip closure), watch `dashboardEventsProvider` + per-event `expenseListProvider(event.id)`, per event run `BalanceLedger.calculate(expenses, event.memberIds).settlements`, distribute by `fromUserId`/`toUserId` matching `uid`, sum totals, build debt rows sorted by `amount` desc, flatten all expenses + sort by `createdAt` desc + take 20 → `recentExpenses`. Manual `AsyncValue` fold (loading-short-circuit, error-short-circuit). Drop debt rows whose `amount.toStringAsFixed(2) == '0.00'` (req 36).
- [x] `lib/app/features/budget/presentation/budget_ledger_screen.dart` — `ConsumerWidget`. Null-uid → sign-in-required empty. Non-null → `globalBalanceLedgerProvider(uid).when(...)`. Five branches: loading / error / data. `data` branch renders a `ListView` carrying `LedgerHeroStrip`, debts section (header + tiles OR `LedgerAllSettledChip` when `debts.isEmpty && recentExpenses.isNotEmpty`), and the recent-expenses section. Empty-ledger overload (`debts.isEmpty && recentExpenses.isEmpty`) → `EmptyStatePlaceholder` adaptive per event count (matches `MyTasksScreen`). Optional `onOpenEventBudget` test seam. Production fallthrough: `context.push('/dashboard/event/${event.id}/budget')`.
- [x] `lib/app/features/budget/presentation/widgets/ledger_hero_strip.dart` — sage owed amount on top line (`labelLarge` label + headlineLarge bold value), terracotta you-owe on bottom line. Keys: `Key('budget.ledger.hero.owedToYou')`, `Key('budget.ledger.hero.youOwe')`. Renders multi-currency disclaimer (`Key('budget.ledger.hero.multiCurrency')`) when any event currency differs from USD.
- [x] `lib/app/features/budget/presentation/widgets/debt_tile.dart` — Phase 3 shape: counterparty avatar (sage circle + first letter fallback) + display name + event title chip + amount in event currency. NO Settle Up button yet (Phase 4). Key: `Key('budget.ledger.debt.${counterpartyUid}.${eventId}')`.
- [x] `lib/app/features/budget/presentation/widgets/recent_expense_tile.dart` — payer avatar + payer name + amount + description + event title + relative timestamp ("2h" / "yesterday" / "Mar 4" — older than 30 days uses absolute, req 37). Key: `Key('budget.ledger.recentExpense.${expenseId}')`. Tap → `onOpenEventBudget` seam fallthrough.
- [x] `lib/app/features/budget/presentation/widgets/ledger_all_settled_chip.dart` — sage-tinted info row with check icon + message (`BudgetStrings.ledgerAllSettledMessage`). Key: `Key('budget.ledger.allSettled')`. No emoji literal in code.
- [x] `lib/app/core/i18n/app_strings.dart` — extend `BudgetStrings` + `_EnglishBudgetStrings` with `ledgerAppBarTitle`, `ledgerHeroOwedToYouLabel`, `ledgerHeroYouOweLabel`, `ledgerDebtsHeader`, `ledgerAllSettledMessage`, `ledgerRecentExpensesHeader`, `ledgerEmptyTitle`, `ledgerEmptyNoEventsSubtitle`, `ledgerEmptySubtitle`, `ledgerErrorTitle`, `multiCurrencyDisclaimer`. Existing `tabEmpty*` fields removed alongside the deleted placeholder screen.
- [x] `lib/app/core/router/app_router.dart` — replaced `/budget` branch's `BudgetTabPlaceholderScreen` with `const BudgetLedgerScreen()`; deleted the import.
- [x] Deleted `lib/app/features/budget/presentation/budget_tab_placeholder_screen.dart` + `test/app/features/budget/budget_tab_placeholder_screen_test.dart` (req 27).
- [x] TDD: `globalBalanceLedgerProvider` composition — I paid $100 in event A 50/50 with alex → totalOwedToYou == $50; recent expenses populated
- [x] TDD: `globalBalanceLedgerProvider` INCLUDES archived events (debts survive trip closure)
- [x] TDD: `globalBalanceLedgerProvider` debt rows sorted by amount desc; I-owe scenarios surface counterparty + amount
- [x] TDD: `globalBalanceLedgerProvider` drops debt rows whose amount rounds to $0.00
- [x] TDD: `globalBalanceLedgerProvider` recent expenses capped at 20, sorted by `createdAt` desc (verified at 25-input → 20-output, newest first)
- [x] TDD: `globalBalanceLedgerProvider` loading propagation (events stream OR per-event expense stream pending → AsyncLoading)
- [x] TDD: `globalBalanceLedgerProvider` error propagation (events OR per-event errors → AsyncError)
- [x] TDD: `globalBalanceLedgerProvider` empty events → `LedgerSummary.empty()`; expense family NEVER subscribed (counter throw)
- [x] TDD: `BudgetLedgerScreen` five branches (loading / null-uid / empty-no-events / empty-with-events-no-expenses / non-empty)
- [x] TDD: `BudgetLedgerScreen` all-settled state — `LedgerAllSettledChip` renders when debts empty but recent expenses present
- [x] TDD: `LedgerHeroStrip` multi-currency disclaimer renders iff an event currency is non-USD
- [x] TDD: `RecentExpenseTile` tap fires `onOpenEventBudget` seam with the right event
- [x] Verify: `flutter analyze` clean; `flutter test` 503 tests pass

### Phase 4: Settle Up — `SettleUpController` + deep links + fallback sheet + DebtTile button

- **Goal**: Wire the Settle Up button into Phase 3's `DebtTile`. Controller picks deep link via `PayLinkBuilder` based on counterparty's canonical `paymentMethod`; missing handle or unsupported platform routes to a `SettleUpFallbackSheet` with copy-amount + mark-paid-manually link. Robot journey covers the happy path + fallback path.
- [ ] `lib/app/features/budget/application/settle_up_controller.dart` — pure controller class taking `Ref ref`. Method `Future<void> handleSettleUp(BuildContext context, DebtRow row)`:
  - Read counterparty via `ref.read(userRepositoryProvider).getUser(row.counterpartyUid)`. On throw → snackbar "Could not load contact info" + open fallback sheet without copy buttons (req 31).
  - Pick link via `switch (counterparty.paymentMethod)`: `venmo` → `PayLinkBuilder.venmo(handle: counterparty.paymentHandle!, amount: row.amount, note: '${row.event.title} settle-up')`; `cashapp` → `PayLinkBuilder.cashApp(handle: counterparty.paymentHandle!, amount: row.amount)`; `zelle | paypal | cash` OR missing handle OR malformed handle (regex fails) → null → fallback.
  - If link non-null: `final ok = await ref.read(urlLauncherProvider).launchUrl(uri)`. If `!ok` → fallback. On throw → catch + fallback (req 30, plus boundaries section).
  - Log malformed-handle warn-once via `developer.log(name: 'budget.settleUp', level: 900)`.
- [ ] `lib/app/features/budget/presentation/widgets/settle_up_fallback_sheet.dart` — `static Future<void> show(BuildContext context, DebtRow row, AppUser? counterparty)`. `showModalBottomSheet` body: recipient name + amount in event currency + "Copy amount" button (`Clipboard.setData(ClipboardData(text: row.amount.toStringAsFixed(2)))`); when counterparty non-null + has payment handle, "Copy handle" button too; "Mark paid in event budget" link → pops sheet → `context.push('/dashboard/event/${row.event.id}/budget')`. Keys: `Key('budget.settleUp.fallback.sheet')`, `Key('budget.settleUp.fallback.copyAmount')`, `Key('budget.settleUp.fallback.copyHandle')`, `Key('budget.settleUp.fallback.markPaid')`.
- [ ] `lib/app/features/budget/presentation/widgets/debt_tile.dart` — add trailing `OutlinedButton` (sage outline, terracotta foreground) labelled `s.budget.ledgerSettleUpCta`; key `Key('budget.ledger.settleUp.${counterpartyUid}.${eventId}')`. Tap → `onSettleUp(context, row)` (passed in from `BudgetLedgerScreen`). Production wiring: `BudgetLedgerScreen` passes `(ctx, row) => ref.read(settleUpControllerProvider).handleSettleUp(ctx, row)`.
- [ ] `lib/app/features/budget/presentation/budget_ledger_screen.dart` — add `onSettleUp` optional test seam (typedef matching `SettleUpController.handleSettleUp` signature minus the `Ref`-managed deps). Production fallthrough uses the controller via Riverpod read.
- [ ] `lib/app/core/i18n/app_strings.dart` — extend `BudgetStrings` with `ledgerSettleUpCta`, `settleUpFallbackTitle(String recipientName)`, `settleUpFallbackCopyAmount`, `settleUpFallbackCopyHandle`, `settleUpFallbackMarkPaid`, `settleUpContactLoadError`.
- [ ] `lib/app/core/providers.dart` — new `settleUpControllerProvider = Provider<SettleUpController>((ref) => SettleUpController(ref));`.
- [ ] TDD: `SettleUpController.handleSettleUp` venmo path — counterparty `paymentMethod: venmo` + valid handle → `urlLauncherProvider.launchUrl` called with `PayLinkBuilder.venmo(...)` URI. Recording fake captures URI; assert exact match (handle, amount, note).
- [ ] TDD: `SettleUpController.handleSettleUp` cashapp path — analogous
- [ ] TDD: `SettleUpController.handleSettleUp` zelle / paypal / cash → no launch; fallback opens
- [ ] TDD: `SettleUpController.handleSettleUp` missing `paymentHandle` → fallback opens; no launch
- [ ] TDD: `SettleUpController.handleSettleUp` malformed handle (regex fails) → fallback opens + warn log captured
- [ ] TDD: `SettleUpController.handleSettleUp` `urlLauncherProvider.launchUrl` returns false → fallback opens
- [ ] TDD: `SettleUpController.handleSettleUp` `urlLauncherProvider.launchUrl` throws → caught; fallback opens
- [ ] TDD: `SettleUpController.handleSettleUp` `userRepositoryProvider.getUser` throws → snackbar + fallback (no copy handle button)
- [ ] TDD: `SettleUpFallbackSheet` Copy Amount taps `Clipboard.setData` with the right amount string (fake `Clipboard.platform` capture via `TestDefaultBinaryMessengerBinding`)
- [ ] TDD: `SettleUpFallbackSheet` "Mark paid" link pops the sheet and fires the captured navigation seam
- [ ] TDD: `DebtTile` renders Settle Up button when amount > $0; tapping fires `onSettleUp` seam exactly once
- [ ] Robot journey: `test/journeys/budget_settle_up_journey_test.dart` — `BudgetLedgerRobot` (new `test/robots/budget_ledger_robot.dart`). Scenario A: one debt, counterparty venmo + handle → tap Settle Up → recording `urlLauncherProvider` captures the exact Venmo URI. Scenario B: same debt, counterparty `paymentMethod: cash` → tap Settle Up → fallback sheet visible → "Copy amount" works → "Mark paid in event budget" fires captured navigation seam. Bounded pumps, no `pumpAndSettle`.
- [ ] Verify: `flutter analyze` clean; `flutter test`; grep confirms zero `_PlaceholderScreen` references (carried over from prior PR's check), zero `ChatTabPlaceholderScreen`/`BudgetTabPlaceholderScreen` references in lib/

## Risks / Out of scope

**Risks**:
- **Provider lifecycle fan-out**: a user in 25+ events spawns 25 × (events stream + chat stream + read-state stream) + 25 × (expense stream) listeners. Same trade-off as `myAssignedTasksProvider`; revisit at ~50 events. Document in PR description.
- **Drift migration v6 → v7**: any data-corruption bug in the migration would brick the app on launch (existing DB exists). The dedicated `test/database/migration_v6_to_v7_test.dart` covers this; trigger pattern is the same as `migration_v5_to_v6_test.dart`. Idempotent design (Drift `m.createTable` on a non-existent table) makes the risk small.
- **Firestore security rule deploy**: if `firestore.rules` is not in-repo, the rules MUST be deployed alongside the app build or `users/{uid}/chatReads/{eventId}` writes will be rejected by Firestore → `markEventRead` logs warnings but no user-facing error. Flag loud-and-clear in the PR description.
- **`urlLauncherProvider` boundary**: tests inject a fake. Production path uses the real Venmo / Cash App schemes. Manual smoke required on a real device to verify the schemes actually open the apps; not covered by automated tests.
- **First-load backfill race**: if `dashboardEventsProvider` emits then re-emits with a new event before the backfill batch lands, the new event might not be backfilled. Acceptable for V1 (new events default to "all unread" which is correct for an event the user just joined). Documented.

**Out of scope** (deferred per spec):
- Server-side `collectionGroup` query strategy for chats or expenses.
- Cloud Functions aggregation of inbox / ledger.
- Mute support — the urgent highlight is V1's entire urgency surface.
- Mark-paid-from-ledger ("Did you pay Alex? [Yes]") — Settle Up only fires deep link, no DB write.
- Multi-platform settle-up UI (stacked Venmo + Cash App buttons per row).
- Push-notification surfaces for urgent messages.
- Dashboard / Tasks / Profile tab enhancements (greeting, Upcoming/Past toggle, glance chips, search bar, payment-methods section).
- Client-side currency conversion on hero totals — disclaimer banner only.
- Cross-event chat sending from the inbox — V1 is read-only; tap a row to send.
- Pagination on Recent Expenses — fixed last 20.
- New lottie animations — reuse `assets/animations/empty_state.json` (default) + `assets/animations/error.json` (error state).
