# V1 Scenario Testing Guides — Implementation Plan

## Overview

Author five markdown files under `docs/guide/` (README, three scenarios, GAPS). Documentation-only deliverable — no Dart code, no `flutter test` gate. Phase 1 ships one end-to-end vertical slice (cricket) so the founder can lock the format before the rest scale out.

**Spec**: `ai_specs/v1-scenario-testing-guides-spec.md` (read for full requirements; non-negotiable rules live there).

## Context

- **Structure**: Output under `docs/guide/` — new subtree, sibling to existing `docs/qa/`.
- **State management**: N/A (markdown).
- **Reference assets** (link, do not duplicate):
  - `docs/qa/v1-tester-handoff-guide.md` — voice, label discipline, §14 bug template, §4 role-permission matrix.
  - `docs/v1-progress-audit.md` — V1 launch blockers + Event Lifecycle matrix (source of truth for pre-flight verification).
  - `docs/qa/push-notifications-testing-guide.md` — push setup link target.
- **Authority on label drift**: live `lib/` strings win. Handoff guide is secondary. Do not edit handoff guide.
- **Assumptions / Gaps**:
  - V1 launch blockers (CreateTaskScreen / Edit Event / Archive Event / JoinEventSheet) may or may not be resolved on current `main` — Phase 1 verifies and records results; unresolved blockers become gap-candidate callouts inside scenarios, not silent failures.
  - Phase 6.2 web push and notification preferences UI status accepted as-is per spec.

## Plan

### Phase 1: Pre-flight + foundation files + cricket scenario (vertical slice)

