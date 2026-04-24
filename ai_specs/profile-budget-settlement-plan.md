## Overview

Soften profile UI, expand user data model with payment preferences, add balance ledger + payment-as-expense settlement flow to budget. Privacy-first data collection.

**Spec**: `ai_specs/profile-budget-settlement-spec.md` (read this file for full requirements)

## Context

- **Structure**: Feature-first with DDD layers
- **State management**: Riverpod (Notifier pattern)
- **Reference implementations**: `lib/app/features/profile/presentation/profile_screen.dart`, `lib/app/features/budget/domain/models/expense.dart`
- **Assumptions/Gaps**:
  - Settlement simplification uses greedy algorithm (sufficient for V1 trip groups)
  - Settlements are computed on-the-fly, NOT persisted — "settling" creates a payment expense
  - Payment handles are semi-public (authenticated read) — Firestore can't do field-level rules

## Plan

### Phase 1: User Data Model + Expense isPayment Flag

- **Goal**: Expand AppUser with payment preferences; add `isPayment` to ExpenseModel; update Drift + Firestore
- [x] `lib/app/features/auth/domain/models/app_user.dart` — Added `paymentMethod`, `paymentHandle`, `currency`
- [x] `lib/app/features/budget/domain/models/expense.dart` — Added `isPayment` boolean
- [x] `lib/app/core/database/app_database.dart` — Added columns + bumped schema to v2
- [x] Regenerated Drift code
- [x] `lib/app/features/profile/presentation/edit_profile_screen.dart` — Payment method dropdown + handle field
- [x] `firestore.rules` — No changes needed (authenticated read at document level)
- [x] Verify: `flutter analyze` && `flutter test` — 47 tests, 0 warnings

### Phase 2: Profile UI Softening

- **Goal**: Gradient hero, soft avatar glow, flat cards, payment section, more breathing room
- [x] Profile hero: charcoal→charcoalDark gradient, radius 32, sage glow avatar, filled sage pill button
- [x] Section cards: elevation 0, lightGrey border, outlined icons in darkGrey
- [x] Payment section: method icon + handle display, or "Add payment method" prompt
- [x] Danger zone: xxxl spacing above
- [x] Verify: `flutter analyze` && `flutter test` — 47 tests, 0 warnings

### Phase 3: Balance Ledger (Pure Logic)

- **Goal**: Calculate net balances + simplified settlements from expenses (including payment expenses)
- [x] `lib/app/features/budget/domain/models/balance_ledger.dart` — BalanceLedger + Settlement (computed only)
- [x] TDD: 3 members equal split — correct balances
- [x] TDD: one payer all expenses — correct creditor/debtor
- [x] TDD: donation — payer excluded from split
- [x] TDD: payment expense — reduces debt correctly (Splitwise model)
- [x] TDD: mixed scenario — expenses + donations + payments
- [x] TDD: simplification — 4 members → minimum transfers
- [x] TDD: empty expenses → zeroes
- [x] Verify: 54 tests, 0 warnings

### Phase 4: Budget UI — Balances + Settlement

- **Goal**: Show per-member balances and settle-up flow that creates payment expenses
- [ ] `lib/app/features/budget/presentation/budget_screen.dart` — Add below total:
  - "Balances" section: list of members with net balance (sage for positive, terracotta for negative)
  - "Settle Up" expandable card: list of computed Settlement transfers with "Settle" button per row
- [ ] `lib/app/features/budget/presentation/widgets/settle_sheet.dart` — Bottom sheet:
  - Shows payee's payment method + handle (if set)
  - "Record Payment" button → creates new `ExpenseModel` with `isPayment: true`, `payerId: fromUserId`, split with `[toUserId]` via existing `expense_repository.dart`
  - If no payment method: "No payment method set — ask them directly"
  - On success: Lottie success animation, sheet dismisses, balances auto-update
- [ ] `lib/app/features/budget/application/budget_provider.dart` — Extend to compute BalanceLedger from expenses
- [ ] TDD: budget provider computes correct balances from expense list
- [ ] TDD: recording a payment creates an isPayment expense and reduces debt
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 5: Privacy Dashboard Update

- **Goal**: Show users exactly what data we collect and why
- [ ] `lib/app/features/profile/presentation/privacy_dashboard_screen.dart` — Add "Data We Collect" section with field + purpose table from spec Section 2.2
- [ ] Add note: "Your payment details (Venmo handle, etc.) are visible to other CrewPoint users to facilitate settlements"
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**:
  - Greedy settlement simplification may not produce optimal minimum transfers for groups >5; acceptable for V1 trip use case
  - Payment handle is free-text — no validation that it's a real Venmo/Zelle username
  - Payment expenses are visually distinct from regular expenses (need clear UI differentiation with `isPayment` badge)
- **Out of scope**:
  - Actual money transfer / payment API integration
  - Unequal splits (custom per-person amounts)
  - Currency conversion
  - Settlement push notification reminders
  - Data export (GDPR portability)
