# CrewPoint — Derod Gaam Convention 2027 Acceptance Test (v4)

**Replaces v1, v2 and v3.** v4 merges the owner's planning since v3 into the v3 scenarios, so nothing is lost and no scenario ID changes meaning:

- **New:** the Saturday waterpark day (Hawaiian Waters private Pool Party, shuttles, waivers) with a bhajan program at the hotel (W), the in-app raffle (RF), the budget and sponsorship list inside CrewPoint (BG), paid serving helpers (HL), 21+ wristbands (AL), and notifications N-24 to N-32.
- **Changed rules:** the fee is **$150 per adult** (was $300 per family plus $150 per extra adult), there are **no quiet hours**, and email-only users get **everything** by email, including 15-minute reminders.
- **Seed:** F11 (single parent, Phoenix) added; the schedule, sponsorship list and pledges follow the budget workbook.
- **Kept from v3** and updated to the new rules: payment edge cases (C-09 to C-20), sponsorships (D), roster import (X), scale (S), safety (R), privacy (Z), operations (O), accessibility (U), and the event-day edge cases (J-10 to J-16).
- **Retired:** N-10 (see §7).

Every expected number below was computed from the seed in §3, and `test_acceptance/spec_check_test.dart` recomputes it from the fixture.

**Goal:** prove CrewPoint can plan, run and close out the convention, and keep a prioritized list of what is missing.

---

## 0. How this spec is used

1. **Tests.** Scenarios are tested in `test_acceptance/` (Flutter) and `functions/test_acceptance/` (Jest, on the emulators). A test's name starts with its scenario ID, such as `B-04 headcount …`. Scenarios with nothing to exercise yet are registered as skipped tests carrying the reason (`scenario_registry_test.dart`), so every ID stays traceable. Never write a test that passes vacuously.
2. **Records.** `test_acceptance/fixtures/scenarios.json` holds each scenario's status and gap, in the same order as this document. `test_acceptance/finished_scenarios.json` lists the scenarios CI protects (`check_finished.py`). `test_acceptance/generate_report.py` writes `CONVENTION_TEST_REPORT_v4.md` from both and refuses statuses the results contradict.
3. **IDs are permanent.** An ID never changes meaning and is never reused. A scenario that no longer applies is **retired** in §7 with its reason, never deleted or renumbered.
4. **Seed.** §3 is `test_acceptance/fixtures/derod_convention_2027_v4.json`, loaded by `test_acceptance/seed.dart`. Spec checks recompute §4 from it; they prove the specification is consistent and never count toward a PASS.
5. **Budget workbook.** BG-03 needs `test_acceptance/fixtures/Derod_Gaam_2027_Budget_Estimate.xlsx` `[OWNER INPUT]`. Until it is there, BG-03 is BLOCKED, not FAIL.
6. **Safety (mandatory):** mock push, email and SMS transports and payment sandboxes only; the `demo-crewpoint` emulator project only (`crewpoint-dev` holds real data); a fake injectable clock for every time-based test, in event time `America/Chicago`; a **seeded** random generator for raffle draws. N-00 must prove that no real message or charge can be sent.
7. **Statuses:** PASS · PARTIAL (exists, some assertions fail or part is missing) · FAIL (exists, broken) · NOT BUILT · PLATFORM (a requirement for a later platform stage) · NOT RUN (needs a real device, a person or a third party) · BLOCKED (missing fixture or testability gap).
8. **Markers:** `[ASSUMPTION]` is a best guess the owner has not confirmed; `[OWNER INPUT]` is a fact only the owner can supply; `[TEST VALUE]` is invented seed data that exists only to make assertions possible.

---

## 1. Event facts and product rules

### Event
| Item | Value |
|---|---|
| Event | Derod Gaam Convention 2027 (4th convention; the last was ~13 years ago, in Houston), hosted by the Derod families of Dallas. Open to all Derod families (USA, Canada, UK) |
| Expected attendance | **350–400 people** |
| Host | Registered nonprofit. Legal name and EIN `[OWNER INPUT]` |
| Dates | Fri Jul 16 – Mon Jul 19, 2027 · `America/Chicago` |
| Venue | Hyatt Place Dallas/Garland/Richardson & Firewheel Conference Center, 5101 N George Bush Hwy, Garland, TX 75040 · Garland Hall (rounds, 400), contracted Jul 16–18 |
| Hotel rooms | Families book their own via the group link + code · $99/night + 14.98% tax · cutoff **Jul 3, 2027** · early departure = 1-night charge · block attrition is tracked outside CrewPoint |
| Saturday offsite | Hawaiian Waters Garland, 4550 N Garland Ave, Garland, TX 75040 — private **Pool Party** package |
| Languages | English + Gujarati, per user. Gujarati spelling of the village: **દેરોદ** (never ડેરોડ) |

### Rules confirmed by the owner
| Rule | Value |
|---|---|
| Registration fee | **$150 per adult (18+); kids under 18 free.** 1 adult = $150, 2 = $300, 3 = $450, regardless of kids. Age is computed on **Jul 16, 2027** |
| Payment methods | Card in app · Zelle (family reports, finance confirms) · check/cash (finance records) · pay at check-in |
| Pay at check-in | **No** unpaid-fee reminders; only a "balance due at check-in" line in the final-week message |
| Unpaid check-in | Allowed; the finance team is notified (J-10, N-23) |
| Quiet hours | **None.** Scheduled messages go out at the set Central time; each recipient sees it in their own time zone |
| Email-only users (no app) | Get **everything** by email, including 15-minute session reminders |
| Waterpark day | Per-person sign-up (waterpark vs. stay at the hotel for bhajan) · shuttle seats and times · liability waiver · meal counts per location |
| Waterpark package | $8,500 for up to 250 guests · $30.99 per extra guest · + 8.25% tax · 2.5 hours · includes admission, wave pool, 2 slide towers and a catered meal |
| Raffle | Tickets bought in the app **and** paper sales logged by volunteers · prize list with purchased/donated + donor · drawings run in the app · $10 single, 6 for $50 · each ticket is for one drawing |
| Raffle legality | Run under the qualified organization used in Houston; tickets and receipts show that organization's name; **no cash prizes** (gift cards OK) |
| Unclaimed raffle prize | Winner notified; prize held until **Mon Jul 19, 11:00am** (checkout); then redrawn from the same drawing's tickets |
| Kids drawing | Free · every registered child under 18 gets **1 automatic entry** |
| Alcohol | Served by the hotel. The app flags guests **21+** for bar wristbands at check-in |
| Helpers | **Paid staff:** 10 per meal, hours logged, $20/hr (configurable); finance sees hours and pay |
| Budget & sponsorship | Managed **in CrewPoint**: budget lines (estimate vs actual), sponsorship list with Include Yes/No, asks rounded up, pledges, received, in-kind |
| Sponsorship ask | Cost × 1.10, rounded up to the next **$100** when that result is under $1,000, otherwise to the next **$500** `[ASSUMPTION]` that "under $1,000" applies to cost × 1.10; the workbook decides (BG-03) |
| Money visibility | Admin + finance only |
| Live schedule changes | Any committee member |

