<goal>
Produce a **utility-package audit** for CrewPoint V1: inventory every Flutter package and platform capability the app already uses, identify the utility-shaped gaps for concrete in-flight V1 user journeys, prioritize each gap as *launch-blocker / should-ship / V1.x*, and name the follow-up spec for every prioritized add.

Why it matters: the team keeps tripping over "we need a package for X" mid-PR (e.g., the invite-share question, OCR for receipts, screenshot sharing) which fragments planning. A single source of truth — alongside the existing [`docs/v1-progress-audit.md`](../docs/v1-progress-audit.md) — lets the team sequence package adoption deliberately rather than reactively.

Who benefits: anyone scoping the next feature spec; reviewers checking whether a proposed package is justified; anyone later asking "why do we depend on X?".
</goal>

<background>
**Tech stack:** Flutter 3.11.5 / Dart 3.x, Firebase (Auth/Firestore/Storage/Functions/Messaging), Drift 2.25, Riverpod 3, GoRouter 14.

**Files to examine:**
- `@pubspec.yaml` — current dependency set, including dev_dependencies and locked versions.
- `@docs/v1-progress-audit.md` — already names two utility-shaped launch blockers (web Firestore persistence, Zelle UX) plus the Event Lifecycle Deep Dive section. The new audit cross-references but does NOT duplicate.
- `@lib/app/core/services/firebase_image_service.dart` — existing image-picker + Storage wiring (touchpoint for receipt OCR).
- `@lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart` — current invite-join flow (input only; no outbound share yet).
- `@lib/app/features/budget/data/pay_link_builder.dart` — already builds Venmo + CashApp deep links via `Uri()`; pattern to mirror for any invite-link work.
- `@lib/app/core/services/file_export_service.dart` — platform-aware export seam (PDF/CSV); pattern to follow for any new platform-aware seams.

**Constraints from existing decisions:**
- **OCR is on-device** for V1 via Google ML Kit (`google_mlkit_text_recognition`). No per-call cost, no Cloud Function. Cloud OCR is V1.x if accuracy is insufficient.
- **Invite-share format is plain text** for V1 via the already-present `share_plus`. Deep links + QR are V1.x adds.
- **No screenshot-sharing utility** in V1. The settlement-summary use case is covered by the already-shipped PDF export pipeline (`expense_pdf_builder`); receipt-from-gallery is covered by `image_picker`. Revisit only if user testing reveals a real need.
- **No new architectural patterns.** Every utility add follows existing seams (Riverpod provider, platform-aware abstract interface where mobile/web differ, dependency injection in tests).

**Out of scope for the audit doc itself:**
- Implementation of any individual utility — each gets its own spec named here.
- Re-auditing the V1 progress pillars — `docs/v1-progress-audit.md` stays the source of truth for those.
</background>

<user_flows>
This audit isn't a user-facing feature, but it must reflect concrete user journeys the utilities enable. Each row in the audit's gap matrix MUST cite a real user flow, not a hypothetical.

**Concrete user journeys the audit MUST address:**

1. **Invite a member to an event** — admin opens an existing event → taps "Invite" → app generates a join code (already shipped via `generateInviteCode` CF) → user shares via system share sheet → recipient sees plain text "Join my Tahoe Trip on CrewPoint — code: ABC123" → recipient opens app → enters code in the existing `JoinEventSheet`. *Currently broken: no share button exists; user must read the code aloud or copy-paste manually.*

2. **Add a receipt to an expense via OCR** — user taps "Add Expense" → fills amount → taps "Scan Receipt" → camera opens → user snaps the receipt → on-device OCR extracts the total amount + merchant string → fields are pre-filled → user confirms or edits → save. *Currently missing: only manual amount entry exists.*

3. **Notification permission on first push** — first time the user receives an FCM message, OS prompts for permission. iOS requires explicit consent before the first push lands. *Currently the prompt happens implicitly via firebase_messaging on iOS; the audit must verify whether `permission_handler` is needed for a custom prompt UX or if Firebase's default is sufficient.*

4. **Camera permission on first photo** — when user taps "Add Photo" the OS prompt fires. Same question: do we need a custom permission UX wrapping the OS prompt, or is `image_picker`'s default behavior good enough?

