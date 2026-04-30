## Overview

Pre-launch security + legal hardening: rules audit, CF streaming refactor, legal docs in 3 places, emulator harness. Five phases; Phase 1 proves the test-loop end-to-end via Fix 1.A; Phases 2–4 parallelizable.

**Spec**: `ai_specs/sookoon-security-privacy-audit-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first under `lib/app/features/`; CFs under `functions/src/{events,account}/`; rules at root.
- **State management**: Riverpod 3.0 (no app-state changes; UI/data/CF/rules only).
- **Reference implementations**:
  - `lib/app/features/profile/presentation/privacy_dashboard_screen.dart` — `_SectionLabel` + `_SectionCard` + `_SettingsTile` pattern; existing 240-line screen to extend.
  - `lib/app/features/profile/presentation/profile_screen.dart:40-44` — stubbed `_SettingsTile` (`onTap: () {}`) ready to wire.
  - `lib/app/features/auth/presentation/auth_gate_screen.dart` — `Scaffold > SafeArea > SingleChildScrollView > Center > ConstrainedBox(maxWidth: 480) > Column(const, ...)`; layout test at `test/app/features/auth/auth_gate_screen_layout_test.dart` uses `setSurfaceSize` + `getSize` + stable `Key`.
  - `lib/app/core/i18n/app_strings.dart` — abstract `AuthStrings` + `_EnglishAuthStrings` impl; extension `StringsX on BuildContext`.
  - `lib/app/core/env/app_flavor.dart` — `AppFlavor.dev/stg/prod` enum; extension target for `legalBaseUrl`.
  - `lib/app/core/router/app_router.dart:22-30` — `AppRoutes` static-const paths; nested route under profile at line 214-217.
  - `functions/src/utils/batch.ts` — `commitInChunks(ops[])` chunks at 500. Don't reuse `getSubcollectionRefs()` for unbounded subcollections.
  - `functions/src/events/joinEvent.ts:6` — `MAX_MEMBERS = 50`.
  - `firestore.rules:5-9` — `isEventMember()` helper; 1× `get()` per check.
  - `firebase.json:23-138` — 3 hosting targets; identical rewrites needing `/privacy` + `/terms` insertion before `**` catch-all.
  - `test/app/features/auth/fake_auth_service.dart` — fake naming/structure pattern.
  - `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart:168-176` — current deletion copy.
- **Assumptions/Gaps**:
  - Spec recommends Fix 1.B Option A (projection-split). Plan assumes Option A throughout. Option B fallback noted in spec.
  - Markdown package: `flutter_markdown` archived 2024; plan defaults to `flutter_markdown_plus` pending the verification step (Phase 4 task gate). YAML frontmatter parsed separately via `package:yaml`.
  - Streaming-delete idiom: re-run `limit(N)` until `snapshot.empty` (do NOT carry `startAfter` across deletions — anchor disappears post-delete). Alternatively `firestore.recursiveDelete()` from Admin SDK ≥10.
  - Counsel review is a hard gate but external — plan ships drafts; sign-off recorded in checklist + frontmatter.
  - 9 callables + 1 trigger (`onUrgentMessageCreated`) = 10 functions in scope; spec says "9" loosely.

## Plan

### Phase 1: Test harness + Fix 1.A (events update guard) — end-to-end proving slice

- **Goal**: rules-test loop runs locally; first field-level rule guard shipped + tested; pattern locked in for Phases 2–3.
- [x] `functions/package.json` — added dev deps: `@firebase/rules-unit-testing@^4.0.1`, `firebase-functions-test@^3.4.1`, `jest@^29.7.0`, `ts-jest@^29.2.5`, `@types/jest@^29.5.13`, `tsx@^4.19.2`, `@types/node@^22.10.0`. Added `test` + `test:watch` scripts wrapped in `firebase emulators:exec --only firestore,auth`.
- [x] `functions/jest.config.js` — ts-jest preset, `testTimeout: 30000`, node env, `<rootDir>/test/**/*.test.ts` match.
- [x] `functions/test/setup.ts` — `getTestEnv()` loads `firestore.rules` from disk + boots `RulesTestEnvironment`; throws if `FIRESTORE_EMULATOR_HOST` unset.
- [x] `firebase.json` — added `emulators` block (firestore 8080, auth 9099, functions 5001, ui 4000, `singleProjectMode: true`).
- [x] `functions/README.md` — documented `npm test` run path + emulator prereq + test layout.
- [x] `firestore.rules` — applied Fix 1.A (events update now field-level-guarded against `memberIds`/`adminIds`/`creatorId` mutation; comment cites the dedicated CFs that gatekeep those arrays).
- [x] TDD: rules test — admin cannot promote another member to admin via direct `events/{id}` update (Fix 1.A driving test; RED → applied Fix 1.A → GREEN).
- [x] TDD: rules test — admin cannot remove a member from `memberIds` via direct `events/{id}` update.
- [x] TDD: rules test — creator can update title without touching member arrays (positive case; backward-compat).
- [x] TDD: rules test — anonymous user denied read on `events` (smoke).
- [x] TDD: rules test — non-member denied read on `events/{id}` (smoke).
- [x] Verify: `flutter analyze` clean; `flutter test` 195 pass + 4 screenshot suites skipped; `npm --prefix functions test` 5/5 pass.

### Phase 2: Remaining rule fixes (1.B projection-split + 1.C tasks + 1.D storage) + access-matrix tests + audit reports

- **Goal**: every rule branch hardened; `users` PII isolated to private subcollection; storage MIME allow-list; written reports committed.
- [x] `firestore.rules` — applied Fix 1.B Option A: kept `users/{uid}` publicly readable (display fields only), added `match /users/{uid}/private/{docId}` with self-only `read, write` rule. Comment cites the rationale.
- [x] `firestore.rules` — applied Fix 1.C (tasks update field-level guard for `eventId`/`createdBy`). Comment cites the data-integrity / audit-trail rationale.
- [ ] `firestore.rules` — write-shape allow-listing on `events`/`tasks`/`expenses` create+update (intent-only — deferred follow-up; audit doc lists as out-of-scope for V1).
- [x] `storage.rules` — replaced `image/.*` (admits `image/svg+xml` XSS surface) with explicit `image/(jpeg|png|heic|webp)` allow-list at both `users/{userId}/profile.jpg` and `events/{eventId}/receipts/{filename}` write rules.
- [x] `lib/app/features/profile/data/firestore_user_repository.dart` — write path split via `WriteBatch`: public-doc gets display + payment fields; `private/profile` subdoc gets email/preferences/timestamps/fcmTokens. Read path attempts both; permission-denied on private (non-self read under the new rules) gracefully returns the public projection only.
- [x] `lib/app/features/profile/domain/repositories/i_user_repository.dart` — interface unchanged; the public-vs-private split is hidden behind `getUser(uid)` semantics. Documented in the Firestore impl's class-level dartdoc.
- [x] `functions/scripts/migratePiiToPrivate.ts` — one-shot idempotent migration. Cursor-paged (500-doc pages, document-ID order); skips users with existing `private/profile`; writes `migratedAt` marker. Documented usage for both emulator and prod with required env vars.
- [x] `functions/src/account/deleteUserAccount.ts` — deletes `users/{uid}/private/profile` subdoc before parent (Firestore doesn't cascade). Catches missing-subdoc errors as warnings for retry idempotency.
- [x] Grep audit: every dart call site reading non-self `users/{uid}` doc surveyed — `lib/app/features/chat/application/users_by_id_provider.dart:18` (consumed by chat / tasks / budget pages) reads only public-display fields and survives the projection-split. `lib/app/features/profile/presentation/edit_profile_screen.dart:159` is a self-read and gets the full AppUser. `lib/app/core/services/fcm_service.dart` writes only (now to private subdoc). No other consumers found.
- [x] TDD: rules test — non-self read on `users/{otherUid}` returns public projection (existing rule unchanged); non-self read on `users/{otherUid}/private/profile` denied.
- [x] TDD: rules test — self read on `users/{uid}/private/profile` succeeds; self write succeeds; non-self write denied (RED → applied Fix 1.B → GREEN).
- [x] TDD: rules test — assignee cannot rewrite `eventId` or `createdBy` on a task (Fix 1.C; RED → applied Fix 1.C → GREEN); positive backward-compat (assignee updates `status`) green.
- [x] TDD: rules test — `event_invites` denied to all clients regardless of role (read + create both denied).
- [x] TDD: dart unit test — `firestore_user_repository_test.dart` covers `createUserIfNotExists` PII split, `saveProfile` public-only writes, `addFcmToken`/`removeFcmToken` private-subdoc routing, `getUser` merge logic + missing-private fallback. 7/7 tests pass via `fake_cloud_firestore`.
- [x] `docs/security/firestore-rules-audit.md` — full access matrix, per-rule findings, `get()`-cost table, storage-rule audit, out-of-scope tracking, sign-off checkpoint.
- [x] Verify: `flutter analyze` clean; `flutter test` 202 pass + 4 screenshot suites skipped; `npm --prefix functions test` 15/15 pass; `npm --prefix functions run build` clean.

### Phase 3: Cloud Function hardening pass (10 functions) — input validation + structured logging + HttpsError audit

- **Goal**: every CF validates `request.data` shape; emits start/end structured logs (uid, op, args, elapsed-ms); throws canonical `HttpsError` codes.
- [x] `functions/src/utils/logging.ts` — added `withStructuredLogs({op, uid, args}, fn)` helper + `requireString(value, fieldName)` validator. Used by every callable below.
- [x] `functions/src/account/deleteUserAccount.ts` — input/auth/log/error-code pass; wrapper preserves the existing memory-risk note (deferred to Phase 4).
- [x] `functions/src/events/deleteEvent.ts` — same; memory risk explicitly documented in the function header.
- [x] `functions/src/events/joinEvent.ts` — `requireString` enforces input shape; missing/expired/event-deleted all return `not-found` (with code-cleanup side effect on expired); already-member returns `already-exists`; full returns `resource-exhausted` with `MAX_MEMBERS` interpolated into the message.
- [x] `functions/src/events/removeEventMember.ts` — pass; admin/creator OR self-removal authorization; owner-cannot-be-removed enforced.
- [x] `functions/src/events/promoteToAdmin.ts` — pass; creator-only auth; target-must-be-member check.
- [x] `functions/src/events/demoteAdmin.ts` — pass; **new last-admin guard** (TDD-driven: refuses to demote when `adminIds.length <= 1` with `failed-precondition`); creator-only auth + owner-cannot-be-demoted + target-must-be-admin.
- [x] `functions/src/events/markTaskComplete.ts` — pass; owner/admin/assignee authorization.
- [x] `functions/src/events/disputeSettlement.ts` — pass; payer/payee authorization; idempotency via shared-id chat notice.
- [x] `functions/src/events/onUrgentMessageCreated.ts` — **important Phase 2 follow-up**: reads `fcmTokens` from `users/{uid}/private/profile` (post-projection-split) and prunes dead tokens to the same private subdoc. Without this fix the trigger would silently send zero pushes after Phase 2 deployed.
- [x] `functions/src/events/generateInviteCode.ts` — pass; admin-or-creator auth; collision-retry; single-active-code invariant.
- [x] `functions/test/cloud-functions.test.ts` — 35 emulator-driven integration tests via `firebase-functions-test` v3 online mode. `test.each` covers all 8 callables × auth-failure (8 tests) + all 8 callables × invalid-argument (8 tests). Per-callable suites add authorization-rejection + happy-path + edge cases (last-admin, expired join codes, missing target events, settlement-dispute side effects, deleteEvent subcollection cascade). Setup helper `seedEvent()` reduces fixture boilerplate.
- [x] TDD: each callable's auth-failure test (RED via `test.each` showed all 8 callables already enforced auth; GREEN regression coverage).
- [x] TDD: `joinEvent` rejects expired/redeemed/missing codes with correct `HttpsError` codes — 4 tests cover missing/expired/missing-event/happy-path.
- [x] TDD: `promoteToAdmin`/`demoteAdmin` reject non-creator + refuse last-admin demote with `failed-precondition` — last-admin guard was the driving RED → GREEN cycle for the whole CF test harness.
- [x] `docs/security/cloud-functions-audit.md` — per-function findings, hardening pattern, full HttpsError catalog, test surface, sign-off checkpoint.
- [x] Verify: `flutter analyze` clean; `flutter test` 202 pass + 4 screenshot suites skipped; `npm --prefix functions test` 50/50 pass (15 rules + 35 CF); `npm run build` clean.

### Phase 4: Streaming pagination refactor (deleteEvent + deleteUserAccount) — memory fix

- **Goal**: 100k-doc events delete safely on 256 MiB memory; CF integration test proves chunking on a 1,200+ doc seed.
- [x] `functions/src/utils/batch.ts` — added `streamDeleteSubcollection(parentRef, subcollection)` helper. Loop pattern: `parentRef.collection(subcollection).limit(500).get()` → batched delete → re-run until `snapshot.empty`. Does NOT carry `startAfter` across pages because the cursor anchor would be one of the just-deleted docs. `getSubcollectionRefs` left in place but documented as memory-unsafe for unbounded subcollections.
- [x] `functions/src/events/deleteEvent.ts` — refactored to use `streamDeleteSubcollection` for messages/expenses/tasks. Invite codes + event doc still committed in single batches (bounded by `MAX_MEMBERS` and 1 respectively). Timeout bumped to 540s (callable v2 max) for very large events. Memory now bounded at 500 doc refs in flight regardless of subcollection size.
- [x] `functions/src/account/deleteUserAccount.ts` — `deleteEventCompletely` refactored to use `streamDeleteSubcollection`. `anonymizeUserInEvent` left as upfront fetch because per-user-per-event docs are bounded by user activity (small) — flagged in audit doc as out-of-scope optimization.
- [x] `functions/scripts/seed-large-event.ts` — TypeScript CLI script with `--event-id`, `--creator-uid`, `--messages`, `--expenses`, `--tasks` flags (defaults: 10k/200/500). Uses 500-doc batched writes + page progress logging. Documented usage + manual smoke procedure in script header.
- [x] TDD: `deleteEvent` happy path on small event — covered in Phase 3.
- [x] TDD: `deleteEvent` rejects non-creator caller with `permission-denied` — covered in Phase 3.
- [x] TDD: `deleteEvent` succeeds on 1,200-message seeded event with 60s test timeout (proves streaming pagination — an upfront-collection regression would surface as either OOM or timeout).
- [x] TDD: `deleteUserAccount` solo event → hard delete; public + private user docs gone; Firebase Auth user deleted (verified via `admin.auth().getUser` rejecting with `auth/user-not-found`).
- [x] TDD: `deleteUserAccount` shared event → ownership transferred to first remaining admin; senderId/payerId on existing messages/expenses → `'deleted_user'`; assigneeId on owned tasks → `null`; deleting user removed from memberIds + adminIds.
- [x] TDD: retry safety — running `deleteEvent` twice in a row, second invocation rejects with `not-found` (the missing-event guard at the top); no crash, clean error.
- [x] Document retry-safety property in dartdoc-style comment on each function — already done in Phase 3 (§ deleteEvent header) and updated this phase to reference the streaming pattern's natural idempotency.
- [x] Verify: `flutter analyze` clean; `flutter test` 202 pass + 4 screenshot suites skipped; `npm --prefix functions test` 55/55 pass (15 rules + 40 CF including Phase 4 additions); `npm run build` clean.

### Phase 5: Legal docs — drafts + in-app render + hosted static + auth footer

- **Goal**: Privacy Policy + ToS shipped in three places (markdown, in-app via `PrivacyDashboardScreen`, hosted static HTML on all 3 hosting targets); auth-gate footer linked.
- [x] `docs/legal/privacy-policy.md` — YAML frontmatter (TBD-marked sign-off fields) + body covering controller/contact, exhaustive data collection list, MVD ethos verbatim, GDPR Articles 15–22, CCPA Right to Know/Delete/Opt-out/Non-discrimination, account-deletion mechanics, "no location tracking — yet", children 13+ (counsel may raise to 16), `us-central1` data residency, retention table, security posture (no-E2EE-V1 disclosed), change-notification policy.
- [x] `docs/legal/terms-of-service.md` — same frontmatter shape; body covers acceptance, account requirements, acceptable use, user content + license, settlements (CrewPoint doesn't process payments), termination, disclaimers, liability cap (counsel-pending), governing law (Delaware default; counsel-pending), no-mandatory-arbitration default, changes.
- [x] `assets/legal/{privacy-policy,terms-of-service}.md` — generated via `scripts/build_legal_html.dart` from the canonical `docs/legal/` source. Re-run on every doc edit to keep both surfaces in sync.
- [x] `pubspec.yaml` — registered `assets/legal/`; added `flutter_markdown_plus: ^1.0.7` (last release 2025-12-28; supports Flutter 3.27.1+) + `yaml: ^3.1.2` (frontmatter parser); added `markdown: ^7.3.0` to dev deps for the build script.
- [x] **Markdown package verification gate**: `flutter_markdown_plus` 1.0.7 verified via pub.dev API — last release 2025-12-28 (well within the 6-month window), `environment: {sdk: ^3.4.0, flutter: '>=3.27.1'}`. `flutter_markdown` archived by Flutter team 2024 — used `flutter_markdown_plus` as drop-in successor.
- [x] `lib/app/core/env/app_flavor.dart` — extended with per-flavor `legalBaseUrl` getter (dev → `crewpoint-dev.web.app`; stg → `crewpoint-stg.web.app`; prod → `crewpoint.sookoon.space`) + a `static final AppFlavor.current` derived from `String.fromEnvironment('FLAVOR')` so any UI surface can resolve the active flavor without a Riverpod provider.
- [x] `lib/app/core/router/app_router.dart` — added `AppRoutes.privacyDashboard = '/profile/privacy-dashboard'` as a nested go_router route under profile.
- [x] `lib/app/features/profile/presentation/profile_screen.dart:40-44` — wired the stubbed `_SettingsTile.onTap` to `context.push(AppRoutes.privacyDashboard)`. Added stable `Key('profile.privacyDashboard.tile')` for journey-test selectors.
- [x] `lib/app/features/profile/presentation/privacy_dashboard_screen.dart` — appended "LEGAL DOCUMENTS" `_SectionLabel` + `_SectionCard` with two `ListTile`s pushing `MarkdownRenderScreen` via `Navigator.of(context).push`. Stable Keys `privacyDashboard.legal.{privacy,terms}`.
- [x] `lib/app/features/profile/presentation/markdown_render_screen.dart` — new screen accepts `title`, `assetPath`, `hostedUrl`. Loads asset via `rootBundle.loadString`, splits frontmatter via regex (`^---\r?\n([\s\S]*?)\r?\n---\r?\n`), parses YAML via `package:yaml`, renders body via `MarkdownBody`. Frontmatter stamps `legal.stamp.{effective,lastUpdated}` surface above body. "View hosted version" button (`legal.viewHosted`) at the bottom.
- [x] `lib/app/features/profile/presentation/markdown_render_screen.dart` — asset-load failure path renders `_LoadFailure` with `legal.fallback.viewOnline` button + the hosted URL displayed below. Logs the failure via `dart:developer`.
- [x] `lib/app/features/auth/presentation/widgets/legal_footer.dart` — new widget rendering "By continuing, you agree to our Terms and Privacy Policy" via `Text.rich` with `WidgetSpan + InkWell` link tap targets. URLs resolved per-flavor via `AppFlavor.current.legalBaseUrl`. Test seam: `urlLauncher` parameter (defaults to `launchUrl`).
- [x] `lib/app/features/auth/presentation/auth_gate_screen.dart` — restructured: `Scaffold > SafeArea > Column(children: [Expanded(SingleChildScrollView(... 480-clamped column ...)), LegalFooter()])`. Inner Column inside ConstrainedBox stays `const`; outer Column dropped const because `LegalFooter()` is now mounted.
- [x] `lib/app/core/i18n/app_strings.dart` — added 5 new `AuthStrings` getters: `legalFooterPrefix`, `legalFooterTermsLink`, `legalFooterAnd`, `legalFooterPrivacyLink`, `legalFooterSuffix`. English impl wires them into `_EnglishAuthStrings`.
- [x] `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart:168-176` — replaced copy with the verbatim privacy-policy retention clause. Inline comment cites the source-of-truth in `docs/legal/privacy-policy.md` so any future edit keeps both files in lock-step.
- [x] `scripts/build_legal_html.dart` — Dart CLI build script. Reads `docs/legal/*.md` → strips YAML frontmatter → renders body via `package:markdown` (GitHub-flavored) → wraps in self-contained HTML with inline styles + `<meta name="robots" content="noindex">`. Outputs both the `assets/legal/*.md` copies and `web/legal/{privacy,terms}.html`. Idempotent.
- [x] `web/legal/privacy.html` + `terms.html` — generated; checked in.
- [x] `firebase.json` — added `/privacy` → `/legal/privacy.html` and `/terms` → `/legal/terms.html` rewrites BEFORE the `**` catch-all in **all 3 hosting targets** (`crewpoint-dev`, `crewpoint-stg`, `crewpoint-prod`).
- [x] TDD: widget test — `PrivacyDashboardScreen` "LEGAL DOCUMENTS" section + both row Keys tappable. Tall surface (400×2000) lets the lazy ListView build all sections.
- [x] TDD: widget test — `MarkdownRenderScreen` renders H1 from bundled asset + frontmatter stamps surface above body (combined into one test to dodge cross-test state bleed). Asset-load failure renders the fallback button.
- [x] TDD: widget test — `LegalFooter` link Keys present; tapping each invokes `IUrlLauncher` fake with the per-flavor `/{privacy,terms}` URL.
- [x] TDD: layout-regression — at 1280×800, footer width > 480 (full-viewport edge-to-edge); at 375×812, footer is mounted and bottom edge fits within the viewport.
- [ ] Robot journey: `PrivacyDashboardRobot.viewPrivacyPolicy()` — **deferred follow-up.** Equivalent coverage exists in `privacy_dashboard_screen_test.dart` (asserts both row keys) + `markdown_render_screen_test.dart` (asserts H1 renders); a robot-class abstraction would be ergonomic sugar but doesn't add new coverage. Tracked in `ai_specs/todo.md`.
- [ ] Robot journey: `PrivacyDashboardRobot.viewTermsOfService()` — **deferred follow-up** (same rationale).
- [ ] Robot journey: `AuthGateRobot.tapPrivacyFooter()` — **deferred follow-up.** Equivalent coverage exists in `legal_footer_test.dart` (asserts the fake URL launcher gets per-flavor `/privacy` and `/terms` URLs).
- [ ] Manual smoke: `flutter build web --release --dart-define=FLAVOR=dev && firebase deploy --only hosting:crewpoint-dev`; visit `https://crewpoint-dev.web.app/{privacy,terms}` — confirm static HTML renders. Repeat for stg. **Manual user step.**
- [x] Verify: `flutter analyze` clean; `flutter test` 210 pass + 4 screenshot suites skipped (8 new tests: 2 markdown_render, 1 privacy_dashboard, 3 legal_footer, 2 layout-regression); `npm --prefix functions test` 55/55 pass; `dart run scripts/build_legal_html.dart` produces clean assets + HTML.

### Phase 6: Pre-launch verification checklist + final hand-off

- **Goal**: every gate from spec §Phase-5 documented; counsel sign-off recorded; production smoke green.
- [ ] `docs/security/pre-launch-checklist.md` — every gate per spec §req-34 (rules tests green, CF tests green, manual emulator smoke with seeded large event, counsel review, hosted /privacy + /terms on all 3 targets, prod custom-domain TLS, in-app legal reachable, auth-footer links, deletion-dialog copy verbatim, IAM review, Auth provider review, deployed rules match repo, Storage CORS).
- [ ] Update `ai_specs/todo.md` — close out the deferred emulator-harness item; flag any spec items deferred (DPDP Act compliance, E2EE chat, automated retention purge, CI integration of test harness).
- [ ] Manual smoke (counsel-pending — block until done):
  - Counsel review of `docs/legal/privacy-policy.md` + `terms-of-service.md`.
  - Update frontmatter in both legal docs (`counsel_review_date`, `counsel_name`).
  - Update `pre-launch-checklist.md` row with same.
  - Remove `<meta name="robots" content="noindex">` from `web/legal/{privacy,terms}.html` post-counsel.
  - Production deploy: `firebase deploy --only hosting:crewpoint-prod`.
  - Smoke: `https://crewpoint.sookoon.space/{privacy,terms}` — TLS green, no mixed-content, content matches drafts.
  - Verify prod build artifact: auth-gate footer hrefs point at `crewpoint.sookoon.space`, not `*.web.app`.
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test` (final green run before launch flip).

## Risks / Out of scope

- **Risks**:
  - Phase 2 projection-split changes the `users/{uid}` schema; existing user docs need the migration script to run before the rule deploy, or live reads break. Sequence: deploy rules + run migration in same maintenance window. Test with the emulator + a seeded fixture mirroring prod shape.
  - Phase 4 streaming refactor: re-running `limit(N)` after deletions assumes Firestore consistency catches up; if a test seeds 10k docs and the function loops faster than Firestore's read-after-write latency settles, the loop could exit early. Mitigation: always re-query until 2 consecutive empty pages OR use `firestore.recursiveDelete()` from Admin SDK ≥10.
  - Phase 5 markdown package choice: `flutter_markdown` archive may surface gotchas in `flutter_markdown_plus` (selectable text, link-tap interception). Verify on first widget test before bundling assets.
  - Counsel review timeline (Phase 6) is external — could delay launch indefinitely. Plan ships drafts that are good enough to start counsel review immediately; do not block engineering work behind it.
- **Out of scope**:
  - DPDP Act (India) compliance clauses — separate spec.
  - E2EE chat — separate large spec.
  - Automated retention purge for anonymized records — V1 manual via support contact.
  - CI integration of `npm --prefix functions test` — track in `ai_specs/todo.md`.
  - Per-uid rate-limit infrastructure for Cloud Functions — Firebase defaults stand for V1.
  - Fix 1.B Option B (denormalization) — Plan assumes Option A; Option B fallback noted in spec §Fix-1.B if Phase 2 grep audit surfaces blockers.
