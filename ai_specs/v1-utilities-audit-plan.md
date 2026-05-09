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

### Phase 1: Write the V1 utilities audit + cross-links

- **Goal**: Single-source-of-truth utility decisions; companion to `docs/v1-progress-audit.md`.

**Audit doc:**

- [ ] `docs/v1-utilities-audit.md` — open with freshness header: `Generated against commit <sha> on 2026-05-09. Re-run the verification steps if pubspec.yaml changes.`
- [ ] **Section 1 — Already in pubspec.** Per-package table for the 16 deps + 2 dev_deps. Columns: name / version / status (✅⚠️❌) / file refs / one-line note. Transcribe from researcher table. Flag `package_info_plus` as ⚠️ Underused (imported in `profile_screen.dart` but no `.version` / `.appName` call).
- [ ] **Section 2 — V1 launch blockers (utility-shaped).**
  - **Invite share (pre-decided, refined scope):** `share_plus` is wired in `add_member_sheet.dart:107-109` but the share affordance is buried in member management. Missing: (a) Share button surfaced from event detail screen, (b) post-create share prompt after `CreateEventScreen.submit` succeeds. Follow-up: `invite-share-spec.md`.
  - Cross-link to `docs/v1-progress-audit.md` for web Firestore persistence + Zelle UX.
- [ ] **Section 3 — V1 should-ship.**
  - **On-device OCR (pre-decided):** `google_mlkit_text_recognition`, mobile-only. Cross-platform contract: button **shown-with-fallback** on web (existing manual amount-entry path). Caveats — flag both: (a) ~5–10MB iOS bundle delta, (b) first-call model-download UX on Android (Play Services). Follow-up: `receipt-ocr-spec.md`.
  - **`permission_handler` outcome:** **NOT NEEDED for V1** per decision rule. `image_picker` + `firebase_messaging` prompt natively; no custom rationale UI exists or is justified.
  - **`flutter_local_notifications` outcome:** **NOT NEEDED for V1** per decision rule. Every notification journey flows through FCM (server-triggered). Defer to V1.x if a device-local reminder becomes a user story.
- [ ] **Section 4 — V1.x follow-ups.** QR-code generation for invites (`qr_flutter`), deep-links/universal-links (`app_links` or Firebase Hosting redirect-to-app), connectivity-state UI (`connectivity_plus`), contact picker (`flutter_contacts`), biometrics (`local_auth`). Screenshot capture/share package: deferred — existing PDF export covers settlement-summary use case.
- [ ] **Section 5 — Explicitly NOT adopting.** Mark each entry firm vs conditional:
  - Cloud OCR — **conditional → revisit when** on-device ML Kit accuracy on V1 telemetry shows >20% of receipts mis-parsed (specific threshold; the receipt-ocr-spec defines the metric).
  - Screenshot capture/share package — **firm** (PDF export already covers the settlement-summary case).
  - State-management swap (Bloc, etc.) — **firm** (Riverpod 3 in place; no migration justified).
- [ ] **Section 6 — Follow-up specs index, V1 priority order:**
  1. `invite-share-spec.md` — V1 launch blocker.
  2. `receipt-ocr-spec.md` — V1 should-ship.
  3. `qr-invite-spec.md` — V1.x.
  4. `deep-link-invite-spec.md` — V1.x.
  5. `connectivity-state-ui-spec.md` — V1.x.

**Cross-platform contract per Section 3 OCR row:**

- [ ] Spell out in the audit row: button visibility = shown-with-fallback; fallback path = existing manual amount entry; conditional-branch location = `kIsWeb` check inside the receipt-attachment widget (mirrors `event_repository.dart` web/mobile branch).

**Back-link:**

- [ ] `docs/v1-progress-audit.md` — append `**Companion audit:**` line near the top pointing to `docs/v1-utilities-audit.md`. Future readers landing on either doc find both.

**Spec freshness:**

- [ ] `ai_specs/v1-utilities-audit-spec.md` — confirm the doc references in Done When are current; no other edits needed.

**Verify:**

- [ ] Every Section 1 "Used" claim cites at least one file:line; reviewer can open the path and confirm.
- [ ] Every Section 5 entry tagged **firm** or **conditional → revisit when X**.
- [ ] Section 6 sequenced V1 priority order (launch blockers first).
- [ ] Spot-check one random Section 1 row by `grep`-ing for the cited file:line.
- [ ] `flutter analyze` clean (only the pre-existing `TableMigration` warning) — no code changes expected.
- [ ] `flutter test` not required (doc-only deliverable); skip if no code changes.

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
