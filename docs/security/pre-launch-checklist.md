# CrewPoint — Pre-Launch Verification Checklist

Every gate that must pass before flipping the public launch. Driven by the **Sookoon Security & Privacy Audit** spec at `ai_specs/sookoon-security-privacy-audit-spec.md`.

This is a release-time gate, not a continuous check. Run through it as a single ceremony before promoting `crewpoint-prod` to public access.

## Owner

Each row carries an owner in `[brackets]`. Engineering owns the test/code rows; the user (project owner) owns the counsel + IAM + manual smoke rows.

---

## 1. Code-level gates (engineering)

- [ ] **Phase 1 + 2 rules tests green** — `npm --prefix functions test` reports the `firestore-rules.test.ts` block (15 cases) all passing against the local emulator. [eng]
- [ ] **Phase 3 + 4 CF tests green** — same test suite reports the `cloud-functions.test.ts` block (40 cases) all passing, including the 1,200-doc streaming-delete test and the `deleteUserAccount` solo + shared paths. [eng]
- [ ] **`flutter analyze` clean.** [eng]
- [ ] **`flutter test` green** (210 pass + 4 screenshot suites skipped at the time of writing — confirm the suite still runs end-to-end on a fresh checkout). [eng]
- [ ] **`functions/ npm run build` clean** — TypeScript compiles without warnings. [eng]
- [ ] **`dart run scripts/build_legal_html.dart` clean** — regenerates `assets/legal/*.md` + `web/legal/{privacy,terms}.html` from the source `docs/legal/*.md`. Re-run after any legal-doc edit. [eng]

## 2. Manual emulator smoke (engineering)

- [ ] **Large-event delete smoke**: run the seed script, then invoke `deleteEvent` against the seeded event from a callable harness or dart test. Observe:
  ```bash
  FIRESTORE_EMULATOR_HOST=localhost:8080 \
  GCLOUD_PROJECT=crewpoint-dev \
  firebase emulators:exec --only firestore,auth \
    'npx tsx functions/scripts/seed-large-event.ts \
       --event-id=evtSmoke --creator-uid=creatorSmoke \
       --messages=10000 --expenses=200 --tasks=500'
  ```
  - Function returns `{success: true}` within the 540s callable timeout.
  - Memory profile (Cloud Functions logs in production OR emulator UI) stays well under 256 MiB.
  - Observe paged-deletion progress in logs (the streaming pattern issues many small batches).
  - Subcollections empty after; `events/{eventId}` doc deleted. [eng]

## 3. Rules-deploy ↔ migration sequencing (engineering)

The Fix 1.B Option A projection-split requires existing user docs to have their PII fields moved into the `users/{uid}/private/profile` subcollection. The new rule **does not** retroactively protect data still living at the top level of the public doc.

- [ ] **Run the migration script against `crewpoint-stg` first**:
  ```bash
  FIRESTORE_EMULATOR_HOST="" \
  GOOGLE_APPLICATION_CREDENTIALS=/path/to/stg-sa.json \
  GCLOUD_PROJECT=crewpoint-stg \
  npx tsx functions/scripts/migratePiiToPrivate.ts
  ```
  Confirm script reports `migrated=N skipped=0` on first run (or `skipped>0` on a second idempotent dry-run). [eng]
- [ ] **Deploy the rules to `crewpoint-stg`**: `firebase deploy --only firestore:rules,storage:rules --project=crewpoint-stg`. [eng]
- [ ] **Spot-check stg**: pick one stg user and verify in the Firebase Console that the public `users/{uid}` doc no longer carries `email` / `providerIds` / `fcmTokens` / `preferences` and that `users/{uid}/private/profile` does. [eng]
- [ ] **Repeat for `crewpoint-prod`** in the same maintenance window: migration first, then rules. **Do not ship the rules without running the migration first** — the existing public docs would otherwise leave PII readable to every authenticated user until the next user-doc write. [eng]

## 4. Legal documents (counsel + engineering)

- [ ] **Counsel review**: external legal counsel reviews `docs/legal/privacy-policy.md` + `docs/legal/terms-of-service.md`. Counsel may move:
  - children floor (13 → 16 to align with strict GDPR interpretation)
  - liability cap
  - governing-law jurisdiction
  - dispute-resolution shape (currently no mandatory arbitration; counsel may push for one)
  - retention specifics. [user / counsel]
- [ ] **Update both legal-doc frontmatter** with `effective_date`, `last_updated`, `counsel_review_date`, `counsel_name`. [user]
- [ ] **Update this checklist row** with the counsel sign-off date + name (the audit doc cites this row as authoritative):
  - Counsel: __TBD__
  - Sign-off date: __TBD__