### Schedule (times marked * are placeholders)
| ID | Item | When | Where | Notes |
|---|---|---|---|---|
| M1 | Welcome Dinner | Fri Jul 16, 7:00pm* | Garland Hall | |
| P1 | Karaoke & Garba + Raffle drawing (Fri) | Fri Jul 16, 9:00pm* | Garland Hall | |
| M2 | Breakfast | Sat Jul 17, 8:00am* | Garland Hall | |
| S1/S2 | Shuttle to waterpark – Run 1 / Run 2 | Sat 9:30am* / 10:00am* | Hotel lobby | |
| W1 | Hawaiian Waters private Pool Party | Sat 10:30am–1:00pm* | Hawaiian Waters | Lunch included (park meal) |
| B1 | Bhajan (day program) | Sat 10:00am–4:00pm* | Garland Hall | For elders and anyone staying |
| M3 | Saturday lunch – **two locations** | Sat 12:30pm* | Park meal (W1) **or** hotel lunch | Each person counted at one location. In the fixture: **M3P** (park) and **M3H** (hotel) |
| R1/R2 | Shuttle back – Run 1 / Run 2 | Sat 1:15pm* / 1:45pm* | Hawaiian Waters | |
| B2 | Bhajan & Prasad (all) | Sat 4:00pm* | Garland Hall | |
| K1 | Kids activities + Kids raffle drawing | Sat 5:00pm* | Garland Hall | Children who signed up |
| M4 | Dinner | Sat 7:00pm* | Garland Hall | |
| P2 | Garba & Karaoke + Raffle drawing (Sat) | Sat 9:00pm* | Garland Hall | |
| M5 | Breakfast | Sun Jul 18, 8:00am* | Garland Hall | |
| M6 | Lunch | Sun 12:30pm* | Garland Hall | |
| M7 | Gala Night Dinner + DJ + Grand raffle drawing | Sun 7:00pm* | Garland Hall | Bar (21+) |
| M8 | Farewell Breakfast | Mon Jul 19, 8:00am* | TBD | Not in the hall contract |

---

## 2. Roles

| Role | Can | Cannot |
|---|---|---|
| Admin | Everything | — |
| Finance | All money: fees, payments, Zelle confirmations, refunds, pledges, budget, vendor amounts, raffle cash, helper pay | — |
| Committee member | Tasks, vendors (no amounts), schedule, **live updates**, registrations and headcounts, walk-ins (and the amount due from the walk-in being registered), shuttle assignments, waiver status, run raffle drawings | See any other money amount |
| Volunteer | Own shifts, QR check-in, meal-line counter, issue reports, **log paper raffle sales**, see the 21+ flag at check-in, see and record the balance due only for the family being checked in. If a QR fails, search by family name: at least 3 letters, family name and city only, one family at a time, every lookup logged `[ASSUMPTION]` | Other finances, the registration list, live updates, raffle draws |
| Helper (paid) | Own shifts, clock in/out | Anything else |
| Family contact | Register the whole family, edit, pay, pledge, buy raffle tickets, sign waivers, waterpark sign-up, invite members, directory opt-in, personal agenda | Other families' data (except the opted-in directory) |
| Family member (invited) | View/edit own family, buy raffle tickets | Other families |
| Sponsor (family or business) | Pledge, in-kind donation, see own pledges/receipts, choose public recognition | Others' amounts |

**A person can hold several roles.** Most committee members and volunteers are also family contacts. Each permission is scoped: a committee member sees their own family's fee and receipts as a family, and no other money as committee (H-06).

Login: Google or Apple sign-in, plus phone or email one-time code. Families can register from a web link (no install) or the app; the app is optional and adds push notifications.

---

## 3. Seed data

Ages on Jul 16, 2027. Diet: V veg · J Jain · N non-veg. **WP** = signed up for the waterpark (otherwise stays at the hotel for bhajan and hotel lunch). **KA** = kids activities. Hotel stays list the **nights** booked: "nights Jul 16–18" means the nights of Jul 16, 17 and 18 (3 nights). T-shirt sizes and Derod relations are in the fixture `[TEST VALUE]`.

### Families
| ID | Family | From | Lang | App? | Arrive → Depart | People (age, diet, WP, KA) | Hotel | Fee & payment | Directory |
|---|---|---|---|---|---|---|---|---|---|
| F1 | Patel | Dallas TX (local, drives) | EN | App | Fri 5pm → Sun night | Amit 45 V WP · Nisha 42 V WP · Riya 10 V WP KA · Dev 6 V WP KA | None | $300 card | Listed |
| F2 | Bhakta | Chicago IL (flying) | EN | App | Fri 3pm → Mon | Raj 38 V WP · Priya 36 V WP · Kiaan 3 V WP (KA no) | 1 room, nights Jul 16–18, conf **HP123456** | $300 Zelle (pending → confirmed) | Listed |
| F3 | Desai | Edison NJ (flying) | **GU** | App | Fri 2pm → Mon | Kunal 44 V WP · Meera 41 V WP · **Ramesh 72 J (hotel)** · **Kamla 70 J (hotel)** · Neel 17 V WP (born Jul 17, 2009) · Asha 8 V WP KA · Om 4 V WP KA | Intent 2 rooms, nights Jul 16–18, **no conf** | **$600 unpaid** | Listed |
| F4 | Mistry | Houston TX (drives) | **GU** | **Web only**, email code | **Sat 11am** → Mon | Savita 74 V (hotel) | 1 room, nights Jul 17–18, conf **HP223344** | **$150** check #1043 | Not listed |
| F5 | Chauhan | London UK (flying), tz Europe/London | EN | App | Fri 1pm → Mon | Vikram 47 N WP · Anjali 45 N WP · **Rohan 18** N WP · Tara 14 N WP · Kabir 9 N WP KA | 1 room, nights Jul 14–18, conf **HP334455** | $450 card | Listed |
| F6 | Patel | Toronto (flying), tz America/Toronto | EN | App | Fri 4pm → Mon | Hemant 52 V (hotel) · Jaya 50 N WP, opts out of **M2** | Intent 1 room, nights Jul 16–18; enters conf **HP445566 on Jun 10, 2027** | $300 **pay at check-in** | Not listed |
| F7 | Bhakta (host) | Dallas TX (local, drives) | **GU** | App | Fri 5pm → Sun night | Mahesh 50 V (hotel, host duties) · Leela 48 V WP · Sonal 11 V WP KA · Jay 5 V WP KA | None | $300 cash | Not listed |
| F11 | Rana (single parent) | Phoenix AZ (flying), tz America/Phoenix | EN | App | Fri 3pm → Mon | Kavita 38 V WP · Ishan 13 V WP · Mira 7 V WP KA | 1 room, nights Jul 16–18, conf **HP556677** | **$150** card | Listed |
| F8 | Shah | Atlanta GA | EN | App | — | 2 adults V | — | $300 card → **cancels Mar 1, 2027**, full refund | — |
| F9 | Joshi (**walk-in**) | Austin TX | EN | — | Registered at the door **Sat 4:00pm** → Sun night | Sanjay 35 V · Ritu 33 V · Aarav 7 V (no WP, no KA) | None | $300 cash at the door | Not listed |
| F10 | Desai (**duplicate**) | Houston TX | GU | App | — | Ramesh 72 J · Kamla 70 J (same people as F3), registered Jan 20, 2027, unpaid | — | — | Merged into F3, F10 removed |

