# Derod Gaam Convention 2027: Test Report (v3)

**Test spec:** [`CREWPOINT_CONVENTION_TEST_v3.md`](CREWPOINT_CONVENTION_TEST_v3.md) · **Run:** Nov 3, 2026 · **Branch:** `test/derod-convention-v2`, cut from `main` at `3d83407`

**Result: CrewPoint is not ready for this event, and most of the event-specific product does not exist yet.** Of 157 scenarios, 1 passes, 20 are partial, 4 fail, 65 are not built, 61 belong to the tool you are buying, and 6 need a person or outside access. The task, budget-split, chat and push foundations are sound, but they need permissions, Gujarati, email and an import path before they can serve this event.

**Most urgent, because they apply before any real data arrives:**

1. Choose the registration tool. The requirements in section 4 narrow the field quickly.
2. Change the privacy policy. It says CrewPoint is not for under-13s, and this event registers 3-year-olds.
3. Fix permissions. Every member can read all money today, which breaks your committee and volunteer rules.
4. Turn on backups and billing alerts. There are no backup schedules on dev or prod, and no alert policies.

**How far to trust this:**

- 44 tests ran against the real app code and backend code: 18 passed and 26 failed. A failure here is a finding, and these tests sit outside CI so they don't block normal work.
- Everything ran on emulators, with mocked push. Nothing touched `crewpoint-dev` or production, and no real message was sent.
- Timings come from a Mac and a local emulator. Expect phones to be slower, and real delivery times are unmeasured.
- NOT BUILT comes from reading and searching the code. Those scenarios are registered as skipped tests, with the reason.
- The settlement fix in PR #39 is not on this branch. It does not affect any result here.

## 1. Inventory

| Area | Today |
|---|---|
| Stack | Flutter 3.47 (iOS, Android, web), Firebase Auth, Firestore, Storage, Messaging, 15 Cloud Functions on Node 22, Drift on mobile |
| Data models | Events, tasks with checklists, expenses with splits, chat messages, users. **No** family, attendee, schedule, sponsor, vendor, shift or check-in model |
| Auth | Google, Apple, email and password. **No** phone or email one-time code |
| Roles | Owner, admin and member only, enforced in rules and functions. No finance, committee, volunteer or family roles |
| Payments | None processed. Settle-up records payments between members and opens Venmo or Cash App links; it cannot collect fees |
| Notifications | Push only, with 7 categories, per-category preferences, event mute, dead-token cleanup and English templates. Quiet hours **drop** messages. No email, SMS, scheduled messages, segments, delivery log or history |
| Scheduling | Two jobs: task due reminders every 15 minutes and an hourly digest check. Neither takes an injectable clock |
| Offline | Reads work on mobile through the Drift copy. Firestore queues writes, but nothing covers check-in rules or conflicts |
| Languages | English only. The string layer is designed for more, but no Gujarati exists |
| Limits | 50 members per event, invite codes last 24 hours, one invite code per event, PDF reports stop at 200 expenses |
| Existing tests | 862 Flutter tests passing and 4 skipped on `main`, and 155 backend tests passing. One flaky timing test was seen once under load |

## 2. Scorecard

| Section | PASS | PARTIAL | FAIL | NOT BUILT | VENDOR | NOT RUN | Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| A: Event setup | · | 2 | · | 3 | · | · | 5 |
| L: Login | · | · | · | · | 5 | 2 | 7 |
| B: Registration | · | · | · | 4 | 11 | · | 15 |
| C: Fees and payments | · | · | · | · | 20 | · | 20 |
| D: Sponsorships | · | · | · | · | 15 | · | 15 |
| H: Committee | · | 2 | 1 | 4 | · | · | 7 |
| V: Volunteers | · | · | · | 4 | · | · | 4 |
| J: Event days | · | · | · | 16 | · | · | 16 |
| K: After the event | · | 1 | · | 2 | · | · | 3 |
| X: Tool integration | · | · | · | 6 | 1 | · | 7 |
| S: Scale | · | 4 | 1 | 3 | · | · | 8 |
| R: Safety | · | · | · | 6 | · | · | 6 |
| Z: Privacy | · | 1 | 1 | 3 | 2 | · | 7 |
| O: Operations | · | · | · | 5 | · | 3 | 8 |
| U: Accessibility | · | 3 | 1 | · | · | 1 | 5 |
| N: Notifications | 1 | 7 | · | 9 | 7 | · | 24 |
| **Total** | **1** | **20** | **4** | **65** | **61** | **6** | **157** |

