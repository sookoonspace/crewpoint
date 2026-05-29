<goal>
Replace the empty Chat and Budget bottom-nav tabs with real V1 implementations:

1. **Chat tab — Global Inbox** at `/chat`. A chronologically-sorted list of every active-event chat the user belongs to, with sender + snippet + relative timestamp on each row, an unread badge per row, and a terracotta "urgent" highlight when an unread message is flagged `isHighPriority`. Replaces `ChatTabPlaceholderScreen`.

2. **Budget tab — Financial Ledger** at `/budget`. A hero strip showing "You are owed $X" / "You owe $Y" across every event the user belongs to (active *and* archived), a per-counterparty-per-event debt breakdown with a "Settle Up" deep-link button per row, and a flat feed of the last 20 expenses across all events. Replaces `BudgetTabPlaceholderScreen`.

3. **Per-user chat read tracking infrastructure**: new Firestore-mirrored `users/{uid}/chatReads/{eventId}` documents storing `lastReadAt`. Written when the user opens an event's chat; read by the global inbox to compute unread counts. First-launch backfill so existing users land on a zero-unread inbox.

Beneficiaries: users who today see "Chat is coming soon" / "Budget is coming soon" placeholder screens. After this PR the Tasks / Chat / Budget tabs all reach feature-parity — every bottom-nav tab is a real cross-event aggregator, and the bottom nav stops feeling half-built.
</goal>

<background>
**Tech stack & conventions** (already in the codebase):

- Flutter 3.27+ / Dart 3.x; Riverpod 3 (no `@riverpod` codegen on the cross-event composition layer per the just-shipped `myAssignedTasksProvider` pattern); `go_router` 14 driving the `StatefulShellRoute.indexedStack` bottom nav.
- `lottie: ^3.3.1` already in `pubspec.yaml`; `assets/animations/empty_state.json` is the V1 lottie for empty states. `EmptyStatePlaceholder` (`lib/app/core/widgets/empty_state_placeholder.dart`) is the canonical empty-state widget — reuse it everywhere.
- Brand palette `lib/app/core/constants/app_colors.dart`: sage (positive/owed-to-you), terracotta (urgent/owed-by-you), charcoal (default text), cream (background).
- All user-facing copy flows through `lib/app/core/i18n/app_strings.dart` via `ChatStrings` / `BudgetStrings` extensions; literal strings in widget files are not allowed.

**Existing data layer (confirmed via codebase survey):**

- `chatRepositoryProvider` + `chatMessagesProvider(eventId)` (`lib/app/core/providers.dart:233`) — `StreamProvider.family<List<ChatMessageModel>, String>`; per-event Drift-mirrored watch via `ChatRepository.watchMessages(eventId)`. NO cross-event aggregation method.
- `ChatMessageModel` (`lib/app/features/chat/domain/models/chat_message.dart`) fields: `id, eventId, senderId, text, timestamp, isHighPriority, senderName, kind` (`ChatMessageKind: {normal, settlement}`). NO per-user read/unread field today — this PR introduces one.
- `expenseListProvider(eventId)` (`lib/app/core/providers.dart:208`) — `StreamProvider.family<List<ExpenseModel>, String>`; per-event Drift-mirrored watch. NO cross-event aggregation.
- `ExpenseModel`: `id, eventId, payerId, amount, description, receiptPath, isDonation, isPayment, splits, createdAt`. `splits` is `List<ExpenseSplit { userId, amount }>`. `isPayment: true` marks a settlement record.
- `BalanceLedger.calculate(expenses, memberIds)` (`lib/app/features/budget/domain/models/balance_ledger.dart`) — pure function returning `BalanceLedger { netBalances: Map<uid → double>, settlements: List<Settlement {fromUserId, toUserId, amount}>, totalExpenses }`. Operates on one event's expense list at a time; computed in-memory, not persisted.
- `PayLinkBuilder` (`lib/app/features/budget/data/pay_link_builder.dart`) — pure helpers: `venmo(handle, amount, note)`, `venmoWebFallback(...)`, `cashApp(...)`. Validates handle pattern `^[A-Za-z0-9_-]{1,30}$`.
- `AppUser` (`lib/app/features/auth/domain/models/app_user.dart`) carries `paymentMethod` (enum: `venmo, zelle, cashapp, paypal, cash`), `paymentHandle` (canonical handle for the selected method), plus legacy `venmoHandle` and `cashappHandle` strings.
- `urlLauncherProvider` (`lib/app/core/providers.dart:241`) wraps `package:url_launcher` so widget tests can fake the launch.
- `dashboardEventsProvider` (`lib/app/core/providers.dart:135`) — `StreamProvider<List<EventModel>>`; canonical source of the user's events. `EventModel.status` is `EventStatus { active, archived }`.
- `currentUserIdProvider` (`lib/app/core/providers.dart:114`) — `Provider<String?>`; nullable, short-circuit before any family invocation per spec req 21 of the just-shipped empty-state plan.

**Cross-tab navigation** (already in place per `lib/app/core/router/app_router.dart`):

- Bottom nav is `StatefulShellRoute.indexedStack`. The Dashboard branch already hosts nested event-scoped routes (`/dashboard/event/:eventId/{chat,budget,tasks}`); the Chat / Budget / Tasks branches are flat.
- Pushing `/dashboard/event/<id>/chat` from the Chat tab will stack onto the Chat branch (bottom nav stays visible). Confirmed via the Tasks tab's existing pattern (`context.push('/dashboard/event/${row.event.id}/tasks/${row.task.id}')`).

**Files to examine before implementing:**

- `lib/app/features/tasks/application/my_assigned_tasks_provider.dart` — the canonical "compose dashboardEventsProvider + per-event family provider" pattern; this PR mirrors it twice (chat + budget).
- `lib/app/features/tasks/presentation/my_tasks_screen.dart` — the canonical five-branch consumer (loading / null-uid / empty-no-events / empty-with-events / non-empty) with `onOpenTask` / `onOpenDashboard` test seams. Mirror the seam shape on both new screens.
- `lib/app/features/chat/data/chat_repository.dart` — extend with `markEventRead(uid, eventId)` + `watchLastReadByEvent(uid)`.
- `lib/app/features/budget/data/pay_link_builder.dart` — already shipped; just call it.
- `lib/app/core/database/app_database.dart` — Drift schema; this PR adds a new `chat_reads` table (eventId, uid, lastReadAt).
- `lib/app/features/chat/presentation/event_chat_page.dart` — call `markEventRead` from `initState`. Already navigated via `/dashboard/event/:eventId/chat`.

**Out of scope** (deferred):

