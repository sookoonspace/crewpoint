# CrewPoint v1 — Consolidated Gap Log

This file collects **gaps** — things v1 doesn't do that real organizers want — surfaced across the three scenario guides ([cricket](./01-cricket-tournament.md) · convention · wedding).

> **Bug vs gap reminder.** A **bug** is the app crashing, throwing a red error, freezing, or failing to do something it explicitly promises. File bugs with the template in [`../qa/v1-tester-handoff-guide.md` §14](../qa/v1-tester-handoff-guide.md#14-bug-report-template). A **gap** is the app working perfectly but you wishing it had a tool to finish your scenario — that's what goes here.

Organized by category, not by scenario. Each entry uses the format:

```
### GAP-<SCN>-NN — <short title>
**Surfaced in:** <scenario + step>
**Severity for v1 release:** Blocker / Should-have / Nice-to-have
**Suggested fit:** v1.1 / v2 / backlog
**Workaround for testers:** <one line>
```

Scenario prefixes: `CRK` = cricket, `CON` = convention, `WED` = wedding, `ANY` = all three.

---

## Invites & onboarding

### GAP-CON-01 — No bulk / link / QR / CSV invite
**Surfaced in:** Convention Planning §P-2 (`CL` tries to seat 25+ attendees with one 6-character code).
**Severity for v1 release:** Should-have. Organizers of >10-person events will resort to manual paste, which the founder has accepted for v1 but won't survive a 25-attendee convention without complaints.
**Suggested fit:** v1.1.
**Workaround for testers:** `CL` copies the one event code via **Generate New Code** + **Code copied to clipboard** and pretends to share it via Slack/email to the 25 named attendees. Do not actually create 25 accounts.

### GAP-ANY-02 — One invite code per event (no per-team / per-cohort codes)
**Surfaced in:** Cricket Planning §P-3 (`TD` wants Team A captains to get a different code than sponsors, so role can be inferred at join time).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v2.
**Workaround for testers:** Same code for everyone; role assignment happens after join via promote-to-admin (`EV-MEM-04`).

### GAP-ANY-03 — No invite expiry / single-use codes
**Surfaced in:** Wedding Planning §P-2 (couple wants to share a code with guests but not let it spread).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v2.
**Workaround for testers:** Tap **Generate New Code** to rotate when over-shared (old code stops working per `EV-MEM-02`).

---

## Task management

### GAP-CRK-04 — No recurring tasks
**Surfaced in:** Cricket Ramp-up §R-1 (`CapA` wants "practice net session" repeating M/W/F).
**Severity for v1 release:** Should-have for sports/ops use cases.
**Suggested fit:** v1.1.
**Workaround for testers:** Duplicate the task three times via `TASK-DUP-01` and adjust dates manually. Note effort cost in the debrief.

### GAP-ANY-05 — No sub-tasks / task dependencies
**Surfaced in:** Convention Ramp-up §R-3 (`SC` wants "Confirm keynote travel" → "Book hotel" → "Send itinerary" as a chain).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** backlog.
**Workaround for testers:** Use the checklist editor (`TASK-CHK-01`) on a single parent task for shallow sub-steps. Not the same as real dependency chains.

### GAP-ANY-06 — No task attachments
**Surfaced in:** Wedding Ramp-up §R-2 (`Vend` wants to attach catering quote PDF to the task).
**Severity for v1 release:** Should-have. The `TaskAttachment` domain model exists; storage wiring deferred.
**Suggested fit:** v1.1.
**Workaround for testers:** Paste a link in the task description. Note that receipt-style uploads do work in Budget (`BUD-RECEIPT-01`), just not for tasks.

### GAP-ANY-07 — No task templates / event-template duplication
**Surfaced in:** Cricket Planning §P-4 (`TD` wants to copy last year's tournament setup as a starting point).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v2.

### GAP-ANY-08 — No Kanban / board view
**Surfaced in:** Convention Event-day §E-2 (`CL` wants a drag-status board for ops triage).
**Severity for v1 release:** Nice-to-have. List view ships v1 per audit Pillar 2.
**Suggested fit:** v1.x.

### GAP-ANY-09 — No due-date reminders / nudge notifications
**Surfaced in:** Cricket Event-day §E-3 (`PlayerA1` misses a "Bring whites" task because no push fires until match day).
**Severity for v1 release:** Should-have.
**Suggested fit:** v1.1.
**Workaround for testers:** `CapA` posts an urgent chat message instead — proves the workaround but exposes the missing primitive.

---

## Calendar & scheduling

### GAP-CRK-10 — No bracket / match-fixture view
**Surfaced in:** Cricket Planning §P-5 (`TD` wants Team A vs Team B / C vs D / winners-bracket display).
**Severity for v1 release:** Blocker for tournament-organizer use case specifically; not-applicable for trip/wedding.
**Suggested fit:** v2 if expanding to sports vertical; backlog otherwise.
**Workaround for testers:** Create tasks like "Match: Team A vs Team B — 2026-10-12 14:00" — list-view simulates a schedule but is not a bracket.

### GAP-CON-11 — No calendar / agenda grid view
**Surfaced in:** Convention Ramp-up §R-4 (`CL` wants a Day-1/Day-2/Day-3 column grid with sessions in time slots).
**Severity for v1 release:** Should-have for multi-day events.
**Suggested fit:** v1.1.

### GAP-WED-12 — No multi-day schedule blocks (events with mehndi / wedding day / reception)
**Surfaced in:** Wedding Planning §P-4 (`WP` wants three sub-day blocks with their own task groupings).
**Severity for v1 release:** Should-have for cultural/multi-day weddings.
**Suggested fit:** v1.1.

---

## RSVP & guest management

### GAP-WED-13 — No RSVP collection
**Surfaced in:** Wedding Planning §P-3 (`Couple` wants to track yes/no/maybe + meal choice + +1 across 30 guests).
**Severity for v1 release:** Blocker for wedding-organizer use case specifically.
**Suggested fit:** v2 (decision pending — is wedding even a v1 target vertical?).
**Workaround for testers:** Track manually in a checklist on a single "Guest RSVPs" task. Note how painful this is in the debrief.

### GAP-WED-14 — No guest dietary / preference metadata
**Surfaced in:** Wedding Ramp-up §R-3 (`Vend` wants per-guest meal-choice + allergy info).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** backlog.

---

## Budget & finance

### GAP-WED-15 — No Zelle deep link (Pillar 3 decision pending)
**Surfaced in:** Wedding Wrap-up §W-2 (`Couple` wants to settle with `FL` via Zelle).
**Severity for v1 release:** Should-have. Audit V1 launch blocker #7 — design decision (web-banking redirect vs copy-paste) pending.
**Suggested fit:** v1.0 if shipped before launch, else v1.1.
**Workaround for testers:** Confirm v1 falls through to the `LED-FALL-01` fallback sheet ("Copy payment details"). This is **expected v1 behavior, NOT a bug**.

### GAP-ANY-16 — No multi-currency FX display in the ledger
**Surfaced in:** Cross-scenario — tester running cricket (₹) + convention ($) back-to-back hits the `LED-CUR-01` multi-currency disclaimer.
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v2.
**Workaround for testers:** Disclaimer is already shown in v1; behavior is "we don't convert" — that's the documented limit.

### GAP-ANY-17 — No per-expense currency override
**Surfaced in:** Wedding Ramp-up §R-4 (`Vend` paid the florist in cash but event is INR — no way to mark one expense as a different currency).
**Severity for v1 release:** Nice-to-have. Event currency is immutable per audit row 4.
**Suggested fit:** v2.

### GAP-ANY-18 — No expense categories / labels
**Surfaced in:** Convention Wrap-up §W-1 (`CL` wants AV / Catering / Marketing breakdowns in the PDF report).
**Severity for v1 release:** Should-have.
**Suggested fit:** v1.1.
**Workaround for testers:** Prefix expense descriptions ("[AV] Microphone rental — $450"). Manual but works.

### GAP-ANY-19 — No receipt OCR
**Surfaced in:** Wedding Ramp-up §R-5 (`Vend` uploads handwritten florist invoice; amount + date have to be typed in by hand).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** backlog.

### GAP-WED-40 — No custom / non-equal split UI
**Surfaced in:** Wedding Ramp-up §R-6 (`FL` paid Friday late dinner intending only the bride's side to bear the cost — `Couple` + `FL`, not `WP` or `Vend`).
**Severity for v1 release:** Should-have. Wedding / fundraiser / shared-with-restricted-group expenses cannot be modeled — splits are always `total ÷ all members` (with the Donate this cost toggle optionally excluding the payer entirely; that is the only deviation). The single biggest budget gap surfaced.
**Suggested fit:** v1.1.
**Workaround for testers:** None clean. Logging two donation-mode expenses gets close but doesn't match the math. Acknowledge in debrief.

### GAP-ANY-20 — No real settlement reconciliation (Venmo webhook / Plaid)
**Surfaced in:** Wedding Wrap-up §W-3 (deep link launches Venmo, but the app has no idea whether the payment actually went through — `Couple` has to mark settled manually).
**Severity for v1 release:** Nice-to-have. Pillar 3 accepts deep-link + dispute model.
**Suggested fit:** v2.
**Workaround for testers:** Use the in-chat settlement-system-message dispute sheet (`CHAT-DISP-01`) if the recipient says they never got it.

---

## Chat

### GAP-ANY-21 — No reactions / emoji
**Surfaced in:** Cricket Event-day §E-1 (`PlayerA1` wants to thumbs-up a "Game on!" message instead of replying).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v1.1.

### GAP-ANY-22 — No edit / delete-for-everyone
**Surfaced in:** Convention Ramp-up §R-2 (`SC` typos a Zoom link, can't fix it — has to send a new message).
**Severity for v1 release:** Should-have.
**Suggested fit:** v1.1.

### GAP-ANY-23 — No message search
**Surfaced in:** Wedding Wrap-up §W-4 (`Couple` wants to find "what did the florist say about delivery time?" three days later).
**Severity for v1 release:** Should-have.
**Suggested fit:** v1.1.

### GAP-ANY-24 — No typing / read receipts
**Surfaced in:** Cricket Event-day §E-1 (no visibility into who's seen the urgent message).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v2.

---

## Notifications

### GAP-ANY-25 — **No notification preferences UI at all** (headline gap)
**Surfaced in:** All three scenarios — every persona hits Profile → **Notifications** row and finds it does nothing (`PROF-NOTIF-01` "deliberate no-op (NOT a bug)").
**Severity for v1 release:** Should-have. Privacy/control posture suffers without per-category toggles.
**Suggested fit:** v1.1.
**Workaround for testers:** OS-level notification control only. The no-op is intentional per the handoff guide and **NOT a bug** — confirm it sits silently as documented.

### GAP-ANY-26 — No quiet hours / Do-Not-Disturb window
**Surfaced in:** Wedding Event-day §E-2 (urgent push fires at 02:00 because vendor sent a question late).
**Severity for v1 release:** Should-have.
**Suggested fit:** v1.1 (gated on GAP-ANY-25).

### GAP-ANY-27 — No granular per-event mute durations (only iOS MUTE_EVENT 8h notif action)
**Surfaced in:** Convention Event-day §E-3 (`SponLi` wants to mute one event for 3 days, not 8 hours).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v1.1 (gated on GAP-ANY-25).

### GAP-ANY-28 — No FCM web push delivered to users
**Surfaced in:** Web Parity section of all three scenarios (testers on Chrome/Safari get no push at all).
**Severity for v1 release:** Acknowledged. Phase 6.2 schema landed but user-facing delivery is deferred.
**Suggested fit:** v1.1.

---

## Roles & permissions

### GAP-CRK-29 — No Observer / view-only / sponsor role
**Surfaced in:** Cricket persona `SponsorS` (logged in as regular Member but role-plays restraint). If `SponsorS` can create tasks / log expenses / send chat, that confirms the gap — it is **NOT a bug**.
**Severity for v1 release:** Should-have for tournaments/conventions where sponsors need read-only access.
**Suggested fit:** v1.1.
**Workaround for testers:** Tester voluntarily limits behavior. Note in debrief whether the lack of role-enforcement was noticed by other personas.

### GAP-CON-30 — No vendor-scoped role (member can see ONLY their own task scope)
**Surfaced in:** Convention Ramp-up §R-5 (`SponLi` shouldn't see speaker-honorarium expenses but can).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v2.

### GAP-ANY-31 — No transfer-ownership UI
**Surfaced in:** Wedding Planning §P-6 (`Couple` wants to hand the keys to `WP` for the final week and reclaim after).
**Severity for v1 release:** Should-have.
**Suggested fit:** v1.1.
**Workaround for testers:** None — owner can promote to admin but not transfer the owner bit. Note the coverage loss.

### GAP-WED-32 — No multi-owner / co-owner role
**Surfaced in:** Wedding persona `Couple` is one Firebase account (intentional coverage simplification — see scenario banner).
**Severity for v1 release:** Should-have for shared-event use cases (couples, business partners).
**Suggested fit:** v1.1.

### GAP-ANY-33 — Admin can promote/demote but not invite-as-role-presets
**Surfaced in:** Convention Planning §P-2 (`SC` wants to invite a speaker as Member-with-speaker-tag in one step).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v2.

---

## Offline & sync

### GAP-ANY-34 — No offline writes (mobile or web)
**Surfaced in:** All three scenarios — forced-fail drill "Drop network mid-task-submit" produces an error snackbar; the create attempt does not queue (confirms `SYNC-NET-01` behavior).
**Severity for v1 release:** Acknowledged. Pillar 1 ships read-side offline mirrors only.
**Suggested fit:** v1.1.

### GAP-ANY-35 — Firestore web persistence is intentionally OFF
**Surfaced in:** Web Parity section of all three scenarios — reload always re-fetches; queued writes lost (audit V1 launch blocker #6, founder-acknowledged).
**Severity for v1 release:** Should-have for web-first organizers.
**Suggested fit:** v1.0 if resolved before launch, else v1.1.

### GAP-ANY-36 — No background sync / periodic refresh
**Surfaced in:** Cricket Event-day §E-2 (`PlayerA1` puts phone in pocket between innings; opens app to find stale chat for 2 seconds until streams reconnect).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v2.

---

## Reporting & exports

### GAP-CON-37 — No branded / customizable PDF templates
**Surfaced in:** Convention Wrap-up §W-1 (`CL` wants a sponsor-facing report with Aurora branding).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v1.1.

### GAP-ANY-38 — No scheduled / automated exports
**Surfaced in:** Cricket Wrap-up §W-1 (`TD` wants weekly auto-emailed budget summary during the tournament).
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v2.

### GAP-ANY-39 — No richer report types (member summary, attendance, task-completion %)
**Surfaced in:** Cricket Wrap-up §W-2 (`TD` wants "tasks completed per team captain").
**Severity for v1 release:** Nice-to-have.
**Suggested fit:** v2.

---

*Add new gap entries above their category divider as scenarios are run. Use sequential numbering within the SCN prefix; do not renumber on insertion.*
