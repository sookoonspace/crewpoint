<goal>
Upgrade CrewPoint to V3 (Enterprise Operations) to support B2B, Non-Profit, and large-scale community events. The platform will now support centralized P&L budgeting (Fund Mode), nested sub-events, mass dues collection, custom spectator roles, itinerary management, and white-labeled tax receipt generation—while strictly maintaining the V1/V2 offline-first Drift cache architecture.
</goal>

<background>
**Tech stack & constraints:**
- Flutter 3.11.5 / Dart 3.x; Riverpod 3.
- Database: Live Firestore for writes (SDK queued), Drift SQLite for instant offline reads.
- Existing Math: `BalanceLedger.calculate()` must remain untouched for P2P; Fund Mode uses a new `FundLedger` aggregator.
- Drift Schema: Will bump from v4 to v5.
</background>

<domain_models>
To support enterprise templates (Sports, Corporate, Wedding, Non-Profit) without fragmenting the database, the core models expand:

**1. EventModel Expansion**
- `budgetMode`: string (`'p2p'` | `'fund'`)
- `parentId`: string? (If not null, this is a Sub-Event)
- `taxId`, `legalEntityName`: string? (For 501c3 / Corporate receipts)
- `brandPrimaryColor`, `brandSecondaryColor`, `customLogoUrl`: string?
- `isArchived`: boolean (Freezes all ledgers)

**2. ExpenseModel Expansion**
- `payerId`: string (Now accepts `'central_fund'` or an external vendor string)
- `isTaxDeductible`: boolean
- `dueDate`: timestamp? (For installment tracking, e.g., Wedding caterer deposits)
- `reimbursementStatus`: enum (`none`, `pending`, `reimbursed` — bridges P2P and Fund mode)

**3. EventMemberModel (New Subcollection & Drift Table)**
- Replaces the flat `memberIds` array for enterprise events.
- `eventId`, `userId`: string
- `role`: enum (`owner`, `admin`, `member`, `spectator`)
- `tags`: List<String> (e.g., `["paid_2026", "youth_group"]` for rolling rosters)

**4. Dues & Requests (New Models)**
- `PaymentRequestModel`: `id`, `eventId`, `title`, `amount`, `assignedToUid`, `status` (`pending`, `paid`, `confirmed`)

**5. ItineraryItemModel (New Models)**
- `id`, `eventId`, `title`, `description`, `startTime`, `endTime`, `locationUrl`
</domain_models>

<user_flows>

## Flow: Fund Mode Dashboard & Reimbursements
1. Organizer creates "Corporate Offsite" and selects **Fund Mode**.
2. Dashboard renders Central Pot: Total Budget vs Total Spent. `BalanceLedger` is bypassed.
3. Admin buys HDMI cables on personal card. Logs expense with `payerId = 'AdminUID'` and `reimbursementStatus = 'pending'`.
4. Dashboard alerts Organizer: "Outstanding Reimbursement: $200 owed to Admin".
5. Organizer cuts corporate check, taps "Mark Reimbursed".

## Flow: Mass Dues Collection (Fraternity/Non-Profit)
1. Treasurer creates Payment Request: "Annual Dues - $100". Assigns to tag `@all_members`.
2. Cloud Function fans out 100 `PaymentRequestModels` to the subcollection.
3. Members see "Action Required" on dashboard, tap to pay via V2 Zelle/Venmo link, and tap "I Paid".
4. Treasurer dashboard shows "75/100 Paid". Treasurer verifies bank, taps "Confirm", shifting funds into Central Pot.

## Flow: Sub-Events (Hybrid Architecture)
1. In the "Master Wedding Event", Admin taps "Create Sub-Event".
2. Creates "Groomsmen Villa", sets it to **Trip Mode (P2P)**.
3. Selects 8 users from the master roster using the `@groomsmen` tag.
4. Groomsmen have a completely isolated chat and P2P ledger, invisible to the main wedding dashboard.

## Flow: White-Label Tax Receipts
1. Sponsor taps their $5,000 contribution in the Fund Ledger.
2. Taps "Export Tax Receipt".
3. `DonationReceiptPdfBuilder` generates a legally compliant PDF.
4. The builder detects `brandPrimaryColor` and `customLogoUrl` on the `EventModel` and overrides the default Sookoon styling.

## Flow: The Enterprise Archive Export
1. Event finishes. Owner taps "Archive Event".
2. Cloud Function flags `isArchived = true`, triggering Firestore rules to reject any further writes.
3. Owner taps "Generate Accounting Export".
4. A Cloud Function zips the RFC-4180 CSV (containing `originalCurrency` from V2) AND every receipt image in the Storage bucket. Delivers a secure download link.
</user_flows>

<requirements>

## 1. Database & Sync (The Offline Mandate)
1. Bump Drift schema to v5. 
2. Add tables: `event_members_detailed`, `payment_requests`, `itinerary_items`.
3. Add mirror sync streams for all new collections so the Itinerary and Dashboard render instantly offline.

## 2. Role-Based Access Control (RBAC) Expansion
4. Introduce the `spectator` role.
5. Update `firestore.rules`: Spectators have `read` access to `events`, `itinerary`, and `messages` (broadcasts only), but `deny` on `expenses`, `tasks`, and writing to `messages`.

## 3. The Ledger Fork
6. `BudgetScreen` layout builder must branch based on `event.budgetMode`. 
7. If `'p2p'`, render the classic "Who owes whom" UI. If `'fund'`, render the "Income vs Expenses" progress bar UI.

## 4. Sub-Event Navigation
8. The Event Drawer/Sidebar must show a visual hierarchy: Master Events, with their linked Sub-Events nested below them.

## 5. UI Templates
9. During Event Creation, add a "Template" selector: Trip (P2P), Corporate (Fund), Non-Profit (Fund + Tax ID prompt), Wedding (Fund + Installments). Templates simply pre-configure the data model fields.
</requirements>

<validation>
- **Robot:** End-to-end dues collection (Treasurer creates -> Member marks paid -> Treasurer confirms).
- **Unit:** `DonationReceiptPdfBuilder` correctly injects `taxId` and `brandPrimaryColor` when present.
- **Rules:** Firebase emulator tests proving `spectator` role cannot read or write to `expenses`.
</validation>