### 2.1 Cost estimate (S-08)

A rough, worst-case model, not a measurement. Chat loads the whole history, so 400 people opening a 5,000-message chat 5 times a day could mean up to **10 million Firestore reads a day**, or low single-digit dollars a day at list prices as I recall them (check current pricing). Offline caching should reduce this. Cost is not the main risk; the 53-second slowdown per message is. Limiting chat history fixes both. SMS would be the largest variable cost if you adopt it, especially for UK numbers.

## 3. Results

| ID | Scenario | Status | Evidence | Gap | Effort | Needed by |
|---|---|---|---|---|---|---|
| A-01 | Event with dates, America/Chicago, venue address, Garland Hall. | PARTIAL | `A-01` tests in app_capability_test.dart | Title and dates are stored. There is no event time zone or venue field. | S | P1 |
| A-02 | Schedule from §1 incl. programs and kids activity; M3/K1 flagged outdoor; M8 "location… | NOT BUILT |  | No schedule or session model. | M | P1 |
| A-03 | Bilingual event name/description; Gujarati uses **દેરોદ**. Add a test that fails if… | PARTIAL | `A-03` tests | Spelling guard added and passing, but the app has no Gujarati content to guard. | L | P0 |
| A-04 | Donation item list from §1 loaded, incl. a closed item (Gala Dinner) and an item with… | NOT BUILT |  | No donation item model in CrewPoint. Depends on the tool. | M | P1 |
| A-05 | Map/directions entries: hotel address, Garland Hall, picnic park (TBD), parking. | NOT BUILT |  | No maps or directions entries. | S | P1 |
| L-01 | Google sign-in creates an account. | NOT RUN | test/app/features/auth, firebase_auth | Implemented with unit tests, but real Google and Apple sign-in needs a person on a device. | · | P0 (tool choice) |
| L-02 | Apple sign-in creates an account. | NOT RUN | test/app/features/auth, firebase_auth | Implemented with unit tests, but real Google and Apple sign-in needs a person on a device. | · | P0 (tool choice) |
| L-03 | Phone one-time code login (Meera, F3). | VENDOR | `grep` for signInWithPhoneNumber, signInWithEmailLink: no hits | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no phone or email one-time code. | · | P0 (tool choice) |
| L-04 | Email one-time code login (Savita, F4, web only). | VENDOR | `grep` for signInWithPhoneNumber, signInWithEmailLink: no hits | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no phone or email one-time code. | · | P0 (tool choice) |
| L-05 | Family contact invites a family member; invitee gets access to **that family only**. | VENDOR | `grep` for signInWithPhoneNumber, signInWithEmailLink: no hits | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no phone or email one-time code. | · | P0 (tool choice) |
| L-06 | Same person signs in with Google, later with email code using the same email → same… | VENDOR | `grep` for signInWithPhoneNumber, signInWithEmailLink: no hits | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no phone or email one-time code. | · | P0 (tool choice) |
| L-07 | Web link registration works with no app installed; app login later shows the same family. | VENDOR | `grep` for signInWithPhoneNumber, signInWithEmailLink: no hits | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no phone or email one-time code. | · | P0 (tool choice) |
| B-01 | Contact registers whole family with every per-person field: name, age (or date of… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| B-02 | Per-person arrival/departure: F4 arrives Sat 11:00am → excluded from M1, M2, P1… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| B-03 | Per-meal, per-person opt-out (Jaya M2; Ramesh & Kamla M3). | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| B-04 | Headcounts, diet totals, kids activity count, T-shirt report match §4. | NOT BUILT |  | No attendee data. Needs the roster import plus count logic. | M | P0 (tool choice) |
| B-05 | Per-meal counts match §4 table, by diet. | NOT BUILT |  | No attendee data. Needs the roster import plus count logic. | M | P0 (tool choice) |
| B-06 | Family member (Meera) edits registration → counts update; audit shows who changed what. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| B-07 | Hotel section: intent (rooms, nights), confirmation number field; booking link + code… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| B-08 | Directory opt-in setting per family (default **off**). | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| B-09 | Registration form fully usable in Gujarati. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| B-10 | Export registrations + per-meal diet counts to CSV/Excel for the caterer. | NOT BUILT |  | No registration or per-meal export, and no freeze. | M | P0 (tool choice) |
| B-11 | Duplicate handling: system flags F10 as a likely duplicate; committee merges into F3;… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| B-12 | Capacity: admin sets a limit (400); registration past it goes to a waitlist; a… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| B-13 | Registration closes on a set date; later changes need committee help. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| B-14 | Caterer count freeze: admin locks meal counts on a date; later changes are listed as a… | NOT BUILT |  | No registration or per-meal export, and no freeze. | M | P0 (tool choice) |
| B-15 | After the Jul 3 hotel cutoff: the booking link is replaced by "call the hotel" and… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-01 | Hybrid fee calculation for every family matches §4 (incl. F4 single adult, F5 three… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-02 | Card payment in app (sandbox) → paid + receipt. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-03 | Zelle: family marks "sent by Zelle" → status **pending**; finance confirms → **paid**… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-04 | Check (#1043) and cash recorded by finance with method and reference. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-05 | Pay at check-in: F6 shows "$300 due at check-in"; volunteer at desk records card/cash;… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-06 | F8 cancels after paying → refund $300 (sandbox) or credit; removed from all counts and… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 |
| C-07 | Receipts name the nonprofit and payment method. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-08 | Fee settings changeable by admin (family fee, extra-adult fee, kid age) and totals… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-09 | F1 adds a third adult after paying → owes **+$150**, and the unpaid reminder restarts… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-10 | F5 removes Rohan after paying $450 → **$150** refund due, handled by finance. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-11 | Partial cancellation: one person cancels, the family stays, counts and fee recalculate. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-12 | No-show: a family never checks in; pay-at-check-in F6 would stay owing $300 and is… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-13 | Refund window: the cancellation deadline and refund percentage are settings. `[OWNER… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-14 | Zelle never arrives: finance rejects the pending report → the family is told and… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-15 | Zelle amount differs from the fee → finance records the actual amount; the balance… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-16 | Partial payment: F3 pays $300 of $600 → balance $300; reminders use the new balance. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-17 | Failed card: the family stays unpaid and is told why; no receipt. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-18 | Double submit or retried webhook → one charge and one receipt. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-19 | Chargeback: finance is notified; the family returns to owing. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| C-20 | Card processing fee: report net vs gross. Who absorbs the fee is `[OWNER INPUT]`. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-01 | Family picks an open item to sponsor and pledges an amount. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-02 | Several families share one item; % pledged and % received shown (Sun Lunch: 100% / 60%). | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-03 | Fully pledged and closed items can't be picked (Sun Lunch after F2, Gala Dinner). | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-04 | Pledge now, pay later; pledged vs received tracked; totals match §4. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-05 | General tier sponsorship (F6 Gold) not tied to an item. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-06 | Public thank-you list: names only, recognition opt-in respected, no amounts. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-07 | Business/vendor sponsor (non-family) can be added by finance. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-08 | Sponsor receipts. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-09 | F2 cancels the pledge → Sun Lunch reopens with $1,999 remaining; the reminder stops. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-10 | F2 pays $1,000 of $1,999 → received $4,001; reminders continue for $999. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-11 | A pledge above the remaining amount is rejected, or offered the remainder. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-12 | Two families pledge the last $1,999 at the same moment → one succeeds, the other is told. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-13 | Non-shareable items (Gala music/DJ, Photography & video) accept one sponsor for the… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-14 | Bhajan Prasad gets an amount later → existing pledges count toward it. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 (tool choice) |
| D-15 | Donation receipts name the nonprofit and EIN, the date and amount, and state whether… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 |
| H-01 | Committee sub-teams (food, hotel, program, finance, picnic, registration); members… | NOT BUILT |  | No sub-teams. Only owner, admin and member exist. | M | P1 |
| H-02 | Tasks with owner, due date, status, sub-team; overdue highlighted. | PARTIAL | `H-02` test, lib/app/features/tasks/application/tasks_filter.dart | Owner, due date, status and overdue filter work. No sub-team on tasks. | S | P1 |
| H-03 | Vendors (caterer, DJ, decorator, photographer, hotel bar) with contacts, contract… | NOT BUILT |  | No vendor model, contracts or deadlines. | M | P1 |
| H-04 | Budget: estimate vs actual per line; visible to admin/finance only. | NOT BUILT |  | Only a display-only `budgetEstimate` per task, readable by every member. No budget lines or actuals. | M | P1 |
| H-05 | Permissions matrix from §2 — one test per role per restricted screen/API (UI **and**… | PARTIAL | `H-05` tests (3 pass, 4 fail) | Outsiders are blocked, and members cannot change event settings. But every member can read all expenses and task budgets, and any signed-in user can read anyone's payment handles. Needs finance, committee and volunteer roles enforced in firestore.rules. | L | P0 |
| H-06 | Dual roles: Amit (F1 contact, program committee) sees F1's fee and receipts, and no… | NOT BUILT |  | No scoped roles exist. | M | P0 |
| H-07 | Removing someone from the committee ends access immediately, including tasks, money… | FAIL | `H-07` tests (3 fail), firestore.rules, removeEventMember.ts | Removed members can still edit their old expenses and assigned tasks, and can rejoin with the same code for 24 hours. | S | P1 |
| V-01 | Shift schedule per volunteer. | NOT BUILT |  | No shifts, scanner, counter or issue reports. | L | P2 |
| V-02 | QR check-in scanner (see J-01). | NOT BUILT |  | No shifts, scanner, counter or issue reports. | L | P2 |
| V-03 | Meal-line counter: tap to count plates served by diet (V/J/N) per meal; totals visible… | NOT BUILT |  | No shifts, scanner, counter or issue reports. | L | P2 |
| V-04 | Report an issue (category, text, optional photo): "food running low" → food team;… | NOT BUILT |  | No shifts, scanner, counter or issue reports. | L | P2 |
| J-01 | QR code per family (in app and in email); scanning checks in the family and lets the… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-02 | QR contains a token only — no names, phone, or email encoded. | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-03 | Walk-in: committee registers F9 at the door, takes $300 cash, prints/shows QR; counts… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-04 | Offline: check-in and meal counts work with no network; queue syncs later; same family… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-05 | Live schedule "now & next" for everyone. | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-06 | Personal agenda per family/person (F4 sees nothing before Sat 11am; F3 elders don't… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-07 | Live update: a **committee member** (not admin) changes M3 location to "Garland Hall… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-08 | Directory shows only opted-in families, never contact details. | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-09 | Language toggle EN ⇄ GU on every event-day screen. | NOT BUILT | `J-09` test | English only. No Gujarati strings, and no language setting in the app. | L | P2 |
| J-10 | Unpaid check-in: F3 is scanned with $600 due → check-in **succeeds**, the volunteer… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-11 | Scanning a cancelled family's QR (F8) or a merged one (F10) is rejected with a clear… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-12 | Scanning the same family twice shows "already checked in at <time>" and does not… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-13 | No QR: the volunteer finds the family using the limited name search in §2, and the… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-14 | Paper fallback: admin prints a roster and meal sheet the night before, in case phones… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-15 | Partial arrival: part of a family checks in now and the rest later; both are recorded… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| J-16 | Scanners stay signed in with no network for the whole shift, and a lost scanner can be… | NOT BUILT |  | No check-in, QR, agenda, live schedule or directory. Offline covers reads only. | L | P2 |
| K-01 | Final reconciliation for finance: fees + sponsorship received vs actual spend. | NOT BUILT |  | No reconciliation or sponsor messaging. | M | P3 |
| K-02 | Bulk thank-you to sponsors with receipts. | NOT BUILT |  | No reconciliation or sponsor messaging. | M | P3 |
| K-03 | Export all event data (for the next host city). | PARTIAL | `K-03` tests (1 pass, 2 fail) | Expense CSV is complete, but cells starting with `=` are not neutralised, the PDF stops at 200 expenses, and there is no full export. | M | P3 |
| X-01 | Import a roster of 400 people from the tool's export into CrewPoint, with all… | NOT BUILT |  | No import path. This is the new work created by buying registration. | L | P1 |
| X-02 | Re-import is safe: new families added, changes updated, nothing duplicated, and manual… | NOT BUILT |  | No import path. This is the new work created by buying registration. | L | P1 |
| X-03 | A family cancelled in the tool is removed from counts and its QR is revoked on the… | NOT BUILT |  | No import path. This is the new work created by buying registration. | L | P1 |
| X-04 | Payment status and balance are imported, and a payment recorded at the door is… | NOT BUILT |  | No import path. This is the new work created by buying registration. | L | P1 |
| X-05 | A person signing in to CrewPoint is matched to their imported family by email or… | NOT BUILT |  | No import path. This is the new work created by buying registration. | L | P1 |
| X-06 | Import errors (missing diet, unknown age, duplicate email) are listed, and do not stop… | NOT BUILT |  | No import path. This is the new work created by buying registration. | L | P1 |
| X-07 | Tool outage or cancelled subscription: all data can still be exported. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P1 |
| S-01 | 400 people can belong to the event (the 50-member cap must not block this). | FAIL | `S-01` tests, functions/src/events/joinEvent.ts:6 | joinEvent stops at 50 members, and invite codes expire after 24 hours. | S | P1 |
| S-02 | Import of 108 families finishes within **2 min** and headcounts match. | NOT BUILT | `S-02` test | No import path to measure. | M | P1 |
| S-03 | The 7:00am morning summary to 400 recipients is fully handed to the mock transport… | PARTIAL | `S-03` tests (1 pass, 1 fail) | A 400-person send took about 2 s on the local emulator with a mock transport, inside the 30 s limit. Every recipient gets the same text, so a personal agenda is not possible yet. Production timing not measured. | M | P2 |
| S-04 | Live update delivered to 400 within **60 s** (mock). | PARTIAL | `S-04` test | Delivery path handled 400 in about 2 s on the local emulator. There is no live-update feature using it, and real delivery time is not measured. | M | P2 |
| S-05 | Check-in rush: 108 families over 60 min on 4 scanners, with each scan under **2 s**… | NOT BUILT |  | No check-in or meal counting to load. | L | P2 |
| S-06 | Meal line: 400 plates in 45 min across 2 counters, totals correct. | NOT BUILT |  | No check-in or meal counting to load. | L | P2 |
| S-07 | Event screens stay usable with 400 members: chat with **5,000 messages**, member list,… | PARTIAL | `S-07` tests (1 pass, 1 fail), chat_repository.dart | The ledger is fast at 400 members. One new message with 5,000 in chat took about 53 s and 4,902 screen updates on a Mac. | M | P2 |
| S-08 | Monthly cost estimate for reads, writes, function runs, email and SMS at this size. | PARTIAL |  | Rough estimate only, in section 2.1. Needs real traffic numbers. | S | P1 |
| R-01 | Allergy and medical notes per person, kept separate from diet, visible to the food… | NOT BUILT |  | No safety features or fields. | M | P2 |
| R-02 | Emergency contact per family, visible to admins only and available offline. | NOT BUILT |  | No safety features or fields. | M | P2 |
| R-03 | Medical emergency issue category: alerts admins and committee at once, bypassing quiet… | NOT BUILT |  | No safety features or fields. | M | P2 |
| R-04 | Weather or outdoor change: moving M3/K1 indoors reaches everyone, including those who… | NOT BUILT |  | No safety features or fields. | M | P2 |
| R-05 | Kids activity sign-in and sign-out by a named guardian. | NOT BUILT |  | No safety features or fields. | M | P2 |
| R-06 | Lost child alerts need an acknowledgement, and go back out if nobody responds within… | NOT BUILT |  | No safety features or fields. | M | P2 |
| Z-01 | Children's data: only a parent enters it, birth dates are not shown to committee or… | FAIL | assets/legal/privacy-policy.md:94 | The privacy policy says CrewPoint is for ages 13 and up and does not knowingly collect data from under-13s. This event registers children as young as 3. Needs a policy change and legal review. | M | P0 |
| Z-02 | Photo and video consent per family, including children, available to the photographer. | NOT BUILT |  | No consent record or retention rule for event data. | S | P0 |
| Z-03 | Liability waiver accepted at registration and recorded `[OWNER INPUT]`. | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 |
| Z-04 | UK and Canadian attendees: consent, access and deletion requests work, and the privacy… | PARTIAL | `Z-04` tests (2 fail), deleteUserAccount.ts | The policy covers EU/UK rights and deletion exists, but the user ID stays in expense splits and tasks, and personal subcollections survive. Canada is not mentioned. | M | P0 |
| Z-05 | Email has a working unsubscribe for non-essential messages; SMS (if used) is… | NOT BUILT |  | No email or SMS, so no unsubscribe. | S | P0 |
| Z-06 | Tax and legal wording on receipts is approved, and records are kept for the required… | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. | · | P0 |
| Z-07 | Data retention after the event: what is deleted, what passes to the next host (K-03),… | NOT BUILT |  | No consent record or retention rule for event data. | S | P3 |
| O-01 | Billing alerts, budget caps and a named owner. A lapsed billing account must not be… | NOT RUN | gcloud billing budgets: permission denied | All projects lost billing until Nov 2, 2026. Budget alerts could not be checked: this login has no access to the billing account. | S | P0 |
| O-02 | Crash reporting and backend error alerts reach a person during event hours. | NOT BUILT | pubspec.yaml; Cloud Monitoring API: 0 policies | No crash reporting or analytics packages, and no alert policies on dev or prod. | S | P1 |
| O-03 | Automated Firestore backups, with a restore rehearsed. | NOT BUILT | gcloud firestore backups schedules list: 0; databases describe: PITR disabled | No backup schedules on dev or prod, and point-in-time recovery is off. Data loss today would be permanent. | S | P0 |
| O-04 | Email domain authenticated (SPF, DKIM, DMARC), with bounce handling and a test send to… | NOT BUILT |  | No email sending or domain setup in the repo. | S | P0 |
| O-05 | App approved in the App Store and Google Play before announcement, with enough lead… | NOT RUN |  | Needs store console access or a visit to the venue. | · | P1 |
| O-06 | Release freeze from Jul 9, with a rollback plan; old app versions keep working. | NOT BUILT |  | No release freeze or on-call plan. | S | P2 |
| O-07 | Venue network test at the Hyatt: Wi-Fi and cell coverage in Garland Hall and at the… | NOT RUN |  | Needs store console access or a visit to the venue. | · | P2 |
| O-08 | Event-day on-call plan and contacts. | NOT BUILT |  | No release freeze or on-call plan. | S | P2 |
| U-01 | Readable at 200% system text size, on every family and volunteer screen. | PARTIAL | `U-01` test | The dashboard is fine at 200% text. Other screens are untested, and family and volunteer screens do not exist. | M | P1 |
| U-02 | Screen reader labels on registration, agenda and check-in. | PARTIAL | `U-02` test | Dashboard tap targets are labelled and sized. Other screens are untested. | M | P1 |
| U-03 | Gujarati renders correctly (spelling **દેરોદ**) on iOS, Android, web, email and PDF… | FAIL | `U-03` tests (1 pass, 1 fail) | Gujarati is lost from PDF reports: Latin text extracts, Gujarati does not. Phone, web and email rendering are untested. Also see issue #29. | S | P1 |
| U-04 | Colour contrast meets WCAG AA in light and dark mode. | PARTIAL | test/app/core/constants/app_colors_contrast_test.dart | The current palette is checked by existing tests. New screens are not built. | S | P1 |
| U-05 | An older non-technical user (Savita, 74) can complete web registration and find her… | NOT RUN |  | Needs a real session with an older user, once the screens exist. | · | P2 |
| N-00 | Safety | PASS | `N-00` test | Push goes only through a mocked transport on the emulator. Email has no transport at all yet. | · | P2 |
| N-01 | Registration confirmation | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no email sending. | · | P0 (tool choice) |
| N-02 | Family member invite | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no email sending. | · | P0 (tool choice) |
| N-03 | Payment receipt | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no email sending. | · | P0 (tool choice) |
| N-04 | Unpaid fee reminder | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no email sending. | · | P0 (tool choice) |
| N-05 | Hotel not booked | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no email sending. | · | P0 (tool choice) |
| N-06 | Pledge not received | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no email sending. | · | P0 (tool choice) |
| N-07 | Know before you go | NOT BUILT |  | No email, segments, scheduled messages, history or de-duplication. | L | P2 |
| N-08 | Morning summary | PARTIAL | `N-08` test, onDigestSummary.ts:14 | A daily digest exists, but it is opt-in, fires at 9:00am, and summarises tasks rather than an agenda. | M | P2 |
| N-09 | 15-minute session reminder | NOT BUILT | `N-09` test | Reminders exist for tasks only. Quiet hours also use the profile time zone, so F5's 6:45pm reminder would be dropped. | M | P2 |
| N-10 | Quiet hours by recipient zone | PARTIAL | `N-10` tests (1 pass, 1 fail), suppress.ts | The quiet-hours window is right for each time zone, but a blocked message is dropped rather than sent at 7:00am. | M | P2 |
| N-11 | Live schedule change | PARTIAL | `N-11` test | Urgent chat bypasses quiet hours, which is the path a live update could use. There is no schedule-change message or email. | M | P2 |
| N-12 | Segment messages | NOT BUILT |  | No email, segments, scheduled messages, history or de-duplication. | L | P2 |
| N-13 | Volunteer shift reminder | NOT BUILT |  | No email, segments, scheduled messages, history or de-duplication. | L | P2 |
| N-14 | Issue alerts | PARTIAL | `N-14` test | Urgent chat exists, but a muted event blocks it, so a lost-child alert can be missed. No issue categories. | S | P2 |
| N-15 | Cancellation | VENDOR |  | Requirement for the bought tool. Not testable until one is chosen. CrewPoint has no email sending. | · | P0 (tool choice) |
| N-16 | Opt-out | PARTIAL | `N-16` test | Per-category opt-out works for push. No email categories. | S | P1 |
| N-17 | De-duplication | NOT BUILT |  | No email, segments, scheduled messages, history or de-duplication. | L | P1 |
| N-18 | Delivery failure | PARTIAL | `N-18` tests (1 pass, 1 fail) | Dead tokens are removed. Failures are not logged anywhere staff can see, and there is no email fallback. | M | P1 |
| N-19 | Scheduled message admin | NOT BUILT |  | No email, segments, scheduled messages, history or de-duplication. | L | P1 |
| N-20 | History | NOT BUILT |  | No email, segments, scheduled messages, history or de-duplication. | L | P1 |
| N-21 | Language switch | PARTIAL | `N-21` test | Per-recipient language lookup exists, with English templates only. | M | P2 |
| N-22 | Web-only coverage | NOT BUILT |  | No email, segments, scheduled messages, history or de-duplication. | L | P2 |
| N-23 | Finance: unpaid check-in | NOT BUILT |  | No email, segments, scheduled messages, history or de-duplication. | L | P2 |

## 4. Priorities by the real calendar

**P0: before announcing registration (Nov–Dec 2026)**

- **Choose the tool.** Check these first, because they are hardest to find: hybrid family fee (C-01), per-person meal choices and arrival times (B-01, B-03), Gujarati forms and emails (B-09, N-01), Zelle pending and offline payments (C-03, C-04), full data export (X-01), and sponsorship items with shared funding (D-02).
- **Privacy and legal:** Z-01, Z-03, Z-04, Z-05 and Z-06, including the nonprofit's legal name, EIN and receipt wording (D-15).
- **Permissions:** H-05 and H-06, before committee members and real data arrive.
- **Resilience:** O-01 billing alerts, O-03 backups, O-04 email domain.

**P1: sponsorship and hotel push (Jan–Jun 2027)**

- Roster import (X), schedule and venue (A), sub-teams, vendors and budget (H), the 50-member cap (S-01), and app store approval (O-05).
- Accessibility (U-01…U-04) and notification controls (N-16…N-20).

**P2: final week and event days (Jul 2027)**

- QR check-in, offline sync, meal counter, agenda and live updates (J, V), safety (R), and scale rehearsal (S-03…S-07).
- Event-week messages in both languages, by push and email (N-07…N-14, N-21…N-23). Rehearse before the Jul 9 release freeze (O-06).

**P3: after the event**

- Reconciliation, sponsor thank-yous, export, and data retention (K, Z-07).

## 5. Top 10 gaps

1. **No event data in CrewPoint.** Build a roster import from the tool's export into new family and attendee models (X-01…X-06). Everything on event days depends on it. Decide the export format once the tool is chosen.
2. **Permissions do not match your roles.** Add finance, committee, volunteer and family roles. Move money into documents only finance and admins can read, since Firestore rules cannot hide single fields. Add a test per role (H-05, H-06).
3. **Privacy policy excludes this event's children.** Update the policy with counsel, add parental entry, and show age bands rather than birth dates (Z-01).
4. **No Gujarati.** Add the Gujarati strings through the existing string layer, a language setting, translated templates and a PDF font that supports Gujarati. Use a human translator and keep the spelling check (A-03, J-09, N-21, U-03).
5. **No email.** Add an email provider with an authenticated domain, unsubscribe and bounce handling. Web-only families depend on it (N-07, N-22, O-04).
6. **No check-in or offline event-day flow.** Build family QR tokens, a scanner, the limited name search, an offline queue with a clear conflict rule, and a printed fallback (J, V). This is the largest single build, so prototype it early and test it at the hotel.
7. **Scale limits.** Replace the 50-member cap, and load chat in pages while saving only what changed. That one change removes the 53-second slowdown and most of the read cost (S-01, S-07).
8. **Messages are dropped, not delayed, and cannot be scheduled.** Add a scheduled message queue that holds quiet-hours messages until 7:00am, uses event time during the event, and supports per-person content. Emergency alerts should ignore event mute (N-09, N-10, N-14, S-03).
9. **Removed members keep access.** Check current membership in the rules for expenses, tasks and messages, and rotate or block invite codes on removal. A small, high-value fix (H-07).
10. **No safety net.** Turn on scheduled backups, billing alerts and crash reporting, and name an on-call person. Small tasks, and yesterday's billing outage shows why they matter (O-01…O-03, O-08).

## 6. Testability gaps

- **No clock seam in the backend.** `sendCategorizedPush` and the scheduled jobs call `new Date()` directly. The N-10 test works around it by faking only `Date` in Jest. Anything that schedules messages should take a clock.
- **No email or SMS transport to mock.** N-00 can only prove safety for push.
- **Scheduled jobs have no recipient-level result.** `sendCategorizedPush` returns only counts, and skipped messages are not recorded, so recipient assertions must inspect the mock.
- **Real sign-in and real delivery.** Google and Apple sign-in, APNs and FCM delivery need real devices and accounts (L-01, L-02).
- **Not checked: Storage rules, store listings, billing budgets (no access), venue network.**
- **Live device testing was stopped at your request** before any test account was created. The Android and iOS builds succeeded, and the app launched on both. A manual two-account pass on dev is still worth doing for the features that exist.
- **Vendor scenarios** cannot run until a tool is chosen. Rerun them against the tool, using the same fixture.

## 7. Assumptions

| Assumption | What the app does now | Recommendation |
|---|---|---|
| A 1-adult family pays $300 | No fee logic. Tool requirement | Confirm |
| Age is computed on Jul 16, 2027 | No age data | Keep, and collect birth year or an under-18 flag if the tool allows, to hold less about children |
| The buy/CrewPoint split in §1.1 | New | Confirm, especially sponsorships |
| Sign-in with Google, then email code, is one account (L-06) | Not built; depends on the tool | Keep |
| Bhajan Prasad accepts any amount before one is set | Not built | Keep |
| Pledged-but-unpaid sponsors appear on the thank-you list | Not built | Confirm: consider listing only after receipt |
| F5's pre-event nights get the group rate | Outside the app | Ask the hotel |
| Volunteers can search by family name if QR fails | Not built | Keep, with logging |
| Duplicate who already paid goes to finance | Not built | Keep |
| Walk-ins past capacity need admin override | Not built | Confirm the real hall limit with the hotel |
| Paid families are not re-billed after a fee change | Not built | Keep |
| Pay-at-check-in families get no unpaid reminder | Not built | Keep, with one reminder in N-07 |
| Web-only users get no session reminders | No email at all | Keep; email every 15 minutes would be noise |
| Quiet hours are 9:00pm–7:00am, deferred not dropped | User-set window; **drops** messages | Keep; requires a build |
| Event time applies to quiet hours Jul 16–19 | Uses the profile time zone | Keep; requires a build |
| Pledge reminders stop at event start | Not built | Confirm |
| Event-day messages reach each family member with a login | Not built | Keep |
| Shift reminders the day before at 6:00pm, and 30 minutes before | Not built | Keep |
| Opted-out families still get receipts and live changes | Per-category opt-out exists for push | Keep, and have counsel check it against email rules |
| Lost-child alerts re-send after 2 minutes with no acknowledgement | Not built | Confirm with whoever runs safety |
| Registration is a bought tool even for per-meal data | New | If no tool handles per-meal choices, collect them in a follow-up form and import |

**Owner input still needed:** nonprofit legal name and EIN, refund policy (C-13), who absorbs card fees (C-20), waiver text (Z-03), whether to adopt SMS for emergencies (N-14).

## How to re-run

```bash
flutter test test_convention/
cd functions && npx firebase emulators:exec --only firestore,auth \
  "npx jest --runInBand --config jest.convention.config.js"
```