- Chat mute infrastructure. The "urgent breaks through mute" phrasing in the user-facing description maps to V1's `isHighPriority` highlight only; there is no mute concept to bypass.
- A `collectionGroup` query strategy for chats or expenses. V1 fans out N per-event subscriptions, same trade-off as `myAssignedTasksProvider`. Revisit at ~25+ events.
- Mark-paid-from-ledger ("Did you pay Alex? [Yes]"). The Settle Up CTA only fires the deep link in V1 — recording the settlement still happens inside the event's budget screen.
- Multi-platform settle-up UI (Venmo + Cash App buttons stacked per row). V1 reads the counterparty's canonical `paymentMethod` enum + `paymentHandle` and picks one. Future spec may surface alternates.
- Push-notification side of urgent messaging. The inbox row gets the highlight; the notification system stays as-is.
- Dashboard / Tasks / Profile tab enhancements described in the user's broader vision (greeting strip, Upcoming/Past toggle, glance chips on event cards, Tasks search bar, payment-methods section in Profile). Each is a separate future spec.
</background>

<user_flows>

## Chat tab — Global Inbox

**Primary (has chats):**

1. User taps the Chat bottom-nav tab.
2. `ChatInboxScreen` renders a scrolling list of rows, one per active event the user belongs to that has at least one message. Sort: latest-message timestamp desc.
3. Each row shows: event title (bold if `unreadCount > 0`), sender name + first 60 chars of the last message, relative timestamp ("2m", "yesterday", "Mar 4"), and a small unread badge on the right (terracotta if any unread message has `isHighPriority`; sage otherwise).
4. User taps a row → `context.push('/dashboard/event/<eventId>/chat')`. Stacks the per-event chat page onto the Chat branch; bottom nav remains visible.
5. `EventChatPage.initState` fires `chatRepository.markEventRead(uid, eventId)` → writes `users/{uid}/chatReads/{eventId}` with `lastReadAt = now()`. Drift mirror updates; inbox row re-emits with `unreadCount: 0` next time it's surfaced.
6. User hits back → returns to Chat tab. Previously-unread row is no longer bold; badge is gone.

**Primary (no chats yet — has events):**

1. Tap Chat tab → `ChatInboxScreen` renders `EmptyStatePlaceholder` with `title = ChatStrings.inboxEmptyTitle` ("No messages yet"), `subtitle = ChatStrings.inboxEmptySubtitle` ("Open an event from the Dashboard to start chatting."), `ctaLabel = TasksStrings.openDashboardCta` (reused), `onCta = () => context.go(AppRoutes.dashboard)`.

**Primary (no events at all):**

1. Tap Chat tab → same empty-state widget but `subtitle = ChatStrings.inboxEmptyNoEventsSubtitle` ("Create or join an event to chat with your crew."), `ctaLabel = TasksStrings.createFromDashboardCta`.

**Urgent message flow:**

1. Another member sends a message with `isHighPriority: true` (or a settlement notice arrives — `kind == settlement` always has `isHighPriority == true`).
2. While the user is on the Chat tab, their inbox row for that event re-renders with the terracotta highlight + `Icons.notification_important_outlined` bell to the left of the event title.
3. Tap the row → enters event chat → `markEventRead` fires → highlight clears on return.

**First launch after deploy (backfill):**

1. New build released; existing user opens the Chat tab.
2. `ChatInboxScreen` detects this is the first cold-start where `users/{uid}/chatReads` is empty.
3. Lazy backfill: for every event in `dashboardEventsProvider`'s current emission, write `lastReadAt = now()` to `users/{uid}/chatReads/{eventId}` once (idempotent — only writes if the doc doesn't already exist).
4. Inbox renders with zero unread counts everywhere on this first launch. Subsequent messages drive real counts.

## Budget tab — Financial Ledger

**Primary (has events with expenses):**

1. User taps the Budget bottom-nav tab.
2. `BudgetLedgerScreen` renders a hero strip at the top:
   - Top line, large bold: "You are owed" → "$150.00" in `AppColors.sage`.
   - Bottom line, large bold: "You owe" → "$45.00" in `AppColors.terracotta`.
   - Amounts use the user's default display currency. (V1: USD. Multi-currency aggregation across events is deferred — the hero sums amounts directly without currency conversion, and the per-row currency chip is the source of truth for the actual currency.)
3. Below the hero, a "Settle up" section header followed by a list of debt rows. Each row represents one `(counterpartyUid, eventId)` pair where the user owes money:
   - Left: counterparty avatar + display name.
   - Middle: amount in the event's currency + event title chip ("for Tahoe Ski Trip").
   - Right: `OutlinedButton` labeled "Settle Up" (sage outline, terracotta foreground because this is debt action).
4. User taps Settle Up:
   - Lookup counterparty's `AppUser.paymentMethod` + `paymentHandle`.
   - Build deep link via `PayLinkBuilder` based on `paymentMethod`:
     - `venmo` → `PayLinkBuilder.venmo(handle: paymentHandle, amount: amount, note: "$eventTitle settle-up")`
     - `cashapp` → `PayLinkBuilder.cashApp(handle: paymentHandle, amount: amount)`
     - `zelle` / `paypal` / `cash` → V1 has no deep-link helper, so fall through to fallback sheet
   - Launch via `urlLauncherProvider.launch(...)`. On iOS/Android the system either opens the matching app or falls back to the web equivalent (Venmo specifically uses `venmoWebFallback` if `canLaunch` returns false).
