# ACT Specification: Profile Redesign, User Data Model & Budget Settlement

## 1. Goal

Redesign the Profile screen for a softer, premium feel. Define the complete user data model for Firestore with privacy-first principles. Extend the budget feature with "who owes whom" balance calculation and settlement flow — enabling the core use case of friends splitting costs on a trip.

---

## 2. Privacy-First Data Collection Policy

### 2.1 Principles

- **Collect only what the app needs to function.** No speculative data.
- **User-initiated only.** Never auto-collect device info, location, contacts, or analytics IDs without explicit opt-in.
- **Payment info is optional.** Users can track balances without adding payment methods.
- **Transparent storage.** Privacy Dashboard shows exactly what we store.

### 2.2 What We Collect & Why

| Field | Why | Required? |
|-------|-----|-----------|
| `displayName` | How you appear to crew members | Yes (from auth) |
| `email` | Contact for settlements, account recovery | Yes (from auth) |
| `photoUrl` | Avatar in events, chat, expenses | No |
| `paymentMethod` | Show crew how to pay you (Venmo, Zelle, etc.) | No |
| `paymentHandle` | Your @username or phone for the chosen method | No |
| `currency` | Display formatting preference | No (default USD) |
| `dataOptIn` | Anonymous usage analytics | No (default false) |

### 2.3 What We Do NOT Collect

- Phone number (unless user puts it in paymentHandle by choice)
- Physical address, birthday, gender, demographics
- Device identifiers, advertising IDs
- Contacts or social graph
- Location data (deferred to Phase 2)
- Browsing/usage history (unless dataOptIn is true)

### 2.4 Data Residency

- Firestore: `users/{uid}` — profile + preferences
- Firebase Storage: `users/{uid}/profile.jpg` — avatar only
- Local Drift: cached copy for offline access
- Secure Storage: auth tokens only (no PII)

---

## 3. Firestore User Document Schema

```
users/{uid}:
  displayName: string
  email: string
  photoUrl: string | null              // Storage download URL
  paymentMethod: string | null         // "venmo" | "zelle" | "cashapp" | "paypal" | "cash" | null
  paymentHandle: string | null         // @johndoe, phone, email — user-entered
  createdAt: timestamp
  updatedAt: timestamp
  preferences:
    dataOptIn: boolean                 // false by default
    currency: string                   // "USD" by default
```

**Privacy notes:**
- `paymentMethod` and `paymentHandle` are readable by any authenticated user (Firestore rules operate at document level, not field level — field-level restrictions would break profile loading). These are semi-public identifiers (Venmo @handles, Zelle emails) that users choose to share.
- On account deletion: entire document deleted; shared data anonymized per existing deletion flow

---

## 4. Profile Screen Redesign — Softer UI

### 4.1 Current Issues

- Flat charcoal hero card is too stark/heavy
- Hard sage ring on avatar feels rigid
- Card elevation creates harsh shadows on cream
- Sections feel cramped

### 4.2 Design Changes

**Hero area** (top section):
- Replace flat charcoal → **subtle gradient** (charcoal → charcoalDark, top-to-bottom)
- Increase bottom corner radius from `AppRadius.xxl` (24) to 32
- Avatar: replace hard sage ring → **soft sage glow** (shadow with sage color, blur 12, spread 2)
- More vertical breathing room between elements (+8px between name and email)
- "Edit Profile" button: sage **filled** pill (not outlined) for warmth — sage bg, white text, no border

**Section cards**:
- Reduce elevation from 1 → 0 (flat cards, rely on white-on-cream contrast)
- Add subtle `AppColors.lightGrey` border (0.5px) for definition without shadow
- Increase internal padding from default ListTile to `AppSpacing.md` vertical
- Icons: use **outlined** variants consistently, `AppColors.darkGrey` (not charcoal — too heavy)

**Payment section** (new):
- Between Settings and Account sections
- "PAYMENT" header
- Single card with: payment method icon + handle display
- If not set: "Add payment method" prompt with sage text
- Tapping opens edit flow (within Edit Profile screen)

**Danger zone**:
- Keep isolated card with terracotta border (works well)
- Increase spacing above from `xxl` to `xxxl` for more separation

**App version**: Keep as-is (centered, mediumGrey, bottom)

### 4.3 Edit Profile Updates

