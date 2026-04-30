<goal>
Lock down CrewPoint's Firestore rules, Cloud Functions, and legal posture before any real users touch the system. Three concurrent workstreams produce: (1) a written rules audit + PR-ready rule diffs + emulator-driven access-matrix tests, (2) a hardening pass across all nine Cloud Functions including a fix for the known memory risk in `deleteEvent`, and (3) Privacy Policy + Terms of Service drafts published in three places (markdown source, in-app screen, hosted page) covering GDPR + CCPA + US-general law. Outcome: a verifiable security boundary, server-side operations that don't crash on a 100k-doc event, and legal docs that explicitly state the "Minimum Viable Data" ethos (no data sale, no location tracking yet, financial records anonymized — not deleted — on account deletion to preserve group integrity).

Beneficiaries: end users (data-handling transparency, GDPR/CCPA rights), operators (no production OOM crashes during account deletion), Sookoon as an entity (legal posture before public launch, store-listing readiness).
</goal>

<background>
**Stack:** Flutter 3.27+ / Dart 3.11.5 client, Firebase backend (Auth + Firestore + Storage + Cloud Functions v2 in TypeScript / Node 22), Firebase Hosting (`crewpoint-dev` + `crewpoint-prod` targets per `firebase.json`).

**Files to examine:**
- `@firestore.rules` — 117 lines, gates `events/`, nested `messages/`, `tasks/{taskId}/checklist/`, `expenses/`, `event_invites/`, `users/`.
- `@storage.rules` — gates `users/{uid}/profile.jpg`, `users/{uid}/{allPaths=**}`, `events/{eventId}/receipts/{filename}`.
- `@functions/src/index.ts` — entry point listing all 9 callable / trigger functions.
- `@functions/src/utils/batch.ts` — `commitInChunks(operations[])` chunks Firestore writes by 500.
- `@functions/src/events/deleteEvent.ts` — owner-only event deletion. **Known risk:** collects every subcollection ref into memory before chunking; a 100k-message event would OOM the 256 MiB function before chunking begins.
- `@functions/src/account/deleteUserAccount.ts` — solo events hard-deleted, shared events anonymized (`senderId`/`payerId` → `'deleted_user'`, `assigneeId` → `null`), ownership transferred to first remaining admin.
- `@functions/src/events/{joinEvent,removeEventMember,promoteToAdmin,demoteAdmin,markTaskComplete,disputeSettlement,onUrgentMessageCreated,generateInviteCode}.ts` — remaining 7 functions in scope for hardening.
- `@web/index.html`, `@firebase.json` — Firebase Hosting target wiring for the static legal pages.
- `@ai_specs/todo.md` — already lists the deferred Firebase emulator harness as an open item; this spec resolves it.

**Existing scaffolding gaps:**
- No `functions/test/` directory exists. Test harness is fresh-build territory.
- No `docs/legal/` directory. No prior privacy/terms drafts in the repo.
- No `firestore.indexes.json` review in scope (separate concern).
- No emulator config in `firebase.json` beyond the hosting + rules entries — this spec adds an `emulators` block.

**Constraints / non-negotiables:**
- Cannot break existing client behavior. Rules tightening must preserve every legitimate flow that 195 existing tests cover.
- Cloud Function signatures (input shape, return shape, error codes) must stay backward-compatible with deployed clients.
- Privacy/Terms drafts are starting points only. External legal counsel review is a hard gate before public launch (see `<done_when>`).
- Static HTML legal pages must deploy via the existing `crewpoint-dev` and `crewpoint-prod` hosting targets — no new hosting target.

**"Minimum Viable Data" ethos** (the verbatim phrase to use in legal copy):
- We don't sell data.
- We don't track locations (yet — explicit "yet" because the roadmap includes geofence reminders).
- Financial records are anonymized — not deleted — on account deletion, to protect the group ledger's integrity for remaining members. A right-to-erasure on a per-event basis is available on request via support contact (manual process for V1).
</background>

<user_flows>
The audit/hardening work is largely non-user-facing infrastructure. Only the legal-docs surface introduces new user touchpoints.

**Primary flow — viewing legal docs (signed-in):**
1. User taps Profile → "Privacy Dashboard" row (the existing stubbed-out tile that this spec finally wires up).
2. `PrivacyDashboardScreen` shows: data we collect, what we don't collect, third-party services, **and a new "LEGAL DOCUMENTS" section** with Privacy Policy + Terms of Service rows.
3. Tap Privacy Policy → `MarkdownRenderScreen` loads `assets/legal/privacy-policy.md` and renders via the chosen markdown package (decided in Phase 3 requirement 20).
4. Tap Terms of Service → same renderer, different markdown source.
5. Each screen surfaces the frontmatter (`effective_date`, `last_updated`, `counsel_review_date`) above the body and a "View hosted version" button linking to `crewpoint.sookoon.space/{privacy,terms}` (per-flavor via `AppFlavor.legalBaseUrl`).

**Pre-signup flow — auth gate footer link:**
1. Signed-out user lands on the auth gate.
2. Below the social + email auth buttons, footer copy reads: "By continuing, you agree to our Terms and Privacy Policy."
3. Each link is a tap target that opens the **hosted** static page in an external browser (`url_launcher`). No in-app render is exposed pre-signup so the markdown bundle isn't required during the first launch.

**Account-deletion confirmation flow:**
1. Profile → Settings → Delete Account.
2. Confirmation dialog shows two-paragraph copy that mirrors the privacy-policy clause: "Your solo events will be permanently deleted. In shared events, your name and account ID will be replaced with 'deleted user' so the historical record stays intact for the rest of your group. This is irreversible. To request full erasure of an anonymized record on a per-event basis, contact support after deletion."
3. User confirms → existing `deleteUserAccount` Cloud Function fires.

**Error / edge flows:**
- Markdown asset missing (build glitch) → in-app screen falls back to a "Couldn't load — view hosted version at …" link. Logged via `dart:developer`.
- `url_launcher` fails on web (popup blocked) → snackbar with copy-to-clipboard URL.
- Account-deletion CF fails mid-anonymize → existing error handling stands; retry is idempotent against the partial state because anonymization uses `arrayRemove` + `where senderId == uid` queries that re-converge.