5. Below the debts list, "Recent Expenses" section header followed by a chronological list (last 20 expenses across all the user's events, sorted by `createdAt` desc). Each row: payer avatar, payer name, amount, expense description, event title chip, relative timestamp. Tap → `context.push('/dashboard/event/<eventId>/budget')`.

**Primary (user is square with everyone):**

1. Hero strip shows "You are owed $0.00" / "You owe $0.00".
2. "Settle up" section: replaced by a sage-tinted info chip "You're all settled up 🎉" (string — no emoji literal; if user prefers no emoji, omit).
3. Recent Expenses section still renders if any expenses exist across events.

**Primary (no events):**

1. `EmptyStatePlaceholder` with `title = BudgetStrings.ledgerEmptyTitle` ("No balances yet"), `subtitle = BudgetStrings.ledgerEmptyNoEventsSubtitle`, `ctaLabel = TasksStrings.createFromDashboardCta`.

**Settle Up — no payment handle stored:**

1. User taps Settle Up on a debt where counterparty's `paymentHandle` is null OR `paymentMethod` is `zelle` / `paypal` / `cash` (no V1 deep link).
2. Modal bottom sheet (`SettleUpFallbackSheet`) opens with: recipient's display name, amount due, event title, a "Copy amount" button, optional "Copy email" / "Copy phone" buttons if the user has provided those, and a "Mark paid in the event budget" link that pushes `/dashboard/event/<eventId>/budget`.
3. Dismiss the sheet → user is back on the ledger. No state change.

**Settle Up — counterparty has a handle but the launch fails:**

1. `urlLauncherProvider.launch(...)` returns false (no app installed, no browser, etc.).
2. Same `SettleUpFallbackSheet` opens; copy-amount + manual instructions.

## Existing surfaces (unaffected)

- Per-event Chat (`/dashboard/event/:eventId/chat`) — unchanged except for the new `markEventRead` call in `initState`.
- Per-event Budget (`/dashboard/event/:eventId/budget`) — unchanged.
- Dashboard, Tasks, Profile tabs — untouched.

## Error / fallback flows

- **`globalInboxProvider` errors** (e.g., `dashboardEventsProvider` throws or a per-event `chatMessagesProvider` errors): render `EmptyStatePlaceholder(title: ChatStrings.inboxErrorTitle, subtitle: error.toString(), lottieAsset: 'assets/animations/error.json')`. Log via `developer.log(name: 'chat.inbox')`.
- **`globalBalanceLedgerProvider` errors**: same shape — `BudgetStrings.ledgerErrorTitle`, error lottie, `developer.log(name: 'budget.ledger')`.
- **Network offline on cold start**: events + per-event streams emit empty initially; both tabs show their empty state until Firestore reconnects + Drift mirror catches up. Then lists populate.
- **`markEventRead` write fails** (offline / permission denied): swallow + `developer.log` warn-once per `(uid, eventId)`; the row stays bold until the next successful write. Do NOT block navigation on the write.
- **Read-tracking backfill partial failure**: backfill is per-event, idempotent. A failure on one event doesn't block others; failed events stay "all unread" until next launch.

</user_flows>

<requirements>

**Functional — `globalInboxProvider`:**

1. New file `lib/app/features/chat/application/global_inbox_provider.dart`. Public surface:
   ```dart
   class InboxRow {
     final EventModel event;
     final ChatMessageModel? lastMessage;
     final int unreadCount;
     final bool hasUrgentUnread;
   }
   final globalInboxProvider = Provider.family<AsyncValue<List<InboxRow>>, String>((ref, uid) { ... });
   ```
2. Composes existing providers — does NOT call any repo method directly:
   - `ref.watch(dashboardEventsProvider)` → user's events.
   - Filter to `event.status == EventStatus.active` BEFORE invoking inner family providers (archived events do not show in the inbox).
   - For each active event: `ref.watch(chatMessagesProvider(event.id))` → `List<ChatMessageModel>`.
   - For each active event: `ref.watch(eventChatReadStateProvider((uid: uid, eventId: event.id)))` → `DateTime? lastReadAt`.
   - Per-event `InboxRow`: `lastMessage = messages.lastOrNull`; `unreadCount = messages.where((m) => m.senderId != uid && (lastReadAt == null || m.timestamp.isAfter(lastReadAt))).length`; `hasUrgentUnread = unreadCount > 0 && messages.any((m) => m.isHighPriority && m.senderId != uid && (lastReadAt == null || m.timestamp.isAfter(lastReadAt)))`.
   - Skip events whose messages list is empty (no row for "no messages yet" events — they live in the empty state).
   - Sort by `lastMessage.timestamp` desc.
   - Any input `loading` → `AsyncValue.loading()`. Any input `error` → `AsyncValue.error(...)`.
3. New helper provider `eventChatReadStateProvider` (`Provider.family<AsyncValue<DateTime?>, ({String uid, String eventId})>`) — wraps `ChatRepository.watchLastRead(uid, eventId)`. Emits null when no read doc exists yet.

**Functional — `ChatInboxScreen`:**

4. New file `lib/app/features/chat/presentation/chat_inbox_screen.dart`. `ConsumerWidget`. Mirrors `MyTasksScreen` shape:
   - Reads `currentUserIdProvider` first. Null → `EmptyStatePlaceholder(title: TasksStrings.signInRequiredTitle)`, NO family invocation.
   - On first non-null uid emission, fires a one-shot backfill: `ref.read(chatRepositoryProvider).backfillReadStateForExistingEvents(uid, events)` — idempotent (writes only if doc absent). Spec req 14.
   - Watches `globalInboxProvider(uid).when(...)`:
     - `loading` → `LoadingAnimation`.
     - `error` → `EmptyStatePlaceholder` with error lottie + `developer.log(name: 'chat.inbox')`.
     - `data: rows` → empty → `EmptyStatePlaceholder` with copy/CTA adapting to event count (existing events: `inboxEmptySubtitle` + `openDashboardCta`; zero events: `inboxEmptyNoEventsSubtitle` + `createFromDashboardCta`).
     - `data: rows` non-empty → `ListView.builder` of `InboxTile`s. Tap → `onOpenChat?(context, row) ?? context.push('/dashboard/event/${row.event.id}/chat')`.
5. AppBar title from `context.strings.chat.inboxAppBarTitle` — no literals. AppBar background `AppColors.cream`, elevation 0 (matches MyTasksScreen).
6. Two optional navigation seams: `OpenChatCallback? onOpenChat` and `VoidCallback? onOpenDashboard`. Tests inject capturing callbacks; production leaves both null.

**Functional — `InboxTile` widget:**

7. New file `lib/app/features/chat/presentation/widgets/inbox_tile.dart`. `StatelessWidget`. Public API: `InboxTile({Key? key, required InboxRow row, required VoidCallback onTap})`.
8. Layout (LTR):
   - 40 px circular event-color disc (placeholder lottie/avatar — V1: solid sage circle with first letter of event title, charcoal letter).
   - Column: event title (titleSmall, charcoal, fontWeight.w700 when `unreadCount > 0` else w500); below: "{senderName}: {last message text truncated to 60 chars + …}" (bodySmall, mediumGrey, max 1 line, ellipsis).
   - Spacer.
   - Column (right-aligned): relative timestamp (`labelSmall`, mediumGrey); below: badge (only if `unreadCount > 0`) — circle 18 px, terracotta background if `hasUrgentUnread`, sage otherwise, charcoal text "{count}" (cap at "99+").
9. When `hasUrgentUnread == true`, prepend a 16 px `Icons.notification_important_outlined` in terracotta to the left of the event title.
10. Stable key: `Key('chat.inbox.tile.${row.event.id}')`.

**Functional — Chat read tracking (data layer):**

11. New Drift table in `lib/app/core/database/app_database.dart`:
    ```dart
    class ChatReads extends Table {
      TextColumn get eventId => text()();
      TextColumn get uid => text()();
      DateTimeColumn get lastReadAt => dateTime()();
      @override Set<Column> get primaryKey => {eventId, uid};
    }
    ```
    Schema migration: new table + `schemaVersion` bumped; migration step adds the table empty.
12. New DAO `lib/app/core/database/daos/chat_reads_dao.dart` (`ChatReadsDao`) exposing:
    - `Stream<DateTime?> watchLastReadAt({required String eventId, required String uid})`
    - `Future<void> upsert({required String eventId, required String uid, required DateTime lastReadAt})`
13. Extend `ChatRepository` (`lib/app/features/chat/data/chat_repository.dart`):
    - Constructor takes `ChatReadsDao chatReadsDao` (in addition to existing deps).
    - `Stream<DateTime?> watchLastRead(String uid, String eventId)` — composes Firestore source-of-truth (`users/{uid}/chatReads/{eventId}` doc snapshot) with Drift cache. Same mirror pattern as `watchMessages`.
    - `Future<void> markEventRead(String uid, String eventId)` — writes `users/{uid}/chatReads/{eventId}` with `{lastReadAt: FieldValue.serverTimestamp()}` (merge: true). On success, upserts Drift via the DAO. On Firestore failure, swallow + warn-log; do NOT crash.
    - `Future<void> backfillReadStateForExistingEvents(String uid, List<EventModel> events)` — for each event NOT yet in `users/{uid}/chatReads`, write `{lastReadAt: now()}`. Idempotent. Batched Firestore write where possible. Called once per app session on first inbox render.
14. `lib/app/features/chat/presentation/event_chat_page.dart` — call `chatRepository.markEventRead(uid, eventId)` from `initState` after `super.initState()`. The call is fire-and-forget; do not block UI.
15. Firestore security rule update (`firestore.rules` — if managed in-repo): `users/{uid}/chatReads/{eventId}` is read+write only by the owning uid. Document the rule diff in the PR description; if rules live outside the repo, the PR description must explicitly call this out and the engineer must update them separately before deploy.

**Functional — `globalBalanceLedgerProvider`:**

16. New file `lib/app/features/budget/application/global_balance_ledger_provider.dart`. Public surface:
    ```dart
    class DebtRow {
      final String counterpartyUid;
      final EventModel event;
      final double amount;        // always positive; you owe this much
      final String currency;      // event's currency
    }
    class RecentExpenseRow {
      final ExpenseModel expense;
      final EventModel event;
    }
    class LedgerSummary {
      final double totalOwedToYou;   // sum across events, current display currency
      final double totalYouOwe;
      final List<DebtRow> debts;       // sorted by amount desc
      final List<RecentExpenseRow> recentExpenses; // last 20, createdAt desc
    }
    final globalBalanceLedgerProvider =
        Provider.family<AsyncValue<LedgerSummary>, String>((ref, uid) { ... });
    ```
17. Composition (no archive filter — debts survive trip closure):
    - `ref.watch(dashboardEventsProvider)` → all events (active + archived).
    - For each event: `ref.watch(expenseListProvider(event.id))` → `List<ExpenseModel>`.
    - Per event: `BalanceLedger.calculate(expenses, event.memberIds).settlements` yields `List<Settlement {fromUserId, toUserId, amount}>`. For each settlement:
      - If `settlement.toUserId == uid` → counterparty `settlement.fromUserId` owes the user this amount → add `amount` to `totalOwedToYou`.
      - If `settlement.fromUserId == uid` → the user owes `settlement.toUserId` this amount → add a `DebtRow(counterpartyUid: settlement.toUserId, event, amount, currency: event.currency)`; add `amount` to `totalYouOwe`.
    - Concatenate every event's expenses into one list; sort by `createdAt` desc; take the top 20 → `recentExpenses`.
    - Debt rows sorted by `amount` desc (largest debt first).
    - Loading / error propagation same as `myAssignedTasksProvider`.
18. `totalOwedToYou` / `totalYouOwe` are summed WITHOUT currency conversion in V1. The display layer renders these in the user's default display currency (V1: USD) but does not convert. If events use different currencies the totals will be approximate; the per-row currency chip is the source of truth. Document this loud-and-clear in the spec banner copy ("All amounts shown in your default currency; per-row currency may differ" — `BudgetStrings.multiCurrencyDisclaimer`).

**Functional — `BudgetLedgerScreen`:**

19. New file `lib/app/features/budget/presentation/budget_ledger_screen.dart`. `ConsumerWidget`. Reads `currentUserIdProvider` first; null → sign-in-required empty state, no family invocation.
20. Non-null uid → `globalBalanceLedgerProvider(uid).when(...)`:
    - `loading` → `LoadingAnimation`.
    - `error` → `EmptyStatePlaceholder` with error lottie + log.
    - `data: ledger` → `CustomScrollView` with three sliver sections:
      - `LedgerHeroStrip(owedToYou: ledger.totalOwedToYou, youOwe: ledger.totalYouOwe)` — large bold typography, sage/terracotta amounts.
      - `LedgerDebtSection(debts: ledger.debts, onSettleUp: ...)` — `ListView.builder`, one `DebtTile` per row, plus the "Settle up" section header. When `debts.isEmpty`, replaces with `LedgerAllSettledChip` (sage tinted, "You're all settled up").
      - `LedgerRecentExpensesSection(rows: ledger.recentExpenses)` — `ListView.builder`, one `RecentExpenseTile` per row. Tap → `onOpenEventBudget?(context, row.event) ?? context.push('/dashboard/event/${row.event.id}/budget')`.
    - Empty-ledger overload: when `debts.isEmpty && recentExpenses.isEmpty`, render `EmptyStatePlaceholder` with adaptive copy per event count (matches MyTasksScreen).
21. AppBar title from `context.strings.budget.ledgerAppBarTitle`. Optional `onSettleUp` and `onOpenEventBudget` test seams (matches MyTasksScreen's pattern).

**Functional — Settle Up:**

22. `DebtTile` (`lib/app/features/budget/presentation/widgets/debt_tile.dart`): row with counterparty avatar + display name + event chip + amount in event currency + "Settle Up" `OutlinedButton`. Button key `Key('budget.ledger.settleUp.${counterpartyUid}.${eventId}')`. Tap → `onSettleUp(context, row)`.
23. Production `onSettleUp` (when no test seam provided) calls a new `SettleUpController` (`lib/app/features/budget/application/settle_up_controller.dart`):
    - Reads counterparty's `AppUser` via `userRepositoryProvider.getUser(counterpartyUid)`.
    - Picks the deep link based on counterparty's canonical `paymentMethod`:
      - `venmo` → `PayLinkBuilder.venmo(handle: counterparty.paymentHandle, amount: row.amount, note: "${row.event.title} settle-up")`
      - `cashapp` → `PayLinkBuilder.cashApp(handle: counterparty.paymentHandle, amount: row.amount)`
      - `zelle`, `paypal`, `cash`, OR missing handle → return null (fallback).
    - If deep link is non-null: `urlLauncherProvider.launch(uri)`. If launch returns false (no app installed), fall through to fallback.
    - Fallback path: `SettleUpFallbackSheet.show(context, row, counterparty)` — `showModalBottomSheet` rendering recipient name + amount + Copy buttons + a "Mark paid in event budget" link that calls `context.push('/dashboard/event/${row.event.id}/budget')`.
24. Settle Up does NOT call `ExpenseRepository.recordSettlement` in V1. The user records the settlement themselves inside the event's budget screen (existing flow).

**Functional — i18n:**

25. `lib/app/core/i18n/app_strings.dart` — extend `ChatStrings` + `_EnglishChatStrings` with:
    - `inboxAppBarTitle` → "Chat"
    - `inboxEmptyTitle` → "No messages yet"
    - `inboxEmptySubtitle` → "Open an event from the Dashboard to start chatting."
    - `inboxEmptyNoEventsSubtitle` → "Create or join an event to chat with your crew."
    - `inboxErrorTitle` → "Could not load your inbox"
    - `inboxUrgentBadgeLabel` → "Urgent"
    - `inboxLastMessagePrefix(String senderName, String text)` → "$senderName: $text" (templated; sender's own messages: "You: $text")
    - Keep the existing `tabEmptyTitle` / `tabEmptySubtitle` fields — they're still consumed by the old placeholder until the route is rewired, then can be removed in the same PR.
26. Extend `BudgetStrings` + `_EnglishBudgetStrings` with:
    - `ledgerAppBarTitle` → "Budget"
    - `ledgerHeroOwedToYouLabel` → "You are owed"
    - `ledgerHeroYouOweLabel` → "You owe"
    - `ledgerDebtsHeader` → "Settle up"
    - `ledgerSettleUpCta` → "Settle Up"
    - `ledgerAllSettledMessage` → "You're all settled up."
    - `ledgerRecentExpensesHeader` → "Recent expenses"
    - `ledgerEmptyTitle` → "No balances yet"
    - `ledgerEmptyNoEventsSubtitle` → "Create an event from the Dashboard to start tracking expenses."
    - `ledgerEmptySubtitle` → "Open an event from the Dashboard to log an expense."
    - `ledgerErrorTitle` → "Could not load your ledger"
    - `multiCurrencyDisclaimer` → "Totals are approximate when events use different currencies."
    - `settleUpFallbackTitle(String recipientName)` → "Pay $recipientName"
    - `settleUpFallbackCopyAmount` → "Copy amount"
    - `settleUpFallbackMarkPaid` → "Mark paid in event budget"
27. Both tab placeholder screens (`ChatTabPlaceholderScreen`, `BudgetTabPlaceholderScreen`) are DELETED in this PR. Their tests are deleted with them. The router rewires `/chat` → `ChatInboxScreen()` and `/budget` → `BudgetLedgerScreen()`.

**Error Handling:**

28. `globalInboxProvider` / `globalBalanceLedgerProvider` errors → consumer screens render error empty state per req 4 / 20, logged via `developer.log`.
29. `markEventRead` Firestore write failure → swallow + warn-log via `developer.log(name: 'chat.reads', level: 900)`. No user-facing error UI. Row stays bold until next attempt succeeds.
30. `urlLauncherProvider.launch` returns false → open `SettleUpFallbackSheet` (req 23). The fallback also opens immediately when `paymentMethod` is `zelle`/`paypal`/`cash` (no V1 deep link helper).
31. `userRepositoryProvider.getUser(counterpartyUid)` throws → show a snackbar "Could not load contact info" and fall back to `SettleUpFallbackSheet` with a "Mark paid in event budget" link only (no Copy buttons since we have no handle).

**Edge Cases:**

32. Event with one message that's from the current user → row renders with `unreadCount: 0` (own messages never count as unread).
33. Event with messages BUT `chatReads/{eventId}` doc absent (not yet backfilled) AND messages all sent BEFORE the user joined the event — backfill backstops this: every existing event gets `lastReadAt = now()` on first inbox render so the user sees zero unread on launch day.
34. Counterparty avatar URL missing → fall back to a sage circle with the first letter of the display name (matches the V1 event disc fallback).
35. Two debts with the same `(counterpartyUid, eventId)` shouldn't be possible (one BalanceLedger.calculate output per event), but defensively de-dupe via `Set` keyed on the tuple if the algorithm ever returns duplicates.
36. Debt amount rounds to $0.00 after currency-display formatting → omit the row (don't show "Owe Alex $0.00").
37. Recent Expenses tile timestamp older than 30 days → show "MMM d" (e.g., "Mar 4"). Otherwise relative ("2h", "yesterday").
38. User leaves an event between the inbox refresh and the tap → `EventGuard` already renders the friendly fallback if the event is no longer in `dashboardEventsProvider`. No new handling needed.

**Validation:**

39. All new copy routes through `app_strings.dart` (architectural rule from the just-shipped empty-state spec; grep-enforceable: `! grep -r '"[A-Z][a-z]\+ [a-z]'`-style literal-string checks pass).
40. `globalInboxProvider` / `globalBalanceLedgerProvider` MUST NOT import any Firestore / Drift code directly — they compose Riverpod providers only (matches `myAssignedTasksProvider`).
41. `EmptyStatePlaceholder` is the only allowed empty/error state widget on both screens. No ad-hoc Center+Text.
42. Existing per-event chat tests + budget tests pass UNCHANGED. The Drift schema bump adds the new `chat_reads` table without touching existing tables.

</requirements>

<boundaries>

**Edge cases:**

- **`paymentMethod == cash`**: Always uses the fallback sheet (no deep link). The sheet wording is identical to the missing-handle case but with a "Pay in cash" callout.
- **Counterparty's payment handle doesn't match `PayLinkBuilder`'s validator regex**: builder returns `null`; treat as a fallback case. Log the malformed handle once via `developer.log(name: 'budget.settleUp', level: 900)` for debugging.
- **Chat message with empty text (rare; settlement notices can have placeholder text)**: render snippet as `<{senderName} sent a notice>` rather than blank.
- **Very long event title (>30 chars)**: truncate with ellipsis on both inbox row and debt row event chip — never wrap.
- **User has 30+ events** (Risks section flag): both inbox and ledger spawn one per-event subscription per event. Acceptable for V1; document in PR description with a profiling-trigger threshold ("revisit if any user routinely sits above 50 events"). Same trade-off the just-shipped `myAssignedTasksProvider` accepts.

**Error scenarios:**

- **Drift migration failure** (adding `chat_reads`): app re-runs the migration on next launch (Drift behavior). If it keeps failing, the inbox falls back to "everything looks unread" because `watchLastReadByEvent` errors → `globalInboxProvider` propagates the error → user sees the error empty state. The migration logic itself must be idempotent.
- **Firestore listener limit (100 concurrent listeners per client)**: a user with 100+ events would hit Firestore's default cap (events + messages + reads = 3 listeners per event = 33 events before cap). Out of scope; spec'd in PR description.
- **`urlLauncherProvider.launch` throws (not just returns false)**: catch + treat as fallback. Don't crash.

**Limits:**

- **No pagination on `RecentExpenses`** (last 20 fixed). Revisit when real users routinely report missing expenses.
- **No client-side currency conversion** on hero totals (req 18). Multi-currency users see the disclaimer banner.
- **No cross-event chat sending from the inbox** — V1 is a read-only inbox. Tapping a row navigates into the event chat to send.

</boundaries>

<implementation>

**Files to create:**

- `lib/app/features/chat/application/global_inbox_provider.dart` — composes `dashboardEventsProvider` + `chatMessagesProvider` + `eventChatReadStateProvider`. Exports `InboxRow`, `globalInboxProvider`, `eventChatReadStateProvider`.
- `lib/app/features/chat/presentation/chat_inbox_screen.dart` — ConsumerWidget; five-branch consumer pattern + first-load backfill.
- `lib/app/features/chat/presentation/widgets/inbox_tile.dart` — pure presentation row.
- `lib/app/core/database/daos/chat_reads_dao.dart` — Drift DAO for the new `chat_reads` table.
- `lib/app/features/budget/application/global_balance_ledger_provider.dart` — composes `dashboardEventsProvider` + `expenseListProvider` + `BalanceLedger.calculate`.
- `lib/app/features/budget/application/settle_up_controller.dart` — picks deep link vs fallback per counterparty `paymentMethod`.
- `lib/app/features/budget/presentation/budget_ledger_screen.dart` — ConsumerWidget; CustomScrollView with three sections.
- `lib/app/features/budget/presentation/widgets/ledger_hero_strip.dart` — sage owed / terracotta owe.
- `lib/app/features/budget/presentation/widgets/debt_tile.dart` — counterparty row + Settle Up button.
- `lib/app/features/budget/presentation/widgets/recent_expense_tile.dart` — chronological expense row.
- `lib/app/features/budget/presentation/widgets/settle_up_fallback_sheet.dart` — modal bottom sheet with copy buttons + manual-pay link.
- `test/app/features/chat/application/global_inbox_provider_test.dart` — composition tests (Riverpod overrides; mirror `myAssignedTasksProvider_test`).
- `test/app/features/chat/presentation/chat_inbox_screen_test.dart` — five-branch widget tests.
- `test/app/features/chat/data/chat_repository_reads_test.dart` — `markEventRead` + `backfillReadStateForExistingEvents` behavior via `FakeFirebaseFirestore`.
- `test/app/features/budget/application/global_balance_ledger_provider_test.dart` — composition + balance correctness.
- `test/app/features/budget/application/settle_up_controller_test.dart` — deep-link selection per `paymentMethod`; fallback path; launch-failure path.
- `test/app/features/budget/presentation/budget_ledger_screen_test.dart` — five-branch widget tests.
- `test/journeys/budget_settle_up_journey_test.dart` — robot-driven: pump ledger with one debt → tap Settle Up → fake url launcher captures the Venmo URI; or no handle → fallback sheet opens.
- `test/journeys/chat_inbox_open_event_journey_test.dart` — robot-driven: pump inbox with 2 events (one unread, one urgent) → assert highlight + badge → tap → captured navigation seam fires.

**Files to modify:**

- `lib/app/core/database/app_database.dart` — add `ChatReads` table; bump `schemaVersion`; add migration step.
- `lib/app/core/providers.dart` — new `chatReadsDaoProvider`; thread it into `chatRepositoryProvider`. New top-level `globalInboxProvider` re-export if needed (otherwise keep in feature folder).
- `lib/app/features/chat/data/chat_repository.dart` — new constructor param, `watchLastRead`, `markEventRead`, `backfillReadStateForExistingEvents` methods.
- `lib/app/features/chat/presentation/event_chat_page.dart` — call `markEventRead` in `initState`.
- `lib/app/core/router/app_router.dart` — replace `ChatTabPlaceholderScreen` → `ChatInboxScreen`; replace `BudgetTabPlaceholderScreen` → `BudgetLedgerScreen`.
- `lib/app/core/i18n/app_strings.dart` — extend `ChatStrings` + `BudgetStrings` per req 25 / 26.
- `firestore.rules` (if managed in-repo) — add rule for `/users/{uid}/chatReads/{eventId}` (owner-only read+write).

**Files to delete:**

- `lib/app/features/chat/presentation/chat_tab_placeholder_screen.dart` + `test/app/features/chat/chat_tab_placeholder_screen_test.dart`
- `lib/app/features/budget/presentation/budget_tab_placeholder_screen.dart` + `test/app/features/budget/budget_tab_placeholder_screen_test.dart`

**Patterns to use:**

- Both new screens mirror `MyTasksScreen`: five-branch consumer, `onOpenX` test seams, AppBar title from i18n, `EmptyStatePlaceholder` for all loading/error/empty states.
- Both new providers mirror `myAssignedTasksProvider`: `Provider.family<AsyncValue<...>, String>` composing two layers of Riverpod streams; manual `AsyncValue` fold (return `AsyncLoading` / `AsyncError` short-circuits; flatten on data).
- DAO/repo pattern: `ChatReadsDao` follows the existing DAO shape (`lib/app/core/database/daos/tasks_dao.dart` is a good template); `ChatRepository` extensions mirror `TaskRepository.disposeMirror` for cleanup.
- Deep-link launching: existing `urlLauncherProvider` seam is the only allowed path. Tests inject a recording fake (see how `PayLinkBuilder` is tested today for the URL shape — extend with launch-side coverage).
- Settle Up fallback: `showModalBottomSheet` + `Clipboard.setData` for copy actions. No custom packages.

**What to avoid:**

- No new pub packages. Lottie + url_launcher + firestore are all already in `pubspec.yaml`.
- Do NOT introduce a `collectionGroup` query for chats or expenses. Acceptable trade-off, deferred.
- Do NOT call `ExpenseRepository.recordSettlement` from Settle Up — V1 is deep-link-only (req 24).
- Do NOT migrate the per-event `chat_screen.dart` / `budget_screen.dart` to read from these new providers. They stay event-scoped.
- Do NOT centralize the inbox / ledger via Cloud Functions in V1.
- No mute support — out of scope; the urgent highlight is the entire urgency surface.
- No `pumpAndSettle` in any test that renders `EmptyStatePlaceholder` (lottie loops; spec validation block from the prior empty-state PR).

</implementation>

<validation>

**Required automated coverage outcomes** (each item must be a passing test before merge):

- **Unit tests — pure logic / state:**
  - `globalInboxProvider` composition: override `dashboardEventsProvider` to emit two active + one archived event; override `chatMessagesProvider(...)` per event; assert archived is excluded, rows are sorted by last-message timestamp desc, `unreadCount` correctly subtracts own-sent messages, `hasUrgentUnread` flips iff at least one unread has `isHighPriority`.
  - `globalInboxProvider` loading propagation: any input `AsyncLoading` → provider returns `AsyncLoading`.
  - `globalInboxProvider` error propagation: any input `AsyncError` → provider returns `AsyncError`.
  - `globalInboxProvider` empty events list → `AsyncData([])`, no inner family providers subscribed.
  - `globalBalanceLedgerProvider` composition: two events with mixed splits; assert `totalOwedToYou` / `totalYouOwe` / `debts` sorted by amount desc / `recentExpenses` capped at 20 sorted by `createdAt` desc.
  - `globalBalanceLedgerProvider` includes archived events (req 17 — debts survive trip closure).
  - `globalBalanceLedgerProvider` loading + error propagation mirror the inbox test pairs.
  - `ChatRepository.markEventRead`: success path writes `chatReads/{eventId}` Firestore doc AND upserts Drift. Firestore-write failure path swallows + logs.
  - `ChatRepository.backfillReadStateForExistingEvents`: idempotent (calling twice writes once); skips events that already have a read doc.
  - `ChatRepository.watchLastRead`: Drift-cached emission first, then Firestore stream emission overrides.
  - `SettleUpController`:
    - `paymentMethod == venmo` → returns `PayLinkBuilder.venmo(...)` URI.
    - `paymentMethod == cashapp` → returns `PayLinkBuilder.cashApp(...)` URI.
    - `paymentMethod == zelle | paypal | cash` → returns null (signals fallback).
    - Missing `paymentHandle` → returns null.
    - Malformed handle (regex fails) → returns null + warn-log.
    - `urlLauncherProvider.launch` returns false → controller surfaces a "fallback needed" signal.

- **Widget tests — `ChatInboxScreen`:**
  - Loading branch: when `globalInboxProvider` overridden to `AsyncLoading`, screen renders `LoadingAnimation`; no list, no empty state.
  - Empty-no-events branch: `dashboardEventsProvider` data is `[]` → `EmptyStatePlaceholder` with `inboxEmptyNoEventsSubtitle` + `createFromDashboardCta`.
  - Empty-with-events branch: events present but every event's messages list is empty → empty state with `inboxEmptySubtitle` + `openDashboardCta`.
  - Null-uid branch: `currentUserIdProvider` overridden to null → `signInRequiredTitle` rendered; `globalInboxProvider` NEVER subscribed (override counter).
  - Non-empty branch: 3 rows across 3 events, one urgent → assert `Key('chat.inbox.tile.{eventId}')` exists for each, urgent row has terracotta badge + bell icon, regular row has sage badge; unread count text rendered.
  - First-load backfill side effect: when uid + events emit for the first time, `chatRepository.backfillReadStateForExistingEvents(uid, events)` is called exactly once (assert via spy / fake repo).

- **Widget tests — `BudgetLedgerScreen`:**
  - Five branches mirror the inbox tests (loading / null-uid / empty-no-events / empty-with-events-no-expenses / non-empty).
  - All-settled state: ledger has expenses but every settlement net to zero → `LedgerAllSettledChip` renders instead of debts list; recent expenses still show.
  - Debt tile: tapping the Settle Up button fires the captured `onSettleUp` seam exactly once.
  - Hero strip renders sage amount for owed-to-you and terracotta for you-owe; both formatted in default display currency.
  - Multi-currency disclaimer renders iff any event currency differs from the user's default.

- **Widget tests — `InboxTile`:**
  - Bold title when `unreadCount > 0`, normal weight otherwise.
  - Bell icon visible iff `hasUrgentUnread == true`.
  - Badge text "99+" when `unreadCount > 99`.
  - Sender prefix "You: …" when last message's `senderId == currentUid`.

- **Widget tests — `SettleUpFallbackSheet`:**
  - Renders recipient name + amount + Copy buttons.
  - Tapping Copy Amount calls `Clipboard.setData`.
  - "Mark paid in event budget" link fires the captured navigation seam.

- **Robot journey tests:**
  - `test/journeys/chat_inbox_open_event_journey_test.dart`: pump `ChatInboxScreen` (screen-level scope, not full StatefulShellRoute — deferred per the prior empty-state plan) with 2 seeded events (one unread + urgent, one read); assert urgent row visible with bell icon; tap the urgent row; captured `onOpenChat` callback fires with the correct event id.
  - `test/journeys/budget_settle_up_journey_test.dart`: pump `BudgetLedgerScreen` with one debt where counterparty has `paymentMethod: venmo` + `paymentHandle: alex_v`; override `urlLauncherProvider` with a recording fake; tap Settle Up; assert the launched URI matches `PayLinkBuilder.venmo(handle: 'alex_v', amount: 45.00, note: 'Tahoe Ski Trip settle-up')`. Second scenario: counterparty has no handle; assert `SettleUpFallbackSheet` appears.

**TDD expectations** (per `flutter-tdd`):

- Build slices in order:
  1. Drift schema + `ChatReadsDao` (one test at a time: schema migration; upsert; watch).
  2. `ChatRepository` reads/backfill methods (one behavior per cycle).
  3. `globalInboxProvider` composition (composition → archived filter → unread count → urgent flag → loading → error → empty — one test per cycle).
  4. `globalBalanceLedgerProvider` composition (totals → debts ordering → archived inclusion → recent expenses cap → loading → error).
  5. `SettleUpController` (one paymentMethod per cycle).
  6. `InboxTile` + `DebtTile` widget tests.
  7. `ChatInboxScreen` + `BudgetLedgerScreen` widget tests (one branch per cycle).
  8. `SettleUpFallbackSheet`.
  9. Robot journeys last.

- Required seams:
  - `urlLauncherProvider` — Riverpod override with recording fake.
  - `userRepositoryProvider` — Riverpod override with seeded user map.
  - `firestoreProvider` — `FakeFirebaseFirestore` (already in dev deps).
  - `databaseProvider` — `AppDatabase` over `NativeDatabase.memory()` (already used elsewhere).
  - `dashboardEventsProvider` + `chatMessagesProvider` + `expenseListProvider` — Riverpod stream overrides (existing pattern from `my_assigned_tasks_provider_test.dart`).
  - Screen-level `onOpenChat` / `onOpenDashboard` / `onSettleUp` / `onOpenEventBudget` callbacks — production-default to `context.push`/`context.go`; tests inject capturing closures.

- Mocking policy: prefer Riverpod overrides + fakes (`FakeFirebaseFirestore`, in-memory Drift). Mock only at the `urlLauncherProvider` boundary. No mocks of internal classes.

- Justified exceptions: lottie playback / `clipboard_unstable` platform plugin behavior is NOT exercised in widget tests; trust the dependency. The dispatch into the OS payment app is captured at the `urlLauncherProvider.launch(...)` boundary — actual app launch is platform-tested manually.

**Robot testing baseline** (per `flutter-robot-testing`):

- Stable selectors required:
  - `Key('chat.inbox.tile.{eventId}')` per inbox row.
  - `Key('chat.inbox.tile.{eventId}.badge')` per badge.
  - `Key('chat.inbox.tile.{eventId}.urgent')` on the urgent bell icon (presence == urgent state).
  - `Key('budget.ledger.hero.owedToYou')` + `Key('budget.ledger.hero.youOwe')` on the hero amounts.
  - `Key('budget.ledger.debt.${counterpartyUid}.${eventId}')` per debt row.
  - `Key('budget.ledger.settleUp.${counterpartyUid}.${eventId}')` per Settle Up button.
  - `Key('budget.ledger.recentExpense.${expenseId}')` per recent expense row.
  - `Key('budget.settleUp.fallback.sheet')` on the fallback bottom sheet.
  - `Key('budget.settleUp.fallback.copyAmount')` on the Copy Amount button.

- Robot helpers (new `test/robots/chat_inbox_robot.dart` and `test/robots/budget_ledger_robot.dart`):
  - `ChatInboxRobot.tapRowFor(String eventId)`, `expectUrgent(String eventId)`, `expectUnreadCount(String eventId, int count)`, `expectEmptyState()`.
  - `BudgetLedgerRobot.tapSettleUp(String counterpartyUid, String eventId)`, `expectFallbackSheet()`, `expectHeroAmounts({required String owed, required String youOwe})`.

- Deterministic seams:
  - Override `dashboardEventsProvider` to a fixed-size list (0, 1, or N events).
  - Override `chatMessagesProvider` family per event with `Stream.value(...)`.
  - Override `expenseListProvider` family per event with `Stream.value(...)`.
  - Override `urlLauncherProvider` with a recording fake that records `Uri` arguments.
  - Override `userRepositoryProvider` to return seeded `AppUser` objects keyed by uid.

- Known testing risks:
  - Lottie loading is async — pump 3 × 50 ms frames; NEVER `pumpAndSettle` against any screen that renders `EmptyStatePlaceholder`.
  - Drift in-memory schema migration: new `chat_reads` table tested against a freshly-opened `NativeDatabase.memory()` per test (no migration step needed) AND against a seeded v(N-1) DB to verify the migration step runs. Reference `test/database/migration_v5_to_v6_test.dart` for the pattern.

**Manual smoke** (before declaring done):

- Cold-launch the app on a fresh user → land on Auth → sign up → land on Dashboard → tap Chat tab → see branded empty state with "Open Dashboard" CTA → tap CTA → ends back on Dashboard.
- Same with one event + no messages → Chat tab shows event-empty copy.
- Send a message in an event → return to Chat tab → see the row populated, no unread badge (since you sent it).
- Have another member send a message → Chat tab shows unread badge; mark `isHighPriority` on the message → see terracotta highlight + bell. Tap row → enter chat → return → badge cleared.
- Budget tab: cold-launch with no events → empty state with "Create" CTA. Add an event with an expense where you owe Alex $45 → return to Budget tab → see hero "You owe $45" in terracotta. Tap Settle Up where Alex has `paymentMethod: venmo + paymentHandle: alex_v` → Venmo app opens with $45 + note pre-filled.
- Same flow with `paymentMethod: zelle` → fallback sheet appears.
- Archive the event → ledger still shows the debt; chat inbox stops showing the row.

</validation>

<done_when>

- `globalInboxProvider` implemented per requirements 1–3 with composition / archive-filter / unread / urgent / loading / error / empty tests passing.
- `globalBalanceLedgerProvider` implemented per requirements 16–18 with composition / debts / recent-expenses / archived-included / loading / error tests passing.
- `ChatInboxScreen` ships per requirements 4–6 with all five-branch widget tests + first-load backfill test passing.
- `BudgetLedgerScreen` ships per requirements 19–21 with five-branch widget tests + all-settled / multi-currency-disclaimer cases passing.
- `InboxTile`, `DebtTile`, `RecentExpenseTile`, `LedgerHeroStrip`, `LedgerAllSettledChip`, `SettleUpFallbackSheet` widgets implemented per the spec, each with its own widget tests.
- `ChatRepository` extended with `watchLastRead`, `markEventRead`, `backfillReadStateForExistingEvents`. `EventChatPage.initState` calls `markEventRead`. `ChatReadsDao` + new `chat_reads` Drift table + schema migration shipped + tested.
- `SettleUpController` ships per requirement 23 with deep-link selection tests for each `paymentMethod` + fallback path tests.
- `ChatStrings` / `BudgetStrings` extended per requirements 25–26; no hardcoded literals in any modified or new file (architectural rule; grep-enforced).
- Router rewired: `/chat` → `ChatInboxScreen`, `/budget` → `BudgetLedgerScreen`. Both old placeholder screens + their tests deleted.
- Robot journey tests (`chat_inbox_open_event_journey_test.dart`, `budget_settle_up_journey_test.dart`) pass.
- `flutter analyze` clean (only the pre-existing `TableMigration` experimental warning is allowed; the `chat_reads` migration step is permitted to reuse that API).
- `flutter test` green; existing per-event Chat and Budget tests pass unchanged.
- Firestore security rule for `users/{uid}/chatReads/{eventId}` updated (in-repo or noted in PR description for manual deploy).
- Branch name suggestion: `chat-budget-tabs`. Off latest `main` after the just-shipped `tasks-tab-empty-state` PR merges (or stacked off `tasks-tab-empty-state` if that hasn't merged yet — pick whichever is current).

</done_when>
