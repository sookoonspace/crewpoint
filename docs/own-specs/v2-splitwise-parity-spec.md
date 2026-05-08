<goal>
Upgrade CrewPoint's budget module to achieve parity with Splitwise's core premium features without inheriting their regulatory, payment-gateway, or online-only baggage. 

This spec introduces four major upgrades: 
1. Zelle deep-link support (clipboard fallback).
2. Custom/Unequal Splits (with strict Orphaned Cent validation).
3. Offline Multi-Currency (locked exchange rates via local Drift cache).
4. On-Device Receipt OCR (ML Kit horizontal-bounding-box parsing).
5. Global Balances (cross-event debt aggregation).
</goal>

<background>
**Tech stack & constraints:**
- Flutter 3.11.5 / Dart 3.x; Riverpod 3 (hand-written `Notifier`s).
- Local DB: Drift (SQLite) — offline-first cache.
- ML Kit: `google_mlkit_text_recognition` for strictly on-device, free OCR (no cloud API calls).
- Background Sync: `workmanager` for fetching daily exchange rates silently.
- Existing Math: The `BalanceLedger` greedy algorithm is already implemented and relies on `expense_splits`.
</background>

<user_flows>

## Primary Flow: OCR Receipt Scan
1. User creates an expense and taps the "Camera" icon.
2. `image_picker` opens. User snaps photo.
3. ML Kit runs on-device text recognition.
4. Parser searches for anchor words ("Total", "Amount Due", "Balance").
5. Parser checks the horizontal Y-axis bounding box next to the anchor for a decimal string (XX.XX).
6. If found, auto-fills the "Amount" field. If confidence is low, highlights numbers on the image and prompts user to tap the correct total.

## Primary Flow: Custom Splits
1. In `ExpenseModal`, user taps "Split Options".
2. Toggles between "Equally", "Exact Amounts", and "Percentages".
3. User enters exact amounts. 
4. **Validation Guard:** The "Save" button remains disabled until the sum of all splits exactly equals the Total Amount (down to the cent).
5. If user chooses "Equally" for a $100 bill 3 ways, the UI assigns $33.34 to the payer and $33.33 to the others to prevent orphaned cents.

## Primary Flow: Offline Multi-Currency
1. User enters $100, taps currency selector, and chooses `EUR`.
2. App instantly looks up the `EUR -> USD` rate in the local Drift `ExchangeRates` table.
3. Saves the expense with locked rates: `originalAmount: 100`, `originalCurrency: 'EUR'`, `baseAmount: 110`, `exchangeRate: 1.10`.
4. `BalanceLedger` calculates everything using `baseAmount`.

## Primary Flow: Zelle Settle
1. User taps "Settle" row for Alex.
2. `SettleSheet` shows Venmo, CashApp, and Zelle.
3. User taps Zelle. App copies exact string "$25.00" to clipboard and shows snackbar: "Copied $25.00 for Alex's Zelle (alex@email.com). Open your banking app to send."
4. User returns to app and confirms "Did you send it?" to record the settlement.

</user_flows>

<requirements>

## 1. Zelle & Custom Splits (UI / Data Expansion)
1. Add `zelleHandle` to `UserModel`, `Users` Drift table, and `EditProfileScreen`.
2. Update `SettleSheet` to show Zelle. Implement the clipboard-fallback UX for Zelle since it lacks a universal pre-fill deep link.
3. Update `ExpenseModal` UI to support "Exact Amounts" and "Percentages".
4. **Orphaned Cent Rule:** In `ExpenseModal`, `Sum(splits) == Total` must evaluate to true before the Save button is enabled. Write a utility function to handle fractional penny remainders for equal splits (always assign the remainder penny to the payer).

## 2. Offline Multi-Currency (Architecture Shift)
5. Create Drift table `exchange_rates(currencyCode, rateToBase, updatedAt)`.
6. Add `workmanager` task to fetch exchange rates once daily and update the Drift table silently in the background.
7. Expand `ExpenseModel` and `expenses` Drift table: add `originalAmount`, `originalCurrency`, `baseAmount`, `exchangeRate`.
8. The `BalanceLedger` must be updated to strictly consume the `baseAmount` so debts never fluctuate as live exchange rates change.
9. UI shows a tiny subtitle on the expense: *"€100.00 (Locked at 1.10)"*.

## 3. Receipt OCR (On-Device ML)
10. Add `google_mlkit_text_recognition` to `pubspec.yaml`.
11. Build `ReceiptParserService`. Do not just grab the largest number. Use Regex to find anchors (`"Total"`, `"Amount Due"`, `"Balance"`).
12. Use the ML Kit `Text.Element.boundingBox` to find decimal strings sitting on the same Y-axis as the anchor word.
13. If parsing fails, fall back gracefully and leave the Amount field empty for manual entry.

## 4. Global Balances (Cross-Event Aggregator)
14. Add a "Friends" tab to the `ResponsiveShell` (mobile bottom nav / desktop side rail).
15. Create a Drift query `getGlobalSplits()` that aggregates all `expense_splits` grouped by `userId` across all events the user is part of.
16. Feed the aggregated splits into the existing `BalanceLedger.calculate()` engine.

</requirements>

<boundaries>
- **No Cloud Vision APIs:** OCR must be 100% on-device via ML Kit to protect privacy and work offline.
- **No Live FX Lookups:** Never block an expense creation to fetch a live exchange rate. Always use the cached Drift rate. If the cache is empty, default to 1.0 and flag it.
- **No Orphaned Cents:** The app must mathematically guarantee that ledgers never get stuck at $0.01 differences.
- **No Plaid/Banking APIs:** Zelle settlement relies completely on the "Did you send it?" manual confirmation.
</boundaries>

<validation>
- **TDD:** Unit test the equal-split penny distribution logic. 
- **TDD:** Unit test `ReceiptParserService` with mock bounding box data to ensure it ignores phone numbers and dates.
- **TDD:** Unit test `BalanceLedger` against the new `baseAmount` field to ensure fluctuating exchange rates do not break historic debts.
- **Robot:** E2E journey for taking a photo, auto-filling amount, choosing exact split, and settling via Zelle clipboard fallback.
</validation>