**Decision points:**
- Pre-signup: hosted page vs in-app render. Decision: **hosted only** before sign-in (avoids bundling concerns + SEO-indexable for app-store listings).
- Post-signup: in-app render preferred, hosted link as escape hatch (offline access via the bundled markdown asset).

**Permutation considerations:**
- First-time vs returning user: First-time users see the auth-gate footer; returning users can find the same docs under Profile.
- Network-offline: In-app renderer works (asset is bundled). Hosted-page link will fail gracefully via the standard browser offline handling.
- Cancellation: User can back out of the deletion confirmation at any point; the dialog has explicit "Cancel" + "Delete account" buttons with destructive styling on the latter.
</user_flows>

<requirements>

## Phase 1 — Firestore + Storage Rules Audit

**Functional:**
1. Produce `docs/security/firestore-rules-audit.md` listing every collection/subcollection match block in `firestore.rules`, the access matrix it implies (read/create/update/delete × actor: anonymous / signed-in / member / admin / creator), every bypass risk identified, and the recommended fix.
2. Apply the following PR-ready rule diffs to `firestore.rules` (exact rule shape; implementer must not paraphrase):

   **Fix 1.A — `events` update field-level guard (prevents admins from tampering with `memberIds`/`adminIds`/`creatorId` outside the dedicated Cloud Functions):**
   ```
   allow update: if request.auth != null
     && (resource.data.creatorId == request.auth.uid
         || request.auth.uid in resource.data.adminIds)
     && request.resource.data.memberIds == resource.data.memberIds
     && request.resource.data.adminIds == resource.data.adminIds
     && request.resource.data.creatorId == resource.data.creatorId;
   ```
   Rationale: `promoteToAdmin`, `demoteAdmin`, `removeEventMember` Cloud Functions exist precisely to gatekeep these arrays. Without the field-level guard, a malicious admin client could bypass them.

   **Fix 1.B — `users` read scope tightening:**
   Current: `allow read: if request.auth != null;` — any signed-in user reads any user doc, exposing PII (`email`, `providerIds`, `fcmTokens`, `preferences`) to every CrewPoint user. Confirmed via `lib/app/features/profile/data/firestore_user_repository.dart:17-39` (`getUser()` returns the full doc) and `lib/app/features/profile/data/firestore_user_repository.dart:113-137` (`createUserIfNotExists()` writes `email`, `displayName`, `preferences` into one record).

   **Decision: projection-split (preferred) vs denormalization (alternative).** Two viable rule shapes:

   **Option A — Projection-split (preferred).** Move PII to a self-only subcollection. The public `users/{uid}` doc keeps only fields that are already visible to all CrewPoint users in practice (`displayName`, `photoUrl`, `paymentMethod`, `paymentHandle`, `venmoHandle`, `cashappHandle`, `currency`). PII fields (`email`, `providerIds`, `fcmTokens`, `preferences`, `createdAt`, `updatedAt`) move to `users/{uid}/private/profile`. New rule shape:
   ```
   match /users/{userId} {
     allow read: if request.auth != null;     // public projection — same as today
     allow write: if request.auth.uid == userId;

     match /private/{docId} {
       allow read, write: if request.auth.uid == userId;
     }
   }
   ```
   Migration: `firestore_user_repository.dart` splits its `set(...)` into a public-doc set + a private-doc set (or one-shot batch). `getUser()` reads the public doc only when fetching another user; reads both when fetching self. Existing user-list / chat-render code (e.g., `lib/app/features/chat/application/users_by_id_provider.dart`) keeps working unchanged because it only ever reads non-PII fields. Backfill: a one-shot `migratePiiToPrivate.ts` Cloud Function script splits existing user docs (idempotent — checks for `private/profile` existence first). **Zero write amplification on membership changes.** No denormalization staleness window. Recommended.

   **Option B — Co-member denormalization (alternative).** Tighten the public read rule via a `sharedEventIds` denormalized array:
   ```
   allow read: if request.auth != null
     && (request.auth.uid == userId
         || isCoMember(userId));
   function isCoMember(otherUid) {
     return exists(/databases/$(database)/documents/users/$(request.auth.uid))
       && get(/databases/$(database)/documents/users/$(request.auth.uid))
            .data.get('sharedEventIds', []).hasAny(
              get(/databases/$(database)/documents/users/$(otherUid))
                .data.get('sharedEventIds', [])
            );
   }
   ```
   Maintenance burden: every membership-mutating CF must keep `sharedEventIds` consistent — `joinEvent` (push), `removeEventMember` (pull), `deleteEvent` (`arrayRemove(eventId)` on every member's user doc — up to `MAX_MEMBERS` writes, currently 50 per `functions/src/events/joinEvent.ts:6`), `deleteUserAccount` (pull from co-members of any anonymized events). Costs: write fan-out ≤ `MAX_MEMBERS` per event-delete, read race window after `joinEvent` (CF write→client read may miss the new entry for ~1s and produce phantom denials), schema migration on existing user docs (backfill or null-default the rule), AppUser model gains the field, `firestore_user_repository.getUser()` field-decoding update, every co-member Riverpod provider may need invalidation on membership change.

   **Required pre-implementation step (regardless of option chosen):** run a grep audit listing every dart call site that reads a non-self `users/{uid}` doc. Known starting points: `lib/app/features/chat/application/users_by_id_provider.dart` (file comment: "V1 fetches each `users/{uid}` doc once per build"). Audit doc must enumerate the list and verify each site survives the chosen rule under realistic timing. Option A makes this audit a confirmation step; Option B makes it a list of candidates for staleness-window mitigation.

   **Spec recommends Option A.** Phase 1 deliverables assume projection-split; Phase 2 deliverables drop the `sharedEventIds` write fan-out from `deleteEvent` / `deleteUserAccount` accordingly. If the implementer chooses Option B during planning, they must update Phase 2 requirements 8 and 9 to reinstate the `sharedEventIds` scrub and add the AppUser/repository/backfill/null-safety touchpoints listed above.

   **Fix 1.C — `tasks` update field-level guard:**
   ```
   allow update: if request.auth != null
     && (eventDoc().creatorId == request.auth.uid
         || request.auth.uid in eventDoc().adminIds
         || resource.data.assigneeId == request.auth.uid)
     && request.resource.data.eventId == resource.data.eventId
     && request.resource.data.createdBy == resource.data.createdBy;
   ```
   Prevents an assignee from rewriting `eventId` or `createdBy`.

   **Fix 1.D — Receipt write hardening (`storage.rules`):**
   The `events/{eventId}/receipts/{filename}` block already enforces 5 MB image-only on write — verify the `.matches('image/.*')` regex is exhaustive (e.g., rejects `image/svg+xml` which has known XSS surface). If `image/svg+xml` is allowed in the current regex, replace with an explicit allow-list: `image/jpeg|image/png|image/heic|image/webp`.

3. Lower-stakes findings (intent-only — implementer chooses exact rule shape):
   - Add write-shape allow-listing (only-known-fields validation) on `events`, `tasks`, `expenses` create/update where it doesn't break existing client writes.
   - Verify no client-side dart code attempts a direct read or write against `event_invites`. Cloud Functions use the Admin SDK which bypasses Firestore rules entirely — the rule's `allow read, write: if false` is a client-only deny and the CF coverage is irrelevant to this rules audit. Grep `lib/` for `event_invites`; if every reference is in functions/CFs (server-side only), no further action.

**Error Handling:**
4. The audit doc must list every rule that performs a `get()` lookup and flag any path where a single client read costs >2 backend reads (Firestore charges 1 read per `get()` in rules).

**Edge Cases:**
5. Rules must remain backward-compatible with the existing 195-test suite. After applying diffs, the full `flutter test` suite must continue to pass.

**Validation:**
6. Author `functions/test/firestore-rules.test.ts` using `@firebase/rules-unit-testing` covering at minimum:
   - Anonymous user cannot read or write any collection.
   - Signed-in non-member cannot read `events/{eventId}` or any of its subcollections.
   - Member can read messages but cannot delete another member's message.
   - Member cannot promote themselves to admin via direct event update.
   - Admin cannot remove another member from `memberIds` via direct event update (post-Fix-1.A).
   - User cannot read another user's `users/{otherUid}` doc unless they share an event (post-Fix-1.B).
   - Assignee cannot rewrite `eventId` or `createdBy` on a task (post-Fix-1.C).
   - `event_invites` is unreadable to all clients regardless of role.

## Phase 2 — Cloud Function Hardening

**Functional:**
7. Audit each of the 9 functions in `functions/src/` for: input validation (`request.data` shape), auth presence check (`request.auth`), authorization check (caller-has-permission), idempotency under retry, error logging with structured context, rate-limit posture. Findings recorded in `docs/security/cloud-functions-audit.md`.

8. Refactor `functions/src/events/deleteEvent.ts` to **stream subcollection refs in pages of 500** instead of accumulating all refs in memory, then commit each page via `commitInChunks` directly. This removes the OOM ceiling for events with very large message/expense/task subcollections.

   Concrete shape:
   - Replace `getSubcollectionRefs(eventRef, 'messages')` with a paged loop using `query.startAfter(lastDoc).limit(500)` until the page is empty.
   - For each page: build the `BatchOperation[]`, commit, discard, advance cursor.
   - Final commit handles invite codes + the event doc itself.
   - Function timeout stays at 120 s; memory can stay at 256 MiB once the upfront accumulation is gone.

   **`sharedEventIds` scrub (only required if Fix 1.B Option B is chosen):** if planning selects Option B (co-member denormalization), this function must read the event's `memberIds` array and issue an `arrayRemove(eventId)` write to every `users/{memberId}` doc before deleting the event doc — up to `MAX_MEMBERS` writes per call, chunked through `commitInChunks` (the 500 batch cap dwarfs 50). Order matters: scrub `sharedEventIds` **before** deleting the event doc so the `isCoMember()` rule stays consistent for any concurrent reader. **If Option A (projection-split) is chosen — the spec's recommendation — skip this scrub entirely; PII access is gated by the private subcollection rule, which `deleteEvent` doesn't touch.**

9. Apply the same streaming pattern to `functions/src/account/deleteUserAccount.ts` for the inner `deleteEventCompletely` and `anonymizeUserInEvent` helpers. **Option B addendum (only if Fix 1.B selects denormalization):** `deleteEventCompletely` from this path is a no-op for `sharedEventIds` (the lone member's user doc is about to be deleted); `anonymizeUserInEvent` must `arrayRemove(eventId)` from the deleting user's own `sharedEventIds` as part of the same batch. **Option A (projection-split, recommended):** no `sharedEventIds` work needed; the existing anonymization (senderId/payerId → 'deleted_user', assigneeId → null) is sufficient.

   **Co-member migration (Option A only):** `deleteUserAccount` must additionally delete the user's `users/{uid}/private/profile` subcollection document before deleting the parent `users/{uid}` doc — Firestore does not cascade-delete subcollections.

10. Add structured logging (`logger.info` with a labeled object) at the start and end of each Cloud Function recording: `uid`, `op`, key arguments, and elapsed-ms. Errors must include the same context.

**Error Handling:**
11. Every `HttpsError` thrown must use a stable `code` from the Firebase callable error catalog (`unauthenticated`, `permission-denied`, `invalid-argument`, `not-found`, `failed-precondition`, `aborted`, `internal`). The audit doc must list every current `throw new HttpsError(...)` call and confirm the code is correct.

12. Validate `request.data` shape at the top of each handler before any Firestore work. Use a tiny inline guard (e.g., `if (typeof request.data?.eventId !== 'string') throw new HttpsError('invalid-argument', '…')`). No new validation library required — the goal is rejecting malformed payloads cheaply, not formal schema validation.

**Edge Cases:**
13. `deleteEvent` and `deleteUserAccount` must be safe to retry: if a previous invocation deleted a partial set of documents and the function retries, the second pass converges on the same end state. Document this property in the function's dartdoc-style comment.

14. `joinEvent` must reject codes that have already been redeemed AND codes whose target event has been deleted (currently relies on a `not-found` from a downstream `get()` — make the check explicit at the top of the handler).

**Validation:**
15. Author `functions/test/cloud-functions.test.ts` using `firebase-functions-test` + the local Firestore emulator, covering at minimum:
    - `deleteEvent` happy path on a small event (verify all subcollections gone).
    - `deleteEvent` rejects non-creator caller with `permission-denied`.
    - `deleteEvent` succeeds on an event seeded with 1,200 messages (proves chunking + streaming pagination).
    - **PII isolation (Option A only)**: a non-self read of `users/{otherUid}/private/profile` is denied; a self read succeeds. After `deleteUserAccount`, the deleted user's private subcollection doc is gone (no orphan).
    - **Membership denormalization (Option B only — skip if Option A wins)**: `deleteEvent` scrubs `sharedEventIds` (seed 3-member event; after delete, no member's array contains the eventId); `joinEvent` pushes the eventId; `removeEventMember` pulls it; co-members' arrays stay consistent through `deleteUserAccount`.
    - `deleteUserAccount` solo event → hard delete; shared event → anonymize + ownership transfer.
    - `joinEvent` rejects expired/redeemed/missing codes with the right `HttpsError` code.
    - `promoteToAdmin` / `demoteAdmin` reject non-creator callers and refuse to demote the last admin.

16. Commit `functions/scripts/seed-large-event.ts` — a one-shot TypeScript script that seeds an emulator-resident event with 10,000 messages + 200 expenses + 500 tasks. Used as the fixture for the chunking test in (15) and for any future manual emulator smoke runs.

## Phase 3 — Legal Docs (Privacy Policy + Terms of Service)

**Functional:**
17. Author `docs/legal/privacy-policy.md` with the following YAML frontmatter (authoritative metadata; counsel updates these fields directly):
    ```yaml
    ---
    effective_date: TBD
    last_updated: TBD
    counsel_review_date: TBD
    counsel_name: TBD
    version: 1.0
    ---
    ```
    Body covers:
    - **Effective date** + **last-updated date** (also surfaced in the rendered prose; frontmatter is the source of truth).
    - **Controller / contact**: Sookoon entity name + jurisdiction + contact email.
    - **Data collected**: enumerate exactly — Firebase Auth identifiers (uid, email, providerIds, displayName, photoURL), event-domain data (events, messages, tasks, expenses), receipt images, device identifiers received via FCM tokens. Make the list exhaustive against the actual schema.
    - **How we use it**: only to operate the service. Explicitly: "We do not sell or share your data with advertisers or data brokers."
    - **"Minimum Viable Data" section** — verbatim ethos from `<background>`.
    - **GDPR rights** (Articles 15–22): access, rectification, erasure, portability, restriction, objection, automated-decision opt-out. Contact path for each.
    - **CCPA rights**: Right to Know, Right to Delete, Right to Opt-Out of Sale ("we don't sell"), Right to Non-Discrimination.
    - **Account deletion mechanics**: solo-events hard-deleted, shared-events anonymized to `deleted_user`. Indefinite retention of anonymized records by default. Per-event right-to-erasure available on request via support contact (manual process for V1).
    - **No location tracking — yet**: mention the geofence-reminder roadmap and commit to updating the policy before any location collection ships.
    - **Children**: 13+ only (or 16+ if we want to be EU-conservative — defer to counsel).
    - **Data residency**: Firebase default region (us-central1). Statement that this may change and an updated policy will be published in advance.
    - **Retention**: receipts + financial records anonymized indefinitely; messages tied to a deleted account anonymized indefinitely; FCM tokens deleted on sign-out.
    - **Security**: Firebase Auth + TLS in transit + Google Cloud encryption at rest. No claim of E2EE for messages (chat is not E2EE in V1 — `firestore_chat_service.dart` notes this is a known gap).
    - **Changes to this policy**: in-app notice + email if material change.

18. Author `docs/legal/terms-of-service.md` with the same YAML frontmatter shape as (17). Body covers:
    - Effective date + last-updated date (also surfaced in rendered prose).
    - Acceptance: signing in constitutes acceptance.
    - Account requirements: 13+ (or 16+), accurate info.
    - Acceptable use: no illegal content, no harassment, no scraping, no reverse engineering.
    - User content: user retains ownership; grants Sookoon a license to display content within the service to other group members.
    - Termination: Sookoon can terminate for ToS violation; user can delete account at any time.
    - Disclaimers: service provided as-is, no warranty.
    - Limitation of liability: standard small-startup boilerplate, jurisdiction-appropriate.
    - Governing law: defer to counsel.
    - Dispute resolution: defer to counsel; default proposal is informal-resolution-first then small-claims, no mandatory arbitration unless counsel requires it.
    - Changes to terms: in-app notice if material.

19. Bundle both markdown files as Flutter assets:
    - Place at `assets/legal/privacy-policy.md` and `assets/legal/terms-of-service.md` (sym-linked or copied from `docs/legal/` via a build-time script — implementer chooses; if copying, document the build-time copy step).
    - Add `assets/legal/` to `pubspec.yaml` `flutter.assets`.

20. **Markdown rendering package — verify before adding.** Before pinning a dependency, confirm the chosen package's last release is within 6 months and it explicitly supports Flutter 3.27+. Candidates: `flutter_markdown` (Flutter team archived primary maintenance in 2024 — verify status), `markdown_widget`, `gpt_markdown`, `flutter_markdown_plus`. Implementer picks one and justifies the pick in the implementation PR description; spec does not pre-commit.

21. **Integrate legal docs into the existing `PrivacyDashboardScreen` rather than building a parallel `LegalScreen`.** `lib/app/features/profile/presentation/privacy_dashboard_screen.dart` already exists (240 lines: data inventory, what-we-don't-collect, third-party services). The Profile screen has a stubbed-out "Privacy Dashboard" tile at `lib/app/features/profile/presentation/profile_screen.dart:40-44` (`onTap: () {}`) waiting to be wired up. Required work:

    - **Wire the stub tile**: replace `onTap: () {}` with `onTap: () => context.push(AppRoutes.privacyDashboard)` (add the route to `lib/app/core/router/app_router.dart`).
    - **Extend `PrivacyDashboardScreen`**: append a new section "LEGAL DOCUMENTS" below the existing "THIRD-PARTY SERVICES" section, containing two `_SettingsTile`-style rows with chevron — "Privacy Policy" and "Terms of Service". Each row pushes a `MarkdownRenderScreen` that loads the asset and renders via the chosen markdown package.
    - **New screen**: `lib/app/features/profile/presentation/markdown_render_screen.dart` — accepts `assetPath`, `title`, `hostedUrl`. AppBar shows the title; body renders the markdown; bottom-of-screen "View hosted version" button opens `hostedUrl` via `url_launcher`. The asset's frontmatter (effective_date, last_updated) is parsed and displayed at the top.
    - **Do NOT create a separate `LegalScreen`** — the dashboard already serves as the privacy hub; adding a sibling screen splits the privacy story.

22. Auth-gate footer (`lib/app/features/auth/presentation/auth_gate_screen.dart`): add footer text "By continuing, you agree to our Terms and Privacy Policy" below the existing scrollable content.

    **Layout placement (precise — implementer must follow):** the existing body is `SafeArea > SingleChildScrollView > Center > ConstrainedBox(maxWidth: 480) > Column(const, ...)`. The footer must render **outside** the `ConstrainedBox` so it spans full viewport width (legal copy reads edge-to-edge), but **inside** the `SafeArea` so it doesn't collide with the home indicator on iOS. Wrap the existing `SingleChildScrollView` in a `Column(children: [Expanded(child: SingleChildScrollView(...)), _LegalFooter()])`. The `Column` inside the `ConstrainedBox` keeps its `const` modifier; only the outer `Scaffold > SafeArea > Column` becomes non-const because of the new footer widget.

    Tapping a link opens the **hosted** URL via `url_launcher` to the per-flavor host from (Finding 7's resolution) — `crewpoint-dev.web.app/{privacy,terms}` for dev, `crewpoint.sookoon.space/{privacy,terms}` for prod. Use the existing `context.strings.auth.*` extension (already wired in `ui-polish-i18n-foundation-plan` Phase 3). Add new keys: `auth.legalFooter`, `auth.legalFooterTermsLink`, `auth.legalFooterPrivacyLink`.

    **Layout regression test:** add to `auth_gate_screen_layout_test.dart` — pump at 1280×800 and assert footer width > 480 (footer spans wider than the clamped column); pump at 375×812 and assert footer is visible above bottom safe area.

**Hosted static pages:**
23. Generate `web/legal/privacy.html` and `web/legal/terms.html` from the markdown sources via a one-shot script `scripts/build_legal_html.dart` (or shell + `pandoc` — implementer chooses; the script must be checked in).
24. Wire Firebase Hosting to serve `/privacy` and `/terms` to those HTML files. **Apply to all three hosting targets** in `firebase.json` (`crewpoint-dev`, `crewpoint-stg`, `crewpoint-prod`) — staging cannot ship without these routes or smoke tests on stg builds will 404.

    Each target's `rewrites` array currently has only `{ source: "**", destination: "/index.html" }`. Firebase Hosting evaluates rewrites top-to-bottom and serves the first match — the catch-all must stay last. **Insert above it:**
    ```json
    "rewrites": [
      { "source": "/privacy", "destination": "/legal/privacy.html" },
      { "source": "/terms", "destination": "/legal/terms.html" },
      { "source": "**", "destination": "/index.html" }
    ]
    ```
    Alternative: `cleanUrls: true` + filenames at `web/legal/privacy.html` and `web/legal/terms.html`. Pick one; do not mix. The explicit-rewrites approach is preferred because it leaves the rest of Firebase Hosting's URL behavior untouched.

**Error Handling:**
25. In-app markdown screen: if asset load fails, render a single-line fallback with a "View online" button that opens the hosted URL.

**Validation:**
26. Widget test for the extended `PrivacyDashboardScreen` confirming the new "LEGAL DOCUMENTS" section renders with both Privacy Policy and Terms of Service rows, each tappable.
27. Widget test for `MarkdownRenderScreen` with a fixed-content markdown asset asserting at least the H1 + first paragraph render, and that frontmatter `effective_date` / `last_updated` surface above the body.
28. Auth-gate widget tests: (a) footer copy present + both links tappable via stable selectors `auth.legal.termsLink` and `auth.legal.privacyLink`; (b) layout-regression assertion in `auth_gate_screen_layout_test.dart` per requirement 22's placement contract (footer width > 480 at 1280×800; footer visible above bottom safe area at 375×812).
29. Manual smoke: deploy `crewpoint-dev`, visit `https://crewpoint-dev.web.app/privacy` and `/terms`. Smoke-test stg deploy at `https://crewpoint-stg.web.app/privacy` and `/terms` before any production traffic. Production-tier smoke happens in Phase 5 against the custom domain `crewpoint.sookoon.space/privacy` and `/terms`.

## Phase 4 — Test Infrastructure (lightweight harness + seed script)

**Functional:**
30. Stand up `functions/test/` with:
    - `package.json` adds dev deps: `@firebase/rules-unit-testing`, `firebase-functions-test`, `jest`, `ts-jest`, `@types/jest`.
    - `jest.config.js` configured for TypeScript.
    - `functions/test/setup.ts` boots the emulator (firestore + auth + functions) and exposes helpers.
    - `firebase.json` gains an `emulators` block exposing firestore (8080), auth (9099), functions (5001), ui (4000).
    - `npm --prefix functions test` runs the suite. Document the command in `functions/README.md` (create if absent).

31. Commit `functions/scripts/seed-large-event.ts` per Phase 2 requirement (16). Script signature: `npx tsx scripts/seed-large-event.ts --event-id=<id> --messages=10000 --expenses=200 --tasks=500`.

**Edge Cases:**
32. Tests must run against the emulator only — never the live project. Add a guard in `setup.ts` that errors out if `FIRESTORE_EMULATOR_HOST` is unset.

**Validation:**
33. CI: add a GitHub Actions workflow (or note it as a follow-up if CI infra isn't in scope) that runs `npm --prefix functions test` against the Firebase emulator on every PR. If CI infra is out of scope for this spec, document the manual run path in `functions/README.md` and flag it as a follow-up in `ai_specs/todo.md`.

## Phase 5 — Pre-launch Verification Checklist

**Functional:**
34. Produce `docs/security/pre-launch-checklist.md` listing every gate that must pass before flipping the public launch:
    - All Phase-1 rules tests green.
    - All Phase-2 CF tests green.
    - Manual emulator smoke: seed 10k-msg event, run `deleteEvent`, observe streaming chunked deletion in logs, function returns within 120s, no OOM.
    - Privacy + Terms drafts reviewed by external counsel, sign-off recorded **in three places**: (a) `docs/security/pre-launch-checklist.md` row with date + counsel name, (b) `docs/legal/privacy-policy.md` frontmatter (`counsel_review_date`, `counsel_name` fields), (c) `docs/legal/terms-of-service.md` frontmatter (same fields).
    - Hosted `/privacy` and `/terms` live on **all three** hosting targets (`crewpoint-dev`, `crewpoint-stg`, `crewpoint-prod`) AND reachable via the custom domain `https://crewpoint.sookoon.space/privacy` + `/terms` for production (not just the default `crewpoint-prod.web.app` Firebase hostname). Verify TLS, no mixed-content warnings, and that the in-app + auth-gate-footer links point at the custom domain — never at `*.web.app` in production builds.
    - In-app: Profile → Privacy Dashboard → Legal Documents section reachable; both Privacy Policy and Terms of Service render via the chosen markdown package; frontmatter `effective_date` / `last_updated` surface above the body.
    - Auth gate footer linked + tap-tested on iOS, Android, web; layout-regression test green at both 1280×800 and 375×812.
    - Account-deletion confirmation copy matches the privacy-policy retention clause verbatim.
    - Firebase Console review: project IAM (no over-privileged service accounts), Auth providers (only Google + Apple + Email enabled per the auth fix work), security rules deployed match repo rules.
    - Storage CORS configured for receipt uploads from the prod web hostname (`crewpoint.sookoon.space`).
</requirements>

<boundaries>
**Edge cases:**
- Massive event deletion (100k+ messages): streaming pagination ensures bounded memory, but a single deleteEvent may approach the 120 s timeout. If observed, raise timeout to 540 s (Firebase max for callable v2) and document in the function's comment.
- User with hundreds of shared events at deletion time: `deleteUserAccount` already iterates events serially. If observed timeouts, parallelize with `p-limit` capped at 5 — but only if real workloads demand it. Out of scope unless emulator soak proves it's needed. Note: per-event member count is bounded by `MAX_MEMBERS` (currently 50 — see `functions/src/events/joinEvent.ts:6`) so per-event work is fixed; the variable is the count of events the user belongs to.
- User signs in, opens auth gate, taps Terms link — `url_launcher` returns false on web due to popup blocker: snackbar shows the URL with a copy-to-clipboard action.
- Markdown asset fails to load (build glitch, on-device corruption): in-app screen falls back to a hosted-link prompt. Logged via `dart:developer`.
- Counsel sign-off requested edits: drafts in `docs/legal/` are the source of truth — re-running `scripts/build_legal_html.dart` regenerates the static HTML and the next Flutter build re-bundles the asset.

**Error scenarios:**
- Cloud Function fails mid-anonymize: the anonymization queries (`where senderId == uid`) are convergent under retry — re-running the function picks up where the previous run left off without double-applying.
- Rules-unit-testing fails because the emulator port is occupied: `setup.ts` should `kill -9` any existing emulator on the relevant ports OR error out cleanly with a "kill the running emulator" message. Implementer chooses; the latter is safer.
- Hosted `/privacy` 404 because the rewrites block didn't get the explicit entry: surface in the manual smoke step in Phase 5; verify before flipping prod.

**Limits:**
- `commitInChunks` limit of 500 documents per batch is a Firestore hard cap. Do not raise.
- `flutter_markdown` does not render arbitrary HTML inside markdown. If counsel-edited prose embeds raw HTML, strip it during the markdown-to-asset copy step.
- The static HTML pages must be self-contained — no external CSS/JS dependencies that could break under the Firebase Hosting cache. Inline styles only.
- Static HTML pages should not be indexed if Sookoon is pre-public; add `<meta name="robots" content="noindex">` until launch flip is done. Remove on launch.
</boundaries>

<implementation>
**Files to create:**
- `docs/security/firestore-rules-audit.md`
- `docs/security/cloud-functions-audit.md`
- `docs/security/pre-launch-checklist.md`
- `docs/legal/privacy-policy.md`
- `docs/legal/terms-of-service.md`
- `assets/legal/privacy-policy.md` (built/copied from docs/legal/)
- `assets/legal/terms-of-service.md` (built/copied from docs/legal/)
- `web/legal/privacy.html` (generated)
- `web/legal/terms.html` (generated)
- `scripts/build_legal_html.dart` (md → html script)
- `functions/test/firestore-rules.test.ts`
- `functions/test/cloud-functions.test.ts`
- `functions/test/setup.ts`
- `functions/scripts/seed-large-event.ts`
- `functions/jest.config.js`
- `functions/README.md` (test-run instructions)
- `lib/app/features/profile/presentation/markdown_render_screen.dart`
- `lib/app/features/auth/presentation/widgets/legal_footer.dart` (new widget for the auth-gate footer)
- Widget tests under `test/app/features/profile/` (`PrivacyDashboardScreen` legal-section test, `MarkdownRenderScreen` test) and `test/app/features/auth/` (auth-footer + layout-regression updates to `auth_gate_screen_layout_test.dart`).

**Files to modify:**
- `firestore.rules` — apply Fixes 1.A, 1.B, 1.C.
- `storage.rules` — apply Fix 1.D if regex audit identifies the gap.
- `functions/src/events/deleteEvent.ts` — streaming pagination.
- `functions/src/account/deleteUserAccount.ts` — streaming pagination + co-member denormalization writes.
- `functions/src/events/{joinEvent,removeEventMember,promoteToAdmin,demoteAdmin}.ts` — co-member denormalization writes for Fix 1.B.
- All 9 functions — input validation, structured logging, `HttpsError` code audit per requirement 11–12.
- `firebase.json` — add `emulators` block; `/privacy` + `/terms` rewrites in **all three** hosting targets (`crewpoint-dev`, `crewpoint-stg`, `crewpoint-prod`).
- `functions/package.json` — add jest + rules-unit-testing dev deps.
- `pubspec.yaml` — add the chosen markdown package (after maintenance verification per requirement 20), register `assets/legal/`.
- `lib/app/features/auth/presentation/auth_gate_screen.dart` — footer, restructured per requirement 22 layout contract.
- `lib/app/core/i18n/app_strings.dart` — add `auth.legalFooter*` keys.
- `lib/app/core/router/app_router.dart` — add `AppRoutes.privacyDashboard` (and optionally `.privacyPolicy` / `.termsOfService` sub-routes for deep linking).
- `lib/app/features/profile/presentation/profile_screen.dart` — wire the existing stubbed-out "Privacy Dashboard" `_SettingsTile` (`onTap: () {}` at lines 40-44) to `context.push(AppRoutes.privacyDashboard)`.
- `lib/app/features/profile/presentation/privacy_dashboard_screen.dart` — append the new "LEGAL DOCUMENTS" section per requirement 21.
- `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart` — update copy to mirror the privacy-policy retention clause verbatim ("Your solo events will be permanently deleted. In shared events, your name and account ID will be replaced with 'deleted user' so the historical record stays intact for the rest of your group. This is irreversible. To request full erasure of an anonymized record on a per-event basis, contact support after deletion.").
- `lib/app/core/env/app_flavor.dart` — extend with a per-flavor `legalBaseUrl` getter returning `https://crewpoint-dev.web.app` (dev), `https://crewpoint-stg.web.app` (stg), `https://crewpoint.sookoon.space` (prod). The auth-gate footer + markdown-render screen consume this getter — never hardcode a hostname.
- **If Fix 1.B Option A (projection-split, recommended) is chosen:** `lib/app/features/auth/domain/models/app_user.dart` — no schema change needed; `lib/app/features/profile/data/firestore_user_repository.dart` — split write path into public-doc write + `private/profile` subdoc write, split read path to fetch private subdoc only on self-reads.
- **If Fix 1.B Option B is chosen instead:** `lib/app/features/auth/domain/models/app_user.dart` — add `sharedEventIds: List<String>` field; `lib/app/features/profile/data/firestore_user_repository.dart:17-39` — extend `getUser()` field-decoding; backfill strategy (one-shot `migrateSharedEventIds.ts` Cloud Function or lazy ensure-on-write); rule-side `.get('sharedEventIds', [])` for null-safety.
- `ai_specs/todo.md` — close out the deferred emulator-harness item; flag any spec items deferred to follow-up.

**Patterns to use:**
- Streaming pagination: `query.orderBy(FieldPath.documentId()).startAfter(lastDoc).limit(500)` — standard Firestore pattern.
- Rules tests: `@firebase/rules-unit-testing`'s `initializeTestEnvironment({ projectId, firestore: { rules } })` + `assertSucceeds` / `assertFails`.
- CF tests: `firebase-functions-test`'s `wrap()` for callable functions; emulator-resident Firestore for state assertions.
- Markdown rendering: `flutter_markdown`'s `Markdown` widget with `selectable: true` and `onTapLink:` to open external URLs via `url_launcher`.
- Static HTML: GitHub-flavored markdown rendered to a single self-contained HTML file with inline styles. Use `markdown` Dart package (already transitively available) or `pandoc` if installed.

**What to avoid (and why):**
- Do not introduce a JSON schema validator (zod, yup) for Cloud Function inputs. The existing inline `typeof` checks are sufficient; adding a library inflates the cold-start cost on every function.
- Do not change Cloud Function call signatures or return shapes. Deployed clients depend on them; a change is a separate spec.
- Do not couple legal-text edits to Flutter rebuilds — the hosted HTML lets us hot-fix legal copy without an app store re-submission, and the in-app asset can be updated on the next regular release.
- Do not enable a CI job in this spec if CI infra isn't already standing — track it as a follow-up. The harness must be runnable via `npm test` locally even without CI.
- Do not run rules tests against the live project. Emulator only.
- Do not write tests for the audit reports themselves (they're prose); only the rule-fix and CF behaviors get automated coverage.
</implementation>

<validation>
**Baseline coverage outcomes (required):**

- **Rules tests** (`functions/test/firestore-rules.test.ts`): exercises every rule branch the audit modifies. Each test states the actor (anonymous / signed-in non-member / member / admin / creator), the op (read/create/update/delete), and the expected outcome (allow / deny). At least one negative case per fix (1.A, 1.B, 1.C, 1.D).
- **CF integration tests** (`functions/test/cloud-functions.test.ts`): every callable in `functions/src/index.ts` has at least one happy-path and one auth-failure test. `deleteEvent` and `deleteUserAccount` get an additional large-dataset test seeded by `seed-large-event.ts` (≥1,200 docs to prove chunking + streaming pagination).
- **Widget tests** for the new legal surfaces: extended `PrivacyDashboardScreen` shows the new "LEGAL DOCUMENTS" section with both rows tappable; `MarkdownRenderScreen` renders an H1 + paragraph from a fixed asset and surfaces frontmatter; auth-gate footer presents the two links by stable selector keys (`auth.legal.termsLink`, `auth.legal.privacyLink`).
- **Unit tests** for `scripts/build_legal_html.dart` / the markdown-to-HTML conversion if the converter has non-trivial transformation logic. Skip if it's a thin pandoc shell-out.

**TDD expectations (Phase 2 + Phase 3 — features with testable logic):**

- Behavior order — write the failing test first for each behavior slice:
  1. RED: rules test asserting a non-member is denied event read.
  2. GREEN: rule already enforces this (or apply the fix); test passes.
  3. RED: rules test asserting an admin cannot self-promote via direct event update.
  4. GREEN: apply Fix 1.A; test passes.
  5. Repeat for each fix and each CF behavior change.
- Vertical-slice cycles for `deleteEvent` streaming refactor:
  1. RED: a CF test seeds an event with 1,200 messages; current `deleteEvent` (with upfront ref collection) is expected to either OOM under tighter memory or simply complete — depending on test setup. Assertion target: post-call `messages` subcollection is empty AND total memory used during the call stays bounded (use a memory-watching test helper). If memory monitoring is too tedious, settle for a deterministic assertion that the Firestore query log shows multiple paged reads instead of one large fetch.
  2. GREEN: refactor `deleteEvent` to streaming pagination. Test passes.
- Testability seams: existing CFs already use Firebase Admin SDK directly. Inject the admin SDK via a thin module wrapper (`functions/src/utils/firestore.ts` exposing `getDb()`) only if the test setup proves to need it. Default: no DI — use `firebase-functions-test`'s emulator-pointing instance.
- Mocking policy: NO mocks. Tests run against the local Firestore emulator (real Firestore behavior). Fakes acceptable only at external boundaries that the emulator doesn't simulate (e.g., Apple App Server Notifications, FCM delivery — neither of which is in scope here).
- Justified exception: the audit reports themselves have no test coverage — they're prose. Their correctness is verified by code-review + the rules + CF tests passing.

**Robot-driven journey tests (user-facing flows):**

- **`PrivacyDashboardRobot.viewPrivacyPolicy()`** — Profile → Privacy Dashboard → Privacy Policy row → asserts markdown H1 visible.
- **`PrivacyDashboardRobot.viewTermsOfService()`** — same path, Terms of Service row.
- **`AuthGateRobot.tapPrivacyFooter()`** — auth gate → tap privacy link → asserts `url_launcher` is invoked with the per-flavor hosted URL (use a fake `IUrlLauncher` per existing test conventions).
- Stable selectors required: `Key('profile.privacyDashboard.tile')` (the previously stubbed Profile tile), `Key('privacyDashboard.legal.privacy')`, `Key('privacyDashboard.legal.terms')`, `Key('legal.markdown.body')`, `Key('auth.legal.termsLink')`, `Key('auth.legal.privacyLink')`.
- Deterministic seams: bundle the markdown asset for tests; do NOT load from network in test mode.

**Test-type mapping:**

- **Robot tests** — critical happy-path journeys (Profile → Legal → Privacy/Terms; auth-gate footer tap).
- **Widget tests** — screen-level edge cases (markdown asset missing → fallback render; auth-gate footer copy + selector presence).
- **Unit tests** — markdown→HTML script if it has logic; rule helper functions if any are extracted.
- **Rules tests** — every rule branch the audit modifies (Phase 1).
- **CF integration tests** — every callable function (Phase 2), with the large-dataset variant for `deleteEvent` and `deleteUserAccount`.

**Manual smoke (Phase 5 checklist):**

- Deploy to `crewpoint-dev`, run the seed script against the emulator, run `deleteEvent` against the seeded event, observe paged-deletion logs.
- Open `https://crewpoint-dev.web.app/privacy` and `/terms` in an incognito window — confirm renders.
- Sign in fresh, navigate Profile → Legal → both docs. Confirm last-updated stamps + hosted-version links.
- Tap the auth-gate footer Terms link and confirm it opens the hosted page.
- Initiate account deletion, confirm the dialog copy matches the privacy-policy retention clause verbatim.
</validation>

<stages>
**Phase 1 — Firestore + Storage Rules Audit.** Verify completion: `docs/security/firestore-rules-audit.md` committed, rules diffs applied, `functions/test/firestore-rules.test.ts` green against the emulator.

**Phase 2 — Cloud Function Hardening.** Verify completion: `docs/security/cloud-functions-audit.md` committed, all 9 functions audited and updated, `functions/test/cloud-functions.test.ts` green including the large-dataset `deleteEvent` test.

**Phase 3 — Legal Docs.** Verify completion: drafts in `docs/legal/`, in-app screens reachable, hosted HTML renders on `crewpoint-dev`, widget + robot tests green.

**Phase 4 — Test Infrastructure.** Verify completion: `npm --prefix functions test` runs locally and produces a green report covering both rules + CF tests.

**Phase 5 — Pre-launch Verification.** Verify completion: `docs/security/pre-launch-checklist.md` committed; every checkbox manually verified during the public-launch readiness review (this is a release-time gate, not a continuous check).

Each phase produces an independently committable, deployable set of changes. Phase 3 can run in parallel with Phase 2 (they touch disjoint files); Phases 1, 2, 4 must complete before Phase 5.
</stages>

<done_when>
**Code-level gates** (verified by automated tests + diff review):
- All five rule fixes (1.A through 1.D plus the lower-stakes hardening in (3)) applied to `firestore.rules` / `storage.rules`.
- `deleteEvent` and `deleteUserAccount` use streaming pagination; no upfront ref accumulation remains.
- Every Cloud Function in `functions/src/` validates `request.data` shape at the top of the handler, performs an auth check, throws the canonical `HttpsError` code on failure, and emits structured start/end log lines.
- `functions/test/firestore-rules.test.ts` covers every fix with at least one allow + one deny case per rule branch.
- `functions/test/cloud-functions.test.ts` covers every callable function with happy-path + auth-failure + (for `deleteEvent` / `deleteUserAccount`) a large-dataset case.
- `functions/scripts/seed-large-event.ts` runs end-to-end against the emulator.
- `npm --prefix functions test` is green.
- `flutter test` is green (now ≥ 200 tests counting the new legal-screen + auth-footer cases).
- `flutter analyze` is clean.

**Documentation-level gates:**
- `docs/security/firestore-rules-audit.md`, `docs/security/cloud-functions-audit.md`, `docs/security/pre-launch-checklist.md` committed.
- `docs/legal/privacy-policy.md` + `docs/legal/terms-of-service.md` committed as drafts (counsel-pending).

**Hosted + in-app gates** (verified manually via the Phase 5 checklist):
- Dev smoke: `https://crewpoint-dev.web.app/privacy` and `/terms` render the static HTML.
- Staging smoke: `https://crewpoint-stg.web.app/privacy` and `/terms` render the static HTML.
- Production smoke: `https://crewpoint.sookoon.space/privacy` and `/terms` render the static HTML over the custom domain (not just the `crewpoint-prod.web.app` default hostname).
- Profile → Privacy Dashboard → Legal Documents → Privacy Policy / Terms of Service all reachable on iOS, Android, web. The previously-stubbed Privacy Dashboard tile in `profile_screen.dart` now routes correctly.
- Auth-gate footer links open the hosted pages via `url_launcher`. The href is sourced from `AppFlavor.legalBaseUrl` (extended in `lib/app/core/env/app_flavor.dart`); production builds resolve to `https://crewpoint.sookoon.space/...`, never `*.web.app`. Verify by inspecting the prod build artifact.

**Pre-public-launch hard gate:**
- External legal counsel has reviewed and signed off on `docs/legal/privacy-policy.md` and `docs/legal/terms-of-service.md`. Sign-off recorded in `docs/security/pre-launch-checklist.md` with date + counsel name.
- The "noindex" meta tag has been removed from `web/legal/privacy.html` and `web/legal/terms.html` only after counsel sign-off.

**Out-of-scope tracked in `ai_specs/todo.md`:**
- DPDP Act (India) compliance clauses — Hindi is on the roadmap but India-residency compliance is a separate spec.
- E2EE chat (separate, large spec; the privacy policy explicitly states V1 is not E2EE).
- Automated retention purge for anonymized records (V1 is on-request manual; revisit if compliance posture demands automation).
- CI integration of the test harness if CI infra isn't already standing.
- Rate-limiting infrastructure for Cloud Functions (currently relies on Firebase's built-in default limits; revisit if abuse data warrants per-uid quotas).
</done_when>
