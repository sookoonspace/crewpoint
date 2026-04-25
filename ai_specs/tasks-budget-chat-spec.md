<goal>
Ship V1 of three event-collaboration features that turn a CrewPoint event into a working hub for project tasks, trip expenses, and crew chat:

1. **Tasks** — list view with status toggle, assignee, due date, and persisted checklists. Anyone in the event can create a task; only the event owner, admins, or the assignee may change `status`.
2. **Budget & Settlements** — persisted expense splits, per-event currency, receipt uploads, the existing `BalanceLedger` math wired end-to-end, and a zero-cost Venmo/CashApp deep-link settlement flow with a payee-dispute path (no payment-gateway compliance burden).
3. **Chat polish** — fix the existing live chat (hardcoded `eventId`, missing sender hydration), mirror messages into Drift for instant loads, and add FCM push notifications for the existing Urgent toggle so terracotta alerts reach members whose app is closed.

This spec is for the CrewPoint event app (`crewpoint_app`, Flutter + Riverpod + Firebase + Drift). Substantial scaffolding already exists for all three features; this is V1 wiring, gap-filling, and the new server-side pieces.
</goal>

<background>
**Tech stack & conventions** — established in earlier phases:

- Flutter 3.11.5 / Dart 3.x; Riverpod 3 (`riverpod_annotation` codegen); `go_router` 14
- Firebase: `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`. **Add**: `firebase_messaging` for FCM push.
- Drift 2.25 (offline cache); `image_picker` 1.1 already in `pubspec.yaml`
- Cloud Functions: TypeScript, Firebase Functions v2 (onCall + Firestore triggers); see `functions/src/events/removeEventMember.ts` and `functions/src/events/promoteToAdmin.ts` as canonical patterns
- Layering per feature: `data/` (repositories, services), `domain/` (models, repository interfaces), `application/` (Riverpod providers/notifiers), `presentation/` (screens, widgets)
- Brand colors: `AppColors.terracotta` `#CC704B` (urgent / destructive), `AppColors.sage`, `AppColors.cream` background; existing terracotta urgent bubble is already correct

**Files to examine before implementing:**

- @lib/app/features/dashboard/data/event_repository.dart — canonical repository pattern (Firestore stream → Drift mirror)
- @lib/app/features/dashboard/domain/models/event.dart — model + role helpers (`isOwner`, `isAdmin`, `isMember`)
- @lib/app/features/tasks/ — full feature scaffold; models + Drift table + repository complete; screens stubbed; sync stubbed
- @lib/app/features/budget/ — `BalanceLedger` math is **already implemented and correct** (greedy net-balance settlement); splits don't persist; no Firestore wiring; no settle UI
- @lib/app/features/chat/ — Firestore live stream + UI exist; `FirestoreChatService._fromFirestore` has `eventId: ''` bug; no Drift cache; no push
- @functions/src/events/promoteToAdmin.ts and @functions/src/events/removeEventMember.ts — onCall RBAC patterns
- @firestore.rules — current RBAC: events, messages, expenses subcollections defined; tasks subcollection **missing**
- @lib/app/core/database/database.dart — Drift schema v3; will bump to v4
- @lib/app/core/services/sync_engine.dart — stub; we will replace task/expense sync with stream-listener mirrors and remove the unused last-write-wins TODOs from V1 scope
- @lib/app/core/constants/app_colors.dart — terracotta + sage palette
- @docs/cloud-functions-guide.md — registry table to update for new functions

**Out of scope** (deferred to `ai_specs/todo.md`): Kanban board, message reactions/edit/search, E2EE chat, multi-currency display, real settlement reconciliation with bank APIs, web platform, due-date reminders/notifications, task attachments file storage, full last-write-wins offline-first sync engine.
</background>

<user_flows>

## Tasks

**Primary — create and progress a task (assignee or admin):**
1. From event dashboard, open Tasks tab → `TaskListScreen`
2. Tap "+" FAB → `CreateTaskScreen` (title required, assignee picker required, due date optional, checklist optional)
3. Save → returns to list; new task appears at top of "To Do" group
4. Assignee taps tile → status cycles `todo → inProgress → done`; `done` styling mutes the tile
5. Tapping tile body opens `TaskDetailScreen` → can edit fields, tick checklist items, delete (creator/admin only)

**Alternative — non-assignee non-admin:**
- Sees the status indicator as read-only; tapping shows snackbar "Only the assignee or an admin can change this"
- Can still open detail, view checklist, but edit/delete actions are hidden