- [ ] **Re-run `dart run scripts/build_legal_html.dart`** to propagate the new frontmatter into `assets/legal/*.md` + `web/legal/{privacy,terms}.html`. [eng]
- [ ] **Remove the `noindex` meta tag** from `web/legal/privacy.html` and `web/legal/terms.html` only AFTER counsel sign-off. (The build script keeps it in by default; either delete the line in the generated HTML directly, or update `scripts/build_legal_html.dart` to omit it post-launch.) [eng]
- [ ] **In-app deletion-dialog copy verbatim match**: `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart:168-176` must match the privacy-policy retention clause word-for-word. The file already has an inline comment requiring lock-step updates. [eng]

## 5. Hosted /privacy + /terms (engineering)

- [ ] **Dev smoke**: `flutter build web --release --dart-define=FLAVOR=dev && firebase deploy --only hosting:crewpoint-dev`. Visit:
  - `https://crewpoint-dev.web.app/privacy` — renders the Privacy Policy.
  - `https://crewpoint-dev.web.app/terms` — renders the Terms of Service.
  - Verify SPA catch-all still works on every other path (e.g. `/dashboard`). [eng]
- [ ] **Stg smoke**: `flutter build web --release --dart-define=FLAVOR=stg && firebase deploy --only hosting:crewpoint-stg`. Visit:
  - `https://crewpoint-stg.web.app/privacy` and `/terms`. [eng]
- [ ] **Production smoke (custom domain)**: `flutter build web --release --dart-define=FLAVOR=prod && firebase deploy --only hosting:crewpoint-prod`. Visit:
  - **`https://crewpoint.sookoon.space/privacy`** — TLS green, no mixed-content warnings, content matches the canonical `docs/legal/privacy-policy.md`.
  - **`https://crewpoint.sookoon.space/terms`** — same.
  - Verify the in-app + auth-gate-footer links resolve to `crewpoint.sookoon.space/...`, **never `*.web.app`**. Inspect the prod build artifact's `main.dart.js` for `crewpoint-prod.web.app` strings — there should be none. [eng]

## 6. In-app legal surface (engineering)

- [ ] **Profile → Privacy Dashboard tile** is wired (no longer a `() {}` stub) and pushes the dashboard route. [eng]
- [ ] **PrivacyDashboardScreen → LEGAL DOCUMENTS section** renders, both rows tappable. [eng]
- [ ] **MarkdownRenderScreen** renders both docs:
  - Privacy Policy H1 + frontmatter stamps + body.
  - Terms of Service H1 + frontmatter stamps + body.
  - "View hosted version" button at the bottom opens the per-flavor hosted URL. [eng]
- [ ] **Auth-gate footer** present on both iOS and Android builds, full-viewport-width on web. Tap-tested links open the per-flavor hosted URLs. [eng]
- [ ] **Account-deletion dialog copy** matches the privacy-policy retention clause (see row 4). [eng]

## 7. Firebase Console review (user)

- [ ] **IAM check** (`crewpoint-prod`): verify no over-privileged service accounts. Default `firebase-adminsdk-...@crewpoint-prod.iam.gserviceaccount.com` is fine; flag any unexpected ones. [user]
- [ ] **Auth providers**: confirm only the providers we ship are enabled — Email/Password, Google, Apple. Anything else (anonymous, phone, etc.) should be off unless you've made a deliberate decision. [user]
- [ ] **Deployed Firestore rules match repo**: open Firebase Console → Firestore → Rules. The rules text should match `firestore.rules` in the repo at the SHA you're shipping. Same for `storage.rules`. [user]
- [ ] **Storage CORS**: the bucket needs CORS configured to allow receipt uploads from the prod web hostname (`https://crewpoint.sookoon.space`). Verify via:
  ```bash
  gsutil cors get gs://crewpoint-prod.appspot.com
  ```
  Expected: `[{"origin":["https://crewpoint.sookoon.space"], "method":["GET","POST","PUT","DELETE"], ...}]` (adjust per the receipt-upload flow). If unset or set for `*.web.app` only, update via `gsutil cors set cors.json gs://crewpoint-prod.appspot.com`. [user]
- [ ] **Cloud Functions logs**: spot-check production logs for any unhandled exceptions or excessive `internal` HttpsError throws. The Phase 3 hardening pass should have stamped every CF with structured `start/ok/fail` log lines — verify they're flowing. [user]

## 8. Audit doc cross-checks (engineering)

- [ ] `docs/security/firestore-rules-audit.md` reflects the rules at the deploying SHA — re-run the test suite after any rule edit and update the audit if findings changed. [eng]
- [ ] `docs/security/cloud-functions-audit.md` reflects the function code at the deploying SHA. Re-run the test suite + update if behavior changed. [eng]

## 9. Final go/no-go (user)

- [ ] **Sign-off**: `crewpoint-prod` rules deployed, migration completed, hosted pages live, in-app surface wired, counsel approved. Public access can flip. [user]

---

## Sign-off record

| Date | Name | Decision |
|------|------|----------|
| TBD  | TBD  | TBD      |

(Append a row each time this checklist is run as a release ceremony. Keep the history — useful for incident retrospectives.)
