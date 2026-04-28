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
- Per-expense currency override (event-level currency only in V1)
- Expense categories + reporting
- CSV / PDF export
- Receipt OCR

## Chat
- Message reactions
- Message edit / delete-for-everyone
- Message search
- E2EE chat (noted in `firestore_chat_service.dart`)
- Typing indicators
- Read receipts

## Sync / Platform
- Full offline-first last-write-wins sync engine for events / tasks / expenses
- Web platform support (CORS, FCM web push)
- Background message archival job
- Refactor `EventRepository` to Firestore-stream + Drift-mirror (currently Drift-only — write path doesn't reach Firestore for events)

## Test Infrastructure
- Firebase emulator harness (`functions/test/`) for Cloud Function integration tests + `firestore.rules` access-matrix tests (deferred from Phase 1 of tasks-budget-chat plan)
- BudgetRobot settle-via-Venmo journey test (Phase 5) — requires Riverpod overrides for `IUrlLauncher`, `AppLifecycleSource`, faked Firestore + fake auth, and stable per-payee settle-row keys
- ChatRobot urgent-message journey test (Phase 8) — requires faked `IFcmGateway` + `FcmHandler` invariants pumped through a two-session widget harness

## FCM bootstrap (Phase 8 → Phase 9 manual smoke)
- `main.dart`: register `FirebaseMessaging.onBackgroundMessage` (top-level fn with `@pragma('vm:entry-point')`)
- Subscribe `FirebaseMessaging.onMessage` and `onMessageOpenedApp` to `FcmHandler`
- Await `FirebaseMessaging.getInitialMessage()` before first router build (cold-start tap)
- Call `FcmService.attach(uid)` from the auth state listener; `detach(uid)` on sign-out
- Ship the foreground banner UI (`MaterialBanner` with View action that calls `context.go(deepLink)`)
- Pre-deploy: upload APNs key to Firebase console (iOS); verify "🚨 Urgent in {EventName}" push lands on a closed-app device

## Chat polish followups
- "Unknown member" coalescing for removed senders (currently shows UID label)
