## Overview

Single-phase plan: produce `docs/v1-utilities-audit.md` per spec; back-link from `docs/v1-progress-audit.md`. Codebase-researcher pre-gathered evidence — phase becomes a transcription + format pass.

**Spec**: `ai_specs/v1-utilities-audit-spec.md` (commit `ac76e37`)

## Context

- **Structure**: feature-first under `lib/app/features/`; reference docs live in `docs/`.
- **State management**: N/A (doc deliverable; no code change).
- **Reference implementations**:
  - `docs/v1-progress-audit.md` — companion doc; mirror its section style + severity legend.
  - `lib/app/features/dashboard/presentation/widgets/add_member_sheet.dart:107-109` — existing `Share.share()` invite call site (refines the V1 launch-blocker scope).
- **Pre-gathered evidence (codebase-researcher, see `ac76e37` discussion):**
  - All 16 allow-list deps + 2 dev_deps audited. 13 ✅ Used, 1 ⚠️ Underused (`package_info_plus`), 0 ❌ Dead. `yaml` legitimately used (`markdown_render_screen.dart:7` + `scripts/build_legal_html.dart:29`).
  - **`permission_handler` decision rule → NOT NEEDED.** `image_picker.pickImage()` and `firebase_messaging.requestPermission()` both prompt natively; zero custom rationale UI in codebase.
  - **`flutter_local_notifications` decision rule → NOT NEEDED for V1.** Every notification flows through FCM (`fcm_handler.dart`); zero `Timer`/`schedule` device-local triggers.
  - **OCR gap confirmed** — zero refs to `mlkit` / `ocr` / `text_recognizer` in `lib/`.
  - **Invite-share nuance:** `share_plus` IS wired in `add_member_sheet.dart:107-109` (`_shareCode()`). The narrower V1 launch blocker is missing share affordance *from event detail screen* + post-create share prompt — the existing button is buried in the member-management sheet.
- **Assumptions/Gaps:** None unresolved.

## Plan

### Phase 1: Write the V1 utilities audit + cross-links ✅

- **Goal**: Single-source-of-truth utility decisions; companion to `docs/v1-progress-audit.md`.

**Audit doc:**

- [x] `docs/v1-utilities-audit.md` — opens with freshness header `Generated against commit 0f6d357 on 2026-05-09`.
- [x] **Section 1 — Already in pubspec.** 16-row table covering all allow-listed deps + 2 dev_deps with file:line refs. `package_info_plus` flagged ⚠️ Underused; everything else ✅.
- [x] **Section 2 — V1 launch blockers (utility-shaped):** invite-share UX wiring (refined scope: `share_plus` IS wired in `add_member_sheet.dart:107-109`; gap is event-detail surfacing + post-create prompt). Follow-up: `invite-share-spec.md`. Cross-references to V1 audit Pillar 1 (web Firestore persistence) + Pillar 3 (Zelle).
- [x] **Section 3 — V1 should-ship:** on-device OCR via `google_mlkit_text_recognition` (mobile-only, with cross-platform contract spelled out + bundle-size and first-launch caveats). `permission_handler` → NOT NEEDED outcome. `flutter_local_notifications` → NOT NEEDED for V1 outcome.
- [x] **Section 4 — V1.x follow-ups:** QR (`qr_flutter`), deep-link (`app_links`), connectivity (`connectivity_plus`), contacts (`flutter_contacts`), biometrics (`local_auth`). Screenshot package deferred.
- [x] **Section 5 — Explicitly NOT adopting:** Cloud OCR (conditional → >20% mis-parse threshold), screenshot package (firm), state-management swap (firm).
- [x] **Section 6 — Follow-up specs index in V1 priority order:** invite-share → receipt-ocr → qr-invite → deep-link-invite → connectivity-state-ui.

**Cross-platform contract per Section 3 OCR row:**

- [x] Button visibility = shown-with-fallback; fallback path = existing manual amount entry; conditional-branch location = `kIsWeb` check inside the receipt-attachment widget. Pattern reference to `event_repository.dart` and `file_export_service` conditional imports.

**Back-link:**

- [x] `docs/v1-progress-audit.md` — `**Companion audit:**` line added at the top pointing to `docs/v1-utilities-audit.md`.

**Spec freshness:**

- [x] `ai_specs/v1-utilities-audit-spec.md` — Done When references current; no edits needed.

**Verify:**

- [x] Every Section 1 "Used" claim cites at least one file:line.
- [x] Every Section 5 entry tagged **firm** or **conditional → revisit when X**.
- [x] Section 6 sequenced V1 priority order.
- [x] Spot-checked `share_plus` row (`add_member_sheet.dart:107-109`) — `_shareCode()` calls `Share.share('Join my event on CrewPoint! Use code: $_code')`. Confirmed.
- [x] `flutter analyze` clean (only the pre-existing `TableMigration` warning; no code changes).
- [x] `flutter test` skipped — doc-only deliverable; no code changes to validate.

## Risks / Out of scope

**Risks:**

- **Audit goes stale.** Mitigated by the freshness header; reviewer runs `git log pubspec.yaml` to gauge accuracy.
- **`package_info_plus` underused-vs-dead disagreement** — the import is real but the call isn't. Audit calls it ⚠️ Underused; if a reviewer disagrees, refine to ❌ Dead with a deletion follow-up. Acceptable for V1 publication.
- **Cloud-OCR revisit threshold (>20%) is presumptive** — we have no V1 telemetry yet to measure against. Conditional trigger is correct in shape; the exact percentage is a placeholder the receipt-ocr-spec can refine when it defines the OCR metric.

**Out of scope:**

- Implementing any individual utility — each gets its own spec named in Section 6.
- Re-auditing core architecture packages (Riverpod, Drift, GoRouter, Firebase) — `docs/v1-progress-audit.md` is the source of truth there.
- Running `flutter pub add` for any package.
- Removing `package_info_plus` even if confirmed dead — separate cleanup spec.
- Updating CI / GitHub Actions for any of the named packages.
