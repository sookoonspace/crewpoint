# Derod Gaam Convention 2027: Test Report (v3)

**Test spec:** [`CREWPOINT_CONVENTION_TEST_v3.md`](CREWPOINT_CONVENTION_TEST_v3.md) · **Run:** Nov 17, 2026, at the end of Stage 1, on `main` at `07d76e9` · **First run:** Nov 3, 2026

**Result: Stage 1, the platform foundation, is complete, but CrewPoint cannot run this event yet.** Registration and payments arrive in Stage 2, email and Gujarati in Stage 3, and event-day check-in in Stage 5. Of 157 scenarios, 31 pass, 14 are partial, 1 fails, 47 are not built, 61 are platform requirements for later stages, and 3 need a person or outside access. On Nov 3, 2 passed.

**What Stage 1 changed for this event:**

- **Permissions:** twelve preset roles plus custom ones, checked in the rules and on the server, with money kept from everyone who should not see it (H-01, H-05, H-06, H-07).
- **People:** attendees and groups, children included, with custom fields, private details and age bands, a roster import with re-import and cancellations, and accounts linked to their own records by verified email (X-01…X-06, Z-01, PA-05).
- **Schedule:** sessions and venues, attendance policies and a personal agenda that works offline (A-01, A-02, A-05, J-05, J-06).
- **Counts:** headcounts and per-session counts on the server, with CSV export and frozen counts for suppliers (B-04, B-05, B-10, B-14).
- **Scale and safety net:** no 50-member cap, long-lived invites, paged chat, measured load at 400 and 2,000 people, rehearsed restores, crash reporting, backend error alerts and an outside billing check (S-01, S-02, S-07, S-08, O-01…O-03).

**Most urgent now:**