### Registration and payment dates `[TEST VALUE]`
| Family | Registered | Payment |
|---|---|---|
| F1 | Nov 15, 2026 | Nov 15, 2026 |
| F2 | Nov 18, 2026 | Zelle reported Nov 25, 2026; finance confirms Dec 3, 2026 |
| F3 | Nov 20, 2026 | Unpaid |
| F4 | Dec 8, 2026 | Check recorded Dec 10, 2026 |
| F5 | Dec 12, 2026 | Dec 12, 2026 |
| F6 | Jan 5, 2027 | At check-in, Jul 16, 2027 |
| F7 | Nov 30, 2026 | Cash recorded Dec 1, 2026 |
| F11 | Jan 8, 2027 | Jan 8, 2027 |
| F8 | Jan 10, 2027 | Jan 10, 2027; cancelled Mar 1, 2027 |

Other seed facts:
- F3 contact Kunal invites **Meera** as a family member; she logs in with a phone code.
- **Amit (F1) is also the program committee member**, to test dual roles (H-06).
- Shuttle: F1, F4 and F7 drive; everyone else signed up for the waterpark rides the shuttle.
- **Waivers:** signed by F1, F2, F3, F6 (Jaya), F7, F11. **F5 has not signed.**
- **Shuttle runs (test configuration):** 2 runs each way, **15 seats per run**.
- If a duplicate (F10) had already paid, the payment goes to finance to refund or transfer `[ASSUMPTION]`.

### Staff
admin ×1 · finance ×1 · committee: food, program (Amit), registration (×1 each) · volunteers V1 (check-in), V2 (meal line), V3 (raffle desk) · paid helpers **H1, H2, H3** (+ 7 unnamed planned slots per meal).
Helper hours logged for M1 (Fri dinner): H1 4.0 h, H2 4.0 h, H3 3.5 h.

Volunteer shifts `[TEST VALUE]`:
| Volunteer | Shifts |
|---|---|
| V1 check-in | Fri Jul 16 4:00–8:00pm · Sat Jul 17 10:00am–1:00pm · Sun Jul 18 10:00am–12:00pm |
| V2 meal line | Fri Jul 16 6:30–8:30pm · Sat Jul 17 7:30–9:30am · Sun Jul 18 6:30–9:00pm |
| V3 raffle desk | Fri Jul 16 8:30–10:30pm · Sat Jul 17 8:30–10:30pm · Sun Jul 18 6:30–10:00pm |

Vendors (for H-03; amounts come from the budget workbook): caterer, DJ, decorator, photographer, Hawaiian Waters, shuttle company, hotel.

### Sponsorship list (from the budget workbook, asks at 400 guests)
On the list (Include = Yes): Welcome Dinner $9,000 · Breakfast Sat/Sun/Mon $4,500 each · Lunch Sat (hotel group) $3,000 · Dinner Sat $8,000 · Lunch Sun $7,000 · Gala Night Dinner $11,000 (**already sponsored**) · Chai & coffee $2,000 · Bhajan prasad $700 · Bottled water $900 · Soda & juice $1,500 · Paper products $6,000 · Alcohol $6,000 · Entertainment 3 nights $7,000 · Gala decoration $2,500 · Photography & video $2,500 · Bhajan group $600 · Kids activities $700 · Raffle prizes $3,500 · Pool Party $10,500 · Shuttle $2,000 · T-shirts $4,000.
**Off the list** (paid by registration fees): ice & coolers, all Hyatt contract lines, hall resets, insurance, first aid, hotel tips, badges, program booklet, banners, awards, caterer staff, helpers.
**Photography & video** takes one sponsor for the full amount (not shareable) `[ASSUMPTION]`.
General sponsorship tiers (not tied to an item): Platinum $3,001 · Gold $1,001 · Silver $501.

### Pledges and donations
| Sponsor | Type | Amount | For | Received? | Public recognition |
|---|---|---|---|---|---|
| F1 Patel (Dallas) | Silver | $501 | Bottled water | Yes, card | Yes |
| F7 Bhakta (Dallas) | Platinum | $3,001 | Lunch – Sun | Yes, cash | Yes |
| F2 Bhakta (Chicago) | Pledge | $1,999 | Lunch – Sun | **No** (Zelle promised), pledged Mar 1, 2027 | Yes |
| Patel Travels (business) | Pledge | $2,000 | Lunch – Sun | Yes, check | Yes |
| F6 Patel (Toronto) | Gold | $1,001 | General | Pledged Jan 15, 2027; received **Mar 20, 2027** | **No** |
| Pre-arranged sponsor | Item | $11,000 | Gala Night Dinner | Yes | **Anonymous** |
| Patel Travels | In-kind | $500 value | Raffle prize: airline gift card | Delivered | Yes |
| F2 Bhakta (Chicago) | In-kind | $450 value | Raffle prize: Dyson vacuum | Delivered | Yes |

### Raffle
Prizes: the workbook's Raffle tab — **39 pieces**: Fri night 22, Sat night 8, Sun Gala 3, Kids 6 `[OWNER INPUT]`: confirm against the workbook, which lists 21 prize lines. The airline gift card and Dyson are **donated** (above).
Sales:
| Buyer | Channel | Bought | Drawing | Paid |
|---|---|---|---|---|
| F1 Amit | App | 1 bundle (6) | Sun Gala | $50 card |
| F5 Vikram | App | 2 bundles (12) | Sun Gala | $100 card |
| F5 Vikram | App | 2 singles | Sat night | $20 card |
| F3 Kunal | App | 1 bundle (6) | Fri night | $50 Zelle (pending → confirmed) |
| V3 (paper, many buyers) | Paper log | 10 bundles + 5 singles (65) | Fri night | $550 cash |
| F7 Leela | Paper log | 1 bundle (6) | Sat night | $50 cash |

### Scale fixture (generated, deterministic)
**108 families, 400 people**, same diet and arrival mix as F1–F7, 5 sub-teams, 15 volunteers. Used only by the S scenarios.

---

## 4. Expected values

### Headcount (after F10 merge, F8 cancelled, before walk-in)
- Families **8** · adults **17** · kids **12** · total **29**
- Diet: veg **21** · Jain **2** · non-veg **6**
- Kids activities sign-ups **8** · guests 21+ (wristbands) **16** (Rohan 18 and all kids get none)
- T-shirt report: one count per size; sizes sum to **29**
- After walk-in: families **9** · adults **19** · kids **13** · total **32** · 21+ **18**
- Before the F10 merge: families **9** · adults **19** · total **31** · Jain **4** · billed **$2,850**. The merge must bring these back to the values above

