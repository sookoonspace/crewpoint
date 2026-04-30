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
- [ ] `functions/package.json` — add dev deps: `@firebase/rules-unit-testing`, `firebase-functions-test`, `jest`, `ts-jest`, `@types/jest`, `tsx`.
- [ ] `functions/jest.config.js` — TypeScript, emulator-pointed, `testTimeout: 30000`.
- [ ] `functions/test/setup.ts` — boot emulator helpers; **guard**: throw if `FIRESTORE_EMULATOR_HOST` unset.
- [ ] `firebase.json` — add `emulators` block (firestore 8080, auth 9099, functions 5001, ui 4000).
- [ ] `functions/README.md` — document `npm test` run path + emulator prereq.
- [ ] `firestore.rules` — apply Fix 1.A (events update field-level guard for `memberIds`/`adminIds`/`creatorId`). Spec §Phase-1 req-2.
- [ ] TDD: rules test — admin cannot self-promote via direct `events/{id}` update (Fix 1.A negative case).
- [ ] TDD: rules test — admin cannot remove a member via direct `events/{id}` update.
- [ ] TDD: rules test — creator can update title/description/dates without touching member arrays (positive case; backward-compat).
- [ ] TDD: rules test — anonymous user denied read on every collection (smoke).
- [ ] TDD: rules test — non-member denied read on `events/{id}` (smoke).
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`.

### Phase 2: Remaining rule fixes (1.B projection-split + 1.C tasks + 1.D storage) + access-matrix tests + audit reports

- **Goal**: every rule branch hardened; `users` PII isolated to private subcollection; storage MIME allow-list; written reports committed.
- [ ] `firestore.rules` — apply Fix 1.B Option A: keep `users/{uid}` public (display fields only), add `match /users/{uid}/private/{docId}` with self-only rule.
- [ ] `firestore.rules` — apply Fix 1.C (tasks update field-level guard for `eventId`/`createdBy`).
- [ ] `firestore.rules` — write-shape allow-listing on `events`/`tasks`/`expenses` create+update (intent-only).
- [ ] `storage.rules` — audit `image/.*` regex; if `image/svg+xml` admitted, replace with explicit allow-list (Fix 1.D).
- [ ] `lib/app/features/profile/data/firestore_user_repository.dart` — split write path into public-doc set + `private/profile` subdoc set (batched). Split read path: public-only on non-self reads; both on self.
- [ ] `lib/app/features/profile/domain/repositories/i_user_repository.dart` — extend interface if read-self vs read-other diverges.
- [ ] `functions/scripts/migratePiiToPrivate.ts` — one-shot idempotent migration for existing `users/{uid}` docs (check `private/profile` existence before write; record `migratedAt`).
- [ ] `functions/src/account/deleteUserAccount.ts` — delete `users/{uid}/private/profile` subdoc before deleting parent (Firestore doesn't cascade).
- [ ] Grep audit: every dart call site reading non-self `users/{uid}` doc. Start point: `lib/app/features/chat/application/users_by_id_provider.dart`. Verify each survives the projection-split rule.
- [ ] TDD: rules test — non-self read on `users/{otherUid}` returns public projection only; private subdoc denied.
- [ ] TDD: rules test — self read on `users/{uid}/private/profile` succeeds; other reads denied.
- [ ] TDD: rules test — assignee cannot rewrite `eventId` or `createdBy` on a task (Fix 1.C).
- [ ] TDD: rules test — `event_invites` denied to all clients regardless of role.
- [ ] TDD: dart unit test — repository read-self vs read-other returns expected projections.
- [ ] `docs/security/firestore-rules-audit.md` — every match block + access matrix (read/create/update/delete × actor) + `get()`-cost flagging + Fix list.
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`.

### Phase 3: Cloud Function hardening pass (10 functions) — input validation + structured logging + HttpsError audit