**Error:**
- Network failure on create → keep the form open, show error snackbar, do not navigate back
- Status update rejected by Firestore rule → revert optimistic change, show snackbar with the rule-failure message

## Budget & Settlements

**Primary — create expense and settle (payer chooses Venmo):**
1. Budget tab shows totals + per-member balance + "Suggested settlements" from `BalanceLedger`
2. Tap "+" → `ExpenseModal` (description, amount, payer = me by default, splits = equal across members; custom split UI as already-stubbed `ExpenseModal`)
3. Save → expense persists; balances re-compute in real time
4. Tap a "Settle $X with Alex" row → `SettleSheet` opens with two pay buttons: Venmo, CashApp (only those with handles set are enabled)
5. Tap Venmo → `url_launcher` opens `venmo://paycharge?txn=pay&recipients={handle}&amount={amount}&note={eventName}` (App Store fallback if not installed)
6. App returns from background → modal: "Did you send $X to Alex?" with [Yes, recorded] [Not yet]
7. On Yes → writes `isPayment: true` expense (negative on payer's net, positive on payee's net) → ledger zeroes out; pinned settlement notice posted to chat: "Bo settled $25 with Alex via Venmo. Tap to dispute."

**Alternative — payee has no handles:**
- Tapping "Settle" opens `SettleSheet` with both pay buttons disabled and "Copy payment details" button instead → copies "$X to {name} for {event}" → user pays out-of-band → returns and taps "I sent it" → same confirm-and-record flow

**Alternative — payer adds receipt:**
- In `ExpenseModal`, tap receipt icon → `image_picker` → image uploads to `events/{eid}/receipts/{expenseId}.jpg` → thumbnail shown in `ExpenseTile`; full-screen viewer in expense detail

**Dispute (payee):**
- Tap pinned settlement notice in chat → bottom sheet "Did Bo actually pay you $25?" [Yes, all good] [No, dispute]
- On Dispute → settlement expense deleted (only payer or payee allowed); chat notice replaced with "Alex disputed this settlement."

**Error:**
- Deep-link app not installed → on iOS, the universal link falls back to `https://venmo.com/{handle}?txn=pay&...`; on Android, App Store/Play Store sheet is offered
- Receipt upload fails → expense saves without receipt; "Add receipt" CTA remains in detail view
- Confirm dialog dismissed by accident → no settlement recorded; the "Settle" button stays available

## Chat

**Primary — send normal/urgent and receive push:**
1. Chat tab → composer at bottom → type → "Send" (sage)
2. Toggle the alert button (terracotta) → composer flips to urgent state → send → message renders with terracotta bubble + "URGENT" label for everyone
3. Other members offline / app backgrounded → receive FCM push: "🚨 Urgent in {EventName}: {first 80 chars}…" → tap → deep-link to `/event/:id/chat`

**Alternative — first open with cache:**
- Existing members open chat → Drift cache renders last 200 messages instantly → live Firestore stream replaces with authoritative ordering once connected

**Error:**
- Send fails (network) → message stays composed in input field with red error border; "Retry" snackbar
- Push permission denied (iOS) → onboarding-time prompt; if denied, Urgent still works in-app but no push (no error to user)
- Sender display name unknown (member just left) → falls back to "Unknown member" + truncated UID

</user_flows>

<requirements>

## Cross-cutting

**Functional:**
1. Bump Drift schema to v4 with migrations for: `events.currency` (TEXT, default `'USD'`), new `expense_splits` table, new `task_checklist_items` table, `users.venmoHandle` and `users.cashappHandle` (TEXT, nullable), and any new columns needed for chat cache (e.g., `chat_messages.serverTimestamp` if not already present).
2. Add `firebase_messaging` to `pubspec.yaml`; initialize FCM token registration on auth (write to `users/{uid}.fcmTokens` array via `arrayUnion`); clear on sign-out.
3. Create `ai_specs/todo.md` listing deferred items (see `<implementation>` § Backlog file).
4. Update `docs/cloud-functions-guide.md` Function Registry with each new function added in this spec.

**Validation:**
5. `flutter analyze` clean; existing `flutter test` suite passes; new tests added for each feature slice.
6. Existing event/promote/demote flows are untouched and still pass.

## Tasks