- **Goal**: End-to-end proof: pre-flight done, GAPS taxonomy seeded, README locked, cricket fully drafted. Founder spot-checks shape before convention/wedding scale out.
- [ ] **Pre-flight verification** (Requirement 25) — for each blocker, record one-line status in a scratch note:
  - `lib/app/features/tasks/presentation/create_task_screen.dart:73` — `onSubmit?.call` wired in production? (Smoke-test or check `test/app/features/tasks/`.)
  - `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — settings IconButton `onPressed` empty?
  - `_EventActions` archive toggle — does flipping it persist to Firestore?
  - `lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart` — `onSubmit` wired in prod widget tree?
- [ ] **Live label sweep** — confirm literal strings the scenarios will cite:
  - Bottom-nav events-tab label (`Home` vs `Dashboard`).
  - Filter chips: `Mine`, `Overdue`, `Has budget` (lowercase b per `TASK-FILT-01`), `To Do`, `In Progress`, `Done`.
  - Settle Up button labels, dialog titles (Remove Member / Delete Event), invite-sheet labels.
  - Record any handoff-guide drift in passing; do NOT edit `v1-tester-handoff-guide.md`.
- [ ] `docs/guide/GAPS.md` — seed all 10 categories (Requirement 17). Pre-populate ≥3 example entries per scenario covering the headline gaps: notification-preferences UI missing, no Observer role, no bulk/link/QR invite, no Zelle deep link, no Firestore web persistence, no calendar/bracket view, no RSVP, transfer-ownership UI absent. Each entry uses the prescribed `GAP-<SCN>-NN` format with Surfaced-in / Severity / Suggested-fit / Workaround sub-fields.
- [ ] `docs/guide/README.md` — index + audience, persona × device matrix, bug-vs-gap section (Requirement 9 wording), abstract-personas rule banner, "Known web/infra constraints — NOT bugs" canonical list (6 bullets — Requirement 14), seed-account placeholder slots, pre-flight blocker-verification results in **Build info**, cross-links to `../qa/v1-tester-handoff-guide.md` + push guides, optional tester-debrief 3-question template.
- [ ] `docs/guide/01-cricket-tournament.md` — complete arc (Planning / Ramp-up / Event day / Wrap-up):
  - Scale block: currency = ₹, personas `TD` / `CapA` / `PlayerA1` / `SponsorS`, abstract counts, devices, est. duration.
  - Abstract-personas banner; "If you get stuck" stub (Requirement 20).
  - Persona swim-lane callouts (`**[CapA — iPhone]**`) on every step.
  - Ramp-up: 8+ realistic ₹-denominated task creations (e.g., "Book Wankhede practice nets — 2026-10-12 7am — ₹0", "Print scorecards — ₹2,500").
  - Cross-device real-time check (Requirement 21).
  - Gap-candidate callouts at: bracket/fixture view (`GAP-CRK-XX`), recurring practice (`GAP-CRK-XX`), Observer role for Sponsor (`GAP-CRK-XX`).
  - **§Forced-fail drills**: 3–5 explicit drills (admin-only action as member, network drop mid-submit, kick-while-open on device B, cold-start push reuse `PUSH-COLD-01`, attempt observer-role enforcement).
  - **§Web parity** mini-section linking back to README list + one-line iOS long-press gesture primer.
  - Wrap-up: settle-via-Venmo or Cash App sandbox-amount drill; archive-event step gated by pre-flight result.
- [ ] Self-check pass per spec §<validation>: ≥3 gap-candidate callouts each 1-to-1 with a seeded GAPS entry; every bold label verified against `lib/` via Grep.
- [ ] **Verify**: founder reads cricket cold; can brief a tester in ≤5 minutes. GAPS.md format and bug-vs-gap discipline lock in before phase 2 fans out.

### Phase 2: Convention + Wedding scenarios

- **Goal**: Apply locked format to remaining two scenarios; surface their distinct gaps (bulk-invite, RSVP, couple-coordination, custom split).
- [ ] `docs/guide/02-hotel-convention.md` — full arc:
  - Currency = $; personas `CL` / `SC` / `Spkr` / `SponLi`.
  - Planning: `CL` attempts to seat 25+ attendees with one 6-char code — reach the moment, log `GAP-CON-01 No bulk/link/QR invite`, copy-code-and-move-on.
  - Ramp-up: long event descriptions + many checklist items per task (Requirement 22).
  - Cross-device real-time check; cold-start push.
  - Gap-candidate callouts at: bulk invite, sponsor view-only role, calendar/agenda grid view, branded PDF report.
  - **§Forced-fail drills** (3–5).
  - **§Web parity** mini-section.
  - Wrap-up: PDF/CSV export + sandbox settle.
- [ ] `docs/guide/03-wedding-event.md` — full arc:
  - Currency = ₹; personas `Couple` / `WP` / `FL` / `Vend` (Anita — Catering).
  - Couple shared-account coverage-loss banner up top.
  - Planning: guest list challenge → log RSVP gap (`GAP-WED-XX No RSVP collection`), single-code invite reuse.
  - Budget arc: ≥1 non-equal custom split (Requirement 22); receipt upload; settle via Venmo sandbox.
  - Gap-candidate callouts at: RSVP, transfer-ownership UI, multi-owner/co-owner role, Zelle deep link (fall-through to `LED-FALL-01` — confirm not a bug), categories/labels for vendor expenses.
  - **§Forced-fail drills** (3–5).
  - **§Web parity** mini-section.
  - Cross-link primitive flows to cricket (e.g., "complete onboarding as in §01 Planning").
- [ ] Update `docs/guide/GAPS.md` — promote any new gaps surfaced during drafting into seeded entries; renumber if needed.
- [ ] **Verify**: each new scenario passes the same self-check as cricket (≥3 callouts, 1-to-1 GAPS mapping, all bold labels verified via Grep, abstract-personas banner present, Web Parity links to README).

### Phase 3: Final QA + handoff

- **Goal**: Confirm structural integrity across the five-file set; the founder receives a brief-ready bundle.
- [ ] **Bold-label sweep across all five files** — Grep every `**…**` literal against `lib/`; fix any drift. Live `lib/` wins.
- [ ] **Cross-reference audit** — every `GAPS.md` entry has at least one matching callout in the scenarios; every callout points to a real entry. No orphans either direction.
- [ ] **Constraint-list deduplication** — confirm "Known web/infra constraints — NOT bugs" appears once (README) and is referenced (not duplicated) by each Web Parity section.
- [ ] **Bug-vs-gap discipline check** — canonical block appears in README only; each scenario references it.
- [ ] **Abstract-personas rule check** — present in README + banner-top of each scenario.
- [ ] **Word ceiling check** — no scenario exceeds ~3000 words; split into sub-phases if so (Boundaries §Limits).
- [ ] **Founder review** — founder runs the §<validation> Founder review checklist (read cricket cold, GAPS seed sanity check, device matrix coverage check).
- [ ] **Verify**: founder accepts. No CI gate.

## Risks / Out of scope

- **Risks**:
  - Unresolved V1 launch blockers (CreateTaskScreen / Edit Event / Archive Event) may force more scenario steps into gap-candidate callouts than expected, thinning the happy path. Mitigation: pre-flight is Phase 1 task 1.
  - Label drift between `v1-tester-handoff-guide.md` and live `lib/` may multiply Grep work. Mitigation: live `lib/` wins by rule; handoff guide drift noted but not fixed.
- **Out of scope**:
  - Editing `docs/qa/v1-tester-handoff-guide.md` (cross-link only — do not duplicate or repair).
  - Fixing any v1 launch blocker uncovered during pre-flight (escalate to founder; do not patch code as part of this work).
  - Automated tests, Flutter analyze gates, CI — these are markdown docs read by humans.
  - v2 roadmap section in GAPS.md (entry-level `Suggested fit` field carries the roadmap signal).
