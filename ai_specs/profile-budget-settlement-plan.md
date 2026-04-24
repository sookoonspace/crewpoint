## Overview

Soften profile UI, expand user data model with payment preferences, add balance ledger + settlement flow to budget. Privacy-first data collection.

**Spec**: `ai_specs/profile-budget-settlement-spec.md` (read this file for full requirements)

## Context

- **Structure**: Feature-first with DDD layers
- **State management**: Riverpod (Notifier pattern)
- **Reference implementations**: `lib/app/features/profile/presentation/profile_screen.dart`, `lib/app/features/budget/domain/models/expense.dart`
- **Assumptions/Gaps**:
  - Settlement simplification uses greedy algorithm (not optimal for >5 people, but sufficient for V1)
  - Settlements recalculated on expense change — `isSettled` flags preserved

## Plan

### Phase 1: User Data Model + Firestore Schema

- **Goal**: Expand AppUser model with payment preferences; update Drift + Firestore writes
- [ ] `lib/app/features/auth/domain/models/app_user.dart` — Add fields: `paymentMethod`, `paymentHandle`, `currency` (all nullable)
- [ ] `lib/app/core/database/app_database.dart` — Add columns to Users table: `paymentMethod`, `paymentHandle`, `currency`
- [ ] Run `dart run build_runner build -d` to regenerate Drift code
- [ ] `lib/app/features/profile/presentation/edit_profile_screen.dart` — Add payment method dropdown + payment handle text field; persist to Firestore on save
- [ ] `firestore.rules` — Add rule: `paymentMethod` and `paymentHandle` readable only by event members (not all authenticated users)
- [ ] TDD: AppUser with payment fields serializes/deserializes correctly
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Profile UI Softening

- **Goal**: Gradient hero, soft avatar glow, flat cards, payment section, more breathing room
- [ ] `lib/app/features/profile/presentation/profile_screen.dart` — Redesign hero:
  - Charcoal→charcoalDark gradient (top-to-bottom) instead of flat color
  - Bottom corner radius: 32 (up from 24)
  - Avatar: sage BoxShadow glow (blur 12, spread 2) instead of hard ring
  - +8px between name and email
  - "Edit Profile" button: filled sage pill (not outlined)
- [ ] `lib/app/features/profile/presentation/profile_screen.dart` — Update section cards:
  - Elevation 0, add lightGrey border (0.5px)
  - Icons: outlined variants, darkGrey color
  - Add "PAYMENT" section between Settings and Account
  - Payment card: shows method icon + handle, or "Add payment method" prompt
  - Danger zone spacing: xxl → xxxl
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Balance Ledger (Pure Logic)

- **Goal**: Calculate net balances + simplified settlements from event expenses
- [ ] `lib/app/features/budget/domain/models/balance_ledger.dart` — New model:
  - `BalanceLedger.calculate()` — takes expenses + memberIds, returns net balances + settlements
  - `Settlement` — fromUserId, toUserId, amount, isSettled
  - Greedy debt simplification: match largest creditor with largest debtor iteratively
- [ ] TDD: 3 members, equal split — each balance is correct
- [ ] TDD: one person pays all 3 expenses — other 2 owe them
- [ ] TDD: donation expense — payer excluded from their own split
- [ ] TDD: simplification — 4 members, mixed expenses → minimum transfers
- [ ] TDD: empty expenses → all balances zero, no settlements
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Budget UI — Balances + Settlement

- **Goal**: Show per-member balances and settlement flow on budget screen
- [ ] `lib/app/features/budget/presentation/budget_screen.dart` — Add below total:
  - "Balances" section: list of members with net balance (sage for positive, terracotta for negative)
  - "Settle Up" expandable card: list of Settlement transfers with "Settle" button per row
- [ ] `lib/app/features/budget/presentation/widgets/settle_sheet.dart` — Bottom sheet:
  - Shows payee's payment method + handle (if set)
  - "Mark as Settled" button → updates settlement in Firestore
  - If no payment method: "No payment method set — ask them directly"
- [ ] `lib/app/features/budget/data/settlement_repository.dart` — CRUD for settlements subcollection in Firestore
- [ ] `lib/app/features/budget/application/budget_provider.dart` — Extend to compute BalanceLedger from expenses
- [ ] TDD: budget provider computes correct balances from expense list
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 5: Privacy Dashboard Update

- **Goal**: Show users exactly what data we collect and why
- [ ] `lib/app/features/profile/presentation/privacy_dashboard_screen.dart` — Add "Data We Collect" section with field + purpose table from spec Section 2.2
- [ ] Add "Payment Information" privacy note: "Your payment details are only visible to members of events you share"
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**:
  - Greedy settlement simplification may not produce optimal minimum transfers for groups >5; acceptable for V1 trip use case
  - Settlement `isSettled` flag may desync if expenses are deleted after settlement — mitigate by recalculating on expense changes
  - Payment handle is free-text — no validation that it's a real Venmo/Zelle username
- **Out of scope**:
  - Actual money transfer / payment API integration
  - Unequal splits (custom per-person amounts)
  - Currency conversion
  - Settlement push notification reminders
  - Data export (GDPR portability)
