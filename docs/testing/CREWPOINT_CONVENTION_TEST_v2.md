# CrewPoint — Derod Gaam Convention 2027 Acceptance Test (v2)

**Replaces:** `CONVENTION_READINESS_TEST.md` (v1). v2 is built from an interview with the product owner and defines how CrewPoint is *supposed* to work for this event. Where v1 and v2 disagree, v2 wins.

**Goal:** Prove CrewPoint can run the Derod Gaam Convention 2027 end to end — registration, payments, sponsorships, hotel info, committee work, the four event days, and every notification — and produce a prioritized list of what's missing.

---

## 0. Instructions for Claude Code

1. **Branch:** `test/derod-convention-v2`. Do **not** change application code. Add only tests, fixtures, a seed loader, and the report. If something can't be tested without an app change (e.g., no injectable clock, no mock notification transport), record it as a *testability gap* rather than changing the app.
2. **Inventory first** (report section 1): stack, data models, auth providers, roles/permissions, payments integration, notification infrastructure (push provider, email provider, templates, scheduling, localization, quiet hours, delivery logs), offline support, i18n, existing tests.
3. **Seed data:** build the fixture in §3 as `test/fixtures/derod_convention_2027_v2.json` (or the project's fixture convention) plus a loader.
4. **Write and run tests** for every scenario in §5 using the project's existing frameworks (unit / widget / integration / backend emulator). One test or group per scenario ID. Assert the exact expected values in §4.
5. **Safety (mandatory):**
   - No real push, email, SMS, or payment. Mock transports and payment sandboxes only. Test **N-00** must prove this.
   - Emulators / a test project only — never production data.
   - A fake, injectable clock for every time-based test. Event time zone `America/Chicago`.
6. **Classify each scenario:** PASS · PARTIAL (exists, some assertions fail or part missing) · FAIL (exists, broken) · NOT BUILT (describe what's needed; don't build it).
7. **Write `CONVENTION_TEST_REPORT_v2.md`** (format in §6), commit tests + fixture + report to the branch, and end with a short summary of the top gaps.
8. **Product rules marked `[ASSUMPTION]`** are best guesses not yet confirmed by the owner. Test them, but list every assumption and its result in report section 7 so the owner can confirm or change it.

---

## 1. Event facts

| Item | Value |
|---|---|
| Event | Derod Gaam Convention 2027, hosted by the Derod families of Dallas. Open to all Derod families (USA, Canada, UK). Last convention ~13 years ago |
| Dates | Fri Jul 16 – Mon Jul 19, 2027 · time zone America/Chicago |
| Venue | Hyatt Place Dallas/Garland/Richardson & Firewheel Conference Center, 5101 N George Bush Hwy, Garland, TX 75040 · function room: Garland Hall (rounds, 400) |
| Hotel | Families book their own rooms through a group booking link + code. Group rate $99/night + 14.98% tax. Booking cutoff **Jul 3, 2027**. Early departure = 1-night charge. *(Room-block attrition is tracked outside CrewPoint — do not test a block dashboard.)* |
| Languages | English + Gujarati, user-selectable. The village name in Gujarati is spelled **દેરોદ** (not ડેરોડ) |
| Fee model | **Hybrid:** $300 per family covers up to 2 adults and all kids; **+$150 per additional adult**. Kid = **under 18**. `[ASSUMPTION]` a 1-adult family still pays $300. `[ASSUMPTION]` age is computed on the event start date, Jul 16, 2027 |
| Payment methods | Card in app · Zelle (family reports it, finance confirms) · Check / cash (finance records) · Pay at check-in |

### Schedule (times marked * are placeholders until the program is final)

| ID | Item | When | Type | Where |
|---|---|---|---|---|
| M1 | Welcome Dinner | Fri Jul 16, 7:00pm* | Meal | Garland Hall |
| P1 | Karaoke & Garba | Fri Jul 16, 9:00pm* | Program | Garland Hall |
| M2 | Breakfast | Sat Jul 17, 8:00am* | Meal | Garland Hall |
| M3 | Lunch | Sat Jul 17, 12:30pm* | Meal | Outdoor (picnic park) — location may change |
| K1 | Kids activities | Sat Jul 17, 1:30pm* | Kids program | Outdoor (picnic park) |
| P2 | Bhajan & Prasad | Sat Jul 17, 4:00pm* | Program | Garland Hall |
| M4 | Dinner | Sat Jul 17, 7:00pm* | Meal | Garland Hall |
| P3 | Karaoke & Garba | Sat Jul 17, 9:00pm* | Program | Garland Hall |
| M5 | Breakfast | Sun Jul 18, 8:00am* | Meal | Garland Hall |
| M6 | Lunch | Sun Jul 18, 12:30pm* | Meal | Garland Hall |
| M7 | Gala Night Dinner + DJ | Sun Jul 18, 7:00pm* | Meal | Garland Hall |
| M8 | Farewell Breakfast | Mon Jul 19, 8:00am* | Meal | TBD |

### Donation / sponsorship items (from the committee's current list)

| Item | When | Ask | Shareable | Status at seed time |
|---|---|---|---|---|
| Welcome Dinner | Fri | $7,000 | Yes | Open |
| Breakfast | Sat | $2,500 | Yes | Open |
| Lunch | Sat | $5,000 | Yes | Open |
| Bhajan Prasad | Sat | (no amount yet) | — | Open, amount TBD |
| Dinner | Sat | $7,000 | Yes | Open |
| Breakfast | Sun | $2,500 | Yes | Open |
| Lunch | Sun | $5,000 | Yes | Open |
| Gala Night Dinner | Sun | — | — | **Closed: already sponsored** |
| Farewell Breakfast | Mon | $2,500 | Yes | Open |
| Water & soft drinks | All days | $2,500 | Yes | Open |
| Karaoke & Garba | Fri & Sat | $3,000 | Yes | Open |
| Gala night music / DJ | Sun | $2,500 | No | Open |
| Gala night decoration | Sun | $2,000 | Yes | Open |
| Paper products | All days | $2,000 | Yes | Open |
| Photography & video | All days | $2,000 | No | Open |
| **List total** | | **$45,500** | | |

Sponsorship tiers (general, not tied to an item): Platinum $3,001 · Gold $1,001 · Silver $501.

---

## 2. Who uses CrewPoint and what they can do

| Role | Login | Can | Cannot |
|---|---|---|---|
| **Admin** | Google/Apple or phone/email code | Everything | — |
| **Finance team** (committee sub-team) | same | See and record all money: fees, payments, Zelle confirmations, refunds, sponsorships, budget, vendor amounts | — |
| **Committee member** (food, hotel, program, picnic, registration sub-teams) | same | Tasks, vendors (no amounts), schedule, **send live updates**, view registrations & headcounts, register walk-ins | See any money amounts (fees paid, pledges, budget, vendor costs) |
| **Volunteer** | same | Own shifts, QR check-in scanner, meal-line counter, report issues; at check-in see **only** the balance due for the family being checked in and record its payment | See other finances, registrations list, send live updates |
| **Family contact** | same | Register the whole family, edit it, pay, pledge, invite family members, set directory opt-in, see personal agenda | See other families' data (except opted-in directory entries) |
| **Family member** (invited) | same | View and edit their own family's registration and agenda | Other families' data |
| **Sponsor** | (a family or a business) | Pledge, see own pledges/receipts, choose public recognition | Others' amounts |

Login: Google or Apple sign-in, **plus** phone-number or email one-time code for people without Google/Apple. Families can register from a **web link** (no install) or the **app**; the app is optional and adds push notifications.

---

## 3. Seed data

Ages are on Jul 16, 2027. Diet: V = veg, J = Jain, N = non-veg. "Kids act." = signed up for kids activities (K1). Only listed opt-outs differ from "attends every meal between arrival and departure."

### F1 — Patel, Dallas TX (local) · English · app · directory: **listed**
| Person | Age | Diet | T-shirt | Derod relation | Kids act. |
|---|---|---|---|---|---|
| Amit (contact) | 45 | V | L | Son of Bhikhubhai Patel | — |
| Nisha | 42 | V | M | Wife of Amit | — |
| Riya | 10 | V | YM | Daughter of Amit | Yes |
| Dev | 6 | V | YS | Son of Amit | Yes |
Arrive Fri Jul 16 · depart Sun Jul 18 night (skips M8) · no hotel · paid **$300 card** · sponsor **Silver $501, received**, applied to *Water & soft drinks*, public recognition **yes**.

### F2 — Bhakta, Chicago IL (flying) · English · app · directory: **listed**
| Raj (contact) 38 V L · Priya 36 V S · Kiaan 3 V 2T (kids act. **No**) |
Arrive Fri · depart Mon · hotel 1 room, nights Jul 16–18, confirmation **HP123456** · reports **$300 Zelle** (pending until finance confirms) · pledges **$1,999 to Sun Lunch** by Zelle on Mar 1, 2027 (not received) · recognition **yes**.

### F3 — Desai, Edison NJ (flying) · **Gujarati** · app · directory: **listed**
| Person | Age | Diet | Notes |
|---|---|---|---|
| Kunal (contact) | 44 | V | Invites Meera as family member |
| Meera | 41 | V | Accepts invite, logs in with phone code |
| Ramesh | 72 | J | Opts out of M3 (Sat lunch outdoors) |
| Kamla | 70 | J | Opts out of M3 |
| Neel | 17 (born Jul 17, 2009 — turns 18 the day after event start) | V | Kid for fees · kids act. No |
| Asha | 8 | V | Kids act. Yes |
| Om | 4 | V | Kids act. Yes |
Arrive Fri · depart Mon · hotel **intent 2 rooms**, nights Jul 16–18, **no confirmation yet** · **unpaid** (owes $600).

### F4 — Mistry, Houston TX (driving) · **Gujarati** · **web only (no app)**, email-code login · directory: **not listed**
| Savita (contact) 74 V M |
Arrives **Sat Jul 17, 11:00am** (misses M1, M2, P1) · depart Mon · hotel 1 room, nights Jul 17–18, confirmation **HP223344** · paid **$300 by check #1043** (recorded by finance).

### F5 — Chauhan, London UK (flying) · English · tz Europe/London · app · directory: **listed**
| Vikram (contact) 47 N · Anjali 45 N · Rohan **18** N (adult) · Tara 14 N (kids act. No) · Kabir 9 N (kids act. Yes) |
Arrive Fri · depart Mon · hotel 1 room, nights **Jul 14–18** (2 nights before the event), confirmation **HP334455** · paid **$450 card**.

### F6 — Patel, Toronto Canada (flying) · English · tz America/Toronto · app · directory: **not listed**
| Hemant (contact) 52 V · Jaya 50 N (opts out of M2) |
Arrive Fri · depart Mon · hotel **intent 1 room, no confirmation**; enters confirmation **HP445566 on Jun 10, 2027** · payment method **pay at check-in** ($300) · sponsor **Gold $1,001** (general) pledged **Jan 15, 2027**, received **Mar 20, 2027** · recognition **no**.

### F7 — Bhakta, Dallas TX (local, host family) · **Gujarati** · app · directory: **not listed**
| Mahesh (contact) 50 V · Leela 48 V · Sonal 11 V (kids act. Yes) · Jay 5 V (kids act. Yes) |
Arrive Fri · depart Sun night (skips M8) · no hotel · paid **$300 cash** (recorded by finance) · sponsor **Platinum $3,001, received**, applied to *Sun Lunch* · recognition **yes**.

### F8 — Shah, Atlanta GA · English
2 adults, V · paid **$300 card**, then **cancels on Mar 1, 2027** → full refund.

### F9 — Joshi, Austin TX · **walk-in**
Not pre-registered. Registered at the door by a committee member on **Sat Jul 17, 4:00pm**: 2 adults + 1 kid (7), all V · attends M4–M7, leaves Sun night · pays **$300 cash at check-in**.

### F10 — Desai, Houston TX · **duplicate**
A sibling registers **Ramesh (72, J) and Kamla (70, J) Desai** again, same Derod relation as in F3. Committee merges them into F3 and removes F10.

### Staff
admin ×1 · finance ×1 · committee: food ×1, program ×1, registration ×1 · volunteers ×3 (V1 check-in, V2 meal line, V3 floater), each with shifts on Jul 16–18.

---

## 4. Expected values (hand-checked)

### Headcount (after F10 merge, F8 cancelled, before walk-in)
- Families **7** · adults **16** · kids **10** · total **26**
- Diet: veg **18** · Jain **2** · non-veg **6**
- Kids activities sign-ups: **7** (Riya, Dev, Asha, Om, Kabir, Sonal, Jay)
- T-shirt report: one count per size; sizes sum to **26**
- After walk-in F9: families **8** · adults **18** · kids **11** · total **29**

### Per-meal counts (per person, from arrival/departure + opt-outs)
| Meal | Total | Veg | Jain | Non-veg | Why |
|---|---|---|---|---|---|
| M1 Fri Welcome Dinner | 25 | 17 | 2 | 6 | F4 not arrived |
| M2 Sat Breakfast | 24 | 17 | 2 | 5 | F4 not arrived; Jaya opts out |
| M3 Sat Lunch | 24 | 18 | 0 | 6 | Ramesh & Kamla opt out |
| M4 Sat Dinner | 26 | 18 | 2 | 6 | Everyone |
| M5 Sun Breakfast | 26 | 18 | 2 | 6 | Everyone |
| M6 Sun Lunch | 26 | 18 | 2 | 6 | Everyone |
| M7 Sun Gala Dinner | 26 | 18 | 2 | 6 | Everyone |
| M8 Mon Farewell Breakfast | 18 | 10 | 2 | 6 | F1, F7 local, gone |

After the walk-in (F9, 3 veg) registers Sat 4:00pm: **M4, M5, M6, M7 = 29** (veg 21, Jain 2, non-veg 6). M1–M3 and M8 unchanged.

### Fees (hybrid)
| Family | Adults | Fee | How paid |
|---|---|---|---|
| F1 | 2 | $300 | Card |
| F2 | 2 | $300 | Zelle (pending → confirmed) |
| F3 | 4 | **$600** | Unpaid |
| F4 | 1 | $300 `[ASSUMPTION]` | Check #1043 |
| F5 | 3 (Rohan is 18) | **$450** | Card |
| F6 | 2 | $300 | Pay at check-in |
| F7 | 2 | $300 | Cash |
| F8 | 2 | $300 → refunded | Card → refund |
| F9 | 2 | $300 | Cash at door |

- Billed (F1–F7): **$2,550**
- Before Zelle confirmed: paid **$1,350** · pending **$300** (F2) · outstanding **$900** (F3 $600, F6 $300 at check-in)
- After Zelle confirmed: paid **$1,650** · outstanding **$900**
- After event check-in (F6 pays card at desk, F9 walk-in cash): billed **$2,850** · paid **$2,250** · outstanding **$600** (F3)
- F8: refund **$300**, excluded from all totals
- Neel (17, turns 18 on Jul 17) is a **kid**; Rohan (18) is an **adult**

### Sponsorships
- Water & soft drinks: ask $2,500 · F1 $501 received → remaining **$1,999** (20% funded)
- Sun Lunch: ask $5,000 · F7 $3,001 received + F2 $1,999 pledged → pledged **$5,000 (100%)**, received **$3,001 (60%)** → shows **Fully pledged**, no longer pickable
- Gala Night Dinner: **closed / already sponsored**, not pickable
- Bhajan Prasad: open, amount **TBD** (shows "amount to be announced", still pledgeable as any amount `[ASSUMPTION]`)
- Totals: pledged **$6,502** · received **$3,502** (before F6 pays) → **$4,503** after F6 pays on Mar 20 · outstanding **$1,999** (F2)
- Public thank-you list: **Patel (Dallas)**, **Bhakta (Chicago)**, **Bhakta (Dallas)** — names only, **no amounts**; F6 not shown
- Open items still needing sponsors: all except Sun Lunch and Gala Night Dinner

### Hotel
- Booking link + code visible to registered families only (not before registration, not to F8 after cancelling)
- Families with hotel intent but no confirmation: **F3** (until event) and **F6** (until Jun 10, 2027)
- Per-family hotel cost estimate incl. tax: F2 3 nights = **$341.49** · F3 2 rooms × 3 nights = **$682.98** · F4 2 nights = **$227.66** · F5 5 nights = **$569.15**

### Directory ("Who's here")
- Shows **F1, F2, F3, F5** only (opt-in) · name, city, Derod relation/branch · **never** phone or email
- During event: optional "checked in" badge per listed family

---

## 5. Test scenarios

### A — Event setup
- **A-01** Event with dates, America/Chicago, venue address, Garland Hall.
- **A-02** Schedule from §1 incl. programs and kids activity; M3/K1 flagged outdoor; M8 "location TBD"; placeholder times editable.
- **A-03** Bilingual event name/description; Gujarati uses **દેરોદ**. Add a test that fails if **ડેરોડ** appears anywhere in Gujarati strings, templates, or seed text.
- **A-04** Donation item list from §1 loaded, incl. a closed item (Gala Dinner) and an item with no amount (Bhajan Prasad).
- **A-05** Map/directions entries: hotel address, Garland Hall, picnic park (TBD), parking.

### L — Login & accounts
- **L-01** Google sign-in creates an account.
- **L-02** Apple sign-in creates an account.
- **L-03** Phone one-time code login (Meera, F3).
- **L-04** Email one-time code login (Savita, F4, web only).
- **L-05** Family contact invites a family member; invitee gets access to **that family only**.
- **L-06** Same person signs in with Google, later with email code using the same email → same account, not a duplicate `[ASSUMPTION]`.
- **L-07** Web link registration works with no app installed; app login later shows the same family.

### B — Registration
- **B-01** Contact registers whole family with every per-person field: name, age (or date of birth), diet V/J/N, Derod relation, T-shirt size, arrival date/time, departure date, kids activity (shown only for under-18), per-meal attendance.
- **B-02** Per-person arrival/departure: F4 arrives Sat 11:00am → excluded from M1, M2, P1 automatically.
- **B-03** Per-meal, per-person opt-out (Jaya M2; Ramesh & Kamla M3).
- **B-04** Headcounts, diet totals, kids activity count, T-shirt report match §4.
- **B-05** Per-meal counts match §4 table, by diet.
- **B-06** Family member (Meera) edits registration → counts update; audit shows who changed what.
- **B-07** Hotel section: intent (rooms, nights), confirmation number field; booking link + code shown after registration only.
- **B-08** Directory opt-in setting per family (default **off**).
- **B-09** Registration form fully usable in Gujarati.
- **B-10** Export registrations + per-meal diet counts to CSV/Excel for the caterer.

### C — Fees & payments
- **C-01** Hybrid fee calculation for every family matches §4 (incl. F4 single adult, F5 three adults, Neel/Rohan age boundary).
- **C-02** Card payment in app (sandbox) → paid + receipt.
- **C-03** Zelle: family marks "sent by Zelle" → status **pending**; finance confirms → **paid** + receipt; totals before/after match §4.
- **C-04** Check (#1043) and cash recorded by finance with method and reference.
- **C-05** Pay at check-in: F6 shows "$300 due at check-in"; volunteer at desk records card/cash; totals after event match §4.
- **C-06** F8 cancels after paying → refund $300 (sandbox) or credit; removed from all counts and totals; cancellation record kept.
- **C-07** Receipts name the nonprofit and payment method.
- **C-08** Fee settings changeable by admin (family fee, extra-adult fee, kid age) and totals recalculate.

### D — Sponsorships & donations
- **D-01** Family picks an open item to sponsor and pledges an amount.
- **D-02** Several families share one item; % pledged and % received shown (Sun Lunch: 100% / 60%).
- **D-03** Fully pledged and closed items can't be picked (Sun Lunch after F2, Gala Dinner).
- **D-04** Pledge now, pay later; pledged vs received tracked; totals match §4.
- **D-05** General tier sponsorship (F6 Gold) not tied to an item.
- **D-06** Public thank-you list: names only, recognition opt-in respected, no amounts.
- **D-07** Business/vendor sponsor (non-family) can be added by finance.
- **D-08** Sponsor receipts.

### H — Committee, tasks, vendors, budget
- **H-01** Committee sub-teams (food, hotel, program, finance, picnic, registration); members assigned.
- **H-02** Tasks with owner, due date, status, sub-team; overdue highlighted.
- **H-03** Vendors (caterer, DJ, decorator, photographer, hotel bar) with contacts, contract file, deadlines; amounts visible to admin/finance only.
- **H-04** Budget: estimate vs actual per line; visible to admin/finance only.
- **H-05** Permissions matrix from §2 — one test per role per restricted screen/API (UI **and** backend rules). Especially: committee member cannot read any money field via the API; volunteer sees only the balance of the family being checked in.

### V — Volunteers
- **V-01** Shift schedule per volunteer.
- **V-02** QR check-in scanner (see J-01).
- **V-03** Meal-line counter: tap to count plates served by diet (V/J/N) per meal; totals visible to food team.
- **V-04** Report an issue (category, text, optional photo): "food running low" → food team; "lost child" → all admins + committee immediately.

### J — Event days
- **J-01** QR code per family (in app and in email); scanning checks in the family and lets the volunteer tick which members are present (F4 alone on Sat; F9 walk-in gets a QR at the desk).
- **J-02** QR contains a token only — no names, phone, or email encoded.
- **J-03** Walk-in: committee registers F9 at the door, takes $300 cash, prints/shows QR; counts update for M4–M7.
- **J-04** Offline: check-in and meal counts work with no network; queue syncs later; same family scanned on two offline devices → **one** check-in after sync; meal counts from two devices **sum** correctly.
- **J-05** Live schedule "now & next" for everyone.
- **J-06** Personal agenda per family/person (F4 sees nothing before Sat 11am; F3 elders don't see Sat lunch; kids activity shows only for families with sign-ups).
- **J-07** Live update: a **committee member** (not admin) changes M3 location to "Garland Hall (indoors)" → schedule updates for everyone; volunteer and family accounts cannot do this.
- **J-08** Directory shows only opted-in families, never contact details.
- **J-09** Language toggle EN ⇄ GU on every event-day screen.

### K — After the event
- **K-01** Final reconciliation for finance: fees + sponsorship received vs actual spend.
- **K-02** Bulk thank-you to sponsors with receipts.
- **K-03** Export all event data (for the next host city).

---

### N — Notifications

Channels: **push** (app users) and **email** (everyone). Web-only users (F4) get email only. Each message goes out in the recipient's language. For every test, assert: recipients, channel, send time (fake clock), language, resolved placeholders, and that nobody else got it.

**Quiet hours** `[ASSUMPTION]`: no routine messages between **9:00pm and 7:00am in the recipient's local time zone**; deferred to 7:00am. Live event updates and "lost child" alerts bypass quiet hours.

| ID | Notification | Trigger / timing | Recipients (seed) | Channel |
|---|---|---|---|---|
| **N-00** | Safety | Test run | Proves mock transports only; zero real sends | — |
| **N-01** | Registration confirmation | Immediately on submit | Each contact; **Gujarati** for F3, F4, F7; must spell દેરોદ | Push + email (F4 email only) |
| **N-02** | Family member invite | On invite | Meera (F3) | Email (+ SMS if phone code is the invite method) |
| **N-03** | Payment receipt | Card: on success · Zelle: on finance confirm (plus "pending" acknowledgement when reported) · Check/cash: when recorded | F1, F2, F4, F5, F7; F6 & F9 at check-in | Push + email |
| **N-04** | Unpaid fee reminder | Monthly on the 1st (Dec 1, 2026 → May 1, 2027), then weekly Mondays **Jun 7, 14, 21, 28, Jul 5, Jul 12, 2027** | **F3 only.** Not F2 while Zelle is pending. Not F6 (chose pay at check-in `[ASSUMPTION]`). Not F8 | Push + email |
| **N-05** | Hotel not booked | **May 4, Jun 3, Jun 19, Jun 26, 2027** (60/30/14/7 days before Jul 3 cutoff) | F3 all four dates. F6 **May 4 and Jun 3 only** (confirmation entered Jun 10). Never F1, F7 (local), F2, F4, F5 (booked), F8 | Push + email |
| **N-06** | Pledge not received | 30 days after pledge, then every 30 days, stops on receipt | F6: **Feb 14 and Mar 16, 2027**, none after Mar 20. F2: **Mar 31, Apr 30, May 30, Jun 29, 2027** while unpaid | Push + email |
| **N-07** | Know before you go | **Fri Jul 9, 2027**, 10:00am local | All active families F1–F7. Includes address, parking, map link, personal agenda, QR, balance due (F3 $600; F6 $300 at check-in) | Push + email |
| **N-08** | Morning summary | **7:00am Central** on Jul 16, 17, 18, 19 | Each family's personal agenda for that day. F4 gets Sat/Sun/Mon only (by email). F1 & F7 get **no Mon** summary (nothing on their agenda) | Push + email |
| **N-09** | 15-minute session reminder | 15 min before each agenda item | Only people with that item on their agenda (e.g., M3 at 12:15pm Sat → not to Ramesh/Kamla's devices if they're separate users; K1 only to families with kids act. sign-ups). Not to F4 (web only) `[ASSUMPTION]` | Push only |
| **N-10** | Quiet hours by recipient zone | A pre-event reminder scheduled for **Jun 3, 2027 8:00pm Central** | F5 (London, 2:00am) → delivered **Jun 4, 7:00am BST**. F6 (Toronto, 9:00pm) → **Jun 4, 7:00am EDT**. F3 (Eastern, 9:00pm) → Jun 4, 7:00am EDT | — |
| **N-11** | Live schedule change | Committee member moves M3 indoors at Sat 10:30am | Everyone attending Sat; delivered within **60 s** (mock); bypasses quiet hours; F4 by email | Push + email |
| **N-12** | Segment messages | Committee sends to a segment | Jain diet → F3 only · kids activities → F1, F3, F5, F7 · volunteers only → V1–V3 | Push + email |
| **N-13** | Volunteer shift reminder | Day before at 6:00pm + 30 min before shift `[ASSUMPTION]` | Each volunteer for own shifts | Push + email |
| **N-14** | Issue alerts | Volunteer reports issue | "Food running low" → food team · "Lost child" → all admins + committee, immediately, bypasses quiet hours | Push |
| **N-15** | Cancellation | F8 cancels | F8: cancellation + refund confirmation; then **no** further reminders of any kind | Push + email |
| **N-16** | Opt-out | Family turns off announcements | Still receives receipts, confirmations, cancellation, and live schedule changes `[ASSUMPTION]` | — |
| **N-17** | De-duplication | Two reminders of the same type within 24 h | Collapsed into one | — |
| **N-18** | Delivery failure | Expired push token / bad email | Logged as FAILED; push failure falls back to email | — |
| **N-19** | Scheduled message admin | Committee views, edits, cancels a scheduled message before it sends | — | — |
| **N-20** | History | Per family: what was sent, when, channel, language, status | — | — |
| **N-21** | Language switch | F5 switches to Gujarati on Jul 1, 2027 | F5's next message (N-07 on Jul 9) arrives in Gujarati; earlier history stays in English | Push + email |
| **N-22** | Web-only coverage | All of N-01…N-15 that apply to F4 | F4 receives each by **email**; nothing is silently dropped because she has no app | Email |

---

## 6. Report format — `CONVENTION_TEST_REPORT_v2.md`

1. **Inventory** — stack, models, auth, roles, payments, notifications, offline, i18n, test frameworks.
2. **Scorecard** — PASS / PARTIAL / FAIL / NOT BUILT counts per section (A, L, B, C, D, H, V, J, K, N).
3. **Results table** — one row per scenario:

   | ID | Scenario | Status | Evidence (test name / file:line) | Gap | Effort S/M/L | Needed by |
   |---|---|---|---|---|---|---|

4. **Priorities by the real calendar**
   - **P0 — before announcing registration (Nov–Dec 2026):** A, L, B, C-01…C-04, C-07, D-01…D-06, N-00…N-04, N-10, N-21, N-22
   - **P1 — sponsorship & hotel push (Jan–Jun 2027):** C-06, C-08, D-07, D-08, H, N-05, N-06, N-15…N-20
   - **P2 — final week + event days (Jul 2027):** J, V, C-05, N-07…N-09, N-11…N-14
   - **P3 — after the event:** K
5. **Top 10 gaps**, each with a short implementation suggestion.
6. **Testability gaps** — what couldn't be tested and why.
7. **Assumptions** — every `[ASSUMPTION]`, what the app currently does, and a recommendation.