- **Goal**: every CF validates `request.data` shape; emits start/end structured logs (uid, op, args, elapsed-ms); throws canonical `HttpsError` codes.
- [ ] `functions/src/account/deleteUserAccount.ts` — input/auth/log/error-code pass.
- [ ] `functions/src/events/deleteEvent.ts` — same. (Streaming refactor in Phase 4.)
- [ ] `functions/src/events/joinEvent.ts` — explicit "code redeemed / event missing" check at top of handler (spec §req-14); rest of pass.
- [ ] `functions/src/events/removeEventMember.ts` — pass.
- [ ] `functions/src/events/promoteToAdmin.ts` — pass; verify last-admin demotion is impossible.
- [ ] `functions/src/events/demoteAdmin.ts` — pass; verify last-admin demotion is impossible.
- [ ] `functions/src/events/markTaskComplete.ts` — pass.
- [ ] `functions/src/events/disputeSettlement.ts` — pass.
- [ ] `functions/src/events/generateInviteCode.ts` — pass.
- [ ] `functions/src/events/onUrgentMessageCreated.ts` — pass (Firestore trigger, not callable; logging only).
- [ ] `functions/test/cloud-functions.test.ts` — happy-path + auth-failure case per callable (8 callables × 2 = 16 tests minimum). `firebase-functions-test` v3 online mode; seed via Admin SDK pointed at emulator.
- [ ] TDD: each callable's auth-failure test (write before refactor; verify failure mode).
- [ ] TDD: `joinEvent` rejects expired/redeemed/missing codes with correct `HttpsError` codes.
- [ ] TDD: `promoteToAdmin`/`demoteAdmin` reject non-creator + refuse last-admin demote with `failed-precondition`.
- [ ] `docs/security/cloud-functions-audit.md` — per-function findings (input shape, auth, error codes, idempotency, logging gaps + fixes applied).
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`.

### Phase 4: Streaming pagination refactor (deleteEvent + deleteUserAccount) — memory fix

- **Goal**: 100k-doc events delete safely on 256 MiB memory; CF integration test proves chunking on a 1,200+ doc seed.
- [ ] `functions/src/events/deleteEvent.ts` — replace `getSubcollectionRefs()` with paged loop: `query.orderBy(FieldPath.documentId()).limit(500)` re-run until empty (do not carry `startAfter`); commit each page via `commitInChunks`. Then handle invite codes + event doc.
- [ ] `functions/src/account/deleteUserAccount.ts` — same streaming pattern in `deleteEventCompletely` + `anonymizeUserInEvent` helpers.
- [ ] `functions/scripts/seed-large-event.ts` — `npx tsx scripts/seed-large-event.ts --event-id=<id> --messages=10000 --expenses=200 --tasks=500`. Used as fixture for the chunking test + manual smoke runs.
- [ ] TDD: `deleteEvent` happy path on small event — all subcollections empty after; rules-test verifies cascading delete.
- [ ] TDD: `deleteEvent` rejects non-creator caller with `permission-denied`.
- [ ] TDD: `deleteEvent` succeeds on 1,200-message seeded event (proves streaming pagination); function returns within 30s emulator timeout.
- [ ] TDD: `deleteUserAccount` solo event → hard delete; private subdoc gone.
- [ ] TDD: `deleteUserAccount` shared event → senderId/payerId → 'deleted_user'; assigneeId → null; ownership transferred to first remaining admin.
- [ ] TDD: retry safety — partial-state convergence on second invocation (idempotency check per spec §req-13).
- [ ] Document retry-safety property in dartdoc-style comment on each function.
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`.

### Phase 5: Legal docs — drafts + in-app render + hosted static + auth footer

