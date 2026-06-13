<goal>
Produce three tutorial-style, scenario-driven test guides that stress CrewPoint v1 against realistic multi-persona use cases (cricket tournament, hotel brand convention, wedding event), plus a README index and a consolidated GAPS log, so the founder can confidently hand v1 to external testers knowing every angle has been probed.

The guides are the founder's last gate before the first external tester release. Their job is to surface — in writing — every place v1 falls short against a real-world organizer, before strangers do. The deliverables are read and executed by 2–3 paired human testers (not by an AI agent), one of whom may be non-technical.
</goal>

<background>
**App:** CrewPoint, Flutter (iOS/Android/Web) collaborative event-management app. Riverpod state, Firebase (Auth/Firestore/Storage/Messaging/Functions), Drift local mirror. Five-tab shell: Home (events), Tasks, Chat, Budget, Profile.

**Existing testing assets (must be linked, not duplicated):**
- `@docs/qa/v1-tester-handoff-guide.md` — ~3000-line feature-by-feature checklist with bug-report template, device matrix, literal-label discipline. The scenario guides reference this for primitive flows and the bug template.
- `@docs/qa/push-notifications-testing-guide.md` — push setup and verification.
- `@docs/qa/push-notifications-deployed-functions-testing.md` — CF push verification.

**Live v1 feature surface (single source of truth — implementer MUST re-survey before writing each guide; this summary is non-authoritative):**
- Auth: Email/password + Google + Apple (Firebase providers). Non-blocking email-verification banner. No forgot-password UI flow.
- Events: Types (Trip / Project / Social / Custom). Statuses (Active / Archived). RBAC: Owner / Admin / Member. Event currency set on creation (immutable per audit row 4). No view-only / Observer / Vendor-scoped role.
- Tasks: Title, description, assignee, due date, priority 0–3, budget estimate, checklist items. Statuses: To Do / In Progress / Done. Filter chips per `TASK-FILT-01`: **Mine** / **Overdue** / **Has budget** / **To Do** / **In Progress** / **Done** (multi-select). Duplicate flow. **No** recurring tasks, sub-tasks, templates, attachments, Kanban, reminders. **Caveat:** `CreateTaskScreen` is named as V1 launch blocker #3 in `docs/v1-progress-audit.md` (silent-no-op pattern) — implementer MUST verify it persists on current `main` before drafting any scenario that depends on task creation.
- Chat: Per-event real-time + cross-event inbox. Urgent toggle fans out via FCM. Settlement system messages with dispute sheet. **No** reactions, edits, search, typing, read receipts.
- Budget: Per-event expenses + cross-event ledger. Equal/custom splits. Donation toggle. Receipt uploads (Storage). **Venmo + Cash App only** have native deep-link settle (`pay_link_builder.dart`); **Zelle / PayPal / Cash / Other / null-handle** all fall through to the manual `LED-FALL-01` fallback sheet (copy-paste UX, no deep link) — this is current v1 behavior, not a bug. PDF + CSV export via share sheet (mobile) / native browser download (web). **No** multi-currency FX, per-expense currency, categories, OCR.
- Members: **6-character code only** (`EV-MEM-02`) — owner taps **+** FAB on Members screen, app generates a single per-event code, copy + share out-of-band, recipient joins via **Join Event** sheet on Home (`HOME-JOIN-01`). **No** email invite, link invite, bulk invite, CSV upload, QR. **No** transfer-ownership UI.
- Notifications: Push fan-out works (urgent → FCM → device). Channels exist per category (`crewpoint_tasks` / `_budget` / `_chat` / `_urgent` / `_digest`). **BUT** the Profile → **Notifications** row is a deliberate no-op in v1 per `PROF-NOTIF-01` ("Notifications row is a deliberate no-op (NOT a bug)") — there is no user-facing preferences UI, no master toggle, no per-category gate, no digest opt-in switch. This is THE big notifications gap and must headline GAPS.md's Notifications category.
- Profile: Display name, photo, payment handles (Venmo / Zelle / Cash App / PayPal / Cash / Custom — but only Venmo + Cash App actually deep-link; see Budget bullet), currency, theme (light/dark, persisted via shared_preferences). Account deletion via CF.
- Offline: Drift mirrors for cold-start renders on iOS/Android. **No** offline writes anywhere — submits blocked without Firestore (mobile + web).
- Web: Responsive shell with NavigationRail at ≥840px. OAuth via `signInWithPopup()`. Native browser download for exports. **Firestore web persistence is intentionally OFF** (audit V1 launch blocker #6: `firebase_service.dart` has no `persistenceEnabled` / `enableIndexedDbPersistence`) — every reload re-fetches and queued writes are lost regardless of browser. Drift on web is in-memory Wasm.

**Known v1 infrastructure constraints that are NOT bugs (must be pre-listed in README + each Web Parity section so testers don't report them):**
- Web OAuth uses popup not native sheet (`signInWithPopup` — Firebase web SDK constraint).
- Web reloads always re-fetch from Firestore and lose any queued writes — Firestore web persistence is intentionally off (audit V1 launch blocker #6, acknowledged by founder, decision pending Phase X). Affects all browsers, all modes.
- No offline writes anywhere (mobile or web) — submissions require network.
- No FCM web push surfaced as user-facing notifications (Phase 6.2 schema only).
- Zelle / PayPal / Cash settle paths fall through to the manual `LED-FALL-01` fallback sheet — no deep link is a Pillar 3 design choice pending decision, not a bug.
- The Profile → **Notifications** row is a deliberate no-op in v1 (`PROF-NOTIF-01`). Tapping it does nothing on purpose; the per-category preferences UI is not built yet.

**Constraints on the guides:**
- Testers are humans, not agents. Treat onboarding overhead (account creation, device setup) as the most expensive cost. Minimize it.
- Non-technical testers must be able to distinguish a **bug** (broken behavior) from a **gap** (missing feature) without supervision.
- Realistic-but-bounded scale only — see persona/scale rules in <user_flows>.
- Cross-link, do not duplicate, the primitive flows already in `v1-tester-handoff-guide.md`.
</background>

<user_flows>
**Personas — active vs abstract.**

Each scenario defines **3–4 active personas** (real test accounts that real testers log into and operate) and **N abstract personas** (represented by an invite blast, a name in a list, or a placeholder — testers do NOT create or operate them).

**Cricket Tournament — "Mumbai Sixers Invitational"**
- *Scenario currency:* **INR (₹)** — set at event creation, immutable. All line-items use ₹.
- *Active:* `TD` Tournament Director (owner), `CapA` Team Captain A (admin), `PlayerA1` Player on Team A (member), `SponsorS` Sponsor Rep (member — see role-play note below).
- *Abstract:* 19 additional players across 4 teams, referenced by name only. CapA "invites the rest of Team A" by generating + copying ONE 6-character event code (the only invite primitive v1 has — see `EV-MEM-02`) and pretending to share it via WhatsApp. Testers verify the code-generation/copy flow once; they do NOT create 19 accounts.
- *Role-play note:* `SponsorS` is logged in as a regular Member with full member permissions. They role-play view-only restraint to surface the missing Observer / view-only role as `GAP-CRK-XX No view-only / sponsor role`. If `SponsorS` *can* create tasks / send chat / log expenses, that is **not a bug** — it confirms the gap.

**Hotel Brand Convention — "Aurora Hospitality Annual Summit"**
- *Scenario currency:* **USD ($)** — set at event creation, immutable. All line-items use $.
- *Active:* `CL` Convention Lead (owner), `SC` Speaker Coordinator (admin), `Spkr` Speaker (member), `SponLi` Sponsor Liaison (member).
- *Abstract:* 21 additional attendees + 5 speakers + 3 sponsor reps, referenced by name in the planning narrative. CL attempts to "seat 25+ attendees" but v1 only offers one 6-character code per event — testers reach that moment, log the gap, copy the code, and move on. The bulk-invite / CSV-upload / link-invite / QR-invite gap is the explicit `GAP-CON-01` to surface here.

**Wedding Event — "Priya & Marcus, 2026-10-17"**
- *Scenario currency:* **INR (₹)** — set at event creation, immutable. All line-items use ₹.
- *Active:* `Couple` Bride+Groom shared account (owner), `WP` Wedding Planner (admin), `FL` Family Lead — bride's side (member), `Vend` Anita — Catering Vendor (member).
- *Abstract:* 26 additional guests + 4 other vendors (florist, DJ, photographer, officiant), referenced by name only.
- *Coverage-loss note:* `Couple` is ONE Firebase account; couple-as-two-people coordination is intentionally not exercised. Seed `GAP-WED-XX Transfer-ownership UI` and `GAP-WED-XX Multi-owner / co-owner role` to mark this loss.

**Per-scenario arc (chronological — each guide is one of these):**
1. **Planning phase** — owner creates event, sets type/currency/dates, invites active personas + attempts to invite abstract personas, assigns first tasks.
2. **Ramp-up phase** — admins fan out tasks, members accept assignments, chat ramps up, first expenses get logged, settle-up rehearsal.
3. **Event day** — urgent chat, real-time task transitions, push notifications under load, on-the-fly expenses, deep-link cold-start.
4. **Wrap-up & settle** — final expenses, ledger reconciliation, settle via Venmo/Cash App, PDF/CSV export, archive event.

**Per-scenario forced-fail drills (3–5 per guide, each producing a bug OR a gap depending on outcome):**
- Try to perform an admin-only action as a member.
- Drop network mid-task-submit and recover.
- Kick a member while they have the event open on a second device.
- Cold-start tap on a push notification (deep-link routing — re-uses `PUSH-COLD-01` from the handoff guide; cite rather than duplicate).
- Attempt a v1-missing operation (recurring practice schedule, RSVP collection, bulk-invite-by-CSV/link, calendar grid view, observer role, transfer-ownership) — these surface gaps by design.

**Alternative paths (per-persona POV sub-flows):**
- Organizer POV: end-to-end ownership arc.
- Admin POV: delegated authority — what they can/can't do, where the UI feels under-permissioned or over-permissioned.
- Member POV: passive consumer arc — how invitations, notifications, and assignments feel from the receiving end.
- Vendor/Sponsor POV (wedding + convention only): single-purpose participant — do they get useful value without admin rights?

**Error/recovery flows surfaced per scenario:**
- Permission-denied: wrong-role attempt → expected: snackbar or disabled control. Gap if neither.
- Network drop: mid-submit → expected: error snackbar; verify form state preservation against `SYNC-NET-01` (handoff guide §13). Log a gap if data is lost.
- Push permission denied at OS level: → there is no in-app Notifications preferences UI to reflect the denial (`PROF-NOTIF-01` no-op). Expected: push silently stops arriving; in-app banner for foreground urgent messages still works (`PUSH-FG-01`). Bug if app crashes; confirm `GAP-XX-No-notification-preferences-UI` either way.
- Two-device staleness: kick member on device A, observe device B → expected: device B navigates away within sync window (verify against `EV-MEM-03`). Gap if member sees ghost event indefinitely.
- Deep-link cold-start: kill app, tap chat push → re-runs `PUSH-COLD-01`. Expected: lands on the right event chat. If `PUSH-COLD-01` already passes in the live handoff guide, this is a regression check, not a deferral.
</user_flows>

<requirements>
**Functional — output files (each created under `docs/guide/`):**
1. `README.md` — index, audience, how-to-run, persona/device matrix, bug-vs-gap rules (see Requirement 8), known web/infra constraints (see Requirement 14), seed-account checklist, cross-links to existing QA assets.
2. `01-cricket-tournament.md` — full scenario walkthrough for the Mumbai Sixers Invitational.
3. `02-hotel-convention.md` — full scenario walkthrough for the Aurora Hospitality Annual Summit.
4. `03-wedding-event.md` — full scenario walkthrough for Priya & Marcus, 2026-10-17.
5. `GAPS.md` — consolidated rolling log of feature gaps surfaced across all three scenarios, seeded with categories from the known-deferred list.

**Functional — content shape per scenario file:**
6. Each scenario file MUST open with: scale block (active personas, abstract counts, devices needed, est. duration), prerequisites (cross-link to `v1-tester-handoff-guide.md` §0 install/onboarding), and an at-a-glance arc table (Planning / Ramp-up / Event day / Wrap-up — minutes per phase).
7. Each scenario MUST be written as a chronological narrative with persona swim-lane callouts (e.g., `**[Captain A — iPhone]**` before steps that persona executes), not a flat list of unattributed steps.
8. Each scenario step MUST follow the embedded format: literal labels in **bold**, user input in *italics*, expected outcome as a sub-bullet, and where applicable a `> 💡 If you cannot do this, log it as **GAP-<SCENARIO>-NN** in GAPS.md.` line.

**Functional — bug vs gap discipline (the most-important content requirement):**
9. `README.md` MUST include a prominently-placed "Bug vs Gap" section using exactly this distinction (paraphrase preserved, wording can be polished):
   > A **bug** is when the app crashes, throws a red error, freezes, or fails to do something it explicitly promises (e.g., a button that does nothing, a tap that loses data). Use the bug-report template in `v1-tester-handoff-guide.md` §14.
   >
   > A **gap** is when the app works perfectly but you wish it had a tool to finish your scenario (e.g., "I wish I could see all matches on a calendar", "I wish I could collect RSVPs"). Log gaps in `GAPS.md` — do NOT file them as bugs.
10. Each scenario file MUST include — at the spots where a known-deferred feature would naturally be reached — a `> 🕳️ **Gap candidate:** ...` callout that pre-seeds the gap and tells the tester to confirm it in `GAPS.md`. This prevents the same gap from being filed three times.

**Functional — persona / device matrix (in README):**
11. The README MUST contain a Persona × Device assignment table:
    | Scenario | Active personas | Devices needed | Est. tester-hours |
    Plus a guideline: ideal minimum is 2 testers × 2 devices (iPhone + Android) per scenario; 3 testers × 3 devices preferred for the cricket + convention scenarios.

**Functional — abstract personas (account-seeding-exhaustion guard):**
12. The README MUST explicitly state: "You only operate the active personas. Abstract personas (the other 19 players, the other 26 guests, etc.) are represented by names in the narrative and by single invite-blast actions — you do NOT create accounts for them." This rule MUST be repeated in a short banner at the top of each scenario file.
13. Each scenario MUST use the invite flow once with the abstract group to surface bulk-invite gaps, then move on — testers do not iterate on the abstract group beyond that.

**Functional — Web parity:**
14. Each scenario file MUST end with a short "Web parity" mini-section (≤ 20 lines) that names which phases of the scenario are worth re-running on Chrome and Safari, and what to skip. The README MUST contain the canonical "Known web/infra constraints — NOT bugs" list:
    - Web OAuth uses popup, not native sheet (Firebase web SDK constraint).
    - Web reloads always re-fetch from Firestore and lose any queued writes — Firestore web persistence is intentionally off (audit V1 launch blocker #6, founder-acknowledged). Affects every browser and every mode.
    - No offline writes anywhere (mobile or web) — submissions require network.
    - FCM web push not yet user-facing (Phase 6.2 schema only).
    - Zelle / PayPal / Cash settle paths fall through to the manual `LED-FALL-01` fallback sheet (no deep link) — Pillar 3 design decision pending.
    - Profile → **Notifications** row is a deliberate no-op in v1 (`PROF-NOTIF-01`) — there is no preferences UI yet.
15. Scenario Web Parity sections MUST link back to the README list rather than re-listing all constraints. Each scenario's push-notification phase MUST include a one-line gesture primer: "On iOS, notification action buttons (MARK_DONE / MUTE_EVENT) appear on long-press / drag-down of the banner, not on tap — this is standard iOS behavior across all apps." Do NOT classify this as a CrewPoint constraint.

**Functional — forced-fail drills:**
16. Each scenario MUST contain 3–5 explicitly-labeled drills under a `## Forced-fail drills` section (in addition to drills embedded in the narrative). Each drill is a tight 2–5 step recipe with an expected outcome and a bug-vs-gap classification ("If X happens → bug. If Y happens → gap.").

**Functional — GAPS.md structure:**
17. `GAPS.md` MUST be organized by category, not by scenario, and seeded with these categories pre-populated as empty H2s (implementer fills with the gap candidates the scenarios will surface):
    - Invites & onboarding (link invites, QR invites, bulk-by-CSV, multiple invite codes per event)
    - Task management (recurring, sub-tasks, templates, attachments, Kanban, reminders)
    - Calendar & scheduling (calendar grid view, match brackets / fixtures, multi-day schedule blocks)
    - RSVP & guest management
    - Budget & finance (multi-currency FX, per-expense currency, categories, OCR, Zelle/PayPal/Cash deep links, real reconciliation)
    - Chat (reactions, edits, search, typing, read receipts)
    - Notifications (**No preferences UI at all — Profile → Notifications row is a no-op** [headline]; quiet hours; granular per-event mute durations; web push)
    - Roles & permissions (transfer-ownership UI, view-only / Observer role for sponsors, vendor-scoped roles, multi-owner / co-owner)
    - Offline & sync (offline writes mobile, offline writes web, Firestore web persistence not enabled, background sync)
    - Reporting & exports (richer report templates, scheduled exports, branded PDFs)
18. Each gap entry MUST use the format: `### GAP-<SCN>-NN — <short title>` with sub-fields `**Surfaced in:** <scenario + step>`, `**Severity for v1 release:** Blocker / Should-have / Nice-to-have`, `**Suggested fit:** v1.1 / v2 / backlog`, `**Workaround for testers:** <one line>`.
19. Implementer MUST seed `GAPS.md` with the gap candidates each scenario will naturally reach (e.g., `GAP-CRK-01 No bracket / match-fixture view`, `GAP-WED-01 No RSVP collection`, `GAP-CON-01 No bulk-invite by CSV/link`) so testers see the format by example.

**Error Handling — guide content itself:**
20. Each scenario MUST include a short "If you get stuck" stub under the prerequisites: how to reset (sign out / clear data), how to escalate (single contact channel placeholder), how to skip a phase without invalidating the rest of the scenario.

**Edge Cases — content:**
21. Each scenario MUST exercise at least one cross-device real-time scenario (member operates on iPhone while admin operates on Android; verify the change appears within sync window) and at least one deep-link / cold-start push scenario.
22. The cricket guide MUST exercise rapid task creation (8+ tasks within ramp-up) to expose any list-perf or pagination issues; the convention guide MUST exercise long event description / many checklist items per task; the wedding guide MUST exercise the budget / split / settle arc end-to-end with at least one custom (non-equal) split.

**Validation — content quality bar:**
23. Every literal UI label cited in the guides MUST exist in the live app (implementer verifies by grep, not from memory). Authority on mismatch: **live `lib/` strings win**. If `lib/` ≠ `docs/qa/v1-tester-handoff-guide.md` ≠ the spec, treat the live `lib/` string as truth and note the handoff-guide drift in passing — do NOT edit the handoff guide as part of this work.
24. Each scenario MUST embed ≥ 3 gap-candidate callouts, each in 1-to-1 correspondence with a seeded `GAP-<SCN>-NN` entry in `GAPS.md`. The implementer's pass-fail is structural (counts + mappings exist); the tester-engagement metric ("did they actually log entries") is the founder's post-tester observation, not a doc-author gate.

**Pre-flight — V1 launch blocker verification (new):**
25. Before drafting ANY scenario step that depends on Edit Event, Archive Event, or Create Task, the implementer MUST run a quick verification against current `main`:
    - **CreateTaskScreen** — audit blocker #3 (silent-no-op). Smoke-test or check `test/app/features/tasks/`. If unresolved, halt scenario drafting and escalate to founder — the cricket Ramp-up phase is unbuildable until fixed.
    - **Edit event (settings IconButton)** — audit row 4 (❌ Missing). If still missing, every scenario's wrap-up step that says "edit the event" becomes a gap-candidate callout, not a step.
    - **Archive event** — audit row 10 (⚠️ Wired-but-broken; toggle flips visually but does not persist). If still broken, every scenario's wrap-up "Archive event" becomes a forced-fail drill ("toggle Archive, reload, observe whether it persisted — log to `GAP-XX` if not").
    - **JoinEventSheet onSubmit wiring** — audit blocker #4. If unresolved, the Convention scenario's invite/join phase is unbuildable until fixed.
    Record the verification result in the README's "Build info" section so testers know which scenarios are gated.
</requirements>

<boundaries>
**Edge cases — guide design:**
- A scenario phase that depends on a feature the app does not have (e.g., "send RSVPs"): write as a gap-candidate moment — the tester reaches it, confirms the gap, logs to `GAPS.md`, and continues. Do NOT fake the feature using a workaround.
- A scenario phase that requires more than 4 active testers: split into sub-phases or mark explicitly as "single-tester simulated" with reduced verification value, and call it out so the founder knows what coverage was lost.
- Real money in settle-via-Venmo: testers use sandbox amounts (₹10 / $1) and the guide MUST state this; no real settlement.

**Error scenarios for the GUIDE ITSELF (not the app):**
- Stale labels: if a label in the guide doesn't match the running app, the tester is instructed to file the discrepancy as a guide-bug, not an app-bug. The README explains.
- Persona credential confusion: README mandates that the founder supplies real seed-account credentials in a private channel — guides use placeholder slots (`<active-A-email>`, `<active-A-password>`) and never embed credentials.

**Limits:**
- Total tester budget assumed: ≤ 6 tester-hours per scenario (≤ 18 hours total) with 2 testers × 2 devices. Any phase that bloats past 60 minutes for the active personas must be split or trimmed.
- Active persona ceiling: 4 per scenario. If a phase needs a 5th, design it as a baton-pass (one tester swaps accounts) and call it out — do not introduce a 5th tester.
- Word ceiling per scenario file: ~3000 words. If exceeded, split into sub-phases linked from the main file rather than producing a wall of text.
</boundaries>

<implementation>
**Files to create (all under `docs/guide/`):**
- `docs/guide/README.md`
- `docs/guide/01-cricket-tournament.md`
- `docs/guide/02-hotel-convention.md`
- `docs/guide/03-wedding-event.md`
- `docs/guide/GAPS.md`

**Patterns to follow (from existing repo conventions):**
- Match the voice and structure of `docs/qa/v1-tester-handoff-guide.md`: literal-label bolding, italic user input, monospace technical paths, no "should" / "may" in expected outcomes.
- Reuse the bug-report template by reference (link to `v1-tester-handoff-guide.md` §14), do not duplicate it.
- Use the same device matrix style for the persona/device table in the README.

**Implementer process (mandatory ordering):**
1. **Pre-flight: V1 launch blocker verification** (Requirement 25). Confirm CreateTaskScreen / Edit Event / Archive Event / JoinEventSheet status against current `main` and the audit. Record results — they determine which scenario steps survive vs become gap-candidate callouts.
2. **Re-survey the live feature surface.** Glob `lib/features/**` and `lib/router/**`. Confirm route names, the literal bottom-nav label for the events tab (the `<background>` calls it "Home" but the handoff guide uses "Dashboard" — use whichever appears in `lib/` literally), button labels, casing (e.g., "Has budget" lowercase b per `TASK-FILT-01`), and RBAC gates that the scenarios cite. The `<background>` summary is a starting point, not authority.
3. **Confirm or update the known-deferred list.** Cross-check the v1-tester-handoff-guide.md and the v1-progress-audit.md for current deferral status before seeding `GAPS.md`.
4. **Draft `GAPS.md` first** (with seeded categories and 3–5 example gap entries per scenario). This forces the implementer to identify gap candidates before writing the scenarios — so scenarios can route to them.
5. **Draft `README.md` second** (so the bug-vs-gap discipline and known-infra constraints are settled before scenarios reference them).
6. **Draft the three scenarios in order: cricket → convention → wedding.** Each scenario is independent; later ones can cross-link earlier ones for primitive flows (e.g., "complete onboarding as in §01 P-1").
7. **Final pass: literal-label verification.** Grep the codebase for every bolded label in the guides; fix any mismatch. Live `lib/` strings are authoritative on conflict.

**What to avoid:**
- Do NOT duplicate the primitive flows from `v1-tester-handoff-guide.md`. Cross-link.
- Do NOT invent features the app doesn't have. Reaching them is the point.
- Do NOT instruct testers to create 30+ accounts. Active = 3–4; abstract = name-only.
- Do NOT use placeholder Lorem-ipsum for tasks/expenses. Use realistic, currency-aligned line-items: Cricket in ₹ (e.g., "Book Wankhede practice nets — 2026-10-12 7am", "Print scorecards — ₹2,500"), Convention in $ (e.g., "AV check — main ballroom", "Confirm keynote honorarium — $3,500"), Wedding in ₹ (e.g., "Confirm florist deposit — ₹15,000", "Send mehndi-night vendor brief"). Do NOT mix currencies inside one scenario — event currency is immutable.
- Do NOT use real PII in seed examples. Use the personas defined in `<user_flows>`.
- Do NOT add a "v2 roadmap" section to GAPS.md — gap entries already have `**Suggested fit:**` fields. The roadmap lives elsewhere.
- Do NOT instruct testers to look for a "NotificationSettings" screen — there isn't one in v1. The Profile → **Notifications** row is a deliberate no-op (`PROF-NOTIF-01`).
- Do NOT instruct testers to enter Zelle / PayPal / Cash handles and expect a deep link — those paths fall through to the manual fallback sheet (`LED-FALL-01`); design settle drills around Venmo or Cash App.

**Cross-link target spots:**
- README: link to `../qa/v1-tester-handoff-guide.md` for install / onboarding / bug template.
- README: link to `../qa/push-notifications-testing-guide.md` for push setup.
- Each scenario prerequisites: link to `../qa/v1-tester-handoff-guide.md#0-pre-flight-setup--onboarding`.

**Optional but encouraged:**
- A short "Tester debrief template" at the end of README — three questions: "What gap surprised you most?", "Which phase felt the longest?", "Would you ship v1 today, yes/no/why?". Two paragraphs is plenty.
</implementation>

<validation>
**The guides are documentation, not code — validation is qualitative, but must be specific.**

**Self-check pass (implementer runs before declaring done):**
1. Open each scenario as a tester would. Walk through the first 5 steps mentally. Do you have a real persona, a real device assignment, and a real expected outcome at each step? If any step is hand-wavy ("then collaborate"), rewrite it.
2. Search each scenario for every label in **bold**. Confirm the label exists in `lib/` (Grep). If not, fix the guide.
3. For each pre-seeded gap candidate in `GAPS.md`, confirm the scenario actually leads the tester to that moment (i.e., a step exists that would naturally reach it). If not, add the step.
4. Confirm the bug-vs-gap definition appears once in `README.md` (canonical) and is referenced (not duplicated) from each scenario.
5. Confirm the abstract-personas rule appears in the README and as a top banner in each scenario.
6. Confirm the known-infra-constraints list appears once in the README and is referenced (not duplicated) from each scenario's Web Parity section.
7. Confirm GAPS.md uses the prescribed entry format (Requirement 18) for every seeded gap.

**Founder review checklist (the founder runs this before handing to testers):**
- Pick the cricket guide and one persona. Read top-to-bottom. Could you give this to a competent tester with no other context and expect a usable result? If not, what is missing?
- Open `GAPS.md`. Do the seeded entries match your mental list of v1 deferrals? Are any obvious gaps missing?
- Open the device matrix. Do you have testers + devices to satisfy the minimum coverage? If not, mark the under-covered scenarios for later.

**Tester-empathy check (final pass):**
- Read the wedding scenario as if you've never used the app. Do you know which account to sign into at every step? Do you know what device to be on? Do you know what to do if something breaks?

**No automated test coverage required** — these are markdown documents read by humans. Skip the standard Flutter test mapping (unit / widget / robot) — none of it applies here.

**Acceptance gate:** founder reviews + accepts. No CI gate.
</validation>

<done_when>
- All five files exist under `docs/guide/` with content matching the structural requirements (Requirements 1–25).
- Pre-flight blocker verification (Requirement 25) has been performed against current `main` and the results are recorded in the README's "Build info" section.
- Every literal UI label cited in the guides has been verified to exist in `lib/` (no stale labels). Live `lib/` strings are authoritative on any drift between the new guides and `v1-tester-handoff-guide.md`.
- `GAPS.md` is seeded with at least 3 example gap entries per scenario, using the prescribed entry format, and the seed list includes the headline gaps: no notification preferences UI, no observer/view-only role, no bulk/link/QR invite, no Zelle/PayPal/Cash deep link, no Firestore web persistence.
- Each scenario contains ≥ 3 gap-candidate callouts in 1-to-1 correspondence with seeded GAPS.md entries (Requirement 24 — structural proxy).
- `README.md` contains the bug-vs-gap discipline (Requirement 9), the abstract-personas rule (Requirement 12), the persona × device matrix (Requirement 11), the known-web/infra-constraints list (Requirement 14), and the per-scenario currency declarations.
- Each scenario file contains: scale block, persona swim-lanes with handles, 3–5 forced-fail drills, gap-candidate callouts at every known-deferral moment, and a Web Parity mini-section linking back to the README list.
- The founder can read any one scenario and brief a tester on it in ≤ 5 minutes.
</done_when>
