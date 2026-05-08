## Overview
Execute the V2 "Splitwise Parity" update. Focus on strict mathematical integrity (no orphaned cents, locked exchange rates) and privacy-first UX (on-device ML Kit OCR).

**Spec**: `ai_specs/v2-splitwise-parity-spec.md`

## Context
- **Architecture**: Feature-first DDD.
- **State management**: Riverpod 3 (Hand-written notifiers).
- **Database**: Drift offline-first cache.
- **Critical Math**: Do NOT rewrite `BalanceLedger`, just change its input to `baseAmount`.

## Plan

### Phase 1: Zelle & Custom Splits (UI + Data Expansion)
- **Goal**: Expand user data for Zelle, implement clipboard UX, and add exact/percentage splits with strict validation.
- [ ] `lib/app/features/auth/domain/models/user.dart` — Add `zelleHandle` to model and Drift schema.
- [ ] `lib/app/features/budget/presentation/widgets/settle_sheet.dart` — Add Zelle button. Wire up `Clipboard.setData` + Snackbar for the fallback UX.
- [ ] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — Add Split Type toggle (Equal, Exact, Percentage).
- [ ] `lib/app/features/budget/domain/split_calculator.dart` — Create pure utility to handle penny rounding. (e.g., $100 / 3 = $33.34, $33.33, $33.33).
- [ ] `ExpenseModal` — Disable save button if `Sum(splits) != Total`.
- [ ] TDD: `SplitCalculator` correctly distributes remainder pennies.
- [ ] Verify: `flutter analyze` && `flutter test`.

### Phase 2: Offline Multi-Currency (Architecture Shift)
- **Goal**: Implement locked exchange rates via a Drift cache to prevent the "Time-Travel Ledger Trap."
- [ ] `pubspec.yaml` — Add `workmanager` for background fetch.
- [ ] `lib/app/core/database/app_database.dart` — Add `exchange_rates` table. Add `originalAmount`, `originalCurrency`, `baseAmount`, `exchangeRate` to `expenses` table.
- [ ] `lib/app/features/budget/domain/models/expense.dart` — Update model and `toFirestore`/`fromFirestore`.
- [ ] `lib/app/core/services/exchange_rate_service.dart` — Fetch daily rates and cache to Drift.
- [ ] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — Update save logic: lookup cached rate, calculate `baseAmount`, save locked values.
- [ ] `lib/app/features/budget/domain/models/balance_ledger.dart` — Update to strictly calculate using `expense.baseAmount`.
- [ ] TDD: Ledger calculates correctly with mixed currencies.
- [ ] Verify: `flutter analyze` && `flutter test`.

### Phase 3: Receipt OCR (The Magic Trick)
- **Goal**: On-device auto-fill for receipt totals using ML Kit bounding boxes.
- [ ] `pubspec.yaml` — Add `google_mlkit_text_recognition`.
- [ ] `lib/app/features/budget/data/receipt_parser_service.dart` — Pure service. Use Regex to find "Total" anchors. Search adjacent Y-axis bounding boxes for decimal strings.
- [ ] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — Wire camera icon to run image through `ReceiptParserService` and auto-fill the Amount field.
- [ ] TDD: `ReceiptParserService` successfully ignores phone numbers and extracts the correct decimal based on bounding box proximity.
- [ ] Verify: `cd functions && npm run build` (if needed) && `flutter analyze` && `flutter test`.

### Phase 4: Global Balances Dashboard
- **Goal**: Cross-event debt aggregator ("Friends" tab).
- [ ] `lib/app/core/database/daos/expense_splits_dao.dart` — Add `getGlobalSplits()` SQL query to aggregate all splits grouped by `userId`.
- [ ] `lib/app/features/friends/presentation/friends_dashboard_screen.dart` — New screen. Feed global splits into `BalanceLedger.calculate()`.
- [ ] `lib/app/core/widgets/responsive_shell.dart` — Add "Friends" destination to side rail and bottom nav.
- [ ] TDD: `getGlobalSplits()` correctly sums debts across multiple event IDs.
- [ ] Verify: `flutter analyze` && `flutter test`.

## Risks / Out of scope
- **Risks**: `google_mlkit_text_recognition` increases app binary size. Ensure iOS/Android builds succeed after adding dependency.
- **Out of scope**: Line-item specific receipt scanning (assigning specific burgers to specific people). V1 OCR is Total-extraction only.