# Scenario 2 — Aurora Hospitality Annual Summit (hotel brand convention)

A 3-day brand summit at a hotel chain's flagship property. 25 internal attendees, 5 speakers, 3 sponsor reps — 33 people in total. You're running planning through wrap-up via CrewPoint v1 and surfacing where it falls short for a corporate operations workflow. Read [`./README.md`](./README.md) **before** starting.

> 🪧 **Abstract personas rule.** You only operate the **4 active personas** below. The other 29 attendees / speakers / sponsors are names in the narrative — do NOT create accounts for them. When a step says "CL invites the rest of the cohort", you verify the invite primitive works **once** and move on. ([`./README.md`](./README.md#you-only-operate-the-active-personas-dont-burn-out))

## Scale block

| Field | Value |
|---|---|
| Event currency (immutable per audit row 4) | **USD ($)** |
| Active personas | `CL` Convention Lead (owner) · `SC` Speaker Coordinator (admin) · `Spkr` Speaker (member) · `SponLi` Sponsor Liaison (member) |
| Abstract personas (names in narrative only) | 21 attendees + 4 other speakers + 3 sponsor reps = 28 |
| Devices ideally | iPhone (CL), Android (SC), iPad/tablet (Spkr), Web Chrome (SponLi) |
| Min devices | 2 — pair CL with SC on one phone via baton-pass, Spkr + SponLi on the other |
| Estimated tester-hours | ~6 (Planning 75m · Ramp-up 90m · Event day 90m · Wrap-up 60m + Forced-fail drills 30m + Web parity 30m) |

### Sponsor / Speaker role-play note

`SponLi` and `Spkr` are regular **Members** (there is no Sponsor / Speaker / Vendor-scoped role in v1). They role-play limited scope: `SponLi` only views (no task creates, no expense logs), `Spkr` only acts on tasks assigned to them. If either is able to see / do things their real-life counterpart shouldn't — log a gap, not a bug.

## Prerequisites

- Complete install + onboarding + first sign-in via [`../qa/v1-tester-handoff-guide.md` §0](../qa/v1-tester-handoff-guide.md#0-pre-flight-setup--onboarding) per persona on assigned device.
- `CL` and `SC` have Venmo + Cash App handles set in **Profile** (for the Wrap-up settle drills). `Spkr` and `SponLi` do not — that's a deliberate gap probe.
- Read [`./README.md`](./README.md) §"Bug vs gap".

### If you get stuck

| Situation | Do this |
|---|---|
| Persona in the wrong account | `AUTH-OUT-01` → sign back in. |
| Skipped a phase | Run `EV-CRE-01` from the handoff guide to seed an event, then resume the phase you wanted. |
| Build under test has an unresolved V1 launch blocker | Replace the dependent step with a `> 🕳️ Gap candidate:` callout; do not invent a workaround. |

## At-a-glance arc

| Phase | Personas active | What happens | Time |
|---|---|---|:---:|
| Planning (§P) | `CL`, then `SC` | Event created, invite distribution attempt, first speaker outreach tasks | 75m |
| Ramp-up (§R) | All four | Speaker confirmations, long descriptions + heavy checklists, AV/catering expenses, sponsor onboarding | 90m |
| Event day (§E) | All four, multiple devices | Urgent chat (room change), real-time triage, push under load, deep-link cold-start | 90m |
| Wrap-up (§W) | `CL`, `SC` | Final expenses, sponsor reconciliation, PDF/CSV export, settle, archive | 60m |
| Forced-fail drills | `CL` + `SC` paired | 5 deliberate stress tests | 30m |
| Web parity | `SponLi` solo on Chrome + Safari | Re-run select phases on web | 30m |

---

## §P — Planning phase

### P-1 — `CL` creates the summit event

**[CL — iPhone]**

1. From the **Home** tab, tap **Create Event**.
2. Fill the form:
   - Title: *Aurora Hospitality Annual Summit 2026*
   - Description: *Three-day brand summit at the Aurora Marina (San Diego). Keynotes Day 1 morning, breakouts + sponsor lounge Day 1 afternoon. Operations workshops + general session Day 2. Awards gala + closing Day 3. ~33 expected attendees including 5 speakers + 3 sponsor reps. Hashtag #AuroraSummit26.*
   - Event type: **Project** (closest fit — none of the four — **Trip / Project / Social / Custom** — is "Conference").
   - Start date: 2026-09-21 — End date: 2026-09-23
   - Currency: **$ USD** *(immutable once set per audit row 4)*
3. Tap **Create Event** (form's primary button per `create_event_screen.dart:321`).

**Expected**
- `CL` lands on the new event's dashboard. Event card on **Home** shows the title and date range.
- `CL` is **Owner**; currency symbol throughout reads **$**.

### P-2 — `CL` generates the invite code, tries (and fails) to invite 33 people

**[CL — iPhone]**

1. Open **Members** → tap the sage **+** FAB.
2. Wait for **Generating code...** → tap **Copy**. Snackbar: **Code copied to clipboard**.
3. Pretend to share the code with all 33 attendees via the corporate Slack channel and email distribution lists. **Do NOT create 33 accounts.**

> 🕳️ **Gap candidate:** `CL` has exactly one 6-character code for the whole summit. No way to (a) upload a CSV roster of attendees with auto-invite, (b) generate a per-cohort code (e.g., speakers vs sponsors vs attendees), or (c) send a magic link directly to email. For a 33-person event this is workable; for a 200-person event next year it isn't. Confirms `GAP-CON-01 No bulk / link / QR / CSV invite` and `GAP-ANY-33 Admin can promote/demote but not invite-as-role-presets`.

### P-3 — `SC` joins; `CL` promotes them to admin

**[SC — Android]**

1. Sign in. **Home** tab → **Join Event** sheet → enter code → tap **Join Event** (sheet's primary button per `join_event_sheet.dart:160`). Snackbar confirms.

**[CL — iPhone]**

2. Members screen → find `SC`'s row → tap promote.
   - Snackbar **Promoted to admin** (sage). Badge flips Member (grey) → Admin (info-blue).

### P-4 — `Spkr` and `SponLi` join

**[Spkr — iPad/tablet]** Sign in → **Join Event** → enter code → tap **Join Event** (sheet's primary button per `join_event_sheet.dart:160`).

**[SponLi — Web Chrome]** Sign in (OAuth popup; if blocked, follow `AUTH-WEB-01`) → **Join Event** sheet on **Home** → enter code → tap **Join Event** (sheet's primary button per `join_event_sheet.dart:160`).

**Expected**
- All four devices show 4 members. Roles: `CL` Owner, `SC` Admin, `Spkr` Member, `SponLi` Member.
- No role badge distinguishes Speaker or Sponsor from a regular Member.

### P-5 — `CL` and `SC` seed the first outreach tasks (5 tasks)

**[CL — iPhone]** creates:

| Title | Assignee | Due | Priority | Budget |
|---|---|---|:---:|---:|
| Confirm 5 speakers for keynote slate | `SC` | 2026-07-15 | High | $0 |
| Lock the Aurora Marina ballroom + 4 breakouts | `CL` | 2026-07-01 | High | $0 |
| Reach out to 3 sponsor reps — bronze + silver + gold | `SponLi` | 2026-07-30 | Medium | $0 |

**[SC — Android]** creates (sub-task simulation since v1 has no real sub-tasks):

| Title | Assignee | Due | Priority | Budget |
|---|---|---|:---:|---:|
| Speaker travel: research flights + hotel rates | `SC` | 2026-07-20 | Medium | $0 |
| Speaker travel: book Keynote A's flight | `SC` | 2026-07-25 | Medium | $0 |

**Expected**
- Tasks list shows 5 items, all **To Do**.

---

## §R — Ramp-up phase

### R-1 — `SC` builds the heavy-checklist speaker-confirmation task

**[SC — Android]**

1. Open **Tasks** → tap the first **Confirm 5 speakers...** task. Tap edit.
2. Open the Checklist editor (`TASK-CHK-01`). Use the **Add item** hint at the bottom of the checklist section to add these 10 sub-items one by one (the editor stops you at the `maxItems` cap — observe what that cap is and whether the snackbar is graceful):
   - Send slot confirmation email to Keynote A
   - Send slot confirmation email to Keynote B
   - Confirm dietary requirements — Keynote A
   - Confirm dietary requirements — Keynote B
   - Request speaker headshot — Keynote A
   - Request speaker headshot — Keynote B
   - Send AV requirements form — Keynote A
   - Send AV requirements form — Keynote B
   - Add bio to summit microsite — Keynote A
   - Add bio to summit microsite — Keynote B

**Expected**
- Header reads **Checklist (10/<maxItems>)**.
- Each row toggles independently. Adding the 10th item works smoothly. If `maxItems` is < 10, this drill surfaces it as a usability constraint.
- The task tile back on the Tasks list shows the `0/10` progress fraction.

### R-2 — Chat: `SC` posts the Zoom link for the speaker briefing — then typos it

**[SC — Android]**

1. Open **Chat**. Send: *Speaker briefing call Thursday 4pm PT. Zoom: https://zoom.us/j/123456789?pwd=BADTYPO*
2. Realize the link is wrong. Try to edit the message.

> 🕳️ **Gap candidate:** v1 has no edit or delete-for-everyone for chat messages. `SC` has to send a follow-up correction message which adds noise. Confirms `GAP-ANY-22 No edit / delete-for-everyone`. Note in the debrief whether `Spkr` clicked the bad link before the correction arrived.

3. Send the correction: *Correction — Zoom: https://zoom.us/j/123456789?pwd=CORRECTED. Sorry.*

**[Spkr — iPad]** Observe the chat in real time.

**Expected**
- Both messages visible in chronological order on all devices.
- Cross-event Chat inbox shows the summit with an unread badge.

### R-3 — Long-task chain: `SC` creates a 3-task dependency chain that the app can't model

**[SC — Android]** creates these three tasks in order, intending them as a chain `A → B → C`:

| Order | Title | Assignee | Due | Priority |
|:---:|---|---|---|:---:|
| A | Confirm Keynote A travel preferences (dates, class, accommodations) | `SC` | 2026-07-22 | Medium |
| B | Book Keynote A flight + hotel based on prefs from A | `SC` | 2026-07-25 | Medium |
| C | Send Keynote A complete itinerary + Marina pickup details | `SC` | 2026-09-15 | Low |

> 🕳️ **Gap candidate:** There's no way to mark B as blocked-on A or C as blocked-on B. `SC` has to track the dependency in their head (or in the task description as plain text). Confirms `GAP-ANY-05 No sub-tasks / task dependencies`. Note in the debrief how easy it would be to start B before A is done.

### R-4 — `CL` plans the 3-day agenda — but the app has no grid view

**[CL — iPhone]** opens **Tasks** and creates the agenda as 12 tasks (4 sessions × 3 days), with dates and times in the title:

| Day | Title | Due | Priority |
|:---:|---|---|:---:|
| 1 | 09:00 Welcome + Keynote A — Main Ballroom | 2026-09-21 | High |
| 1 | 11:00 Sponsor lounge open | 2026-09-21 | Medium |
| 1 | 14:00 Breakout A1 — Operations | 2026-09-21 | Medium |
| 1 | 16:00 Networking reception | 2026-09-21 | Low |
| 2 | 09:00 Keynote B — Main Ballroom | 2026-09-22 | High |
| 2 | 11:00 Workshop — Revenue Mgmt | 2026-09-22 | Medium |
| 2 | 14:00 Workshop — F&B Innovation | 2026-09-22 | Medium |
| 2 | 18:00 Sponsor dinner | 2026-09-22 | Medium |
| 3 | 09:00 General Session | 2026-09-23 | High |
| 3 | 12:00 Awards Gala | 2026-09-23 | High |
| 3 | 15:00 Closing Keynote | 2026-09-23 | High |
| 3 | 17:00 Wrap-up + thank-yous | 2026-09-23 | Low |

After creating all 12, tap the group toggle (`TASK-GRP-01`) → switch to **Due window** grouping → observe the headers: **Today / This week / Later / No due date**.

> 🕳️ **Gap candidate:** There is no agenda / calendar grid view (Day 1 column / Day 2 column / Day 3 column with sessions in time slots). The closest v1 offers is the **Due window** grouping or sort-by-due-date — neither shows a multi-day grid. Confirms `GAP-CON-11 No calendar / agenda grid view`.

### R-5 — `SponLi` onboards sponsors and discovers they can see everything

**[SponLi — Web Chrome]**

1. Open the event in Chrome. Browse **Tasks** — sees all 17 tasks across speaker / venue / agenda / sponsor outreach. Sees `SC`'s notes about speaker honorariums in the chat.
2. Sees the (currently empty) **Budget** tab.

> 🕳️ **Gap candidate:** A "Sponsor Liaison" in a real corporate event shouldn't be looking at speaker honorarium amounts or sponsor competitor names. v1 has no scoped role that limits `SponLi` to sponsor-related tasks/expenses only. Confirms `GAP-CON-30 No vendor-scoped role` and `GAP-CRK-29 No Observer / view-only / sponsor role` (cross-scenario). This is **NOT a bug** — it confirms the gap. `SponLi` role-plays restraint.

### R-6 — First expenses (AV gear, room block deposit, sponsor honorarium)

**[CL — iPhone]** logs three expenses via `BUD-EXP-01`:

| Amount | Description | Payer | Notes |
|---:|---|---|---|
| $4,500 | AV gear rental (mics + projectors + lighting) | `CL` | Equal split. |
| $12,000 | Aurora Marina ballroom + breakout deposit | `CL` | Equal split. |
| $3,500 | Keynote A honorarium | `CL` | Equal split. Note: `SponLi` will see this — see §R-5 gap callout. |

**Expected**
- Ledger updates: `SC`, `Spkr`, `SponLi` each owe `CL` ~$5,000.

> 🕳️ **Gap candidate:** Expenses have no category — there's no AV / Catering / Speaker / Sponsor breakdown for the wrap-up report. `CL` prefixes descriptions ("[AV] Mics + projectors + lighting") as a workaround. Confirms `GAP-ANY-18 No expense categories / labels`.

---

## §E — Event day

### E-1 — Urgent chat: ballroom flooded morning of Day 1

**[CL — iPhone]**

1. Open **Chat**. Type: *URGENT — Main ballroom water leak overnight. Moving Day 1 morning sessions to Pacific Salon. Direct attendees from lobby. Updated signage incoming.*
2. Toggle the urgent affordance → **Send Critical Alert** modal → confirm → send.

**Expected**
- Urgent terracotta bubble with **Critical Alert** badge per `message_bubble.dart:119`.
- `SC`, `Spkr`, `SponLi` receive a push within ~10s (if mobile + push permissions granted).
- `SponLi` on Web Chrome receives **no push** — see [`./README.md`](./README.md) constraint #4.
- On iOS, long-press / drag-down the banner exposes **MARK_DONE** + **MUTE_EVENT** action buttons (standard iOS notification-action gesture — not a CrewPoint constraint).

### E-2 — Real-time task triage: `CL` and `SC` both editing simultaneously

**[CL — iPhone]** marks the "09:00 Welcome + Keynote A — Main Ballroom" task description → edit → append ` — MOVED to Pacific Salon` → save.

**[SC — Android]** at the same time on the same task tries to update the title to add `(Pacific Salon)`.

**Expected**
- Last-write-wins per Firestore SDK. One of the two edits "loses" silently. Observe which.
- Both devices show the final winning state within ~2s.

> 🕳️ **Gap candidate:** No drag-status board for ops triage during a live event. `CL` would have preferred a Kanban with To Do / In Progress / Done columns to see what's resolved vs in-flight at a glance. Confirms `GAP-ANY-08 No Kanban / board view`.

### E-3 — Granular mute: `SponLi` wants to mute the noisy summit for 3 days, gets 8 hours

**[SponLi — Web Chrome]**

`SponLi` doesn't actually have a mute UI on web (no FCM web push delivered at all per constraint #4). Move this drill to a mobile persona:

**[SC — Android]**

1. After receiving the §E-1 urgent push, long-press the notification banner.
2. Tap **MUTE_EVENT** → event is muted for **8 hours** (default).

> 🕳️ **Gap candidate:** Wants a mute-for-3-days option for the summit duration. Confirms `GAP-ANY-27 No granular per-event mute durations (only iOS MUTE_EVENT 8h notif action)`. Also no quiet-hours preference (`GAP-ANY-26`). And the per-category preferences UI to manage all of this is the headline gap — `GAP-ANY-25 No notification preferences UI at all`.

### E-4 — Cold-start push deep-link

**[Spkr — iPad]** force-kills the app.

**[CL — iPhone]** sends another urgent chat: *Pacific Salon doors opening 5 min — speakers to green-room please.*

**[Spkr — iPad]** taps the push notification on the lock screen.

**Expected** (re-runs `PUSH-COLD-01`)
- App cold-starts and lands directly in the **Chat** of the Aurora Summit event. Urgent message at the bottom.

---

## §W — Wrap-up phase

### W-1 — `CL` logs final expenses and exports the financial report

**[CL — iPhone]** logs the final batch:

| Amount | Description | Payer | Notes |
|---:|---|---|---|
| $8,500 | Catering — 3-day total | `CL` | Equal split. |
| $2,500 | Awards Gala AV upgrade | `CL` | Equal split. |
| $1,800 | Closing dinner — speakers + sponsors (cash sponsorship comp) | `CL` | Toggle **Donate this cost** ON — payer excluded from split. |

Then export the financial report:

1. From the event Budget screen, open the export menu (`BUD-EXPORT-01`). Choose **Export PDF**.
2. iOS share sheet → save / AirDrop.
3. Open the PDF. Note: no Aurora branding, no logo, no AV-vs-Catering-vs-Speaker category breakdown.

> 🕳️ **Gap candidate:** For sponsor-facing financial reporting, `CL` wanted Aurora branding + category breakdown. Confirms `GAP-CON-37 No branded / customizable PDF templates` and (again) `GAP-ANY-18 No expense categories / labels`.

4. Also tap **Export CSV** → save / share. Confirm row count matches expense count + headers in RFC-4180 format per audit Pillar 4.

### W-2 — Sponsor reconciliation: settle via Cash App (sandbox)

**[CL — iPhone]**

1. Open **Budget** → cross-event ledger. Find `SC` or whichever debt is settled in `CL`'s direction.
2. Tap **Settle Up** → **Pay with Cash App** (label per `settle_sheet.dart:123`).
3. **Use sandbox amount: $0.10.** Do NOT settle the real ~$5,000. This is a smoke test.
4. Cancel inside Cash App, return.

**Expected**
- Settlement system-message appears in the event chat (`CHAT-DISP-01`).

### W-3 — `CL` archives the event

**[CL — iPhone]**

1. From the event dashboard, scroll to the bottom. Find the **Archive Event** switch.
2. Toggle on → subtitle changes from **Archive to make read-only** to **Event is archived (read-only)**.

**Expected**
- Persists (no **Could not update archive status** snackbar). Event moves to **Past** on `HOME-FILT-01`. **Archived** badge appears.

### W-4 — Debrief

Two paragraphs in the shared channel per [`./README.md`](./README.md#tester-debrief--fill-at-the-end-of-each-scenario).

---

## §Forced-fail drills

### FF-1 — Member attempts admin-only action

**[Spkr — iPad]** opens Members → tries to remove `SponLi`.

- **If** remove affordance not visible → working as designed (`EV-MEM-03` member behavior). Pass.
- **If** visible & actionable → **BUG**. RBAC violation.

### FF-2 — Network drop mid-expense-submit

**[SC — Android]** enables airplane mode → opens `CreateExpenseScreen` → fills *$500 — drop test* → taps **Add Expense**.

- **If** snackbar **Failed to add expense** fires and form state persists → matches `BUD-EXP-01` edge case. Pass. Confirms `GAP-ANY-34 No offline writes`.
- **If** app crashes or form silently empties → **BUG**.

### FF-3 — Kick `SponLi` while they have the event open

**[CL — iPhone]** opens Members → removes `SponLi` (`EV-MEM-03`). Dialog **Remove Member?** → **Remove**.

**[SponLi — Web Chrome]** is browsing the budget tab at the moment of removal.

- **If** `SponLi`'s web tab navigates out (or shows graceful "removed" notice) within ~5s → working as designed. Pass.
- **If** `SponLi` retains the view indefinitely and can keep clicking around → **GAP** `GAP-XX Removed member retains stale event view on web`. Log to GAPS.md.
- **If** crash on either side → **BUG**.

Recovery: re-invite `SponLi` via fresh code generation if continuing.

### FF-4 — Cold-start push deep-link regression

Already run in §E-4. Re-run after archive (§W-3) — confirms cold-start into an archived event still routes correctly. Push fail → **BUG**. Routing succeeds but no archive banner → **GAP**.

### FF-5 — Attempt v1-missing operation: per-cohort invite codes

**[CL — iPhone]** tries to find a way to give the 3 sponsor reps a different invite code from the 25 attendees.

- **If** no UI for second code → confirms `GAP-ANY-02 One invite code per event (no per-team / per-cohort codes)`. Pass.
- **If** something hidden suggests it but doesn't work → **BUG**.

Recovery: regenerate the single code via **Generate New Code** if testers want to reset.

---

## §Web parity

Re-run on **Chrome desktop ≥1280px** and **Safari mobile (Private Mode)** as `SponLi`. Constraints per [`./README.md`](./README.md#known-web--infra-constraints--not-bugs).

| Phase | Re-run on web? | What to watch for |
|---|:---:|---|
| §P (Planning) | ✅ Yes | OAuth popup recovery (`AUTH-WEB-01`). Create-event flow at desktop breakpoint (NavigationRail ≥840px per `responsive_shell.dart:137-177`). |
| §R (Ramp-up) | ✅ Yes | The 12-task agenda creation on web is a stress test — confirm no list-perf regression vs mobile. Heavy-checklist task editor (§R-1) on web. |
| §E (Event day) | ❌ Skip push | Web receives no FCM push (constraint #4). Skip §E-1's push expectation; confirm urgent message renders + the **Critical Alert** badge. Mute-event (§E-3) is mobile-only. |
| §W (Wrap-up) | ✅ Yes | PDF + CSV export on web uses native browser download (per `file_export_service_web.dart`). Confirm both download cleanly with the correct filename. |
| FF-2 (Network drop) | ✅ Yes | Web has harsher offline behavior — reload mid-submit and the form state is lost (constraint #2, **NOT a bug**). |

iOS notification-actions gesture primer doesn't apply on web. Safari Private Mode also wipes the Drift in-memory Wasm cache on reload — expected per `providers.dart:76-79`.

If a literal bold label drifts between this guide and the live web app, file a guide-bug (note in this file) not an app-bug.

---

## What you should have logged by the end

A scenario run that surfaces nothing new failed. Confirm at minimum:

- ≥ 3 entries reviewed or expanded in [`./GAPS.md`](./GAPS.md): at minimum `GAP-CON-01 No bulk / link / QR / CSV invite`, `GAP-CON-11 No calendar / agenda grid view`, `GAP-CON-37 No branded / customizable PDF templates`. Realistically 6–8 also touched: `GAP-CON-30`, `GAP-ANY-05`, `GAP-ANY-08`, `GAP-ANY-22`, `GAP-ANY-25/26/27`, `GAP-ANY-18`, `GAP-ANY-33`.
- 0–2 bugs filed via [`../qa/v1-tester-handoff-guide.md` §14](../qa/v1-tester-handoff-guide.md#14-bug-report-template). > 5 bugs → stop and tell the founder.
- 1 debrief paragraph.

Then move on to [`./03-wedding-event.md`](./03-wedding-event.md) when ready.
