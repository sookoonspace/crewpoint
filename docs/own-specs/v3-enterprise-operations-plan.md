## Overview
Execute the V3 Enterprise Operations update. Introduces Fund Mode, Sub-Events, Dues Collection, and White-Labeling. Strictly maintains offline-first Drift mirroring for all new data structures.

**Spec**: `ai_specs/v3-enterprise-operations-spec.md`

## Context
- **Architecture**: Feature-first DDD.
- **State management**: Riverpod 3 (Hand-written notifiers).
- **Offline Constraint**: All new tables must have a sync mirror.

## Plan

### Phase 1: Fund Mode & Core Model Expansion
- **Goal**: Drift schema v5 bump, `budgetMode` logic, and the Central Pot UI.
- [ ] `lib/app/core/database/database.dart` — Bump to `schemaVersion: 5`. Add new fields to `events` and `expenses`. Create `itinerary_items` and `payment_requests` tables. Write migration logic.
- [ ] `lib/app/features/dashboard/domain/models/event.dart` — Add `budgetMode`, `parentId`, `taxId`, `brandPrimaryColor`, etc.
- [ ] `lib/app/features/budget/presentation/budget_screen.dart` — Implement layout branch. If `budgetMode == 'fund'`, display Central Pot progress bars and bypass `BalanceLedger`.
- [ ] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — Allow `payerId` to be `'central_fund'`. Add "Reimbursement" toggle.
- [ ] TDD: `BudgetScreen` renders entirely different UI states based on `budgetMode`.

### Phase 2: RBAC, Tags & Spectator Roles
- **Goal**: Transition from flat `memberIds` to `EventMemberModel` and enforce read-only access.
- [ ] `lib/app/features/dashboard/domain/models/event_member.dart` — New model with `role` and `tags`.
- [ ] `firestore.rules` — Update read/write logic to check the `event_members` subcollection. Restrict `spectator` from `expenses` and `tasks`.
- [ ] `lib/app/features/dashboard/presentation/widgets/member_management_sheet.dart` — Allow assigning tags (e.g., `@youth_group`) and toggling spectator roles.
- [ ] TDD/Emulator: Rules successfully block spectator writes.

### Phase 3: Sub-Events (The Hybrid Engine)
- **Goal**: Allow nested events with isolated ledgers.
- [ ] `lib/app/features/dashboard/presentation/create_event_screen.dart` — Add "Create Sub-Event" flow. Inherit `parentId`. Add Template Selector (Trip, Corporate, Wedding).
- [ ] `lib/app/core/widgets/responsive_shell.dart` — Update event sidebar/drawer to group `parentId` matches under their master event visually.
- [ ] Verify: `flutter analyze` && `flutter test`.

### Phase 4: Dues & Mass Collection
- **Goal**: The Non-Profit / Fraternity mass-request system.
- [ ] `lib/app/features/budget/domain/models/payment_request.dart` — Create model and Drift DAO.
- [ ] `functions/src/events/createMassRequest.ts` — Cloud Function. Accepts an amount and a tag (e.g., `@all_members`), fans out documents to the `payment_requests` subcollection.
- [ ] `lib/app/features/budget/presentation/dues_dashboard.dart` — UI for members to mark "Paid" (via V2 deep links) and Treasurer to "Confirm".
- [ ] TDD: Cloud function correctly filters users by tag and batch-writes requests.

### Phase 5: The Itinerary Module
- **Goal**: Read-only schedule for spectators. Offline ready.
- [ ] `lib/app/features/itinerary/domain/models/itinerary_item.dart` — Create model and Drift DAO.
- [ ] `lib/app/features/itinerary/data/itinerary_repository.dart` — Implement Firestore stream -> Drift mirror.
- [ ] `lib/app/features/itinerary/presentation/itinerary_screen.dart` — Chronological timeline UI.

### Phase 6: White-Labeling & Enterprise Archive
- **Goal**: Custom branding, Tax PDFs, and the accounting export.
- [ ] `lib/app/features/budget/data/donation_receipt_pdf_builder.dart` — Pure builder. Injects `event.taxId`, overrides `AppColors` with `event.brandPrimaryColor` if present.
- [ ] `functions/src/events/archiveEvent.ts` — Flips `isArchived`.
- [ ] `functions/src/events/generateAccountingExport.ts` — Uses `archiver` or `jszip` in Node to bundle the CSV and Storage receipts. Returns a signed download URL.
- [ ] Verify: `cd functions && npm run build` && `flutter analyze` && `flutter test`.

## Risks / Out of scope
- **Risks**: Moving from a flat `memberIds` array to an `event_members` subcollection (Phase 2) requires a careful Firestore data migration script for existing V1/V2 events.
- **Out of scope**: Automated calendar syncing (Google/Apple Calendar) for the Itinerary module. This should be deferred to a future V3.1 update.