**Permutations the audit checks for each utility:**
- iOS + Android + web behavior (utilities like ML Kit are mobile-only; the audit must call out the web fallback).
- Online vs offline (e.g., on-device OCR works offline; cloud OCR doesn't).
- First-time vs returning user (permissions matter on first run only).
</user_flows>

<requirements>
**Functional — Audit document (the deliverable):**

1. Output: `docs/v1-utilities-audit.md`. Linked from this spec. Doc opens with a one-line **freshness header**: `Generated against commit <short-sha> on <YYYY-MM-DD>. Re-run the verification steps in <implementation> if pubspec.yaml has changed since.` Future readers can `git log` to gauge staleness.
2. Section 1 — *Already in pubspec.* The audit covers **only the explicit allow-list below**. Anything else (firebase_*, drift, flutter_riverpod, riverpod_annotation, go_router, cloud_firestore, cloud_functions, firebase_*, web, cupertino_icons) is core architecture or framework infrastructure — covered by `docs/v1-progress-audit.md`, NOT this audit.

   **Allow-list (audit each entry):**
   - dependencies: `share_plus`, `url_launcher`, `image_picker`, `intl`, `package_info_plus`, `path_provider`, `path`, `uuid`, `flutter_secure_storage`, `pdf`, `printing`, `csv`, `lottie`, `flutter_markdown_plus`, `clock`, `yaml`.
   - dev_dependencies: `image`, `markdown` (script-only justification — verify still holds).

   For each: name + version + concrete file references showing where it's used + assessment (✅ Used / ⚠️ Underused / ❌ Dead).
3. Section 2 — *V1 launch blockers (utility-shaped).* Concrete user journey + missing capability + recommended package + follow-up spec name.
   - **Invite share (pre-decided)** — `share_plus` is already present; what's missing is the wiring + a share button in the event detail screen and a copy/share affordance in the post-create flow. Follow-up: `invite-share-spec.md`. *V1 launch blocker.*
   - Cross-link the V1 audit's blockers that are also utility-shaped (web Firestore persistence; Zelle UX) so a reader hitting either audit gets the full picture without duplication.

   *Pre-decided rows are inputs from this spec — the audit documents the decision and the user journey, NOT the implementation choice.*
4. Section 3 — *V1 should-ship (utility adds with a strong V1 case).*
   - **On-device OCR for receipts (pre-decided)** — `google_mlkit_text_recognition` (mobile-only). Follow-up: `receipt-ocr-spec.md`. Audit MUST flag two known costs the follow-up spec is responsible for designing UX around: (a) iOS bundle size delta (~5–10MB for the bundled text-recognition model), (b) first-call model-download UX on Android (model fetched via Play Services on first invocation; needs loading copy + offline fallback).
   - **Permission UX — explicit decision rule (no open question).** **Add `permission_handler`** IF either: (a) we want a custom pre-prompt rationale screen *before* the OS prompt (rare for V1 since `image_picker` and `firebase_messaging` both prompt natively at the right time), OR (b) we need to detect the previously-denied state to show "go to Settings" copy in a custom UI. Otherwise document the existing `image_picker` / `firebase_messaging` defaults as sufficient and mark **"not needed."** Follow-up only if (a) or (b) holds: `permission-handler-spec.md`.
   - **Local notifications — explicit decision rule.** **Add `flutter_local_notifications`** IF V1 has a concrete user journey that fires a notification *without* a server-side trigger (e.g., a local reminder for an upcoming event start time, a pending-settlement nudge fired from the device's own clock). If every notification we ship today flows through FCM (server-triggered), defer to V1.x and mark "not needed for V1." Follow-up only if a journey qualifies: `local-notifications-spec.md`.
5. Section 4 — *V1.x follow-ups.* Cover at minimum: QR-code generation for invites (`qr_flutter`), deep links / universal links for invite URLs (`app_links` or Firebase Hosting redirect-to-app pattern), connectivity-state UI (`connectivity_plus`), contact picker (`flutter_contacts`), biometrics (`local_auth`), screenshot capture/share (defer; existing PDF export covers the settlement-summary case).
6. Section 5 — *Explicitly NOT adopting (and why).* For each entry, mark **firm** (no expected revisit) or **conditional → revisit when X** (specific trigger). Required entries:
   - Cloud OCR — **conditional → revisit when** on-device ML Kit accuracy data shows >X% of receipts mis-parsed in V1 telemetry.
   - Screenshot capture/share package — **firm** (PDF export already covers the settlement-summary case).
   - State-management swap (e.g., Bloc) — **firm** (Riverpod 3 is in place; no migration justified).
7. Section 6 — *Follow-up specs index.* Numbered list of every spec named in sections 2–4, **in V1 priority order** (launch blockers first, then should-ship, then V1.x). One-line summary each.

**Functional — Verification:**

8. Every "Used" claim in section 1 cites at least one file path where the package is imported and called.
9. Every "Underused" or "Dead" claim cites a search proof (Grep result) showing the lack of meaningful usage.
10. Every gap in sections 2–4 cites the user journey from `<user_flows>` it addresses.
11. Every follow-up spec name uses the `kebab-case-spec.md` convention and lives under `ai_specs/` per project conventions.

**Error Handling (audit-doc-level):**

12. If a `pubspec.yaml` package can't be located by Grep across `lib/` AND `test/`, mark it ❌ Dead and recommend deletion. Don't silently omit.
13. If a recommended package conflicts with an existing dependency (e.g., a competing state-management lib), flag the conflict and explain why we're keeping the existing choice.

**Edge Cases:**

14. Web-only or mobile-only behavior of a recommended package MUST be documented (e.g., ML Kit is mobile-only; web gets a manual-entry fallback).
15. Packages that ship sufficient V1 capability via the framework / Firebase SDK (e.g., notifications via `firebase_messaging`) should NOT be flagged as gaps just because their dedicated package isn't installed. Document the existing path instead.
</requirements>

<boundaries>
**Edge cases:**

- Audit lists a follow-up spec that turns out to be redundant once written → that follow-up spec ends up scope-cutting; the audit doesn't pre-commit to specific implementations.
- A package landing in section 1 (already in pubspec) that's marked ❌ Dead → recommend deletion; no separate follow-up spec needed.

**Error scenarios:**

- Grep / file inspection misses a package's true call site (e.g., used only via a generated `.g.dart` that's gitignored) → audit MUST note the limitation in section 1's intro and instruct the reader to verify before deleting any flagged-dead package.

**Limits:**

- Audit is for *utilities*, not core architecture. Don't re-audit Riverpod, Drift, GoRouter, Firebase — `docs/v1-progress-audit.md` covers those.
- Audit doesn't make implementation decisions for the follow-up specs beyond naming the package and the user journey. The follow-up specs do the design work.
- Audit does not include CI/CD tooling (gh actions, release-drafter etc.) — those live in `docs/dev-first-rollout-checklist.md` and elsewhere.

**Cross-platform contract (mandatory for any platform-conditional package):**

For any package the audit recommends that doesn't ship on every active platform (iOS / Android / web), the row MUST specify:

- **Button visibility** — hidden / disabled-with-tooltip / shown-with-fallback.
- **Fallback path** — what the user sees when the package isn't available (e.g., "OCR disabled on web → user enters amount manually via the existing form field").
- **Conditional-branch location** — typically a `kIsWeb` (or `Platform.isIOS` / similar) branch in the feature's screen, mirroring the conditional-import pattern at `lib/app/core/database/connection/native.dart` ⇄ `web.dart` and `lib/app/core/services/file_export_service_native.dart` ⇄ `_web.dart`.

Example for ML Kit OCR: button visibility = shown-with-fallback; fallback path = manual amount entry (already present); branch location = `kIsWeb` check inside the receipt-attachment widget that hides the "Scan Receipt" button on web.
</boundaries>

<implementation>
**Output structure of `docs/v1-utilities-audit.md`:**

```
# V1 Utilities Audit

> Companion to `docs/v1-progress-audit.md`. Inventories utility-shaped
> packages (vs. core architecture) and names follow-up specs by priority.

Severity legend: must-ship (V1 launch blocker) / should-ship (V1 if cheap) /
nice-to-have (V1.x).

## 1. Already in pubspec
Table or section per package: Name / Version / Status (✅⚠️❌) /
Where used / Notes.

## 2. V1 launch blockers (utility-shaped)
Per gap: User journey it addresses / What's missing / Recommended
package / Follow-up spec name.

Cross-references:
- Web Firestore offline persistence — see `docs/v1-progress-audit.md`
  Pillar 1.
- Zelle UX — see `docs/v1-progress-audit.md` Pillar 3.

## 3. V1 should-ship
Same shape.

## 4. V1.x follow-ups
Same shape.

## 5. Explicitly NOT adopting
One-line justification each.

## 6. Follow-up specs index
Numbered, in V1 priority order: launch blockers first, then should-ship, then V1.x.
```

**Investigation approach (audit author follows this):**

1. Read `pubspec.yaml`. List every dependency + dev_dependency.
2. For each, run `grep -rln "package:NAME"` across `lib/` and `test/` to locate import sites. Note which features use it.
3. For utilities not yet in pubspec but mentioned in the user journeys (`<user_flows>`), check pub.dev for current maintenance status + license + null-safety. Flag dead/abandoned packages.
4. For OS-permission utilities, verify the existing default behavior of `image_picker` / `firebase_messaging` BEFORE recommending `permission_handler`. The decision rule: only add if the existing default is demonstrably insufficient for the user journey.
5. For each gap, write the follow-up spec name into section 6 in priority order.

**What to avoid:**

- Do NOT execute `flutter pub add` for any package during this audit. The deliverable is the document; package adds happen in their dedicated follow-up specs.
- Do NOT recommend a package without naming the user journey it serves.
- Do NOT flag a package as dead based on a single grep miss — verify by checking generated files, transitive use, and dev-only scripts (e.g., `scripts/build_legal_html.dart` uses `markdown`).
- Do NOT name follow-up specs that duplicate gaps already tracked in `docs/v1-progress-audit.md`. Cross-link instead.
- Do NOT include implementation specifics for any follow-up. The audit names the package + journey; the follow-up spec designs the integration.
</implementation>

<validation>
**Baseline coverage outcomes:**

This is a documentation deliverable; there are no automated tests for the audit content itself. Validation is structural + manual.

*Structural validation (must hold for every revision of the audit doc):*

1. Every package named in section 1 appears in `pubspec.yaml`.
2. Every "Used" cell cites at least one file path.
3. Every "Dead" cell includes a Grep proof or one-line absence justification.
4. Every gap in sections 2–4 cites a user journey number from this spec's `<user_flows>` (or names a new journey explicitly).
5. Every follow-up spec name in section 6 is unique, kebab-cased, and ends in `-spec.md`.
6. Cross-references to `docs/v1-progress-audit.md` use a relative link.

*Manual review checkpoint:*

7. A reviewer who has never read this codebase can answer "what does CrewPoint currently use for X?" by reading section 1 alone.
8. A reviewer can answer "what's the next utility we should add and why?" by reading sections 2 + 6.
9. Every "we considered and rejected this" item in section 5 has a one-line reason that holds up to a "why not?" challenge.

**No TDD / robot tests apply** — the deliverable is a markdown document, not code. If any follow-up spec implements code, that spec carries its own TDD + robot-test requirements per project conventions.

**Manual smoke (post-audit):**

- Open the doc; spot-check three random "Used" claims by `grep`-ing for the cited file references.
- Pick one section-2 gap; the team agrees the named follow-up spec is the next thing to schedule.
- Run a 5-minute "would I, knowing nothing, get the gist?" read-through with someone unfamiliar with the codebase.
</validation>

<done_when>
- `docs/v1-utilities-audit.md` exists and is linked from this spec.
- The audit opens with the freshness header (`Generated against commit <sha> on <date>`).
- All six sections (Already in pubspec / V1 launch blockers / V1 should-ship / V1.x follow-ups / Explicitly NOT adopting / Follow-up specs index) are populated.
- Section 1 audits exactly the allow-listed packages — no more, no less. Anything found in pubspec.yaml that's NOT in the allow-list is acknowledged in a one-line "out of scope, see v1-progress-audit" note.
- Sections 2–4 collectively name AT LEAST these follow-up specs:
  - `invite-share-spec.md` — V1 launch blocker, plain-text share via `share_plus` (already in pubspec).
  - `receipt-ocr-spec.md` — V1 should-ship, on-device `google_mlkit_text_recognition`, mobile-only, with the bundle-size + first-launch model-download caveats noted.
  - Outcome for `permission_handler` (either a follow-up spec OR a "not needed, existing defaults suffice" entry per the explicit decision rule).
  - Outcome for `flutter_local_notifications` (either a follow-up spec OR a "not needed for V1" entry per the explicit decision rule).
- Section 5 marks each entry **firm** or **conditional → revisit when X**:
  - Cloud OCR — conditional, with the X spelled out.
  - Screenshot package — firm.
  - State-management swap — firm.
- Section 6 sequences every named follow-up in V1 priority order.
- Each platform-conditional package recommendation specifies the cross-platform contract per `<boundaries>`.
- The audit cross-links `docs/v1-progress-audit.md` for the two utility-shaped blockers it already tracks (web Firestore persistence; Zelle).
- **Back-link added to `docs/v1-progress-audit.md`** near the top: a `**Companion audit:**` line pointing to `docs/v1-utilities-audit.md` so future readers find both.
</done_when>