### Meals (per person, from arrival/departure, opt-outs and Saturday location)
| Meal | Total | Veg | Jain | Non-veg | After walk-in |
|---|---|---|---|---|---|
| M1 Fri Welcome Dinner | 28 | 20 | 2 | 6 | — |
| M2 Sat Breakfast | 27 | 20 | 2 | 5 | — |
| M3P Sat lunch – **park meal** | 24 | 18 | 0 | 6 | — |
| M3H Sat lunch – **hotel** | 5 | 3 | 2 | 0 | — |
| M4 Sat Dinner | 29 | 21 | 2 | 6 | **32** (veg 24) |
| M5 Sun Breakfast | 29 | 21 | 2 | 6 | **32** |
| M6 Sun Lunch | 29 | 21 | 2 | 6 | **32** |
| M7 Gala Dinner | 29 | 21 | 2 | 6 | **32** |
| M8 Mon Breakfast | 21 | 13 | 2 | 6 | 21 |

Why: F4 arrives Sat 11am (misses M1, M2) · Jaya opts out of M2 · F1, F7 and F9 leave Sun night · Ramesh, Kamla, Savita, Hemant, Mahesh eat at the hotel on Saturday.

### Fees
F1 $300 · F2 $300 · F3 **$600** · F4 **$150** · F5 **$450** · F6 $300 · F7 $300 · F11 **$150** · F8 $300 refunded · F9 $300.
- Billed (F1–F7, F11): **$2,550**
- Before Zelle confirmed: paid **$1,350** · pending **$300** (F2) · outstanding **$900** (F3 $600, F6 $300 at check-in)
- After Zelle confirmed: paid **$1,650** · outstanding **$900**
- After event check-in (F6 pays at the desk, F9 walk-in pays cash): billed **$2,850** · paid **$2,250** · outstanding **$600** (F3)
- At F3's check-in with $600 due: check-in **succeeds**, the balance stays $600, the finance team is notified once (J-10, N-23)
- Neel (17, turns 18 on Jul 17) = kid; Rohan (18) = adult
- C-09: F1 adds a third adult → owes **+$150** · C-10: F5 removes Rohan → **$150** refund due · C-16: F3 pays $300 → balance **$300**

### Waterpark day
- Signed up: **24** (F1 4, F2 3, F3 5, F5 5, F6 1, F7 3, F11 3) · staying at the hotel: **5**
- Package cost: 24 ≤ 250 → **$8,500 + tax = $9,201.25**. Also with 260 synthetic sign-ups: (8,500 + 10 × 30.99) × 1.0825 = **$9,536.72**
- Shuttle riders **17** (F2 3, F3 5, F5 5, F6 1, F11 3). With 15 seats per run: every rider assigned exactly once each way, **no run over 15**, **each family kept together**, F1, F4 and F7 not assigned
- Missing waivers: **F5** (5 people) → blocked from boarding until signed, listed for committee
- Capacity alerts to committee: at **225** sign-ups (90% of 250) and when sign-ups **exceed 250** (cost rises)

### Hotel (per-family estimate incl. tax)
F2 3 nights **$341.49** · F3 2 rooms × 3 nights **$682.98** · F4 2 nights **$227.66** · F5 5 nights **$569.15** · F6 3 nights **$341.49** · F11 3 nights **$341.49**
- Booking link + code visible to registered families only (not before registration, not to F8 after cancelling)
- Intent but no confirmation: **F3** (until event), **F6** (until Jun 10, 2027)
- F5's two nights before the event assume the hotel extends the group rate `[ASSUMPTION]`, confirm with the hotel

### Directory ("Who's here")
- Shows **F1, F2, F3, F5, F11** only (opt-in) · name, city, Derod relation/branch · **never** phone or email

### Sponsorship & donations (cash)
- Pledged **$19,502** · received **$17,503** · outstanding **$1,999** (F2)
- Before F6 pays (before Mar 20, 2027): received **$16,502**
- Lunch – Sun: ask $7,000 · pledged **$7,000 (100%) → "Fully pledged"**, no longer pickable · received **$5,001 (71%)**
- Bottled water: ask $900 · **$399** remaining
- Gala Night Dinner: **already sponsored**, not pickable
- D-09: F2 cancels its pledge → Lunch – Sun pledged **$5,001**, reopens with **$1,999** remaining; total pledged **$17,503**
- D-10: F2 pays $1,000 of $1,999 → Lunch – Sun received **$6,001**; total received **$18,503**; reminders continue for **$999**
- In-kind (separate from cash): **$950** (airline gift card $500, Dyson $450)
- Public thank-you list (names only, no amounts): **Patel (Dallas)**, **Bhakta (Dallas)**, **Bhakta (Chicago)**, **Patel Travels**, **"An anonymous family"**. F6 not shown. The list includes pledged-but-unpaid sponsors (Bhakta, Chicago) `[ASSUMPTION]`

### Budget & sponsorship list (parity with the workbook at 400 guests)
- Sample asks: Welcome Dinner **$9,000** · Breakfast **$4,500** · Bottled water **$900** · Lunch Sun **$7,000** · Pool Party **$10,500** · Gala Dinner **$11,000** · T-shirts **$4,000**
- Sponsorship list: **23** items · total ask **$101,900** · cost of listed items **$88,600** · cost of everything else (paid by fees) **$30,900** · registration income **$40,800** · fees left over **$9,900**
- Budget totals (with 10% contingency): **$127,400** at 375 · **$131,500** at 400 · expected income **$97,800** / **$101,200** · shortfall **–$29,600** / **–$30,300**

### Raffle
- Sales: card **$170** · Zelle **$50** · cash **$600** · total **$820** · tickets **97**
- Tickets per drawing: Fri night **71** · Sat night **8** · Sun Gala **18**
- Prizes per drawing: Fri 22 · Sat 8 · Sun 3 · Kids 6 → Sat night has as many prizes as tickets (every ticket wins; the app warns the committee before the draw)
- Kids drawing entries: **12** before the walk-in, **13** after (Aarav, 7, registered Sat 4:00pm before the 5:00pm draw); Neel (17) included, Rohan (18) not, F8 none
- Purchased prize cost: **~$3,000** (workbook)

### Helpers
- Planned: 10 per meal × 8 meals = **80 shifts**, 4 hours, $20/hr → **$6,400** budget
- Logged for M1: 11.5 hours → **$230** pay (H1 $80, H2 $80, H3 $70)

### After the event (K-01, on seed data)
- In: fees **$2,250** + sponsorship received **$17,503** + raffle **$820** = **$20,573**, against the actual spend entered per budget line, including helper pay and the waterpark invoice

### Notification times
- Pre-event reminders are sent at **10:00am Central**: F5 receives them at **4:00pm BST**, F6 at **11:00am EDT**, F11 at **8:00am MST** (Phoenix, no DST)
- Hotel-not-booked: **60, 30, 14 and 7 days before the Jul 3 cutoff**: **May 4, Jun 3, Jun 19, Jun 26, 2027**
- Pledge reminders: 30 days after the pledge, then every 30 days, stopping on receipt **or at event start (Jul 16)** `[ASSUMPTION]`: F6 **Feb 14, Mar 16, 2027** (none after Mar 20) · F2 **Mar 31, Apr 30, May 30, Jun 29, 2027** (no Jul 29)

