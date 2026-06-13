# Scenario 3 — Priya & Marcus, 2026-10-17 (wedding event)

A multi-day Indian wedding — mehndi night Friday, ceremony + reception Saturday — at a Mumbai venue. 30 guests on the core list, plus a planner and 5 vendors. You're running planning through wrap-up via CrewPoint v1 and surfacing what's missing for a wedding-organizer workflow. Read [`./README.md`](./README.md) **before** starting.

> 🪧 **Abstract personas rule.** You only operate the **4 active personas** below. The other 26 guests + 4 other vendors are names in the narrative — do NOT create accounts for them. ([`./README.md`](./README.md#you-only-operate-the-active-personas-dont-burn-out))

## Scale block

| Field | Value |
|---|---|
| Event currency (immutable per audit row 4) | **INR (₹)** |
| Active personas | `Couple` Bride+Groom shared account (owner) · `WP` Wedding Planner (admin) · `FL` Family Lead — bride's side (member) · `Vend` Anita — Catering Vendor (member) |
| Abstract personas (names in narrative only) | 26 additional guests + 4 vendors (florist, DJ, photographer, officiant) = 30 |
| Devices ideally | iPhone (Couple), Android (WP), iPad (FL), Web Chrome (Vend) |
| Min devices | 2 — pair Couple + WP on one device via baton-pass, FL + Vend on the other |
| Estimated tester-hours | ~5 (Planning 60m · Ramp-up 75m · Event day 60m · Wrap-up 75m + Forced-fail drills 30m + Web parity 30m) |

### Couple shared-account coverage-loss banner

`Couple` is **one Firebase account** that both partners log into in real life. This is an intentional simplification — couple-as-two-people coordination is **not exercised** by this scenario. Seeded gaps to mark the coverage loss: `GAP-WED-32 No multi-owner / co-owner role` and `GAP-ANY-31 No transfer-ownership UI` (so the couple can't even hand the keys to `WP` temporarily and reclaim them after).

### Vendor role-play note

`Vend` (Anita — Catering) is a regular **Member**. There is no Vendor-scoped role in v1. In real life Anita shouldn't see the photographer's invoice or the family-lead's chat about the in-laws. If she can, that confirms `GAP-CON-30 No vendor-scoped role` — **NOT a bug**. She role-plays restraint.

## Prerequisites

- Install + onboarding + first sign-in via [`../qa/v1-tester-handoff-guide.md` §0](../qa/v1-tester-handoff-guide.md#0-pre-flight-setup--onboarding) per persona.
- `Couple` and `WP` have Venmo + Cash App handles set in **Profile** (Wrap-up settle drills). `FL` has set a Zelle handle (deliberate gap probe — see §W-2). `Vend` has no payment handles.
- Read [`./README.md`](./README.md) §"Bug vs gap".

### If you get stuck

| Situation | Do this |
|---|---|
| Persona in the wrong account | `AUTH-OUT-01` → sign back in. |
| Skipped a phase | Run `EV-CRE-01` from the handoff guide, seed an event, then resume the phase. |
| Build under test has an unresolved V1 launch blocker | Replace the dependent step with a `> 🕳️ Gap candidate:` callout; do not invent a workaround. |

## At-a-glance arc

| Phase | Personas active | What happens | Time |
|---|---|---|:---:|
| Planning (§P) | `Couple`, then `WP` | Event created, guest list challenge, invite distribution, vendor onboarding, transfer-ownership probe | 60m |
| Ramp-up (§R) | All four | Multi-day schedule attempt, vendor attachments, dietary/preference probe, custom-split probe, OCR probe | 75m |
| Event day (§E) | All four | Urgent chat, real-time triage, late-night-push pain | 60m |
| Wrap-up (§W) | `Couple`, `WP`, `FL` | Final expenses, settle via Venmo, Zelle fall-through, message search probe, archive | 75m |
| Forced-fail drills | `Couple` + `WP` paired | 5 deliberate stress tests | 30m |
| Web parity | `Vend` solo on Chrome + Safari | Re-run select phases on web | 30m |

---

## §P — Planning phase

### P-1 — `Couple` creates the wedding event

**[Couple — iPhone]**

1. From the **Home** tab, tap **Create Event**.
2. Fill the form:
   - Title: *Priya & Marcus — 2026-10-17*
   - Description: *Multi-day wedding at The Taj Lands End, Mumbai. Friday 2026-10-16 mehndi night (6pm onwards). Saturday 2026-10-17 ceremony 4pm + reception 7pm. ~30 guests + parents + planner + vendors.*
   - Event type: **Social** (closest fit — none of **Trip / Project / Social / Custom** is "Wedding").
   - Start date: 2026-10-16 — End date: 2026-10-17
   - Currency: **₹ INR** *(immutable once set)*
3. Tap **Create**.

**Expected**
- `Couple` lands on the new event dashboard. Currency symbol throughout reads **₹**.

### P-2 — `Couple` generates the invite code and tries to control its spread

**[Couple — iPhone]**

1. Open **Members** → **+** FAB → wait for **Generating code...** → **Copy**. Snackbar **Code copied to clipboard**.
2. Imagine sharing it with the close inner circle only (parents, siblings). Worry that if Aunt Sunita's WhatsApp group gets the code, every distant cousin will join.

> 🕳️ **Gap candidate:** Single per-event code with no expiry, no single-use option, no per-cohort variant. Confirms `GAP-ANY-03 No invite expiry / single-use codes` and `GAP-ANY-02 One invite code per event (no per-team / per-cohort codes)`.

3. Mitigate by tapping **Generate New Code** if it spreads too widely (rotates per `EV-MEM-02`).

### P-3 — Guest list challenge: where do RSVPs go?

**[Couple — iPhone]**

1. Open **Tasks** → create a task: *Collect RSVPs from 30 guests + meal + +1*. Assignee: `WP`. Due: 2026-09-30. Priority: High.
2. Open the new task → checklist editor → add 30 items, one per guest name. Toggle complete as RSVPs come back.

> 🕳️ **Gap candidate:** v1 has no RSVP collection — no structured yes/no/maybe field, no meal-choice field, no +1 field, no automated reminder. A 30-item checklist on a single task simulates the workflow at maximum strain. Confirms `GAP-WED-13 No RSVP collection`. Also confirms (in advance) `GAP-WED-14 No guest dietary / preference metadata` — meal-choice tracking falls into a description blob if you try.

### P-4 — Multi-day schedule attempt

**[WP — Android]**

`WP` joins via the code (Join Event → enter code → Join → snackbar). `Couple` promotes `WP` to admin from the Members screen (snackbar **Promoted to admin**).

Then `WP` creates these 9 tasks to represent the multi-day schedule (3 per day × 3 sub-day-blocks):

| Day | Title | Due | Priority |
|:---:|---|---|:---:|
| Fri | 18:00 Mehndi night — Banquet Hall | 2026-10-16 | High |
| Fri | 18:30 Henna artists arrive — verify 4 stations | 2026-10-16 | Medium |
| Fri | 21:00 Late dinner service | 2026-10-16 | Medium |
| Sat AM | 09:00 Bride getting ready — Suite 1402 | 2026-10-17 | High |
| Sat AM | 10:00 Hair + makeup vendors arrive | 2026-10-17 | Medium |
| Sat PM | 16:00 Ceremony — Mandap (Garden Court) | 2026-10-17 | High |
| Sat PM | 17:00 Cocktail hour | 2026-10-17 | Medium |
| Sat eve | 19:00 Reception — Grand Ballroom | 2026-10-17 | High |
| Sat eve | 23:00 Send-off + cleanup | 2026-10-17 | Low |

> 🕳️ **Gap candidate:** Two real calendar days but three or four functional time-blocks (mehndi night / Saturday morning prep / ceremony / reception). v1's only multi-day grouping is **Due window** in the Tasks screen which buckets by Today/This week/Later — not by mehndi/ceremony/reception. Confirms `GAP-WED-12 No multi-day schedule blocks`.

### P-5 — `FL` and `Vend` join

**[FL — iPad]** Sign in → **Join Event** → enter code → **Join**.

**[Vend — Web Chrome]** Sign in (OAuth popup; recover via `AUTH-WEB-01` if blocked) → **Join Event** sheet → enter code → **Join**.

**Expected**
- 4 members: `Couple` Owner, `WP` Admin, `FL` Member, `Vend` Member.

### P-6 — `Couple` wants to hand the keys to `WP` for the final week

**[Couple — iPhone]**

1. Open the event Members screen. Find `WP`'s row.
2. Look for any **Transfer Ownership** affordance.

> 🕳️ **Gap candidate:** There is no transfer-ownership UI. `Couple` can promote `WP` to admin (already done in §P-4) but the owner bit is permanent and tied to the originating account. Confirms `GAP-ANY-31 No transfer-ownership UI`. Combined with the shared-account note in the persona banner, this means a couple genuinely cannot share ownership of their own wedding event in v1.

---

## §R — Ramp-up phase

### R-1 — `WP` creates vendor coordination tasks (with budget estimates)

**[WP — Android]** creates these tasks via `TASK-CRE-01`:

| Title | Assignee | Due | Priority | Budget |
|---|---|---|:---:|---:|
| Confirm florist deposit | `FL` | 2026-09-15 | High | ₹15,000 |
| Confirm DJ contract + playlist | `WP` | 2026-09-20 | Medium | ₹40,000 |
| Confirm photographer contract | `WP` | 2026-09-22 | High | ₹65,000 |
| Confirm officiant + final ceremony script | `WP` | 2026-09-25 | High | ₹0 |
| Confirm catering menu — Anita | `Vend` | 2026-09-10 | High | ₹2,80,000 |
| Block ice + cold-storage for late dinner Friday | `Vend` | 2026-10-15 | Medium | ₹0 |

**Expected**
- Tap **Has budget** chip → list narrows to 4 tasks with budget estimates set. (Filter behavior per `TASK-FILT-01`.)
- Tap **Mine** as `WP` → list narrows to `WP`'s 3 tasks.

### R-2 — `Vend` wants to attach the catering quote PDF to her task

**[Vend — Web Chrome]**

1. Open the "Confirm catering menu — Anita" task. Look for an attachment field.

> 🕳️ **Gap candidate:** There is no attachment field on tasks in v1 (the `TaskAttachment` domain model exists but Storage wiring is deferred). Anita has to paste a Google Drive link into the task description as a workaround. Confirms `GAP-ANY-06 No task attachments`. Note that receipt attachments DO work in Budget (`BUD-RECEIPT-01`).

2. Workaround: edit the task description, paste *Catering quote: drive.google.com/...* into the description. Save.

### R-3 — `Couple` records guest dietary preferences

**[Couple — iPhone]**

1. Open the §P-3 "Collect RSVPs..." task. Open the checklist editor.
2. Try to add a per-item dietary field (vegan / vegetarian / kosher / allergy: nuts / etc.).

> 🕳️ **Gap candidate:** Checklist items are plain-text strings — no structured fields for meal choice or dietary metadata. Workaround: encode it in the item text (*Riya Patel — RSVP YES — vegan — no peanuts*). Confirms `GAP-WED-14 No guest dietary / preference metadata`.

### R-4 — `Vend` logs the catering deposit — but it was paid in USD by an international guest

**[Vend — Web Chrome]** logs an expense via `BUD-EXP-01`:

- Amount: *₹2,80,000* (the event currency; she enters the ₹ equivalent of what the international guest actually paid in USD).
- Description: *Catering deposit — paid by Aunt Lakshmi (in USD ~$3,350)*
- Payer: `Couple`. Toggle **Donate this cost** OFF.
- Equal split across 4 members (so each of `WP`, `FL`, `Vend` owes `Couple` ~₹70,000).

> 🕳️ **Gap candidate:** The event currency is immutable INR; there's no way to mark this one expense as USD-paid for clarity. Confirms `GAP-ANY-17 No per-expense currency override`. Also no multi-currency FX display in the ledger (`GAP-ANY-16`).

### R-5 — `Couple` logs the florist payment with a hand-written receipt

**[Couple — iPhone]** logs an expense:

- Amount: *₹15,000*
- Description: *Florist deposit — Asha Florals — paid cash*
- Payer: `Couple`. **Equal** split (4 members).
- Tap **Add receipt** → camera → photograph a hand-written receipt (or upload from gallery).

**Expected**
- Receipt thumbnail appears in the expense tile per `BUD-RECEIPT-01`.
- Ledger updates accordingly.

> 🕳️ **Gap candidate:** The amount + description had to be typed manually — no OCR on the hand-written receipt. Confirms `GAP-ANY-19 No receipt OCR`.

### R-6 — Custom split probe: `FL` paid for Friday late dinner alone

**[FL — iPad]** logs:

- Amount: *₹35,000*
- Description: *Mehndi night late dinner — paid by bride's side only (not groom's)*
- Payer: `FL`. **Equal** split (default).

But `FL` *meant* the cost to fall on only the bride's side — i.e., `Couple` + `FL` should bear it, `WP` + `Vend` should not. v1's modal only offers equal split (with the Donate this cost toggle as the only deviation, which excludes the payer entirely).

> 🕳️ **Gap candidate:** v1 has no custom / non-equal split UI. The expense modal computes splits as `total ÷ all members` (minus the payer if Donate this cost is on). For shared-cost-with-restricted-group scenarios (very common in weddings, fundraising, group trips), this fails. Log a new entry: **`GAP-WED-40 No custom / non-equal split UI`** → `GAPS.md` § Budget & finance. Workaround: `FL` logs two expenses — one as a donation (excludes herself) for the "groom's share", then... actually there is no clean workaround. This is the single biggest budget gap surfaced. Note it in the debrief.

---

## §E — Event day

### E-1 — Urgent chat: photographer running late Saturday morning

**[WP — Android]**

1. Open **Chat**. Type: *URGENT — Photographer's car broke down. Arriving 11:30 instead of 10:00. `Couple`: please push hair + makeup to start at 09:30 so we're not behind for getting-ready shots at 11:45.*
2. Toggle the urgent affordance → **Send Critical Alert** modal → confirm → send.

**Expected**
- Terracotta urgent bubble + **Critical Alert** badge.
- `Couple`, `FL`, `Vend` receive push within ~10s (mobile + permissions granted). `Vend` on Web Chrome: **no push** per constraint #4.
- iOS long-press → **MARK_DONE** + **MUTE_EVENT** action buttons (standard iOS gesture).

### E-2 — Late-night urgent push the night before

**[Vend — assume mobile for this drill; use Android paired with Couple]**

The night before (Friday 2026-10-16, ~22:30 IST), `Vend` realizes the cold-storage block is short. She sends an urgent chat: *URGENT — need extra ice ASAP for the late dinner. Can someone authorize a same-night order?*

`Couple` is asleep. The urgent push fires at 22:35 and wakes them.

> 🕳️ **Gap candidate:** No quiet-hours / Do-Not-Disturb window. `Couple` would have preferred urgent pushes silently held until 07:00 the next day, with a single morning summary. Confirms `GAP-ANY-26 No quiet hours / Do-Not-Disturb window`. Also — there's no preferences UI to even toggle this if it existed (`GAP-ANY-25 No notification preferences UI at all`).

---

## §W — Wrap-up phase

### W-1 — `Couple` and `WP` log the final expenses

| Amount | Description | Payer | Split |
|---:|---|---|---|
| ₹1,85,000 | Reception bar + cocktails | `Couple` | Equal |
| ₹65,000 | Photographer final invoice | `Couple` | Equal |
| ₹40,000 | DJ + lighting final | `WP` | Equal — `WP` paid upfront and will recover from `Couple` |
| ₹12,000 | Gift hampers for the 30 guests | `Couple` | Toggle **Donate this cost** ON (excludes payer) |

### W-2 — `Couple` tries to settle with `FL` via Zelle and hits the fallback

**[Couple — iPhone]**

1. Open **Budget** → cross-event ledger. `FL` owes `Couple` (or vice versa — depending on the final ledger after R-4 + W-1 expenses).
2. Tap **Settle Up** on the relevant debt row.
3. Notice the available payment options. `FL` has only a Zelle handle set in Profile.

> 🕳️ **Gap candidate:** Tapping the settle sheet for a Zelle-only counterparty produces the `LED-FALL-01` fallback sheet ("Copy payment details" + the handle). This is **expected v1 behavior, NOT a bug** — Pillar 3 design decision pending per audit V1 launch blocker #7. Confirms `GAP-WED-15 No Zelle deep link`.

4. Tap **Pay with Venmo** instead → Venmo deep link opens → **sandbox amount: ₹10 (≈ $0.12)**. Cancel inside Venmo, return.

**Expected**
- Settlement system-message in chat.
- Cross-event ledger updates. **The Venmo deep link has no idea whether the actual ₹10 went through** — `Couple` has to mark settled manually if it didn't. Confirms `GAP-ANY-20 No real settlement reconciliation`.

### W-3 — `Couple` wants to find the florist's delivery-time message three days later

**[Couple — iPhone]**

1. Open the event **Chat**. Scroll up through the ~80 messages from event week looking for the conversation about florist delivery time.
2. Look for a search field.

> 🕳️ **Gap candidate:** v1 has no message search. `Couple` scrolls for 4 minutes to find the message. Confirms `GAP-ANY-23 No message search`.

### W-4 — Export PDF + CSV financial summary for the bride's father (he asked)

**[Couple — iPhone]**

1. From the event Budget screen, **Export PDF** (`BUD-EXPORT-01`). Save / AirDrop. Open the PDF — currency throughout is ₹, no wedding theme/branding (`GAP-CON-37` cross-scenario), no expense categories (`GAP-ANY-18` cross-scenario).
2. **Export CSV** — save. Open in spreadsheet — confirm headers + row count.

### W-5 — `Couple` archives the event

**[Couple — iPhone]**

1. Event dashboard → scroll to bottom → **Archive Event** switch → toggle on.

**Expected**
- Subtitle becomes **Event is archived (read-only)**. Persists. Event moves to **Past** on `HOME-FILT-01`. **Archived** badge appears.

### W-6 — Debrief

Two paragraphs in the shared channel per [`./README.md`](./README.md#tester-debrief--fill-at-the-end-of-each-scenario). Be honest about how the RSVP, custom-split, and notification gaps felt.

---

## §Forced-fail drills

### FF-1 — Member attempts admin-only action

**[Vend — Web Chrome]** opens Members → tries to remove `FL`.

- **If** no remove affordance visible → working as designed. Pass.
- **If** visible & actionable → **BUG**. RBAC violation.

### FF-2 — Network drop mid-checklist-add

**[Couple — iPhone]** enables airplane mode → opens the "Collect RSVPs..." task → checklist editor → types into the **Add item** field → submits.

- **If** snackbar **Failed to add checklist item** fires (per `task_repository.dart:218`) and the entry persists in the input → matches expected behavior. Confirms `GAP-ANY-34 No offline writes`.
- **If** crash or silent loss → **BUG**.

### FF-3 — Kick `Vend` while she's editing the catering task on web

**[Couple — iPhone]** opens Members → removes `Vend` (`EV-MEM-03`). Dialog **Remove Member?** → **Remove**.

**[Vend — Web Chrome]** has the catering task edit screen open at moment of removal.

- **If** `Vend`'s web tab navigates away or shows a graceful "removed" notice within ~5s → working as designed. Pass.
- **If** `Vend` retains the edit screen and can hit Save → **GAP** `GAP-XX Removed member can submit stale writes on web`. Log to GAPS.md. **If write actually persists** → **BUG** (Firestore rules should reject — verify rule path).
- **If** crash → **BUG**.

Recovery: re-invite `Vend` with a fresh code.

### FF-4 — Cold-start push deep-link regression

**[FL — iPad]** force-kills the app. **[Couple — iPhone]** sends a follow-up urgent message. **[FL — iPad]** taps the lock-screen push.

- **If** app cold-starts into the wedding event chat with the urgent message visible → matches `PUSH-COLD-01`. Pass.
- **If** lands on Home instead of the chat → **BUG** (regression).

### FF-5 — Custom-split workaround attempt

**[Couple — iPhone]** tries to recreate a scenario from §R-6: an expense that should fall only on the bride's side (`Couple` + `FL`), not on `WP` or `Vend`.

- **If** there's no way to do this and the Donate this cost toggle only excludes the payer → confirms `GAP-WED-40 No custom / non-equal split UI`. Pass.
- **If** Couple finds a hidden custom-split UI that works → call it out — the GAPS entry is wrong. Update GAPS.md.

---

## §Web parity

Re-run on **Chrome desktop ≥1280px** and **Safari mobile (Private Mode)** as `Vend`. Constraints per [`./README.md`](./README.md#known-web--infra-constraints--not-bugs).

| Phase | Re-run on web? | What to watch for |
|---|:---:|---|
| §P (Planning) | ✅ Yes | OAuth popup recovery (`AUTH-WEB-01`). Create-event flow at desktop breakpoint. Generating a code on web — does the **Copy** button copy correctly into the clipboard? |
| §R (Ramp-up) | ⚠️ Partial | Skip the multi-day schedule task creation — list-perf isn't the bottleneck. Re-run §R-2 attachment probe and §R-5 receipt upload to verify `firebase_image_service.dart` web bytes path. |
| §E (Event day) | ❌ Skip push | No web push (constraint #4). Skip §E-1/E-2's push expectations; confirm chat renders + the **Critical Alert** badge. Late-night-push drill is mobile-only. |
| §W (Wrap-up) | ✅ Yes | Settle-via-Venmo on web — does the deep-link open in a new tab? Does the universal link to Venmo's website fire instead? PDF + CSV downloads via native browser download. |
| FF-2 (Network drop) | ✅ Yes | Reload the tab mid-checklist-add and the form state is lost (constraint #2). **NOT a bug**. |

iOS notification-actions gesture primer doesn't apply on web. Safari Private Mode wipes the Drift in-memory Wasm cache on reload — expected.

If a literal bold label drifts between this guide and the live web app, file a guide-bug (note in this file) not an app-bug.

---

## What you should have logged by the end

Confirm at minimum:

- ≥ 3 entries reviewed or expanded in [`./GAPS.md`](./GAPS.md): at minimum `GAP-WED-13 No RSVP collection`, `GAP-WED-15 No Zelle deep link`, **`GAP-WED-40 No custom / non-equal split UI`** (added during this scenario). Realistically 7–9 also touched: `GAP-WED-12`, `GAP-WED-14`, `GAP-WED-32`, `GAP-ANY-06`, `GAP-ANY-17`, `GAP-ANY-19`, `GAP-ANY-20`, `GAP-ANY-23`, `GAP-ANY-25/26`, `GAP-ANY-31`.
- 0–2 bugs filed via [`../qa/v1-tester-handoff-guide.md` §14](../qa/v1-tester-handoff-guide.md#14-bug-report-template). > 5 bugs → stop and tell the founder.
- 1 debrief paragraph.

You're done. Send all three debrief summaries to the founder together.