**Functional:**
7. `TaskListScreen` reads from a Firestore-stream-backed `taskListProvider` keyed by `eventId`; mirror writes into Drift for offline reads; UI renders Drift first, then live data when available.
8. `CreateTaskScreen` form fields: title (required, ≤120 chars), assignee (member picker, required), dueDate (optional date picker), checklist (optional list of strings, ≤25 items, each ≤120 chars). Calls `TaskRepository.createTask` which writes the Firestore doc; rule layer permits any event member to create.
9. `TaskDetailScreen` displays title, description (V1: same as title — keep description optional), assignee, dueDate, checklist (toggleable items), status, createdBy, createdAt, completedAt/By if present. Editable by creator/admin/owner. Deletable by creator/admin/owner.
10. Status changes route through Cloud Function `markTaskComplete` (when transitioning to `done`); other transitions (`todo↔inProgress`, `done→inProgress`) write directly to Firestore and rely on rules. Function stamps `completedAt: serverTimestamp()`, `completedBy: auth.uid`.
11. Firestore rules for `events/{eid}/tasks/{tid}`:
    - **Read**: any event member
    - **Create**: any event member; required fields validated; `createdBy == request.auth.uid`
    - **Update (status)**: only owner/admin/assignee
    - **Update (other fields)**: only creator/owner/admin
    - **Delete**: only creator/owner/admin
