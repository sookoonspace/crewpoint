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

### Phase 1: Pre-flight + foundation files + cricket scenario (vertical slice) ✅

- **Goal**: End-to-end proof: pre-flight done, GAPS taxonomy seeded, README locked, cricket fully drafted. Founder spot-checks shape before convention/wedding scale out.
- [x] **Pre-flight verification** (Requirement 25) — all four audit blockers (CreateTaskScreen / Edit Event / Archive Event / JoinEventSheet) are RESOLVED on current `main`. Results recorded in `docs/guide/README.md` §"Pre-flight V1-launch-blocker verification". Audit rows 4 and 10 are stale.
- [x] **Live label sweep** — confirmed via Grep on `lib/`: bottom-nav events-tab label is `Home`; filter chips are `Mine` / `Overdue` / `Has budget` (lowercase b) / `To Do` / `In Progress` / `Done`; settle labels `Pay with Venmo` / `Pay with Cash App` / `Settle Up`; invite-sheet labels `Generating code...` / `Code copied to clipboard` / `Generate New Code`; expense-modal toggle is `Donate this cost` (NOT "Donation"); urgent-chat modal is `Send Critical Alert` with `Critical Alert` bubble badge. Two drifts corrected in cricket guide post-write.
- [x] `docs/guide/GAPS.md` — seeded all 10 categories with 39 example entries spanning the three scenarios' headline gaps (notification-preferences UI, Observer role, bulk/link/QR invite, Zelle deep link, Firestore web persistence, bracket view, RSVP, transfer-ownership, no-offline-writes, etc.). Each entry uses the prescribed format with Surfaced-in / Severity / Suggested-fit / Workaround sub-fields.
- [x] `docs/guide/README.md` — index, persona × device matrix, bug-vs-gap section, abstract-personas rule, 6-bullet "Known web/infra constraints — NOT bugs" list, build-info table with pre-flight verification results (all four blockers ✅ resolved on 2026-06-12), cross-links to `../qa/v1-tester-handoff-guide.md` + push guides, debrief 3-question template.
- [x] `docs/guide/01-cricket-tournament.md` — complete arc with scale block (INR ₹), abstract-personas banner, "If you get stuck" stub, persona swim-lane callouts on every step, Planning §P (5 steps), Ramp-up §R (5 steps, 11 total task creations), Event day §E (4 steps including urgent-chat + cold-start push), Wrap-up §W (5 steps including settle + PDF + archive), §Forced-fail drills (5 drills with bug-vs-gap classification), §Web parity table.
- [x] Self-check pass: cricket scenario references 12+ gap-candidate callouts mapped 1-to-1 to seeded `GAPS.md` entries (well exceeds the ≥3 requirement). Every bold label verified against `lib/`; two corrections applied (`Donation` → `Donate this cost`; `Critical alert` → `Send Critical Alert`).
- [x] **Verify**: founder reads cricket cold; can brief a tester in ≤5 minutes. GAPS.md format and bug-vs-gap discipline locked in before phase 2 fans out.

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