---

## 5. Test scenarios

### A — Event setup
- **A-01** Event with dates, America/Chicago, venue address, Garland Hall.
- **A-02** Full schedule from §1, including the two-location Saturday lunch, shuttle runs, the bhajan day program, the kids drawing and three raffle drawings; M8 "location TBD"; placeholder times editable.
- **A-03** Bilingual event name/description; Gujarati uses **દેરોદ**. A test fails if **ડેરોડ** appears anywhere in Gujarati strings, templates or seed text.
- **A-04** Sponsorship list from §3 loaded, including an already-sponsored item (Gala Night Dinner).
- **A-05** Map/directions entries: hotel, Garland Hall, Hawaiian Waters, shuttle pickup point, parking.
- **A-06** Hawaiian Waters package configured: $8,500, 250 included, $30.99 extra, 8.25% tax.

### L — Login & accounts
- **L-01** Google sign-in creates an account.
- **L-02** Apple sign-in creates an account.
- **L-03** Phone one-time code login (Meera, F3).
- **L-04** Email one-time code login (Savita, F4, web only).
- **L-05** Family contact invites a family member; the invitee gets access to **that family only**.
- **L-06** Same person signs in with Google, later with an email code using the same email → same account, not a duplicate `[ASSUMPTION]`.
- **L-07** Web link registration works with no app installed; app login later shows the same family.

### B — Registration
- **B-01** Contact registers the whole family with every per-person field: name, date of birth/age, diet V/J/N, Derod relation, T-shirt size, arrival/departure, kids activities (under 18 only), meal-by-meal attendance, **waterpark vs. hotel on Saturday**.
- **B-02** Per-person arrival/departure: F4 arrives Sat 11:00am → excluded from M1, M2, P1 automatically.
- **B-03** Per-meal, per-person opt-out (Jaya M2).
- **B-04** Headcount, diet, kids activities, 21+ counts and T-shirt report match §4.
- **B-05** Per-meal counts match §4, by diet, including the **Saturday lunch at each location**.
- **B-06** Family member (Meera) edits the registration → counts update; audit shows who changed what.
- **B-07** Hotel section: intent (rooms, nights), confirmation number; booking link + code shown after registration only.
- **B-08** Directory opt-in setting per family (default **off**).
- **B-09** Registration fully usable in Gujarati.
- **B-10** Export for the caterer: registrations and per-meal, per-location counts by diet (CSV/Excel).
- **B-11** Duplicate handling: F10's Ramesh & Kamla flagged against F3; committee merges into F3; counts go from the before-merge values to the §4 values; F3's fee stays $600; the merge is logged; F10's contact loses access.
- **B-12** Capacity: admin sets a limit (400); registration past it goes to a waitlist; a cancellation offers the place to the waitlist; walk-ins past capacity warn but can be overridden by admin `[ASSUMPTION]`.
- **B-13** Registration closes on a set date; later changes need committee help.
- **B-14** Caterer count freeze: admin locks meal counts on a date; later changes are listed as a delta for the caterer.
- **B-15** After the Jul 3 hotel cutoff: the booking link is replaced by "call the hotel" and hotel reminders stop; F3 is listed for the hotel sub-team.
- **B-16** Cancelled F8 is excluded from every count, list, drawing and reminder.