Add two new fields to edit screen:
- **Payment Method**: dropdown selector (Venmo, Zelle, Cash App, PayPal, Cash, Other)
- **Payment Handle**: text field (hint: "@username, phone, or email")
- Both optional — can leave blank
- Save persists to Firestore `paymentMethod` + `paymentHandle`

---

## 5. Budget Settlement — "Who Owes Whom"

### 5.1 Use Case

Friends on a trip. Anyone can pay for anything. At the end (or during), the app shows:
- Total expenses for the event
- Each person's net balance (positive = others owe them, negative = they owe others)
- Simplified settlements: minimum transfers needed to settle all debts
- How to pay (shows payee's preferred payment method)

### 5.2 Balance Calculation (Pure Dart Logic)

**Input**: List of `ExpenseModel` for an event + list of member IDs

**Algorithm**:
1. For each expense: payer paid `amount`, each member in the split owes `amount / splitCount`
2. Net balance per person = total paid - total owed
3. Simplify debts: greedy algorithm — match largest creditor with largest debtor until all balances are zero

```dart
class BalanceLedger {
  final Map<String, double> netBalances;    // uid → net (+ = owed, - = owes)
  final List<Settlement> settlements;        // minimum transfers (computed, not stored)
  final double totalExpenses;

  static BalanceLedger calculate({
    required List<ExpenseModel> expenses,
    required List<String> memberIds,
  });
}

/// Computed in-memory only — NOT persisted to Firestore.
/// Represents a simplified transfer needed to settle all debts.
class Settlement {
  final String fromUserId;      // who pays
  final String toUserId;        // who receives
  final double amount;
}
```

**`ExpenseModel` additions**: Add `isPayment` boolean (default false). When `isPayment == true`, the expense represents a direct settlement payment, not a group expense.

**Donation handling**: If `isDonation == true`, the payer's share is excluded from splits (existing behavior). Their net balance increases by the full amount minus zero (since they don't owe themselves).

**Payment handling**: If `isPayment == true`, the expense is a direct transfer from `payerId` to the single member in the split. The payer's balance decreases by `amount`, the recipient's balance increases by `amount`. No split division occurs. This is how settlements feed back into the ledger — they are just another expense that the algorithm incorporates automatically.

### 5.3 Settlement Flow (UI)

**Budget screen additions**:
- Below total expenses: "Balances" section showing each member's net balance
  - Green text for positive (owed money), terracotta for negative (owes money)
  - Tap to expand → shows "Settle Up" list
- "Settle Up" card: list of computed `Settlement` transfers
  - Each row: "[Name] pays [Name] $XX.XX" + "Settle" button
  - Tapping "Settle" → shows payee's payment method + "Record Payment" button
  - "Record Payment" creates a new `ExpenseModel` with `isPayment: true`, `payerId: fromUserId`, split with `[toUserId]`. This automatically resolves the debt in the ledger.
  - Already-settled debts disappear naturally because the payment expense zeroes out the balance

**Settlement is NOT persisted separately.** Settlements are computed on-the-fly from the expense list. When a user "settles," it creates a payment expense — just another entry in the same expenses subcollection. This guarantees mathematical consistency regardless of future expense additions/deletions. No financial APIs, no bank connections.

---

## 6. Privacy Dashboard Updates

Add to the existing Privacy Dashboard:
- "Data We Collect" section listing each field from Section 2.2 with its purpose
- "Payment Information" note: "Your payment details are only visible to members of events you share"
- "Data Export" placeholder (future feature)

---

## 7. Validation Criteria

1. Profile screen renders with gradient hero, soft avatar glow, flat cards on cream
2. Edit profile saves display name, photo, payment method, payment handle to Firestore
3. Budget screen shows per-member net balances calculated from all event expenses
4. Settlement list shows minimum transfers with correct amounts
5. "Record Payment" creates a payment expense (`isPayment: true`) that resolves the debt in the ledger
6. Donation expenses correctly excluded from payer's debt calculation
7. Payment expenses correctly reduce payer's debt and increase recipient's balance
8. User with no payment method sees "Add payment method" prompt
9. All code passes `flutter analyze` with zero warnings
10. Balance calculation has unit tests for: equal split, unequal expenses, donation, payment expense, single payer, mixed scenario

---

## 8. Out of Scope

- Actual money transfer / payment API integration
- Unequal splits (custom per-person amounts) — V2
- Recurring expenses
- Currency conversion (single currency per event for V1)
- Push notifications for settlement reminders