1. **Get the privacy policy approved by a lawyer.** Stage 1 runs only on dev until then, and prod still has the code from before Stage 1 (Req 39).
2. **Choose how registration opens.** Building it is Stage 2. A bought tool, brought in through the roster import, is the stopgap if registration must open first (L6).
3. **Finish the live check on dev:** setting up each event type from its template on a real phone and on web (#95).
4. **Set up an email domain** before Stage 3 needs it (O-04).

**How far to trust this:**

- 93 acceptance tests ran against the real app and backend code: 82 passed and 11 failed. A failure is a planned gap for a later stage unless the scenario is on the finished list, which CI protects.
- The tests run on emulators with mocked push, and no message was sent. Live checks were made on dev, with throwaway data: the Stage 1 rollout, Google and Apple sign-in and linking (L-01, L-02), crash reporting on iOS, Android and web (O-02), both alert emails reaching both inboxes (O-01, O-02), and a restore (O-03).
- Timings come from a Mac and local emulators ([load baselines](load-baselines.md)). Expect phones to be slower, and real delivery times are unmeasured.
- NOT BUILT comes from reading and searching the code. Those scenarios are registered as skipped tests, with the reason.

## 1. Inventory

| Area | Today |
|---|---|
| Stack | Flutter 3.47 (iOS, Android, web), Firebase Auth, Firestore, Storage, Messaging, 52 Cloud Functions on Node 22, Drift on mobile |
| Templates | Blank, Party, Wedding, Cricket tournament, Golf outing and Convention, plus templates saved from an event. The same code serves every type |
| Data models | Events with modules, labels, statuses and time zones; roles, crews and member documents; attendees and groups with custom fields and private details; sessions and venues; counts and frozen counts; tasks, expenses and chat. **No** registration, payment, pass, sponsor, vendor, shift or check-in model |
| Auth | Google, Apple, email and password, with accounts linked to attendee records by verified email. **No** phone or email one-time code |
| Roles | Twelve presets and custom roles from a permission catalogue, co-owners and ownership transfer, crews, and own-group access for a group's adults |
| Payments | None processed. Settle-up records payments between members and opens Venmo or Cash App links; it cannot collect fees |
| Notifications | Push only, with per-category preferences, event mute and dead-token cleanup, reading recipients in batches up to 5,000. Quiet hours still **drop** messages. No email, SMS, scheduled messages, segments or delivery log |
| Scheduled jobs | Task reminders, the digest, event status changes, counts every 5 minutes and import cleanup |
| Offline | Schedule, agenda, tasks and chat read from the device copy, showing when they were last updated. Firestore queues writes, but nothing covers check-in rules or conflicts |
| Languages | English only. Labels are renameable per event, and the string layer is ready for Gujarati |
| Limits | An optional member limit per event; invites last until the event starts or up to 400 days; the expense PDF stops at 200 expenses |
| Operations | Daily backups with a rehearsed restore, point-in-time recovery, uptime and backend error alerts, an hourly billing check outside Google Cloud, and crash reporting (dev) |
| Tests | 1,574 Flutter tests and 1,265 backend tests pass, plus the acceptance suites. Every preset role is checked against every restricted path |

## 2. Scorecard

PLATFORM marks what the first run expected a bought tool to do. CrewPoint now builds these itself, in the stage shown in section 3 (L6).

| Section | PASS | PARTIAL | FAIL | NOT BUILT | PLATFORM | NOT RUN | Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| A: Event setup | 3 | 1 | · | 1 | · | · | 5 |
| L: Login | 2 | · | · | · | 5 | · | 7 |
| B: Registration | 4 | · | · | · | 11 | · | 15 |
| C: Fees and payments | · | · | · | · | 20 | · | 20 |
| D: Sponsorships | · | · | · | · | 15 | · | 15 |
| H: Committee | 5 | · | · | 2 | · | · | 7 |
| V: Volunteers | · | · | · | 4 | · | · | 4 |
| J: Event days | 2 | · | · | 14 | · | · | 16 |
| K: After the event | · | 1 | · | 2 | · | · | 3 |
| X: Tool integration | 5 | · | · | 1 | 1 | · | 7 |
| S: Scale | 4 | 2 | · | 2 | · | · | 8 |
| R: Safety | · | · | · | 6 | · | · | 6 |
| Z: Privacy | 2 | · | · | 3 | 2 | · | 7 |
| O: Operations | 3 | · | · | 3 | · | 2 | 8 |
| U: Accessibility | · | 3 | 1 | · | · | 1 | 5 |
| N: Notifications | 1 | 7 | · | 9 | 7 | · | 24 |
| **Total** | **31** | **14** | **1** | **47** | **61** | **3** | **157** |

### 2.1 Cost (S-08)

Measured on emulators rather than modelled: a count run reads about 1.3 documents per person, a roster page 51, and a push 2 per recipient. Chat now loads 50 messages at a time and stores only what changed, which removed the first run's worst case of 10 million reads a day. Costs and the monthly estimate are in [load baselines](load-baselines.md).

## 3. Results

| ID | Scenario | Status | Evidence | Gap | Next | Needed by |
|---|---|---|---|---|---|---|
| A-01 | Event with dates, America/Chicago, venue address, Garland Hall. | PASS | `A-01` tests (3 pass) | Built in #59 and #81: title, dates, the America/Chicago zone, and venues with address, map link and directions. | · | P1 |
| A-02 | Schedule from §1 incl. programs and kids activity; M3/K1 flagged outdoor; M8 "location… | PASS | `A-02` tests (1 pass) | Built in #81: sessions over several days with type, tags, venue, placeholder times to be confirmed, and a location to be announced. | · | P1 |
| A-03 | Bilingual event name/description; Gujarati uses **દેરોદ**. Add a test that fails if… | PARTIAL | `A-03` tests (1 pass, 1 fail) | Spelling guard added and passing, but the app has no Gujarati content to guard. | Stage 3 | P0 |
| A-04 | Donation item list from §1 loaded, incl. a closed item (Gala Dinner) and an item with… | NOT BUILT | · | No donation item model. Contributions arrive in Stage 2. | Stage 2 | P1 |
| A-05 | Map/directions entries: hotel address, Garland Hall, picnic park (TBD), parking. | PASS | `A-05` tests (1 pass) | Built in #81: venues hold an address (or to be announced), a map link and directions, listed by venue on the schedule. | · | P1 |
| L-01 | Google sign-in creates an account. | PASS | Manual, recorded | Manual, in #94, on crewpoint-dev on Nov 17, 2026. Google sign-in worked live on the iOS simulator (iPhone 16) and on the dev website, with a test account that already used a password: Google was added to that account rather than creating a second one. Linking by verified email worked live twice: after sign-in the test account was linked to a throwaway participant carrying its email and joined the event as a Participant, and the event's owner, signing in with Google on the simulator, was linked without losing the Owner role. Signing in again on web linked nothing new, as expected. Creating a brand-new account is covered by unit tests, because both test accounts already existed. The throwaway event was deleted afterwards. | · | P0 |
| L-02 | Apple sign-in creates an account. | PASS | Manual, recorded | Manual, in #94, on crewpoint-dev on Nov 17, 2026. Apple sign-in worked live on the iOS simulator (iPhone 16e, iOS 26.3), sharing the real email: Apple was added to the owner's existing account (which already used Google) rather than creating a second one, the email stayed verified, and the Owner role was kept. Creating a brand-new account is covered by unit tests, because the test account already existed. Linking by verified email works the same way for Apple and was checked live with Google (see L-01). | · | P0 |
| L-03 | Phone one-time code login (Meera, F3). | PLATFORM | · | Platform requirement for Stage 2 (one-time code sign-in and RSVP links), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| L-04 | Email one-time code login (Savita, F4, web only). | PLATFORM | · | Platform requirement for Stage 2 (one-time code sign-in and RSVP links), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| L-05 | Family contact invites a family member; invitee gets access to **that family only**. | PLATFORM | · | Platform requirement for Stage 2 (one-time code sign-in and RSVP links), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| L-06 | Same person signs in with Google, later with email code using the same email → same… | PLATFORM | · | Platform requirement for Stage 2 (one-time code sign-in and RSVP links), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| L-07 | Web link registration works with no app installed; app login later shows the same family. | PLATFORM | · | Platform requirement for Stage 2 (one-time code sign-in and RSVP links), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| B-01 | Contact registers whole family with every per-person field: name, age (or date of… | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| B-02 | Per-person arrival/departure: F4 arrives Sat 11:00am → excluded from M1, M2, P1… | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| B-03 | Per-meal, per-person opt-out (Jaya M2; Ramesh & Kamla M3). | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| B-04 | Headcounts, diet totals, kids activity count, T-shirt report match §4. | PASS | `B-04` tests (4 pass) | Built in #83: counts on the server give 7 groups, 16 adults, 10 children, 26 people, 18/2/6 by diet, 7 kids activity sign-ups and a T-shirt report summing to 26 after import and cancelling F8. | · | P0 |
| B-05 | Per-meal counts match §4 table, by diet. | PASS | `B-05` tests (1 pass) | Built in #83: per-session counts by diet match the §4 table for M1–M8, from arrivals, departures and opt-outs. | · | P0 |
| B-06 | Family member (Meera) edits registration → counts update; audit shows who changed what. | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| B-07 | Hotel section: intent (rooms, nights), confirmation number field; booking link + code… | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| B-08 | Directory opt-in setting per family (default **off**). | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| B-09 | Registration form fully usable in Gujarati. | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| B-10 | Export registrations + per-meal diet counts to CSV/Excel for the caterer. | PASS | `B-10` tests (2 pass) | Built in #84: counts export to CSV per session by category and field, and the roster exports through exportRoster; private fields only when chosen. | · | P0 |
| B-11 | Duplicate handling: system flags F10 as a likely duplicate; committee merges into F3;… | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| B-12 | Capacity: admin sets a limit (400); registration past it goes to a waitlist; a… | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| B-13 | Registration closes on a set date; later changes need committee help. | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| B-14 | Caterer count freeze: admin locks meal counts on a date; later changes are listed as a… | PASS | `B-14` tests (2 pass) | Built in #84: freezeCounts keeps the numbers with the date; the counts screen lists later changes and exports them for the caterer. | · | P0 |
| B-15 | After the Jul 3 hotel cutoff: the booking link is replaced by "call the hotel" and… | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-01 | Hybrid fee calculation for every family matches §4 (incl. F4 single adult, F5 three… | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-02 | Card payment in app (sandbox) → paid + receipt. | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-03 | Zelle: family marks "sent by Zelle" → status **pending**; finance confirms → **paid**… | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-04 | Check (#1043) and cash recorded by finance with method and reference. | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-05 | Pay at check-in: F6 shows "$300 due at check-in"; volunteer at desk records card/cash;… | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-06 | F8 cancels after paying → refund $300 (sandbox) or credit; removed from all counts and… | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-07 | Receipts name the nonprofit and payment method. | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-08 | Fee settings changeable by admin (family fee, extra-adult fee, kid age) and totals… | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-09 | F1 adds a third adult after paying → owes **+$150**, and the unpaid reminder restarts… | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-10 | F5 removes Rohan after paying $450 → **$150** refund due, handled by finance. | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-11 | Partial cancellation: one person cancels, the family stays, counts and fee recalculate. | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-12 | No-show: a family never checks in; pay-at-check-in F6 would stay owing $300 and is… | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-13 | Refund window: the cancellation deadline and refund percentage are settings. `[OWNER… | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-14 | Zelle never arrives: finance rejects the pending report → the family is told and… | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-15 | Zelle amount differs from the fee → finance records the actual amount; the balance… | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-16 | Partial payment: F3 pays $300 of $600 → balance $300; reminders use the new balance. | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-17 | Failed card: the family stays unpaid and is told why; no receipt. | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-18 | Double submit or retried webhook → one charge and one receipt. | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-19 | Chargeback: finance is notified; the family returns to owing. | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| C-20 | Card processing fee: report net vs gross. Who absorbs the fee is `[OWNER INPUT]`. | PLATFORM | · | Platform requirement for Stage 2 (pricing, payments and refunds), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-01 | Family picks an open item to sponsor and pledges an amount. | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-02 | Several families share one item; % pledged and % received shown (Sun Lunch: 100% / 60%). | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-03 | Fully pledged and closed items can't be picked (Sun Lunch after F2, Gala Dinner). | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-04 | Pledge now, pay later; pledged vs received tracked; totals match §4. | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-05 | General tier sponsorship (F6 Gold) not tied to an item. | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-06 | Public thank-you list: names only, recognition opt-in respected, no amounts. | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-07 | Business/vendor sponsor (non-family) can be added by finance. | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-08 | Sponsor receipts. | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-09 | F2 cancels the pledge → Sun Lunch reopens with $1,999 remaining; the reminder stops. | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-10 | F2 pays $1,000 of $1,999 → received $4,001; reminders continue for $999. | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-11 | A pledge above the remaining amount is rejected, or offered the remainder. | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-12 | Two families pledge the last $1,999 at the same moment → one succeeds, the other is told. | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-13 | Non-shareable items (Gala music/DJ, Photography & video) accept one sponsor for the… | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-14 | Bhajan Prasad gets an amount later → existing pledges count toward it. | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| D-15 | Donation receipts name the nonprofit and EIN, the date and amount, and state whether… | PLATFORM | · | Platform requirement for Stage 2 (contributions and receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| H-01 | Committee sub-teams (food, hotel, program, finance, picnic, registration); members… | PASS | `H-01` tests (1 pass) | Built in #65 and #67: committee roles such as Finance and Crew lead, custom roles, and a Roles screen to assign them. | · | P1 |
| H-02 | Tasks with owner, due date, status, sub-team; overdue highlighted. | PASS | `H-02` tests (2 pass) | Built in #68: tasks keep owner, due date, status and the overdue filter, and gain an optional crew, shown, filterable and groupable. | · | P1 |
| H-03 | Vendors (caterer, DJ, decorator, photographer, hotel bar) with contacts, contract… | NOT BUILT | · | No vendor model, contracts or deadlines. | Stage 6 | P1 |
| H-04 | Budget: estimate vs actual per line; visible to admin/finance only. | NOT BUILT | · | Task budget figures are private to `budget.read` (#71). No budget lines or actuals (Stage 6). | Stage 6 | P1 |
| H-05 | Permissions matrix from §2 — one test per role per restricted screen/API (UI **and**… | PASS | `H-05` tests (10 pass) | Every preset role is checked against every restricted path in the rules (functions/test/roleMatrix.test.ts, #70, #95), and outsiders, committee members, volunteers and other groups are kept from money, budgets and private profiles (#65–#73). Tests: `H-05`. | · | P0 |
| H-06 | Dual roles: Amit (F1 contact, program committee) sees F1's fee and receipts, and no… | PASS | `H-06` tests (3 pass) | Several roles grant the union of their permissions, a group's contact edits their own group whatever their roles, and nobody sees an expense they are not part of (#66, #72). The fee and receipts wording arrives with payments in Stage 2. Tests: `H-06`. | · | P0 |
| H-07 | Removing someone from the committee ends access immediately, including tasks, money… | PASS | `H-07` tests (3 pass) | Fixed in PR #40 and verified live on dev and stg. **Not yet deployed to prod.** The at-least-2-admins rule is a process point. | · | P1 |
| V-01 | Shift schedule per volunteer. | NOT BUILT | · | No shifts, scanner, counter or issue reports. | Stage 5 | P2 |
| V-02 | QR check-in scanner (see J-01). | NOT BUILT | · | No shifts, scanner, counter or issue reports. | Stage 5 | P2 |
| V-03 | Meal-line counter: tap to count plates served by diet (V/J/N) per meal; totals visible… | NOT BUILT | · | No shifts, scanner, counter or issue reports. | Stage 5 | P2 |
| V-04 | Report an issue (category, text, optional photo): "food running low" → food team;… | NOT BUILT | · | No shifts, scanner, counter or issue reports. | Stage 5 | P2 |
| J-01 | QR code per family (in app and in email); scanning checks in the family and lets the… | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-02 | QR contains a token only — no names, phone, or email encoded. | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-03 | Walk-in: committee registers F9 at the door, takes $300 cash, prints/shows QR; counts… | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-04 | Offline: check-in and meal counts work with no network; queue syncs later; same family… | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-05 | Live schedule "now & next" for everyone. | PASS | `J-05` tests (2 pass) | Built in #82: the agenda shows what is on now and next, from the viewer's own records, or the whole schedule without one. | · | P2 |
| J-06 | Personal agenda per family/person (F4 sees nothing before Sat 11am; F3 elders don't… | PASS | `J-06` tests (4 pass) | Built in #82: agendas follow the event's attendance policy, each session's rule, and stored opt-outs, sign-ups and invitations. | · | P2 |
| J-07 | Live update: a **committee member** (not admin) changes M3 location to "Garland Hall… | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-08 | Directory shows only opted-in families, never contact details. | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-09 | Language toggle EN ⇄ GU on every event-day screen. | NOT BUILT | `J-09` tests (0 pass, 1 fail) | English only. Gujarati strings and the language setting arrive in Stage 3. | Stage 3 | P2 |
| J-10 | Unpaid check-in: F3 is scanned with $600 due → check-in **succeeds**, the volunteer… | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-11 | Scanning a cancelled family's QR (F8) or a merged one (F10) is rejected with a clear… | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-12 | Scanning the same family twice shows "already checked in at <time>" and does not… | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-13 | No QR: the volunteer finds the family using the limited name search in §2, and the… | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-14 | Paper fallback: admin prints a roster and meal sheet the night before, in case phones… | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-15 | Partial arrival: part of a family checks in now and the rest later; both are recorded… | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| J-16 | Scanners stay signed in with no network for the whole shift, and a lost scanner can be… | NOT BUILT | · | Check-in, passes, live updates and the directory arrive in Stage 5. The schedule, personal agenda and offline reads already exist (#81, #82, Req 74). | Stage 5 | P2 |
| K-01 | Final reconciliation for finance: fees + sponsorship received vs actual spend. | NOT BUILT | · | No reconciliation or sponsor messaging. | Stage 6 | P3 |
| K-02 | Bulk thank-you to sponsors with receipts. | NOT BUILT | · | No reconciliation or sponsor messaging. | Stage 6 | P3 |
| K-03 | Export all event data (for the next host city). | PARTIAL | `K-03` tests (2 pass, 1 fail) | Every CSV cell is neutralised (#55, #84), but the expense PDF still stops at 200 expenses, and there is no full export (Stage 6). | Stage 6 | P3 |
| X-01 | Import a roster of 400 people from the tool's export into CrewPoint, with all… | PASS | `X-01` tests (1 pass) | Roster import from a CSV export (#77): 400 people with every per-person field, and a validation report before anything is applied. Tests: `X-01`. | · | P1 |
| X-02 | Re-import is safe: new families added, changes updated, nothing duplicated, and manual… | PASS | `X-02` tests (1 pass) | Re-importing adds new groups, updates changes, duplicates nobody and keeps data entered in CrewPoint, matching by the import's ID (#77). Tests: `X-02`. | · | P1 |
| X-03 | A family cancelled in the tool is removed from counts and its QR is revoked on the… | PASS | `X-03` tests (1 pass) | A group missing from a new import is listed, and confirming removes it from counts (#77, cancelImportedGroups). Revoking its pass arrives with passes in Stage 5. Tests: `X-03`. | · | P1 |
| X-04 | Payment status and balance are imported, and a payment recorded at the door is… | NOT BUILT | · | Payments arrive with registration in Stage 2, so there is no payment status to import or report back yet. | Stage 2 | P1 |
| X-05 | A person signing in to CrewPoint is matched to their imported family by email or… | PASS | `X-05` tests (2 pass) | Someone signing in is linked to their own imported record by verified email, never by name, and two adults sharing an email go to an organizer (#78). Checked live on dev on Nov 17, 2026 (L-01). Tests: `X-05`. | · | P1 |
| X-06 | Import errors (missing diet, unknown age, duplicate email) are listed, and do not stop… | PASS | `X-06` tests (1 pass) | Rows with a missing answer, an unknown age or a duplicate email are listed in the report, and the good rows still import (#77). Tests: `X-06`. | · | P1 |
| X-07 | Tool outage or cancelled subscription: all data can still be exported. | PLATFORM | · | Platform requirement for Stage 6 (full export), now built into CrewPoint rather than a bought tool (L6). | Stage 6 | P1 |
| S-01 | 400 people can belong to the event (the 50-member cap must not block this). | PASS | `S-01` tests (2 pass) | The 50-member cap is gone (#54: an optional memberLimit), and invites last until the event starts by default on non-party templates, or up to 400 days as the organizer chooses (#79). Load baselines for 400 and 2,000 people are in docs/testing/load-baselines.md (#88). Tests: `S-01` in functions/test_acceptance/convention.test.ts. | · | P1 |
| S-02 | Import of 108 families finishes within **2 min** and headcounts match. | PASS | `S-02` tests (4 pass) | Built in #88: the deterministic fixture (108 groups, 400 people) imports in about 0.5 s on the emulators, and headcounts match. See docs/testing/load-baselines.md. | · | P1 |
| S-03 | The 7:00am morning summary to 400 recipients is fully handed to the mock transport… | PARTIAL | `S-03` tests (1 pass, 1 fail) | A 400-person send took about 2 s on the local emulator with a mock transport, inside the 30 s limit. Every recipient gets the same text, so a personal agenda is not possible yet. Production timing not measured. | Stage 3 | P2 |
| S-04 | Live update delivered to 400 within **60 s** (mock). | PARTIAL | `S-04` tests (1 pass) | Delivery path handled 400 in about 2 s on the local emulator. There is no live-update feature using it, and real delivery time is not measured. | Stage 5 | P2 |
| S-05 | Check-in rush: 108 families over 60 min on 4 scanners, with each scan under **2 s**… | NOT BUILT | · | No check-in or meal counting to load. | Stage 5 | P2 |
| S-06 | Meal line: 400 plates in 45 min across 2 counters, totals correct. | NOT BUILT | · | No check-in or meal counting to load. | Stage 5 | P2 |
| S-07 | Event screens stay usable with 400 members: chat with **5,000 messages**, member list,… | PASS | `S-07` tests (2 pass) | Built in #85: chat listens to the latest 50 messages through docChanges and applies each change in one transaction; one new message with 5,000 in history settles in about 0.1 s. Older pages load on demand. | · | P2 |
| S-08 | Monthly cost estimate for reads, writes, function runs, email and SMS at this size. | PASS | `S-08` tests (1 pass) | Built in #88: reads and writes per operation are measured at 400 and 2,000, with a monthly estimate per tier in docs/testing/load-baselines.md. Email and SMS arrive in Stage 3. | · | P1 |
| R-01 | Allergy and medical notes per person, kept separate from diet, visible to the food… | NOT BUILT | · | No safety features or fields. | Stage 5 | P2 |
| R-02 | Emergency contact per family, visible to admins only and available offline. | NOT BUILT | · | No safety features or fields. | Stage 5 | P2 |
| R-03 | Medical emergency issue category: alerts admins and committee at once, bypassing quiet… | NOT BUILT | · | No safety features or fields. | Stage 5 | P2 |
| R-04 | Weather or outdoor change: moving M3/K1 indoors reaches everyone, including those who… | NOT BUILT | · | No safety features or fields. | Stage 5 | P2 |
| R-05 | Kids activity sign-in and sign-out by a named guardian. | NOT BUILT | · | No safety features or fields. | Stage 5 | P2 |
| R-06 | Lost child alerts need an acknowledgement, and go back out if nobody responds within… | NOT BUILT | · | No safety features or fields. | Stage 5 | P2 |
| Z-01 | Children's data: only a parent enters it, birth dates are not shown to committee or… | PASS | `Z-01` tests (6 pass) | Children have no account; only a linked parent of their group, or someone with participants.edit, enters them (#75). Birth dates sit in private details that committee leads and volunteers cannot read, and counts and reports show age bands (#76, #83). The privacy policy covers children (#74). Tests: `Z-01` in test_acceptance/privacy_policy_test.dart and functions/test_acceptance/children_data.test.ts. A lawyer must still approve the policy before prod (Req 39). | · | P0 |
| Z-02 | Photo and video consent per family, including children, available to the photographer. | NOT BUILT | · | No consent record or retention rule for event data. | · | P0 |
| Z-03 | Liability waiver accepted at registration and recorded `[OWNER INPUT]`. | PLATFORM | · | Platform requirement for Stage 2 (registration forms), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| Z-04 | UK and Canadian attendees: consent, access and deletion requests work, and the privacy… | PASS | `Z-04` tests (7 pass) | The privacy policy covers Canadian and UK rights, regulators and cross-border storage (#74). Deleting an account removes the person from shared records and personal subcollections, and turns a linked attendee record into an unnamed entry that still counts (#56, #78). Tests: `Z-04`. A lawyer must still approve the policy before prod (Req 39). | · | P0 |
| Z-05 | Email has a working unsubscribe for non-essential messages; SMS (if used) is… | NOT BUILT | · | No email or SMS, so no unsubscribe. | Stage 3 | P0 |
| Z-06 | Tax and legal wording on receipts is approved, and records are kept for the required… | PLATFORM | · | Platform requirement for Stage 2 (receipts), now built into CrewPoint rather than a bought tool (L6). | Stage 2 | P0 |
| Z-07 | Data retention after the event: what is deleted, what passes to the next host (K-03),… | NOT BUILT | · | No consent record or retention rule for event data. | Stage 6 | P3 |
| O-01 | Billing alerts, budget caps and a named owner. A lapsed billing account must not be… | PASS | Manual, recorded | Manual, in #93: an hourly GitHub Actions job (.github/workflows/billing-check.yml) checks from outside Google Cloud, as the read-only billing-check service account signed in without a key, that billing is on for dev, stg and prod, and emails derodian@gmail.com and admin@sookoon.space when not. On Nov 16, 2026 a forced test failure reached both inboxes. A $5 and a $15 monthly budget cover the billing account, and uptime alerts exist on dev and prod. See docs/ops/backups-and-alerts.md. | · | P0 |
| O-02 | Crash reporting and backend error alerts reach a person during event hours. | PASS | `O-02` tests (2 pass) | Crash reporting in #92: Sentry on iOS, Android and web behind ICrashReporter, with reports scrubbed of any user identity (`O-02` tests), confirmed live on dev. Backend error alerts in #93: dev and prod each email derodian@gmail.com and admin@sookoon.space when a function logs an error, skipping browser hits on callables; on Nov 16, 2026 a test error on dev reached both inboxes. Crash reporting on stg and prod waits for their DSN. | · | P1 |
| O-03 | Automated Firestore backups, with a restore rehearsed. | PASS | Manual, recorded | Manual, in #91: on Nov 12, 2026 the newest dev backup was restored into a new database in 8 min 33 s, matched live in every collection and document checked (functions/scripts/checkRestore.ts), and was deleted. Daily backups kept 14 days are on for all three projects, with point-in-time recovery on dev and prod. See docs/ops/backups-and-alerts.md. | · | P0 |
| O-04 | Email domain authenticated (SPF, DKIM, DMARC), with bounce handling and a test send to… | NOT BUILT | · | No email sending or domain setup in the repo. | Stage 3 | P0 |
| O-05 | App approved in the App Store and Google Play before announcement, with enough lead… | NOT RUN | · | Needs store console access or a visit to the venue. | Stage 7 | P1 |
| O-06 | Release freeze from Jul 9, with a rollback plan; old app versions keep working. | NOT BUILT | · | No release freeze or on-call plan. | · | P2 |
| O-07 | Venue network test at the Hyatt: Wi-Fi and cell coverage in Garland Hall and at the… | NOT RUN | · | Needs store console access or a visit to the venue. | Stage 7 | P2 |
| O-08 | Event-day on-call plan and contacts. | NOT BUILT | · | No release freeze or on-call plan. | · | P2 |
| U-01 | Readable at 200% system text size, on every family and volunteer screen. | PARTIAL | `U-01` tests (1 pass) | The dashboard is fine at 200% text. Other screens are untested, and family and volunteer screens do not exist. | · | P1 |
| U-02 | Screen reader labels on registration, agenda and check-in. | PARTIAL | `U-02` tests (1 pass) | Dashboard tap targets are labelled and sized. Other screens are untested. | · | P1 |
| U-03 | Gujarati renders correctly (spelling **દેરોદ**) on iOS, Android, web, email and PDF… | FAIL | `U-03` tests (1 pass, 1 fail) | Gujarati is lost from PDF reports: Latin text extracts, Gujarati does not. Phone, web and email rendering are untested. Also see issue #29. | Stage 3 | P1 |
| U-04 | Colour contrast meets WCAG AA in light and dark mode. | PARTIAL | · | The current palette is checked by existing tests. New screens are not built. | · | P1 |
| U-05 | An older non-technical user (Savita, 74) can complete web registration and find her… | NOT RUN | · | Needs a real session with an older user, once the screens exist. | · | P2 |
| N-00 | Safety | PASS | `N-00` tests (1 pass) | Push goes only through a mocked transport on the emulator. Email has no transport at all yet. | · | P2 |
| N-01 | Registration confirmation | PLATFORM | · | Platform requirement for Stage 3 (email), now built into CrewPoint rather than a bought tool (L6). | Stage 3 | P0 |
| N-02 | Family member invite | PLATFORM | · | Platform requirement for Stage 3 (email), now built into CrewPoint rather than a bought tool (L6). | Stage 3 | P0 |
| N-03 | Payment receipt | PLATFORM | · | Platform requirement for Stage 3 (email), now built into CrewPoint rather than a bought tool (L6). | Stage 3 | P0 |
| N-04 | Unpaid fee reminder | PLATFORM | · | Platform requirement for Stage 3 (email), now built into CrewPoint rather than a bought tool (L6). | Stage 3 | P0 |
| N-05 | Hotel not booked | PLATFORM | · | Platform requirement for Stage 3 (email), now built into CrewPoint rather than a bought tool (L6). | Stage 3 | P0 |
| N-06 | Pledge not received | PLATFORM | · | Platform requirement for Stage 3 (email), now built into CrewPoint rather than a bought tool (L6). | Stage 3 | P0 |
| N-07 | Know before you go | NOT BUILT | · | No email, segments, scheduled messages, history or de-duplication. | Stage 3 | P2 |
| N-08 | Morning summary | PARTIAL | `N-08` tests (0 pass, 1 fail) | A daily digest exists, but it is opt-in, fires at 9:00am, and summarises tasks rather than an agenda. | Stage 3 | P2 |
| N-09 | 15-minute session reminder | NOT BUILT | `N-09` tests (0 pass, 1 fail) | Reminders exist for tasks only. Quiet hours also use the profile time zone, so F5's 6:45pm reminder would be dropped. | Stage 3 | P2 |
| N-10 | Quiet hours by recipient zone | PARTIAL | `N-10` tests (1 pass, 1 fail) | The quiet-hours window is right for each time zone, but a blocked message is dropped rather than sent at 7:00am. | Stage 3 | P2 |
| N-11 | Live schedule change | PARTIAL | `N-11` tests (1 pass) | Urgent chat bypasses quiet hours, which is the path a live update could use. There is no schedule-change message or email. | Stage 3 | P2 |
| N-12 | Segment messages | NOT BUILT | · | No email, segments, scheduled messages, history or de-duplication. | Stage 3 | P2 |
| N-13 | Volunteer shift reminder | NOT BUILT | · | No email, segments, scheduled messages, history or de-duplication. | Stage 3 | P2 |
| N-14 | Issue alerts | PARTIAL | `N-14` tests (0 pass, 1 fail) | Urgent chat exists, but a muted event blocks it, so a lost-child alert can be missed. No issue categories. | Stage 3 | P2 |
| N-15 | Cancellation | PLATFORM | · | Platform requirement for Stage 3 (email), now built into CrewPoint rather than a bought tool (L6). | Stage 3 | P0 |
| N-16 | Opt-out | PARTIAL | `N-16` tests (1 pass) | Per-category opt-out works for push. No email categories. | Stage 3 | P1 |
| N-17 | De-duplication | NOT BUILT | · | No email, segments, scheduled messages, history or de-duplication. | Stage 3 | P1 |
| N-18 | Delivery failure | PARTIAL | `N-18` tests (1 pass, 1 fail) | Dead tokens are removed. Failures are not logged anywhere staff can see, and there is no email fallback. | Stage 3 | P1 |
| N-19 | Scheduled message admin | NOT BUILT | · | No email, segments, scheduled messages, history or de-duplication. | Stage 3 | P1 |
| N-20 | History | NOT BUILT | · | No email, segments, scheduled messages, history or de-duplication. | Stage 3 | P1 |
| N-21 | Language switch | PARTIAL | `N-21` tests (0 pass, 1 fail) | Per-recipient language lookup exists, with English templates only. | Stage 3 | P2 |
| N-22 | Web-only coverage | NOT BUILT | · | No email, segments, scheduled messages, history or de-duplication. | Stage 3 | P2 |
| N-23 | Finance: unpaid check-in | NOT BUILT | · | No email, segments, scheduled messages, history or de-duplication. | Stage 3 | P2 |

## 4. Priorities by the real calendar

**P0: before announcing registration (Nov–Dec 2026)**

- **Legal:** lawyer approval of the privacy policy, then Stage 1 to prod (Z-01, Z-04), the nonprofit's legal name, EIN and receipt wording (D-15, Z-06), and the waiver (Z-03).
- **Registration route:** Stage 2, or a bought tool brought in through the roster import (L6). Either way, the fee rules come first: hybrid family fee (C-01), per-person meal choices and arrival times (B-01, B-03).
- **Email domain** (O-04).

**P1: sponsorship and hotel push (Jan–Jun 2027)**

- Stage 2: registration, payments, receipts, contributions and one-time code sign-in (B, C, D, L-03…L-07).
- Stage 3: email, scheduled messages that wait out quiet hours, Gujarati and Unicode PDFs (N, J-09, A-03, U-03).
- App store approval (O-05), and accessibility on every screen (U-01…U-04).

**P2: final week and event days (Jul 2027)**

- Stage 5: passes, check-in, offline writes, volunteers, live updates and safety (J, V, R, S-05, S-06).
- Rehearse at scale (S-03, S-04) before the Jul 9 release freeze (O-06), and name who is on call (O-08).

**P3: after the event**

- Stage 6: reconciliation, vendors, budget lines, full export and data retention (K, H-03, H-04, Z-07).

## 5. Top gaps

1. **No registration or payments.** Families cannot register or pay in CrewPoint until Stage 2. Until then, a bought tool and the roster import, which is built and tested, are the route (B, C, D, X-04).
2. **Prod is still on the code from before Stage 1.** Every Stage 1 change waits for the lawyer's approval of the privacy policy, and runs only on dev (Req 39).
3. **No email.** Web-only families depend on it. It needs an authenticated domain, unsubscribe and bounce handling (N, O-04, Z-05). Stage 3.
4. **No Gujarati.** Strings, a language setting, translated templates and a PDF font that supports Gujarati, with a human translator (A-03, J-09, U-03, N-21). Stage 3.
5. **Messages are dropped, not delayed, and mute blocks urgent alerts.** Quiet hours drop a message instead of sending it at 7:00am, and a muted event blocks a lost-child alert (N-10, N-14). Stage 3's scheduled queue must fix both.
6. **No event-day flow.** Passes, a scanner, the limited name search, offline writes with a clear conflict rule, volunteers and live updates (J, V). This is the largest single build, in Stage 5.
7. **No safety features.** Incident reports, medical and allergy flags, and lost-child handling (R). Stage 5.
8. **The expense PDF stops at 200 expenses.** The CSV is complete, but the PDF is not, and there is no full export (K-03). Stage 6.

## 6. Testability gaps

- **No clock seam in the push and scheduled jobs.** `sendCategorizedPush`, `onTaskDueScheduled` and `onDigestSummary` call `new Date()` directly, so the N-10 test fakes `Date` in Jest. Stage 3's scheduled messages should take a clock, as counts already do.
- **No email or SMS transport to mock.** N-00 can only prove safety for push.
- **Pushes have no recipient-level result.** `sendCategorizedPush` returns only counts, so recipient assertions inspect the mock.
- **Real delivery.** APNs and FCM delivery need real devices.
- **Not checked: store listings and the venue network** (O-05, O-07).

## 7. Assumptions

| Assumption | What the app does now | Recommendation |
|---|---|---|
| A 1-adult family pays $300 | No fee logic. Stage 2 | Confirm |
| Age is computed on Jul 16, 2027 | Age bands come from the private birth date, on the event's first day | Keep |
| Registration is built, with a bought tool as a stopgap (L6) | The roster import is ready for a tool's export | Decide by December |
| Sign-in with Google, then email code, is one account (L-06) | No email code yet. Stage 2 | Keep |
| Bhajan Prasad accepts any amount before one is set | Not built | Keep |
| Pledged-but-unpaid sponsors appear on the thank-you list | Not built | Confirm: consider listing only after receipt |
| F5's pre-event nights get the group rate | Outside the app | Ask the hotel |
| Volunteers can search by family name if QR fails | Not built. Stage 5 | Keep, with logging |
| Duplicate who already paid goes to finance | Not built | Keep |
| Walk-ins past capacity need admin override | Capacity is a setting, compared with the counts | Confirm the real hall limit with the hotel |
| Paid families are not re-billed after a fee change | Not built | Keep |
| Pay-at-check-in families get no unpaid reminder | Not built | Keep, with one reminder in N-07 |
| Web-only users get no session reminders | No email at all | Keep; email every 15 minutes would be noise |
| Quiet hours are 9:00pm–7:00am, deferred not dropped | User-set window; **drops** messages | Keep; requires a build |
| Event time applies to quiet hours Jul 16–19 | Events have a time zone, but quiet hours use the profile's | Keep; requires a build |
| Pledge reminders stop at event start | Not built | Confirm |
| Event-day messages reach each family member with a login | Not built | Keep |
| Shift reminders the day before at 6:00pm, and 30 minutes before | Not built | Keep |
| Opted-out families still get receipts and live changes | Per-category opt-out exists for push | Keep, and have counsel check it against email rules |
| Lost-child alerts re-send after 2 minutes with no acknowledgement | Not built | Confirm with whoever runs safety |

**Owner input still needed:** nonprofit legal name and EIN, refund policy (C-13), who absorbs card fees (C-20), waiver text (Z-03), whether to adopt SMS for emergencies (N-14).

## How to re-run

Keep each scenario's status and gap in `test_acceptance/fixtures/scenarios.json` as work lands, then:

```bash
flutter test test_acceptance/ --reporter json > flutter.json
(cd functions && firebase emulators:exec --project demo-crewpoint --only firestore,auth \
  "npx jest --runInBand --config jest.acceptance.config.js --json --outputFile=../jest.json")
python3 test_acceptance/generate_report.py flutter.json jest.json
```