### C — Fees & payments
- **C-01** $150-per-adult rule for every family matches §4 (F4 and F11 $150, F5 $450, Neel/Rohan age boundary).
- **C-02** Card payment in app (sandbox) → paid + receipt.
- **C-03** Zelle: family marks "sent by Zelle" → status **pending**; finance confirms → **paid** + receipt; totals before/after match §4.
- **C-04** Check (#1043) and cash recorded by finance with method and reference.
- **C-05** Pay at check-in: F6 shows "$300 due at check-in"; a volunteer at the desk records card/cash; totals after the event match §4.
- **C-06** F8 cancels after paying → $300 refund (sandbox) or credit; removed from all counts and totals; cancellation record kept.
- **C-07** Receipts name the organization and the payment method.
- **C-08** Admin changes the fee per adult or the kid age cutoff → totals recalculate. Families already paid are not re-billed unless finance chooses to `[ASSUMPTION]`.
- **C-09** F1 adds a third adult after paying → owes **+$150**, and the unpaid reminder restarts for that amount.
- **C-10** F5 removes Rohan after paying $450 → **$150** refund due, handled by finance.
- **C-11** Partial cancellation: one person cancels, the family stays, counts and fee recalculate.
- **C-12** No-show: a family never checks in; pay-at-check-in F6 would stay owing $300 and is listed for finance, with meals still counted until the freeze.
- **C-13** Refund window: the cancellation deadline and refund percentage are settings `[OWNER INPUT]` for the policy.
- **C-14** Zelle never arrives: finance rejects the pending report → the family is told and returns to unpaid.
- **C-15** Zelle amount differs from the fee → finance records the actual amount; the balance shows the difference.
- **C-16** Partial payment: F3 pays $300 of $600 → balance $300; reminders use the new balance.
- **C-17** Failed card: the family stays unpaid and is told why; no receipt.
- **C-18** Double submit or retried webhook → one charge and one receipt.
- **C-19** Chargeback: finance is notified; the family returns to owing.
- **C-20** Card processing fee: report net vs gross. Who absorbs the fee is `[OWNER INPUT]`.

### D — Sponsorships & donations
- **D-01** A family picks an open item to sponsor and pledges an amount. Families see only Include = Yes items, never costs or off-list items.
- **D-02** Several sponsors share one item; % pledged and % received shown (Lunch – Sun: 100% / 71%).
- **D-03** Fully pledged and already-sponsored items can't be picked (Lunch – Sun after F2, Gala Night Dinner).
- **D-04** Pledge now, pay later; pledged vs received tracked; totals match §4.
- **D-05** General tier sponsorship (F6 Gold) not tied to an item.
- **D-06** Public thank-you list matches §4: names only, recognition opt-in respected, an anonymous option, no amounts.
- **D-07** A business sponsor (Patel Travels) can be added by finance.
- **D-08** Sponsor receipts.
- **D-09** F2 cancels the pledge → Lunch – Sun reopens with $1,999 remaining; the reminder stops.
- **D-10** F2 pays $1,000 of $1,999 → Lunch – Sun received $6,001; reminders continue for $999.
- **D-11** A pledge above the remaining amount is rejected, or offered the remainder (Bottled water: $399 left).
- **D-12** Two sponsors pledge the last $1,999 at the same moment → one succeeds, the other is told.
- **D-13** A non-shareable item (Photography & video) accepts one sponsor for the full amount only.
- **D-14** An item added without an amount yet shows "amount to be announced" and accepts pledges; when an amount is set, existing pledges count toward it `[TEST VALUE]` item.
- **D-15** Donation receipts name the nonprofit and EIN, the date and amount, and state whether goods or services were received. Wording to be approved by the nonprofit's accountant, including sponsors who also attend `[OWNER INPUT]`.
- **D-16** In-kind donations are kept separate from cash, with value, donor and use (raffle prizes): $950 in §4.

### BG — Budget & sponsorship list
- **BG-01** Budget lines by type: per person, per adult, fixed, hotel (× 23% service × 8.25% tax), package (base + extras × price × tax). Each estimate rounded to the nearest $100.
- **BG-02** Two planning headcounts (375, 400) side by side, plus **live** totals at the registered headcount.
- **BG-03** **Parity with the workbook fixture:** every line, subtotal and total at 375 and 400 matches `Derod_Gaam_2027_Budget_Estimate.xlsx` to the dollar (totals in §4).
- **BG-04** Changing any input (e.g., gala plate price, waterpark share, helper rate) updates every dependent line and total; no total can be typed over.
- **BG-05** Actuals entry per line with variance; contingency 10%.
- **BG-06** Sponsorship list: Include Yes/No per item; ask = cost × 1.10 rounded up per §1; asks match §4.
- **BG-07** Summary: 23 items, $101,900 ask, $88,600 listed cost, $30,900 paid by fees, $40,800 registration, $9,900 left over; flipping Alcohol to No updates all five.
- **BG-08** Budget and sponsorship amounts visible to admin and finance only (UI and API).

### H — Committee, tasks, vendors, permissions
- **H-01** Committee sub-teams (food, hotel, program, finance, waterpark, registration); members assigned.
- **H-02** Tasks with owner, due date, status, sub-team; overdue highlighted.
- **H-03** Vendors (caterer, DJ, decorator, photographer, Hawaiian Waters, shuttle company, hotel) with contacts, contract files and deadlines; amounts visible to admin/finance only.
- **H-04** Budget: estimate vs actual per line; visible to admin/finance only. Detailed in BG-01…BG-08.
- **H-05** Permissions matrix from §2 — one test per role per restricted screen/API (UI **and** backend rules). Especially: a committee member cannot read any money field via the API; a volunteer sees only the balance of the family being checked in.
- **H-06** Dual roles: Amit (F1 contact, program committee) sees F1's fee and receipts, and no other family's money or the budget.
- **H-07** Removing someone from the committee ends access immediately, including tasks, money and scanners; an admin cannot be the only one who can do so (at least 2 admins).

### V — Volunteers
- **V-01** Shift schedule per volunteer.
- **V-02** QR check-in scanner (see J-01).
- **V-03** Meal-line counter: tap to count plates served by diet (V/J/N) per meal **and location**; totals visible to the food team.
- **V-04** Report an issue (category, text, optional photo): "food running low" → food team; "lost child" → all admins + committee immediately.
- **V-05** Paper raffle sales log (see RF-03).

### W — Saturday waterpark day
- **W-01** Per-person sign-up (waterpark vs. hotel); totals 24 / 5.
- **W-02** Package cost recalculates: 24 → $9,201.25; 260 synthetic → $9,536.72; exactly 250 → $9,201.25.
- **W-03** Committee alerts at 225 and above 250.
- **W-04** Shuttle assignment: 17 riders, 15 seats per run, families together, no overbooking, drivers excluded; manual move between runs allowed if seats are free.
- **W-05** Liability waiver: the family contact accepts for each member going (parent/guardian for minors); waiver text versioned; timestamp and signer stored.
- **W-06** Missing-waiver list shows F5; the boarding check at the shuttle flags F5 until signed.
- **W-07** Park meal count goes to Hawaiian Waters; hotel lunch count goes to the caterer; each person counted at exactly one location.
- **W-08** Personal agenda: waterpark people see S1/S2, W1, R1/R2 and the park meal; hotel people see B1 and the hotel lunch.
- **W-09** Bhajan day program visible to all; it isn't a sign-up (no headcount needed).

### RF — Raffle
- **RF-01** Raffle configured: prices $10 / 6 for $50, organization name shown on tickets and receipts, drawings Fri night, Sat night, Sun Gala, Kids (Sat).
- **RF-02** In-app purchase (card, Zelle) assigns unique ticket numbers to the chosen drawing; the receipt lists the numbers.
- **RF-03** A volunteer logs paper sales (ticket number ranges, payment method, drawing); ranges can't overlap or repeat.
- **RF-04** Totals match §4: $820 by method; 97 tickets; 71 / 8 / 18 per drawing.
- **RF-05** Prize list with purchased/donated, donor and value; **cash prizes rejected**, gift cards accepted; in-kind value $950.
- **RF-06** Draw (seeded RNG): winners only from that drawing's tickets; a ticket can't win twice in one drawing; every draw logged (who ran it, time, seed, ticket, prize).
- **RF-07** Warning when prizes ≥ tickets (Sat night: 8 and 8).
- **RF-08** Winner notified (push + email, in their language); an email-only winner like F4 gets email.
- **RF-09** Unclaimed: the Sun Gala grand-prize winner (F5) doesn't claim by **Mon Jul 19, 11:00am** → redraw from the Sun Gala pool; committee notified; the original winner marked "unclaimed".
- **RF-10** Kids drawing: automatic free entries for every registered child under 18 (12, then 13 after the walk-in); no tickets sold; Rohan excluded, Neel included.
- **RF-11** Raffle sales flow into budget income; purchased prize cost flows into budget cost.
- **RF-12** Committee can run draws; volunteers can log sales but not draw; only finance sees raffle cash totals.

### HL — Paid helpers
- **HL-01** Helper role: 10 slots per meal × 8 meals = 80 shifts.
- **HL-02** Clock in/out; logged M1 hours give $230 (H1 $80, H2 $80, H3 $70).
- **HL-03** Finance pay report by helper and meal; the total feeds the budget "actual".
- **HL-04** Helpers see only their own shifts; no access to registrations or money.
- **HL-05** Unfilled slots per meal shown to the food team.

### AL — Alcohol (21+)
- **AL-01** The check-in list shows a 21+ flag per person: 16 before the walk-in, 18 after.
- **AL-02** Rohan (18) and all kids not flagged; age computed on the event date.

### J — Event days
- **J-01** QR code per family (in app and in email); scanning checks in the family and lets the volunteer tick which members are present (F4 alone on Sat; F9 walk-in gets a QR at the desk).
- **J-02** QR contains a token only — no names, phone or email encoded.
- **J-03** Walk-in: committee registers F9 at the door, takes $300 cash, shows a QR; counts and the kids drawing update.
- **J-04** Offline: check-in, meal counts and paper raffle logs work with no network; the queue syncs later; the same family scanned on two offline devices → **one** check-in after sync; meal counts from two devices **sum** correctly; ticket ranges still can't collide.
- **J-05** Live schedule "now & next" for everyone.
- **J-06** Personal agenda per family/person (F4 sees nothing before Sat 11am; F3's elders get the hotel lunch, not the park meal; kids activities show only for families with sign-ups).
- **J-07** Live update by a **committee member** (not admin): "Waterpark return moved to 2:00pm" → only waterpark people notified; shuttle times update. Volunteer and family accounts cannot send updates.
- **J-08** Directory shows only opted-in families, never contact details.
- **J-09** Language toggle EN ⇄ GU on every event-day screen.
- **J-10** Unpaid check-in: F3 is scanned with $600 due → check-in **succeeds**, the volunteer sees the balance and can record a payment, and finance is notified (N-23). Also applies to F6 if it declines to pay at the desk.
- **J-11** Scanning a cancelled family's QR (F8) or a merged one (F10) is rejected with a clear message.
- **J-12** Scanning the same family twice shows "already checked in at <time>" and does not double count.
- **J-13** No QR: the volunteer finds the family using the limited name search in §2, and the lookup is logged.
- **J-14** Paper fallback: admin prints a roster and meal sheet the night before, in case phones or network fail.
- **J-15** Partial arrival: part of a family checks in now and the rest later; both are recorded against one family.
- **J-16** Scanners stay signed in with no network for the whole shift, and a lost scanner can be revoked.

### K — After the event
- **K-01** Final reconciliation for finance: fees + sponsorship + raffle vs actual spend, including helper pay and the waterpark invoice (§4).
- **K-02** Bulk thank-you messages and receipts to sponsors and in-kind donors.
- **K-03** Export all event data (for the next host city).
- **K-04** Raffle report: every drawing, winner, claimed/unclaimed, redraws.

### X — Roster import from another tool
Kept for two cases: a bought tool as a stopgap if registration must open before Stage 2 is ready, and moving an event from another tool.
- **X-01** Import a roster of 400 people from the tool's export into CrewPoint, with all per-person fields and a validation report.
- **X-02** Re-import is safe: new families added, changes updated, nothing duplicated, and manual CrewPoint data kept.
- **X-03** A family cancelled in the tool is removed from counts and its QR is revoked on the next import.
- **X-04** Payment status and balance are imported, and a payment recorded at the door is reported back to finance for the tool.
- **X-05** A person signing in to CrewPoint is matched to their imported family by email or phone, never to another family's.
- **X-06** Import errors (missing diet, unknown age, duplicate email) are listed, and do not stop the good rows.
- **X-07** Tool outage or cancelled subscription: all data can still be exported.

### S — Scale (generated 400-person fixture)
- **S-01** 400 people can belong to the event (the 50-member cap must not block this).
- **S-02** Import of 108 families finishes within **2 min** and headcounts match.
- **S-03** The 7:00am morning summary to 400 recipients is fully handed to the mock transport within **5 min**, with a personal agenda each.
- **S-04** Live update delivered to 400 within **60 s** (mock).
- **S-05** Check-in rush: 108 families over 60 min on 4 scanners, with each scan under **2 s** and no lost or double check-ins.
- **S-06** Meal line: 400 plates in 45 min across 2 counters, totals correct.
- **S-07** Event screens stay usable with 400 members: chat with **5,000 messages**, member list, and task list.
- **S-08** Monthly cost estimate for reads, writes, function runs, email and SMS at this size.

### R — Safety
- **R-01** Allergy and medical notes per person, kept separate from diet, visible to the food team as counts and to admins per person.
- **R-02** Emergency contact per family, visible to admins only and available offline.
- **R-03** Medical emergency issue category: alerts admins and committee at once.
- **R-04** Weather or outdoor change: moving the waterpark program or the park meal reaches everyone affected, including those who opted out of the meal.
- **R-05** Kids activity sign-in and sign-out by a named guardian.
- **R-06** Lost child alerts need an acknowledgement, and go back out if nobody responds within **2 min** `[ASSUMPTION]`.

### Z — Privacy and consent
- **Z-01** Children's data: only a parent enters it, birth dates are not shown to committee or volunteers, and only age bands appear in reports.
- **Z-02** Photo and video consent per family, including children, available to the photographer.
- **Z-03** Liability waiver accepted at registration and recorded `[OWNER INPUT]` for the text. The waterpark waiver is W-05.
- **Z-04** UK and Canadian attendees: consent, access and deletion requests work, and the privacy policy covers them.
- **Z-05** Email has a working unsubscribe for non-essential messages; SMS (if used) is registered and consented, with international cost understood.
- **Z-06** Tax and legal wording on receipts is approved, and records are kept for the required period `[OWNER INPUT]`.
- **Z-07** Data retention after the event: what is deleted, what passes to the next host (K-03), and with what consent.

### O — Operations
- **O-01** Billing alerts, budget caps and a named owner. A lapsed billing account must not be able to take the event down unnoticed, as happened on Nov 2, 2026.
- **O-02** Crash reporting and backend error alerts reach a person during event hours.
- **O-03** Automated Firestore backups, with a restore rehearsed.
- **O-04** Email domain authenticated (SPF, DKIM, DMARC), with bounce handling and a test send to Gmail, Outlook and Yahoo.
- **O-05** App approved in the App Store and Google Play before announcement, with enough lead time for fixes.
- **O-06** Release freeze from Jul 9, with a rollback plan; old app versions keep working.
- **O-07** Venue network test: Wi-Fi and cell coverage in Garland Hall and at Hawaiian Waters.
- **O-08** Event-day on-call plan and contacts.

### U — Accessibility and language
- **U-01** Readable at 200% system text size, on every family and volunteer screen.
- **U-02** Screen reader labels on registration, agenda and check-in.
- **U-03** Gujarati renders correctly (spelling **દેરોદ**) on iOS, Android, web, email and PDF receipts.
- **U-04** Colour contrast meets WCAG AA in light and dark mode.
- **U-05** An older non-technical user (Savita, 74) can complete web registration and find her agenda, in Gujarati, unaided. Needs a real session with a person.

---

## 6. Notifications

Channels: **push** for app users, **email** for everyone. Email-only users (F4) get everything by email, including 15-minute reminders. Each message is in the recipient's language. **No quiet hours.** For every test, assert recipients, channel, send time (fake clock), language, resolved placeholders, and that nobody else received it.

**Who receives it** `[ASSUMPTION]`: pre-event messages go to the family contact. Event-day messages go to every family member with their own login, each in their own language.

| ID | Notification | Trigger / timing | Recipients (seed) | Channel |
|---|---|---|---|---|
| **N-00** | Safety | Test run | Mock transports only; zero real sends or charges | — |
| **N-01** | Registration confirmation | On submit | Each contact; **Gujarati** for F3, F4, F7 (spelling દેરોદ) | Push + email (F4 email only) |
| **N-02** | Family member invite | On invite | Meera (F3) | Email (+ SMS if phone code is the invite method) |
| **N-03** | Payment receipt | Card on success · Zelle on confirm (+ "pending" note when reported) · check/cash when recorded | Paying families; F6 and F9 at check-in | Push + email |
| **N-04** | Unpaid fee reminder | 1st of each month Dec 1, 2026 – May 1, 2027, then Mondays Jun 7, 14, 21, 28, Jul 5, 12, 2027, at 10:00am CT | **F3 only** (not F2 while Zelle is pending, not F6 paying at check-in, not F8) | Push + email |
| **N-05** | Hotel not booked | May 4, Jun 3, Jun 19, Jun 26, 2027, 10:00am CT (60/30/14/7 days before the cutoff) | F3 all four; F6 May 4 and Jun 3 only. Never F1, F7 (local), F2, F4, F5, F11 (booked), F8 | Push + email |
| **N-06** | Pledge not received | 30 days after the pledge, every 30 days, stops on receipt or at event start | F6 Feb 14, Mar 16 · F2 Mar 31, Apr 30, May 30, Jun 29; open pledges then go on a list for finance | Push + email |
| **N-07** | Know before you go | Fri Jul 9, 2027, 10:00am CT | All active families: address, parking, map, agenda, QR, **shuttle run & time** for riders, balance due (F3 $600; F6 $300 at check-in) | Push + email |
| **N-08** | Morning summary | 7:00am CT, Jul 16–19 | Each family's agenda for the day; F4 by email Sat–Mon; F1, F7 no Monday summary | Push + email |
| **N-09** | 15-minute session reminder | 15 min before each agenda item, in event time | Only people with that item (e.g., the hotel lunch → Ramesh, Kamla, Savita, Hemant, Mahesh; K1 only to families with sign-ups), **including F4 by email** | Push + email |
| **N-11** | Live schedule change | Committee member, e.g., the return shuttle moved | Only affected people, within 60 s (mock); F4 by email | Push + email |
| **N-12** | Segment messages | Committee sends to a segment | Jain diet → F3 only · kids activities → F1, F3, F5, F7, F11 · waterpark → the 7 WP families · volunteers only → V1–V3 | Push + email |
| **N-13** | Helper & volunteer shift reminder | Day before 6:00pm + 30 min before `[ASSUMPTION]` | Each helper and volunteer, for their own shifts | Push + email |
| **N-14** | Issue alerts | Volunteer report | "Food running low" → food team · "Lost child" and medical emergency → all admins + committee, immediately, and through an event mute | Push; **emergencies also email at once**, plus SMS if adopted `[OWNER INPUT]` |
| **N-15** | Cancellation | F8 cancels | F8: cancellation + refund; then nothing else, ever | Push + email |
| **N-16** | Opt-out | Family turns off announcements | Still gets receipts, confirmations, waiver, shuttle and live changes `[ASSUMPTION]` | — |
| **N-17** | De-duplication | Same type twice for the same family within 24 h | Collapsed into one. **Never applies** to N-03, N-08, N-09, N-11, N-13, N-14 or N-15 | — |
| **N-18** | Delivery failure | Expired push token / bad email | Logged FAILED; push falls back to email | — |
| **N-19** | Scheduled message admin | Committee views, edits, cancels before sending | — | — |
| **N-20** | History | Per family: what, when (local + CT), channel, language, status | — | — |
| **N-21** | Language switch | F5 switches to Gujarati on Jul 1, 2027 | N-07 on Jul 9 arrives in Gujarati; earlier history stays in English | Push + email |
| **N-22** | Web-only coverage | Every message that applies to F4 | F4 receives each by **email**; nothing is silently dropped because she has no app | Email |
| **N-23** | Finance: unpaid check-in | A family with a balance checks in (F3, $600) | **Finance team only**, one message per family with name, balance and checking volunteer. F6 paying at the desk does not trigger it. Offline scans send after sync | Push + email |
| **N-24** | Time-zone delivery | The Jun 3 hotel reminder at 10:00am CT | F5 4:00pm BST · F6 11:00am EDT · F11 8:00am MST (shown in local time in history) | — |
| **N-25** | Item fully pledged | When pledges reach the ask | Committee + finance (Lunch – Sun) | Push + email |
| **N-26** | Waterpark sign-up confirmation | On sign-up or change | Contact of each WP family | Push + email |
| **N-27** | Waiver missing | Jul 9, 10:00am and Jul 16, 6:00pm CT | **F5 only** | Push + email |
| **N-28** | Waterpark capacity | At 225 and above 250 sign-ups | Committee + finance | Push + email |
| **N-29** | Shuttle reminder | 30 min before the assigned run (e.g., Run 1 at 9:00am) | Riders on that run only | Push + email |
| **N-30** | Raffle purchase receipt | On purchase | Buyer, with ticket numbers and drawing | Push + email |
| **N-31** | Drawing starting soon | 15 min before each drawing | Holders of tickets in that drawing; kids drawing → parents of entered kids | Push + email |
| **N-32** | Raffle winner / unclaimed / redraw | On draw; Mon Jul 19, 8:00am reminder to unclaimed winners; on redraw | Winner; committee for redraws | Push + email |

---

## 7. Retired scenarios

These IDs are not reused.

| ID | Was | Why retired |
|---|---|---|
| N-10 | Quiet hours by recipient zone: a message sent during a recipient's quiet hours waits until 7:00am | The owner set **no quiet hours** for this event (§1). Per-user quiet hours remain a platform feature with their own tests |

---

## 8. Report format — `CONVENTION_TEST_REPORT_v4.md`

1. **Inventory** — stack, models, auth, roles, payments, notifications, offline, i18n, randomness source, test frameworks.
2. **Scorecard** — PASS / PARTIAL / FAIL / NOT BUILT / PLATFORM / NOT RUN / BLOCKED per section (A, L, B, C, D, BG, H, V, W, RF, HL, AL, J, K, X, S, R, Z, O, U, N).
3. **Results table:**

   | ID | Scenario | Status | Evidence (test / file:line) | Gap | Next | Needed by |
   |---|---|---|---|---|---|---|

4. **Priorities by the real calendar:**
   - **P0 – before opening registration and the sponsorship drive:** A, L, B-01…B-13, B-16, C-01…C-04, C-06, C-07, D-01…D-08, D-15, D-16, BG-06…BG-08, H-05, H-06, Z-01…Z-06, O-01, O-03, O-04, N-00…N-06, N-21, N-24
   - **P1 – spring 2027 (sponsorship, hotel, budget):** BG-01…BG-05, C-08…C-20, D-09…D-14, H-01…H-04, H-07, W-01…W-03, W-05, RF-01…RF-05, X, S-01, S-02, S-08, U-01…U-04, O-02, O-05, B-15, N-15…N-20, N-25, N-26, N-28
   - **P2 – final weeks + event days (Jul 2027):** W-04, W-06…W-09, RF-06…RF-12, HL, AL, J, V, R, C-05, B-14, S-03…S-07, O-06…O-08, U-05, N-07…N-14, N-22, N-23, N-27, N-29…N-32
   - **P3 – after the event:** K, Z-07
5. **Top 10 gaps**, each with a short implementation suggestion.
6. **Testability gaps.**
7. **Assumptions** — every `[ASSUMPTION]`, what the app does now, and a recommendation.
8. **Open questions for the owner** — every `[OWNER INPUT]`.
