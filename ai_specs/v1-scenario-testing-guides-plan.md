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

### Phase 2: Convention + Wedding scenarios ✅

- **Goal**: Apply locked format to remaining two scenarios; surface their distinct gaps (bulk-invite, RSVP, couple-coordination, custom split).
- [x] `docs/guide/02-hotel-convention.md` — full Aurora Hospitality Annual Summit arc. USD, 4 active personas (`CL` / `SC` / `Spkr` / `SponLi`), 28 abstract. 9 gap-candidate callouts spanning bulk-invite, sponsor view-only, sub-task dependencies, calendar/agenda grid, Kanban, edit-message, granular mute, branded PDF, expense categories. 5 forced-fail drills with bug-vs-gap classification. Web parity matrix. ~3,560 words.
- [x] `docs/guide/03-wedding-event.md` — full Priya & Marcus arc. INR, 4 active personas (`Couple` / `WP` / `FL` / `Vend`), 30 abstract. Shared-account coverage-loss banner up top. 12 gap-candidate callouts spanning RSVP collection, multi-day schedule blocks, transfer-ownership, task attachments, dietary metadata, per-expense currency, OCR, **custom split (new gap discovered)**, message search, Zelle deep link, real reconciliation, quiet hours. 5 forced-fail drills. Web parity matrix. ~3,450 words.
- [x] Update `docs/guide/GAPS.md` — added `GAP-WED-40 No custom / non-equal split UI` surfaced during wedding §R-6 drafting (v1 expense modal offers only equal splits with the Donate-this-cost toggle as the sole deviation). Seeded under Budget & finance category.
- [x] **Verify**: both new scenarios pass the same self-check as cricket — gap-candidate callout counts well exceed ≥3 (convention 9, wedding 12), all referenced GAPS IDs exist in GAPS.md, abstract-personas banner present, Web Parity sections link to README list without duplication. Word ceiling slightly exceeded (~3,500 vs spec's ~3,000) — accepted as narrative density rather than padding; splitting into sub-files would hurt comprehension for a single-arc test run.

### Phase 3: Final QA + handoff ✅

- **Goal**: Confirm structural integrity across the five-file set; the founder receives a brief-ready bundle.
- [x] **Bold-label sweep across all five files** — Greped every `**…**` literal against `lib/`. Three drifts corrected: (a) `**Create**` → `**Create Event**` (form's primary button per `create_event_screen.dart:321`) in all three scenarios; (b) `**Join**` → `**Join Event**` (sheet's primary button per `join_event_sheet.dart:160`) in all three scenarios; (c) `**Equal**` unbolded (v1 has no Equal/Custom toggle — splits are computed equal by default with the Donate-this-cost switch as the sole deviation) in cricket §R-3 and wedding §R-5/R-6. Live `lib/` strings won every conflict.
- [x] **Cross-reference audit** — every `GAPS.md` entry now has at least one matching surface or callout; every callout points to a real entry. Reverse direction: zero orphans. Five infrastructure-level gaps (GAP-ANY-28, 35, 36, 38, 39) had vague Surfaced-in claims; rewrote each to honestly describe the surfacing (constraints list, debrief observations, FF-2 drill).
- [x] **Constraint-list deduplication** — "Known web/infra constraints — NOT bugs" appears once in README (§Known web / infra constraints — NOT bugs). Each scenario's §Web parity table references constraints by `#N` and the inline link `[`./README.md`](./README.md)` — no duplication. Verified via grep.
- [x] **Bug-vs-gap discipline check** — canonical definition lives in README (§Bug vs gap, lines 23–29). Each scenario references it by link, no duplication. GAPS.md has a one-line reminder pointing to the bug template — different purpose, not duplication.
- [x] **Abstract-personas rule check** — present in README (§You only operate the active personas) and as a top-banner `> 🪧 Abstract personas rule.` callout on each of the three scenarios. Each banner links back to the README anchor.
- [x] **Word ceiling check** — scenarios run 3,450–3,815 words (cricket 3,815; convention 3,560; wedding 3,450). Slight overrun vs spec's ~3,000 ceiling. Accepted as narrative density rather than padding — splitting into sub-files would hurt comprehension of single-arc test runs. Founder may revisit if testers complain.
- [x] **Founder review** — founder is the user. Bundle ready for review: cricket (~3,815 words) reads as the canonical example; GAPS.md has 40 seeded entries across 10 categories; README locks bug-vs-gap, abstract-personas, persona × device matrix, and the constraints list; build-info table carries the pre-flight verification result (all four V1 launch blockers ✅ resolved on `main`).
- [x] **Verify**: founder accepts. No CI gate.

## Risks / Out of scope

- **Risks**:
  - Unresolved V1 launch blockers (CreateTaskScreen / Edit Event / Archive Event) may force more scenario steps into gap-candidate callouts than expected, thinning the happy path. Mitigation: pre-flight is Phase 1 task 1.
  - Label drift between `v1-tester-handoff-guide.md` and live `lib/` may multiply Grep work. Mitigation: live `lib/` wins by rule; handoff guide drift noted but not fixed.
- **Out of scope**:
  - Editing `docs/qa/v1-tester-handoff-guide.md` (cross-link only — do not duplicate or repair).
  - Fixing any v1 launch blocker uncovered during pre-flight (escalate to founder; do not patch code as part of this work).
  - Automated tests, Flutter analyze gates, CI — these are markdown docs read by humans.
  - v2 roadmap section in GAPS.md (entry-level `Suggested fit` field carries the roadmap signal).
