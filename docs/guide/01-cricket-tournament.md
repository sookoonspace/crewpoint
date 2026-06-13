# Scenario 1 — Mumbai Sixers Invitational (cricket tournament)

A 4-team weekend tournament. 20 players total, plus a tournament director and a sponsor rep. You're going to run the whole thing through CrewPoint v1 — planning, ramp-up, event day, wrap-up — and surface every gap and bug you hit. Read [`./README.md`](./README.md) **before** starting.

> 🪧 **Abstract personas rule.** You only operate the **4 active personas** below. The other 19 players are names in the narrative — do NOT create accounts for them. When a step says "CapA invites the rest of Team A", you verify the invite primitive works **once** and move on. ([`./README.md`](./README.md#you-only-operate-the-active-personas-dont-burn-out))

## Scale block

| Field | Value |
|---|---|
| Event currency (immutable per audit row 4) | **INR (₹)** |
| Active personas | `TD` Tournament Director (owner) · `CapA` Team Captain A (admin) · `PlayerA1` Player on Team A (member) · `SponsorS` Sponsor Rep (member, view-only role-play) |
| Abstract personas (names in narrative only) | Captains B/C/D, Players A2–A5, B1–B5, C1–C5, D1–D5 = 19 |
| Devices ideally | iPhone (TD + CapA), Android (PlayerA1), Web Chrome (SponsorS) |
| Min devices | 2 — pair TD with CapA on one phone via baton-pass, run PlayerA1 + SponsorS on the other |
| Estimated tester-hours | ~5 (Planning 60m · Ramp-up 75m · Event day 90m · Wrap-up 60m + Forced-fail drills 30m + Web parity 30m) |

### Sponsor role-play note (read before signing in)

`SponsorS` is a regular **Member** in v1 (there is no Observer / view-only role). They role-play restraint: only view, only react in chat, no task creates, no expense logs. If `SponsorS` *can* create a task / send a non-trivial chat / log an expense, that is **NOT a bug** — it confirms `GAP-CRK-29 No Observer / view-only / sponsor role`.

## Prerequisites

- Complete install + onboarding + first sign-in via [`../qa/v1-tester-handoff-guide.md` §0](../qa/v1-tester-handoff-guide.md#0-pre-flight-setup--onboarding) for each active persona on their assigned device.
- Each active persona's Profile has a display name set (`PROF-EDIT-01`). `TD` and `CapA` additionally have Venmo + Cash App handles configured (for the Wrap-up settle drills).
- Read [`./README.md`](./README.md) §"Bug vs gap" — it determines where every issue you find goes.

### If you get stuck

| Situation | Do this |
|---|---|
| Persona is in the wrong account | Sign out via `AUTH-OUT-01`, sign back in with the right credentials. |
| You skipped a phase (e.g., no Planning event exists) | Run `EV-CRE-01` from the handoff guide to seed one minimal event, then resume the scenario phase you wanted. |
| Build under test has an unresolved V1 launch blocker | Replace the dependent scenario step with a `> 🕳️ Gap candidate:` callout; do not invent a workaround. |
| Found something but can't tell bug-vs-gap | Re-read [`./README.md`](./README.md) §"Bug vs gap". When still in doubt: log to GAPS.md and note your uncertainty — the founder will reclassify. |

## At-a-glance arc

| Phase | Personas active | What happens | Time |
|---|---|---|:---:|
| Planning (§P) | `TD`, then `CapA` | Event created, invite code rotated, first tasks assigned | 60m |
| Ramp-up (§R) | All four | Rapid task creation, chat ramps up, first expenses, settle rehearsal | 75m |
| Event day (§E) | All four, on multiple devices | Urgent chat, real-time task transitions, push under load, deep-link cold-start | 90m |
| Wrap-up (§W) | `TD`, `CapA`, `FL` | Final expenses, ledger reconciliation, settle via Venmo/Cash App, PDF/CSV export, archive event | 60m |
| Forced-fail drills | `TD` + `CapA` paired | 5 deliberate stress tests | 30m |
| Web parity | `SponsorS` solo on Chrome | Re-run select phases on web | 30m |

---

## §P — Planning phase

### P-1 — `TD` creates the tournament event

**[TD — iPhone]**

1. From the **Home** tab, tap **Create Event** (sage FAB, bottom-right).
   - The `CreateEventScreen` opens.
2. Fill the form:
   - Title: *Mumbai Sixers Invitational*
   - Description: *4-team weekend tournament. Knockout format. Wankhede practice nets Fri evening, matches Sat + Sun at Cross Maidan.*
   - Event type: **Trip** *(the four options are **Trip / Project / Social / Custom** — none of them are "Tournament", which is itself a soft signal — see callout below.)*
   - Start date: 2026-10-12 (Friday) — End date: 2026-10-14 (Sunday)
   - Currency: **₹ INR** *(immutable once set per audit row 4)*
3. Tap **Create**.

> 🕳️ **Gap candidate:** No **Tournament** / **Sport** event type. This is captured under `GAP-ANY-07 No task templates / event-template duplication` indirectly. If you, the tester, *expected* a dedicated tournament type, add a fresh entry to `GAPS.md` § Task management as `GAP-CRK-XX No tournament event template`.

**Expected**
- Loader spins, then `TD` lands on the new event's dashboard. Event card on **Home** shows **Mumbai Sixers Invitational** with the date range.
- `TD` is listed as **Owner** on the Members screen (`EV-MEM-01`).
- Currency icon throughout the event reads **₹**.

### P-2 — `TD` generates the invite code and shares it

**[TD — iPhone]**

1. From the event dashboard, open **Members** (people-icon link).
2. Tap the sage **+** FAB.
3. Wait for **Generating code...** to resolve into the 6-character code.
4. Tap **Copy**.
   - Snackbar: **Code copied to clipboard**.
5. Pretend to share the code via WhatsApp with `CapA`, captains B/C/D, and all 19 players. **Do NOT actually create those 19 accounts.**

> 🕳️ **Gap candidate:** One invite code for everyone — no way to give Team A their own code separate from Team B/C/D or from sponsors. Confirms `GAP-ANY-02 One invite code per event (no per-team / per-cohort codes)`. Also confirms `GAP-CON-01 No bulk / link / QR / CSV invite` — `TD` has to manually paste the code 23 times in real life.

### P-3 — `CapA` joins via code; `TD` promotes them to admin

**[CapA — iPhone]**

1. Sign in (if not already). On the **Home** tab, tap the **Join Event** sheet entry-point (`HOME-JOIN-01`).
2. Enter the 6-character code from `TD`. Tap **Join**.
   - Snackbar confirms the join. **Mumbai Sixers Invitational** appears on `CapA`'s **Home**.

**[TD — iPhone]**

3. On the event Members screen, find `CapA`'s row. Tap the promote affordance.
   - Snackbar: **Promoted to admin** (sage). Row's role badge flips from **Member** (grey) to **Admin** (info-blue).

**Expected**
- Two members visible: `TD` (Owner badge), `CapA` (Admin badge).

### P-4 — `PlayerA1` and `SponsorS` join

**[PlayerA1 — Android]**

1. Sign in. **Join Event**. Enter code. Tap **Join**.

**[SponsorS — Web Chrome]**

2. Sign in via Web — OAuth uses **popup** not native sheet (this is the documented Web constraint per [`./README.md`](./README.md#known-web--infra-constraints--not-bugs) #1). Allow popups for the staging URL if Chrome blocked it.
3. **Join Event** sheet. Enter code. Join.

**Expected**
- Members screen on every device shows 4 rows: `TD` (Owner), `CapA` (Admin), `PlayerA1` (Member), `SponsorS` (Member).
- All four show their **Profile** display names.

> 🕳️ **Gap candidate:** `SponsorS` is a regular **Member** — there is no role label that signals their sponsor / observer / view-only intent to the rest of the crew. Confirms `GAP-CRK-29 No Observer / view-only / sponsor role`.

### P-5 — `TD` creates the first three planning tasks (one per captain)

**[TD — iPhone]**

1. From the event dashboard, open **Tasks**. Tap the **+** FAB to open `CreateTaskScreen`.
2. Create the following three tasks one after the other (each via `TASK-CRE-01`):

| Title | Assignee | Due date | Priority | Budget |
|---|---|---|:---:|---:|
| Confirm Team B roster + jerseys | (leave unassigned — Captain B abstract) | 2026-10-10 | High (3) | ₹0 |
| Confirm Team C roster + jerseys | (leave unassigned — Captain C abstract) | 2026-10-10 | High (3) | ₹0 |
| Confirm Team D roster + jerseys | (leave unassigned — Captain D abstract) | 2026-10-10 | High (3) | ₹0 |

**Expected**
- Tasks list shows 3 items, all **To Do** status, all due 2026-10-10, all High priority.
- Filter chips at top: **Mine** / **Overdue** / **Has budget** / **To Do** / **In Progress** / **Done**. Tap **Mine** — list empties (since none assigned to `TD`). Tap **Mine** again to clear.

> 🕳️ **Gap candidate:** No bracket / match-fixture view to express the tournament structure (A vs B / C vs D / winners-bracket). Confirms `GAP-CRK-10 No bracket / match-fixture view`.

---

## §R — Ramp-up phase

### R-1 — `CapA` creates the practice and match-prep tasks for Team A (8 tasks)

**[CapA — iPhone]**

Create the following 8 tasks via the `CreateTaskScreen` (`TASK-CRE-01`). Hit Save between each one and confirm the new row appears in the list before adding the next — this exposes any list-perf or pagination issues.

| # | Title | Assignee | Due | Priority | Budget |
|---|---|---|---|:---:|---:|
| 1 | Book Wankhede practice nets — 2026-10-12 7am | `CapA` | 2026-10-10 | High | ₹5,000 |
| 2 | Coordinate practice — Mon evening | `CapA` | 2026-10-12 | Medium | ₹0 |
| 3 | Coordinate practice — Wed evening | `CapA` | 2026-10-14 | Medium | ₹0 |
| 4 | Coordinate practice — Fri morning | `CapA` | 2026-10-16 | Medium | ₹0 |
| 5 | Bring Team A whites (5 sets) | `PlayerA1` | 2026-10-12 | High | ₹0 |
| 6 | Print scorecards (50 copies) | `CapA` | 2026-10-11 | Low | ₹2,500 |
| 7 | Confirm umpire — Match 1 | (unassigned) | 2026-10-11 | High | ₹3,000 |
| 8 | Buy Gatorade + electrolyte sachets | `PlayerA1` | 2026-10-12 | Low | ₹1,800 |

> 🕳️ **Gap candidate:** Tasks 2/3/4 are conceptually one recurring task. v1 has no recurring primitive — `CapA` had to duplicate (`TASK-DUP-01`) or hand-create. Confirms `GAP-CRK-04 No recurring tasks`. Note in the debrief how long this felt.

**Expected**
- Tasks list shows the 3 original `TD` tasks **plus** these 8 = 11 total.
- Status counts: 11 **To Do** / 0 **In Progress** / 0 **Done**.
- Tap the **Has budget** chip — 4 tasks remain visible (1, 6, 7, 8).
- Tap **Mine** while logged in as `CapA` — 4 tasks remain visible (1, 2, 3, 4, 6 → wait, 5). Confirm the chip applies the assigned-to-me filter correctly per `TASK-FILT-01`.

### R-2 — Chat ramps up; `CapA` posts the match itinerary

**[CapA — iPhone]**

1. From the event dashboard, open **Chat**.
2. Send the first message: *Team A — practice nets booked for Fri 7am. Bring whites + shoes. Don't be late, Wankhede gates close at 6:45.*
3. Send a follow-up: *Match 1 is Sat 10:30 vs Team B at Cross Maidan ground 2.*

**[PlayerA1 — Android]**

4. Open **Chat** on the same event. The two messages from `CapA` are visible in real time (Firestore stream — usually < 2s).
5. Reply: *Got it. Will I be batting first or fielding?*

**Expected**
- All four devices see both message threads in chronological order, with sender display names.
- Cross-event inbox (**Chat** tab from the bottom-nav, not inside the event) shows the **Mumbai Sixers Invitational** event with an unread badge for personas who haven't read yet (`INBOX-UNREAD-01`).

> 🕳️ **Gap candidate:** `PlayerA1` would normally thumbs-up `CapA`'s message instead of replying. v1 has no reactions. Confirms `GAP-ANY-21 No reactions / emoji`.

### R-3 — `CapA` logs the first event expense (practice-nets deposit)

**[CapA — iPhone]**

1. Open **Budget** inside the event. Tap **Add Expense**.
2. Amount: *₹5,000*. Description: *Wankhede practice nets — Fri 7am session*. Payer: `CapA`. Splits: **Equal** across all event members.
3. Attach a receipt photo (`BUD-RECEIPT-01`) — anything works; this is a smoke test that image-picker + upload still functions.
4. Save.

**Expected**
- Expense appears in the event budget list. Ledger updates: `TD`, `PlayerA1`, `SponsorS` each owe `CapA` ₹1,250.
- Cross-event ledger on the **Budget** bottom-nav tab reflects the new debt for each member.

> 🕳️ **Gap candidate:** No expense category — "Practice nets" gets no Sports / Equipment / Venue label. Confirms `GAP-ANY-18 No expense categories / labels`.

### R-4 — Settle-up rehearsal (`PlayerA1` settles ₹1,250 with `CapA` via sandbox amount)

**[PlayerA1 — Android]**

1. Open **Budget** → cross-event ledger. Find the `CapA` row.
2. Tap **Settle Up**.
3. Choose **Pay with Venmo** (label confirmed live at `settle_sheet.dart:111`).
   - Venmo deep link opens (or universal-link in browser if Venmo isn't installed — that's expected on this Android device).
4. **Use sandbox amount: ₹10 (≈ $0.12).** Do NOT settle the actual ₹1,250 — this is a rehearsal.
5. Cancel inside Venmo, return to CrewPoint.

**Expected**
- A settlement system-message appears in the event chat (per Pillar 3 dispute design) — `Couple has marked ₹1,250 as settled` or similar wording per `CHAT-DISP-01`.
- The cross-event ledger now shows `PlayerA1` clear with `CapA` (or pending — depends on whether `CapA` disputes from the system-message sheet).

> 🕳️ **Gap candidate:** `PlayerA1` was set up with no Venmo handle of their own → the **Pay with Venmo** button is labeled "No Venmo handle" and is disabled per `settle_sheet.dart:111`. If they instead tap **Pay with Cash App**, that also reads "No Cash App handle". Only `TD` and `CapA` have handles set per prerequisites. This is correct v1 behavior; document the friction.

### R-5 — Cross-device real-time check

**[CapA — iPhone]** marks task #1 (Book Wankhede practice nets) as **Done** (`TASK-STAT-01`: tap status badge → cycle To Do → In Progress → Done).

**[PlayerA1 — Android]** is on the same Tasks list; observe.

**Expected**
- `PlayerA1`'s Tasks list updates the row's status badge to **Done** within ~2 seconds (Firestore stream). Status counts at top: 10 To Do / 0 In Progress / 1 Done.

> 🕳️ **Gap candidate:** No "task completed" push to the rest of the crew. Confirms `GAP-ANY-09 No due-date reminders / nudge notifications` (related — no completion nudges either).

---

## §E — Event day

### E-1 — `CapA` sends an urgent chat (rain delay)

**[CapA — iPhone]**

1. Open **Chat** in the event.
2. Type: *RAIN DELAY — Match 1 pushed to 12:30. Stay in vehicles.*
3. Toggle the urgent-message affordance. The **Send Critical Alert** modal appears — confirm to proceed (`CHAT-URG-01`).
4. Send.

**Expected**
- Message appears in chat with the terracotta urgent-bubble styling and a **Critical Alert** badge per `message_bubble.dart:119`.
- `TD`, `PlayerA1`, `SponsorS` receive a **push notification** within ~10 seconds (per `PUSH-URG-01` — only if their devices have push permissions granted).
- On iOS, long-press / drag-down the banner exposes **MARK_DONE** and **MUTE_EVENT** action buttons (one-line gesture primer: this is standard iOS notification-action behavior across every app, not a CrewPoint constraint).
- `SponsorS` on Web Chrome receives **no push** — see [`./README.md`](./README.md) constraint #4 (FCM web push not yet user-facing).

> 🕳️ **Gap candidate:** No typing/read receipts means `CapA` has no signal whether the urgent message was actually seen. Confirms `GAP-ANY-24 No typing / read receipts`.

### E-2 — Real-time task transitions under load

**[CapA — iPhone]** marks tasks #5, #6, #8 as **Done** in rapid succession.

**[PlayerA1 — Android]** is on the Tasks list throughout.

**Expected**
- Each Done transition propagates to `PlayerA1` within ~2s.
- No layout glitch / scroll jump as rows re-sort under the default sort key.

### E-3 — Cold-start push deep-link

**[PlayerA1 — Android]**

1. Force-kill the CrewPoint app.
2. **[CapA — iPhone]** sends another urgent chat: *Pitch ready. Match starting in 15.*
3. Tap the push notification on `PlayerA1`'s lock screen.

**Expected** (re-runs `PUSH-COLD-01` from the handoff guide)
- App cold-starts and lands directly in the **Chat** screen of **Mumbai Sixers Invitational**. The urgent message is at the bottom of the thread.

> 🕳️ **Gap candidate:** No nudge / reminder if the urgent message goes unread for N minutes. Combined with `GAP-ANY-09 No due-date reminders / nudge notifications`.

### E-4 — `SponsorS` view-only test

**[SponsorS — Web Chrome]**

1. Browse the event for ~3 minutes. Read tasks, scroll chat, view budget ledger.
2. Resist creating any tasks, sending any chat, logging any expenses.
3. Then deliberately attempt: tap **+** FAB on Tasks → `CreateTaskScreen` opens — there is no permission gate. Cancel out.

**Expected**
- App permits every action a Member can perform. There is no "view-only" enforcement.

> 🕳️ **Gap candidate:** Confirms `GAP-CRK-29 No Observer / view-only / sponsor role`. This is **NOT a bug** — Members have full member permissions by design in v1. Update the GAPS entry's Workaround line with what `SponsorS` had to do to maintain restraint.

---

## §W — Wrap-up phase

### W-1 — `TD` logs the final expenses

**[TD — iPhone]**

Log these three expenses via `BUD-EXP-01`:

| Amount | Description | Payer | Split |
|---:|---|---|---|
| ₹3,000 | Match 1 umpire fee | `TD` | Equal across all 4 members |
| ₹1,200 | Team A trophy + medals | `TD` | Equal across all 4 members |
| ₹800 | Cross Maidan ground deposit refund — DONATION | `TD` | Toggle **Donate this cost** ON (payer excluded from split) |

**Expected**
- Budget list shows the new expenses.
- Cross-event ledger updates accordingly.

### W-2 — `TD` settles with `CapA` via Cash App (sandbox)

**[TD — iPhone]**

1. Open **Budget** → cross-event ledger. Find `CapA`'s row (or `TD`'s own row in the debts section, depending on net direction).
2. Tap **Settle Up**.
3. Tap **Pay with Cash App** (label per `settle_sheet.dart:123`).
4. **Use sandbox amount: $0.10 (~₹8).** Do not settle the actual computed debt.
5. Cancel inside Cash App, return.

**Expected**
- Settlement system-message in chat. Ledger reflects the (sandbox) settlement.

### W-3 — `TD` exports a PDF report

**[TD — iPhone]**

1. From the event Budget screen, tap the export menu (`BUD-EXPORT-01`). Choose **Export PDF**.
2. iOS share sheet opens. Save to Files or AirDrop.
3. Open the PDF. Confirm it lists the 4 expenses and the ledger summary in ₹.

**Expected**
- PDF renders cleanly. Currency symbol is **₹** throughout.

> 🕳️ **Gap candidate:** PDF has no Mumbai Sixers branding / customization. Confirms `GAP-CON-37 No branded / customizable PDF templates`.

### W-4 — `TD` archives the event

**[TD — iPhone]**

1. From the event dashboard, scroll to the bottom. Find the **Archive Event** switch (per `event_dashboard_screen.dart:606-639`, gated to admin/owner).
2. Toggle it on. Subtitle changes from **Archive to make read-only** to **Event is archived (read-only)**.

**Expected**
- The switch persists (no error snackbar **Could not update archive status**).
- Event card on **Home** moves from the **Upcoming** section to the **Past** section (per `HOME-FILT-01`).
- An **Archived** badge appears on the event detail (per the badge at `event_dashboard_screen.dart:334`).

### W-5 — Debrief

Open the debrief template in [`./README.md`](./README.md#tester-debrief--fill-at-the-end-of-each-scenario). Two paragraphs max. Be honest about what felt the longest.

---

## §Forced-fail drills

These 5 drills are designed to break things on purpose. Each ends with an explicit **If X → bug. If Y → gap.** classification.

### FF-1 — Member attempts admin-only action

**[PlayerA1 — Android]** opens the event Members screen, tries to remove another member.

- **If** the remove affordance is **not visible** on any row → working as designed (matches `EV-MEM-03` edge case for non-admin). Pass.
- **If** the remove affordance is visible and `PlayerA1` can tap it → **BUG**. File via [`../qa/v1-tester-handoff-guide.md` §14](../qa/v1-tester-handoff-guide.md#14-bug-report-template). RBAC violation.

### FF-2 — Network drop mid-task-submit

**[CapA — iPhone]** enables airplane mode → opens `CreateTaskScreen` → fills in *Drop drill task* → taps Save.

- **If** snackbar fires (e.g., **Failed to create task** per the existing `event_tasks_page.dart:50-55` error path) and the form state is preserved when the snackbar dismisses → matches `SYNC-NET-01`. Pass. Confirms `GAP-ANY-34 No offline writes (mobile or web)`.
- **If** the app crashes, or the form silently empties without an error → **BUG**.

### FF-3 — Kick member while they have the event open on a second device

**[TD — iPhone]** opens Members → removes `PlayerA1` (`EV-MEM-03`). Dialog: **Remove Member?** → tap **Remove**.

**[PlayerA1 — Android]** has the event chat open at the moment of removal.

- **If** `PlayerA1`'s device navigates out of the event (or shows a graceful "removed" notice) within ~5 seconds → working as designed. Pass.
- **If** `PlayerA1` sees the event indefinitely and can keep typing → **GAP** (no force-eviction). Log to `GAPS.md` as `GAP-CRK-XX Removed member retains stale event view`.
- **If** the app crashes on either side → **BUG**.

Recovery: re-invite `PlayerA1` via a fresh generated code if you want to continue.

### FF-4 — Cold-start push deep-link regression

Already executed in §E-3 above. Re-run after wrap-up archive to confirm cold-start into an archived event still routes correctly (or surfaces the appropriate read-only banner). If push fails to deep-link → **BUG** (regression in `PUSH-COLD-01`). If routing succeeds but archive banner is missing → **GAP**.

### FF-5 — Attempt v1-missing operation

**[CapA — iPhone]** tries to find a way to make task #2 (Coordinate practice — Mon evening) recur every Mon/Wed/Fri.

- **If** there's no UI for recurrence → confirms `GAP-CRK-04 No recurring tasks`. Pass.
- **If** `CapA` finds a hidden recurring field that doesn't work → **BUG**.

---

## §Web parity

Re-run these phases on **Chrome desktop ≥1280px** and **Safari mobile (Private Mode)** as `SponsorS`. Web has known infrastructure constraints — see [`./README.md`](./README.md#known-web--infra-constraints--not-bugs). Do NOT file the constraints themselves as bugs.

| Phase | Re-run on web? | What to watch for |
|---|:---:|---|
| §P (Planning) | ✅ Yes | OAuth popup recovery (`AUTH-WEB-01`). Create-event flow on responsive shell (NavigationRail at ≥840px per `responsive_shell.dart:137-177`). |
| §R (Ramp-up) | ⚠️ Partial | Skip the 8-task rapid creation — list perf on web is not the bottleneck. Re-run §R-3 (expense + receipt upload) to verify `firebase_image_service.dart` web-bytes path. |
| §E (Event day) | ❌ Skip push | Web receives no push (constraint #4). Skip §E-1's push expectation; confirm the urgent message still renders in chat. |
| §W (Wrap-up) | ✅ Yes | PDF export on web uses native browser download (per `file_export_service_web.dart`), not iOS share sheet. Confirm the PDF saves cleanly. |
| FF-2 (Network drop) | ✅ Yes | Web has even harsher offline behavior — confirms constraint #2 (no Firestore web persistence). Reload the tab mid-submit; the form state is lost (this is **NOT a bug**). |

iOS notification-actions gesture primer doesn't apply on web.

If you find a label drift between this guide and the live web app, file a guide-bug (note in this file), not an app-bug.

---

## What you should have logged by the end

A scenario run that surfaces nothing new is a scenario run that failed. Confirm the following minimum:

- ≥ 3 entries reviewed or expanded in [`./GAPS.md`](./GAPS.md): at minimum `GAP-CRK-29 No Observer / view-only / sponsor role`, `GAP-CRK-04 No recurring tasks`, `GAP-CRK-10 No bracket / match-fixture view`. (More likely 5–7 — also `GAP-ANY-21`, `GAP-ANY-24`, `GAP-ANY-25`, `GAP-CON-01`.)
- 0–2 bugs filed via [`../qa/v1-tester-handoff-guide.md` §14](../qa/v1-tester-handoff-guide.md#14-bug-report-template). If you found > 5 bugs, stop and tell the founder — v1 may not be tester-ready.
- 1 debrief paragraph in the shared channel.

Then move on to [`./02-hotel-convention.md`](./02-hotel-convention.md) when ready.