12. Checklist items persist as Firestore subcollection `events/{eid}/tasks/{tid}/checklist/{itemId}` (so toggles don't fight a single array doc); mirror to Drift `task_checklist_items`.

**Error Handling:**
13. Permission-denied write → revert optimistic UI; show snackbar "Only the assignee or an admin can change this" (status) or "Only the creator or an admin can edit this task" (other fields).
14. Firestore offline write → Firestore SDK queues automatically; UI shows "Will sync when online" indicator using `SnapshotMetadata.hasPendingWrites`.

**Edge Cases:**
15. Assignee is removed from the event → existing tasks keep the assigneeId but UI shows "(no longer in event)"; reassign action available to admin/creator.
16. Two members complete simultaneously → last-write-wins on `status`; `completedBy` reflects the last writer.

**Validation:**
17. Unit: `TaskRepository`/`TaskListNotifier` create + status transitions with a fake Firestore + fake DAO.
18. Widget: `TaskListScreen` empty state, status filter, read-only state for non-authorized users.
19. Robot journey: create-task → assign → complete (happy path).
20. Cloud Function: emulator integration test for `markTaskComplete` rejects non-owner/admin/assignee callers.
21. Firestore rules: emulator tests covering each access matrix entry above (member can read; non-member cannot; non-assignee non-admin cannot mutate `status`; etc.).

## Budget & Settlements

**Functional:**
22. Add `currency` field (3-letter ISO code, default `'USD'`) to `EventModel` + `Events` Drift table + Firestore `events/{eid}` doc; set in `CreateEventScreen` (default to user's profile currency or `'USD'`); immutable after creation.
23. Persist expense splits: new Drift table `expense_splits(expenseId, userId, amount)` with FK to `expenses(id)`; Firestore stores splits as an array on the expense doc. Fix `ExpenseRepository._toDomain()` to populate `splits` from Drift instead of returning `[]`.
24. `BalanceLedger.calculate(...)` is already implemented and correct; do **not** modify the algorithm. Wire it into `BudgetScreen` so it consumes the live stream of expenses for the event.
25. Receipt upload: in `ExpenseModal`, image picker → upload to `events/{eid}/receipts/{expenseId}.jpg` (Storage rule: only event members can read; only expense `payerId` can write own receipt); persist `receiptPath` on expense.
26. Add `venmoHandle?` and `cashappHandle?` (each ≤30 chars, validated `^[A-Za-z0-9_-]+$`) to `UserModel` + `Users` Drift table + Firestore `users/{uid}` doc + Profile editor with inline validation.
27. `SettleSheet` opens from a "Settle" affordance on each suggested settlement row; shows two payment buttons; disables the ones the payee has not configured; falls back to "Copy payment details" if neither is set.
28. Deep links built by a pure `PayLinkBuilder` utility:
    - Venmo: `venmo://paycharge?txn=pay&recipients={handle}&amount={amount}&note={uri-encoded note}` with web fallback `https://venmo.com/{handle}?txn=pay&amount={amount}&note=...`
    - CashApp: `https://cash.app/${handle}/${amount}` (CashApp uses universal links cleanly)
    - Note format: `"{eventName} settle"` truncated to 60 chars
29. After deep link launches, `WidgetsBindingObserver.didChangeAppLifecycleState` detects return-from-background; if a settlement is pending, show the "Did you send $X?" confirm dialog. On confirm, write expense doc with `isPayment: true`, `payerId: me`, `splits: [{userId: payee, amount: -amount}]` (consistent with existing `BalanceLedger` payment handling).
30. On settle confirm, post a "settlement notice" message to chat with `kind: 'settlement'` metadata, `text: "Bo settled $25 with Alex via Venmo"`, `isHighPriority: false`. Pinned in UI by treating `kind == 'settlement'` specially in `MessageBubble`.
31. Dispute path: tapping a settlement notice opens a sheet → "Dispute" calls `disputeSettlement` Cloud Function (verifies caller is the payee or payer; deletes settlement expense; replaces chat notice text with "Alex disputed this settlement").

**Error Handling:**
32. Receipt upload failure → expense still saves; Detail view shows "Receipt failed to upload — Retry".
33. Deep-link launch returns `false` (no handler) → fall back to web URL via `url_launcher`'s `LaunchMode.externalApplication`; if that also fails, show "Couldn't open Venmo. Copy payment details instead?"
34. User dismisses confirm dialog without confirming → settlement is **not** recorded; "Settle" button remains active.
35. App is killed while pending confirm → on next launch, drop the pending state silently (do not auto-record).

**Edge Cases:**
36. Settlement amount > outstanding balance → still allowed (overpayment); `BalanceLedger` already supports negative net.
37. Settling between two people who are not the current user → disabled in V1 (the settle CTA only appears on rows involving the current user).
38. Currency mismatch between event currency and user's display preference → V1 always shows the event currency symbol; user-currency conversion is in `todo.md`.
39. Member removed mid-flow → existing expenses keep the removed user's UID; balance ledger continues to show their net so it can be settled out.

**Validation:**
40. Unit: `PayLinkBuilder.venmo(...)` / `.cashApp(...)` produce expected URIs for valid handles; throw on invalid handles.
41. Unit: `ExpenseRepository._toDomain` correctly hydrates splits from Drift (regression for the existing `[]` bug).
42. Unit: `BalanceLedger` smoke test (do not rewrite — it is already covered).
43. Widget: `SettleSheet` disables Venmo button when `venmoHandle == null`; shows copy-details fallback when both handles missing.
44. Widget: `ExpenseModal` validates amount > 0, splits sum equals total within 1 cent.
45. Robot journey: create expense → see updated ledger → settle via deep link → confirm → ledger zero (use a fake `UrlLauncher` test seam).
46. Cloud Function: emulator integration test for `disputeSettlement` (only payee/payer can call; expense is deleted; chat notice updated).
47. Firestore rules: emulator tests for new `users` handle fields (only owner can write own); `events/{eid}/expenses` create still gated to `payerId == auth.uid`; storage rule for receipts.

## Chat

**Functional:**
48. Fix `FirestoreChatService._fromFirestore` to receive and populate `eventId` from caller context.
49. Hydrate sender display name via a `usersByIdProvider(eventId)` that subscribes to `users/{uid}` docs for current event members; cache in Drift for offline.
50. Drift mirror: chat stream listener writes the most recent 200 messages per event into `ChatMessages`. `ChatRepository.watchMessages(eventId)` returns a merge stream — Drift first, Firestore overlays. On open, if Drift has cached rows, render immediately.
51. Composer: disable Send while in-flight; auto-scroll list to bottom on outgoing send and on inbound message when already at bottom; do **not** auto-scroll if user has scrolled up.
52. Empty state: "No messages yet — be the first to say something."
53. Cloud Function `onUrgentMessageCreated` (Firestore trigger on `events/{eid}/messages/{mid}` create): if `isHighPriority == true`, build FCM multicast to all `event.memberIds` except `senderId`; payload includes `data.eventId`, `data.deepLink: /event/{eid}/chat`; notification title `"🚨 Urgent in {eventName}"`, body = first 80 chars of message text.
54. Initialize `firebase_messaging` in app bootstrap: request permissions on first sign-in (iOS); register/refresh token to `users/{uid}.fcmTokens` (arrayUnion); deregister on sign-out.
55. Foreground push handler: if user is already on the chat screen for that event, swallow the push (no banner). Otherwise show in-app material banner with "View" action.
56. Tap-on-push deep link: route via `go_router` to `/event/{eventId}/chat`.

**Error Handling:**
57. Send fails → keep text in composer; show retry snackbar; do not write a partial document.
58. FCM token write fails → log to Crashlytics, do not block sign-in.
59. iOS push permission denied → silent; in-app urgent styling still applies.

**Edge Cases:**
60. Sender removed from event after sending → message stays; sender name resolves to "Unknown member".
61. Cache > 200 messages → cap Drift rows by deleting oldest beyond cap on each new mirror write.
62. Settlement notice messages (`kind: 'settlement'`) follow the same RBAC as normal messages but render with a distinct outlined style and a tap-to-dispute hit area.

**Validation:**
63. Unit: `ChatRepository` merge of Drift + Firestore (Drift-only when offline; Firestore wins when both present, ordered by `serverTimestamp`).
64. Widget: `ChatScreen` empty state; auto-scroll behavior at bottom vs scrolled-up; urgent bubble renders terracotta border + label.
65. Robot journey: send urgent → other member's session sees message + push payload (use a fake FCM seam).
66. Cloud Function: emulator integration test for `onUrgentMessageCreated` — verify it ignores non-urgent messages and skips the sender.

</requirements>

<boundaries>

**Edge cases:**
- Event with zero members beyond creator → tasks/expenses still work (assignee = self, splits = self only); ledger is always zero.
- Drift schema migration v3→v4 must preserve existing rows (events, users, tasks, expenses, chat_messages). Provide explicit migration step rather than `m.deleteAll()`.
- A user with neither Venmo nor CashApp handle never sees the deep-link buttons enabled — `SettleSheet` always offers the "Copy details" fallback.

**Error scenarios:**
- All Firestore writes that surface to UI must distinguish "permission-denied" (show specific snackbar) from "unavailable" (show "You're offline — will sync when reconnected").
- Cloud Function failures (`HttpsError`) surface their `code` to the UI for tailored snackbars (`unauthenticated`, `permission-denied`, `failed-precondition`, fallback `unknown`).
- A push payload referencing a deleted event → router gracefully returns to dashboard with a snackbar "That event is no longer available."

**Limits:**
- Task title ≤ 120 chars; checklist items ≤ 25 per task, each ≤ 120 chars.
- Expense description ≤ 200 chars; amount range 0.01 .. 10,000,000.
- Chat message text ≤ 2000 chars; urgent FCM body truncated to 80 chars.
- Drift chat cache capped at 200 rows per event (delete oldest above cap).
- Storage receipt upload capped at 5 MB; auto-compress with `image_picker` `imageQuality: 70` before upload.

</boundaries>

<implementation>

## Files to create

**Tasks**
- `lib/app/features/tasks/presentation/create_task_screen.dart` — full implementation (currently stub)
- `lib/app/features/tasks/presentation/task_detail_screen.dart` — full implementation (currently stub)
- `lib/app/features/tasks/presentation/widgets/checklist_editor.dart`
- `lib/app/features/tasks/presentation/widgets/assignee_picker.dart`
- `lib/app/core/database/tables/task_checklist_items.dart` (Drift table)
- `lib/app/core/database/daos/task_checklist_items_dao.dart`
- `functions/src/events/markTaskComplete.ts` (onCall, owner/admin/assignee, stamps `completedAt`/`completedBy`)
- `firestore.rules` — add `tasks` and `tasks/{tid}/checklist` blocks

**Budget & Settlements**
- `lib/app/features/budget/presentation/widgets/settle_sheet.dart` (real implementation; current is a stub)
- `lib/app/features/budget/data/pay_link_builder.dart` (pure utility — testable, no Flutter import)
- `lib/app/features/budget/application/pending_settlement_notifier.dart` (lifecycle-aware confirmation)
- `lib/app/core/database/tables/expense_splits.dart` (Drift table)
- `lib/app/core/database/daos/expense_splits_dao.dart`
- `functions/src/events/disputeSettlement.ts` (onCall; payer or payee; deletes settlement expense; updates chat notice)
- `firestore.rules` — extend `users` rules for new handle fields; reaffirm storage rules for receipts in `storage.rules`

**Chat**
- `functions/src/events/onUrgentMessageCreated.ts` (Firestore-trigger v2; FCM multicast)
- `lib/app/core/services/fcm_service.dart` (token lifecycle, permission, deep-link handler)

**Cross-cutting**
- `ai_specs/todo.md` — deferred-features backlog (see § Backlog file)
- Migration step in `lib/app/core/database/database.dart` (schemaVersion → 4)
- `docs/cloud-functions-guide.md` — register `markTaskComplete`, `disputeSettlement`, `onUrgentMessageCreated`

## Files to modify

- `lib/app/features/tasks/data/task_repository.dart` — add Firestore stream + Drift mirror; add `markTaskComplete` callable invocation in `updateStatus`
- `lib/app/features/tasks/presentation/task_list_screen.dart` — use new provider; route to detail/create screens
- `lib/app/features/tasks/presentation/widgets/task_tile.dart` — gate status toggle by RBAC
- `lib/app/features/budget/data/expense_repository.dart` — fix `_toDomain` splits bug; add Firestore stream + Drift mirror; add receipt upload helper
- `lib/app/features/budget/domain/models/expense.dart` — no field changes; ensure `toFirestore`/`fromFirestore` handle splits array
- `lib/app/features/budget/presentation/budget_screen.dart` — wire `BalanceLedger` to live stream; add settle CTAs
- `lib/app/features/budget/presentation/widgets/expense_modal.dart` — receipt picker integration; per-event currency display
- `lib/app/features/dashboard/domain/models/event.dart` — add `currency` field, `toFirestore`/`fromFirestore` mappings
- `lib/app/features/dashboard/presentation/create_event_screen.dart` — currency selector (default user currency)
- `lib/app/features/profile/presentation/profile_screen.dart` (or relevant editor) — add Venmo/CashApp handle fields with validation
- `lib/app/features/auth/domain/models/user.dart` — add `venmoHandle?`, `cashappHandle?`, `fcmTokens: List<String>`
- `lib/app/features/chat/data/firestore_chat_service.dart` — fix `eventId: ''` bug; pass `eventId` through
- `lib/app/features/chat/data/chat_repository.dart` — Drift mirror merge stream
- `lib/app/features/chat/presentation/chat_screen.dart` — empty state, auto-scroll discipline, in-app banner suppression on active screen
- `lib/app/features/chat/presentation/widgets/message_bubble.dart` — settlement-kind variant
- `lib/app/core/router/app_router.dart` — add deep-link route handling for FCM tap → chat
- `lib/main.dart` (or `app_bootstrap.dart`) — initialize `firebase_messaging`
- `functions/src/index.ts` — export new functions
- `pubspec.yaml` — add `firebase_messaging`, `url_launcher` (if missing)
- `firestore.rules` — add `tasks` rules; tighten `users` rules for handle fields
- `storage.rules` — receipt-upload rule

## Patterns to follow

- **Repository pattern** — mirror `event_repository.dart`: Firestore stream `Stream<List<X>>` + Drift cache; writes go to Firestore; reads merge Drift first then Firestore.
- **onCall Cloud Functions** — mirror `promoteToAdmin.ts`: auth check, arg validation, doc fetch, RBAC check, mutation, `logger.info`, return `{success: true}`.
- **Riverpod codegen** — use `@riverpod` annotation, `riverpod_annotation` package; one notifier per feature mutation surface.
- **Stable selectors for robot tests** — every interactive widget gets a `Key('domain.feature.action')` selector. See `flutter-robot-testing` skill for the project's conventions.

## What to avoid (and why)

- Do **not** replace `BalanceLedger.calculate` — it is already implemented correctly with the greedy net-balance algorithm and is covered by existing tests; rewriting risks regressions in math you don't need.
- Do **not** wire payment processing or webhooks. The whole point of the deep-link strategy is zero compliance burden — keep settlement recording client-side with an honest "Did you send?" confirm + dispute path.
- Do **not** implement the planned last-write-wins offline sync engine for tasks/expenses in V1. The Firestore SDK already queues offline writes; Drift mirror is for fast cold-start reads only. The full sync engine is in `todo.md`.
- Do **not** put Firestore SDK or `dart:io` imports inside `PayLinkBuilder` — it must be pure for fast unit tests.
- Do **not** broadcast normal messages via FCM — only `isHighPriority == true` triggers the urgent push CF.

## Backlog file

Create `ai_specs/todo.md` with the following structure (one section per feature area, each entry one-liner ≤ 120 chars):

```markdown
# CrewPoint — Deferred Features Backlog

Tracks ideas and partial implementations explicitly out of V1 scope. Promote into a spec when prioritized.

## Tasks
- Kanban board view (3 columns, drag-to-move) — alternative to current list view
- Task attachments file storage (model has `TaskAttachment`, no Drift/Storage wiring)
- Due-date reminders + push notifications
- Recurring tasks
- Task templates per event type

## Budget
- Multi-currency display with FX conversion
- Real settlement reconciliation (Plaid / Venmo webhook)
- Per-event currency override on expense
- Expense categories + reporting
- CSV / PDF export
- Receipt OCR

## Chat
- Message reactions
- Message edit / delete-for-everyone
- Message search
- E2EE chat (noted in firestore_chat_service.dart)
- Typing indicators
- Read receipts

## Sync / Platform
- Full offline-first last-write-wins sync engine for events/tasks/expenses
- Web platform support (CORS, FCM web push)
- Background message archival job
```

</implementation>

<validation>

## Baseline coverage outcomes

Each feature must ship with three layers of coverage:

1. **Logic / business rules** — unit tests for repositories, notifiers, and pure utilities (`PayLinkBuilder`, status transitions, RBAC predicates).
2. **UI behavior** — widget tests for empty states, validation errors, RBAC-driven affordance visibility, and lifecycle-sensitive screens.
3. **Critical journeys** — robot-driven journey tests for the user flows enumerated in `<user_flows>` § Primary.

## TDD expectations

For every requirement that defines testable logic (repositories, notifiers, pure utilities, status-transition rules, BalanceLedger consumers, settlement state machine, FCM token lifecycle), follow strict vertical-slice RED → GREEN → REFACTOR cycles per the project's `flutter-tdd` skill:

- Order behaviors **happy path → boundary → error**; one failing test at a time.
- Implementations must be the minimum needed to pass the current test; refactor only when green.
- Tests exercise public APIs; mock only at true external boundaries (Firebase SDK, FCM, `url_launcher`). Prefer in-memory fakes.
- Required testability seams to expose:
  - `TaskRepository`, `ExpenseRepository`, `ChatRepository` accept their Firestore service + Drift DAO via constructor injection
  - `PayLinkBuilder` is a top-level pure function group with zero Flutter imports
  - `PendingSettlementNotifier` accepts a `Clock` + `AppLifecycleSource` for deterministic tests
  - `FcmService` wraps `firebase_messaging` behind an `IFcmGateway` interface; tests use a fake gateway
  - `UrlLauncher` interactions go through an `IUrlLauncher` interface with a fake for tests

If any requirement cannot be driven test-first (e.g., raw `firebase_messaging` initialization), flag the exception in the implementation PR and write characterization tests post-hoc to capture observed behavior.

## Robot journey expectations

The following critical journeys ship with robot tests using the project's `flutter-robot-testing` skill (`*Robot` API, deterministic seams, `Key('domain.feature.action')` selectors):

- **Tasks — happy path**: open event → tasks tab → create-task with assignee → toggle to in-progress → toggle to done; verify list reflects each transition.
- **Budget — happy path**: open event → budget tab → create expense (equal split) → see balance update → settle via Venmo deep link (faked launcher) → confirm dialog → ledger zero → chat shows settlement notice.
- **Chat — happy path**: open event → chat tab → send normal message → toggle urgent → send urgent message → verify terracotta urgent bubble appears; with two-session harness, second session receives a faked FCM payload.

Required stable selectors (non-exhaustive — declare in each robot test alongside the screen-under-test):
- `Key('tasks.list.create')`, `Key('tasks.tile.{taskId}.status')`, `Key('tasks.detail.delete')`
- `Key('budget.expense.create')`, `Key('budget.settle.{payeeId}')`, `Key('budget.settle.venmo')`, `Key('budget.settle.cashapp')`, `Key('budget.settle.confirm')`
- `Key('chat.composer.send')`, `Key('chat.composer.urgent')`, `Key('chat.message.{messageId}')`

Default test-type mapping:
- **Robot tests** — the three happy-path journeys above
- **Widget tests** — screen-level edge cases: read-only task tile for non-authorized users, settle-sheet with no handles, expense modal validation errors, chat empty state, chat auto-scroll suppression when scrolled up, ExpenseModal split-sum mismatch, dispute-sheet cancel
- **Unit tests** — `PayLinkBuilder`, `TaskRepository.updateStatus`, `ExpenseRepository._toDomain` splits hydration, `PendingSettlementNotifier` lifecycle, `FcmService` token lifecycle, RBAC predicates, Drift migrations v3→v4

## Cloud Functions / rules

- Each new Cloud Function gets an emulator integration test in `functions/test/` covering: unauthenticated → rejected; non-authorized caller → rejected; happy path → expected mutation observable in Firestore.
- Firestore rules and storage rules tested via the existing emulator harness (or add one if absent): every access-matrix row in §11, §47.

## Manual verification (required by user before shipping)

1. Real-device push: send urgent message from one device with the receiver app fully closed; confirm push arrives, taps deep-link to chat, and renders the urgent message.
2. Real Venmo deep link: with a real `venmoHandle`, tap settle → confirm Venmo opens to a prefilled payment.
3. Drift migration on device: install previous build, create some data, install new build, verify all data survives.

</validation>

<stages>

Implementation breaks into thin vertical slices so the path is validated end-to-end before widening. Each stage ends green (analyze + tests pass) and committable.

**Stage 0 — foundations:**
- Drift schema bump v3→v4 with explicit migration; new tables; new columns; backfill `events.currency = 'USD'`; backfill empty `fcmTokens`
- Add `firebase_messaging`, `url_launcher` to `pubspec.yaml`; build clean
- Create `ai_specs/todo.md` backlog
- *Verify:* `flutter analyze` clean; existing tests pass; manual cold-start install on simulator preserves prior data.

**Stage 1 — Tasks vertical slice:**
- `CreateTaskScreen` (title + assignee only, no checklist yet)
- `TaskListScreen` reads from Firestore-stream provider with Drift mirror
- Status toggle + Firestore rules for create/read/update-status; `markTaskComplete` CF
- Robot test for the create→complete happy path
- *Verify:* tests pass; rule emulator test passes; round-trip create/update on simulator with two accounts.

**Stage 2 — Tasks broaden:**
- `TaskDetailScreen` with edit/delete; checklist subcollection + Drift mirror
- Read-only state for non-authorized users; offline-pending indicator
- Widget tests for edge cases
- *Verify:* tests pass; non-authorized snackbar fires.

**Stage 3 — Budget per-event currency + splits persistence:**
- Add `currency` to `EventModel` and `CreateEventScreen`
- New `expense_splits` Drift table; fix `_toDomain` splits regression
- Wire `BudgetScreen` to live Firestore stream (no settle UI yet)
- *Verify:* unit test for splits hydration; existing `BalanceLedger` tests still pass; expenses visible end-to-end.

**Stage 4 — Receipt upload:**
- Storage rule; image picker → upload → store path; thumbnail in tile; full-screen viewer
- *Verify:* manual upload + view round-trip; failure path leaves expense intact.

**Stage 5 — Pay handles + deep-link settle:**
- Profile editor for `venmoHandle` / `cashappHandle` with validation
- `PayLinkBuilder` pure utility + tests
- `SettleSheet` UI; `PendingSettlementNotifier` lifecycle handling; settlement-kind chat notice
- *Verify:* unit tests for builder; widget tests for sheet states; robot test for the settle happy path with a faked launcher.

**Stage 6 — Dispute path:**
- `disputeSettlement` Cloud Function; tap-to-dispute on settlement notice
- *Verify:* CF emulator test; widget test for dispute confirm/cancel.

**Stage 7 — Chat fixes + Drift cache:**
- Fix `eventId: ''` bug; sender-name hydration via `usersByIdProvider`
- Drift mirror of last 200 messages per event; merge stream
- Empty state, auto-scroll discipline, send-in-flight guard
- *Verify:* widget tests; cold-start cache load on simulator.

**Stage 8 — FCM push for urgent:**
- `FcmService`: permission, token lifecycle, deep-link handler
- `onUrgentMessageCreated` CF; foreground in-app banner with active-screen suppression
- *Verify:* CF emulator test; manual two-device push test (closed app, foreground app on other screen, foreground on chat screen).

**Stage 9 — Documentation + cleanup:**
- Update `docs/cloud-functions-guide.md` registry with all three new functions
- Verify all `<requirements>` items are checked off
- Final `flutter analyze`, `flutter test`, manual smoke per `<validation>` § Manual

</stages>

<done_when>

- All `<requirements>` items 1-66 are implemented, tested, and observably correct on a real device.
- `flutter analyze` is clean; `flutter test` passes; `cd functions && npm run build` is clean; emulator tests for new rules and Cloud Functions pass.
- Drift migration v3→v4 preserves all prior local data on a real device upgrade.
- Tasks: a non-assignee non-admin cannot transition status (rule-blocked + UI snackbar); assignee or admin can.
- Budget: settling via deep link from a payer with `venmoHandle` set produces (a) a Venmo intent, (b) a confirmable settlement expense, (c) a balance-ledger zero, (d) a settlement notice in chat that the payee can dispute. Receipt upload works end-to-end.
- Chat: opening an event renders cached messages immediately, then live stream takes over; sending an urgent message produces an FCM push received on a second member's closed-app device and deep-links to chat on tap; foreground urgent messages on the same chat screen are not banner-spammed.
- `ai_specs/todo.md` is committed and lists every deferred item from this spec.
- `docs/cloud-functions-guide.md` Function Registry includes `markTaskComplete`, `disputeSettlement`, and `onUrgentMessageCreated`.

</done_when>