- **Goal**: Privacy Policy + ToS shipped in three places (markdown, in-app via `PrivacyDashboardScreen`, hosted static HTML on all 3 hosting targets); auth-gate footer linked.
- [ ] `docs/legal/privacy-policy.md` — YAML frontmatter (`effective_date`, `last_updated`, `counsel_review_date`, `counsel_name`, `version: 1.0`) + body covering spec §req-17 fields (controller, data collected, MVD ethos, GDPR rights, CCPA rights, account-deletion mechanics, no-location-yet, children, data residency, retention, security, changes).
- [ ] `docs/legal/terms-of-service.md` — same frontmatter + body per spec §req-18.
- [ ] `assets/legal/privacy-policy.md` + `terms-of-service.md` — copy or symlink from `docs/legal/`. Document the copy mechanism.
- [ ] `pubspec.yaml` — register `assets/legal/`; add chosen markdown package (verification gate below).
- [ ] **Markdown package verification gate**: confirm chosen package's last release ≤6 months + Flutter 3.27+ support. Default `flutter_markdown_plus`; fallback `markdown_widget`. Justify in PR description.
- [ ] `lib/app/core/env/app_flavor.dart` — extend with `legalBaseUrl` getter: dev → `https://crewpoint-dev.web.app`; stg → `https://crewpoint-stg.web.app`; prod → `https://crewpoint.sookoon.space`.
- [ ] `lib/app/core/router/app_router.dart` — add `AppRoutes.privacyDashboard` route.
- [ ] `lib/app/features/profile/presentation/profile_screen.dart:40-44` — wire stubbed `_SettingsTile.onTap` to `context.push(AppRoutes.privacyDashboard)`.
- [ ] `lib/app/features/profile/presentation/privacy_dashboard_screen.dart` — append "LEGAL DOCUMENTS" `_SectionLabel` + `_SectionCard(children: [_SettingsTile(privacy), Divider, _SettingsTile(terms)])`.
- [ ] `lib/app/features/profile/presentation/markdown_render_screen.dart` — accepts `assetPath`, `title`, `hostedUrl`. Loads asset, strips YAML frontmatter via regex (`^---\n[\s\S]*?\n---\n`), parses frontmatter via `package:yaml`, renders body via chosen markdown package. AppBar = title; top = effective/last-updated stamps; bottom = "View hosted version" button → `url_launcher` to `hostedUrl`.
- [ ] `lib/app/features/profile/presentation/markdown_render_screen.dart` — error-handling: asset load fail → fallback row with "View online" button.
- [ ] `lib/app/features/auth/presentation/widgets/legal_footer.dart` — new widget; full-width centered text "By continuing, you agree to our Terms and Privacy Policy"; tappable links resolve via `AppFlavor.legalBaseUrl` + `url_launcher`. Stable Keys: `auth.legal.termsLink`, `auth.legal.privacyLink`.
- [ ] `lib/app/features/auth/presentation/auth_gate_screen.dart` — restructure body: `Scaffold > SafeArea > Column(children: [Expanded(SingleChildScrollView(...existing 480-clamped layout...)), LegalFooter()])`. Inner Column inside ConstrainedBox stays `const`; outer `Column` becomes non-const because of `LegalFooter()`.
- [ ] `lib/app/core/i18n/app_strings.dart` — add `auth.legalFooter`, `auth.legalFooterTermsLink`, `auth.legalFooterPrivacyLink` to `AuthStrings` + `_EnglishAuthStrings`.
- [ ] `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart:168-176` — replace copy with the verbatim privacy-policy retention clause (spec §user-flows §account-deletion-confirmation-flow).
- [ ] `scripts/build_legal_html.dart` — markdown → self-contained HTML with inline styles + `<meta name="robots" content="noindex">`. Output to `web/legal/{privacy,terms}.html`.
- [ ] `web/legal/privacy.html` + `terms.html` — generated; checked in.
- [ ] `firebase.json` — add `/privacy` + `/terms` rewrites before `**` catch-all in **all 3 hosting targets** (`crewpoint-dev`, `crewpoint-stg`, `crewpoint-prod`).
- [ ] TDD: widget test — `PrivacyDashboardScreen` LEGAL DOCUMENTS section renders, both rows tappable.
- [ ] TDD: widget test — `MarkdownRenderScreen` renders H1 + first paragraph from a fixed asset; frontmatter `effective_date`/`last_updated` surface above body.
- [ ] TDD: widget test — `MarkdownRenderScreen` asset-load failure → fallback "View online" button visible.
- [ ] TDD: widget test — auth-gate footer present; both link Keys tappable; `IUrlLauncher` fake invoked with per-flavor URL.
- [ ] TDD: layout-regression test in `auth_gate_screen_layout_test.dart` — at 1280×800 footer width > 480; at 375×812 footer visible above bottom safe area.
- [ ] Robot journey: `PrivacyDashboardRobot.viewPrivacyPolicy()` — Profile → Privacy Dashboard tile → Privacy Policy row → markdown H1 visible. Stable selectors per spec §validation.
- [ ] Robot journey: `PrivacyDashboardRobot.viewTermsOfService()` — same path, terms asset.
- [ ] Robot journey: `AuthGateRobot.tapPrivacyFooter()` — auth-gate footer tap → fake `IUrlLauncher` invoked with hosted URL.
- [ ] Manual smoke: `flutter build web --release --dart-define=FLAVOR=dev && firebase deploy --only hosting:crewpoint-dev`; visit `https://crewpoint-dev.web.app/{privacy,terms}` — confirm static HTML renders. Repeat for stg.
- [ ] Verify: `flutter analyze` && `flutter test` && `npm --prefix functions test`.

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
