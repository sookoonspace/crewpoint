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
