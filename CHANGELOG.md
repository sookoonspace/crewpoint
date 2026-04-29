# Changelog

All notable changes to CrewPoint are documented here. Format adheres to
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

GitHub Releases drafts are auto-maintained by `release-drafter` from PR
labels (`feature` / `fix` / `docs` / `chore` / `breaking`). Maintainers
review the draft, edit copy if needed, and publish on tag bump. Entries
below predate the release-drafter wiring and are kept here as a
human-curated history.

## [Unreleased]

### Added — Web admin & reporting (in progress)

Tracking work from `ai_specs/web-admin-reporting-spec.md`.

- **Phase 1 — Responsive shell + dev hosting** (shipped):
  - `ResponsiveShell` swaps `NavigationBar` (<720px) and `NavigationRail`
    (≥720px) as siblings inside a single `Scaffold`, keyed body slot so
    branch state, route stack, and scroll positions survive the
    breakpoint transition.
  - Robot journey test for the rail → bar resize flow.
  - `firebase.json` hosting block + `.firebaserc` wired for the
    `crewpoint-dev` Firebase Hosting target with a flavor-aware
    `predeploy` hook (`flutter build web --release --dart-define=FLAVOR=dev`).
  - Conditional Drift connection: native (mobile) uses persistent SQLite,
    web compiles against Drift's Wasm backend (no `dart:ffi` in the JS
    bundle).
  - Riverpod 3 strict-build guard fix: `currentRouteProvider` mutations
    deferred off the build phase via `Future.microtask`.
  - Manual user steps still pending: `flutterfire configure` rerun (or
    hand-edit `firebase.json` per `docs/flutterfire-reconfigure.md`),
    Firebase Hosting site provisioning, `firebase target:apply`, deploy.

### Added — Repo polish (this release)

- `LICENSE` (MIT, Sookoon Space, 2026).
- `CONTRIBUTING.md` — branching, conventional commits, test/analyze
  gates, links to the setup, web-hosting, and Cloud Functions docs.
- `.github/PULL_REQUEST_TEMPLATE.md` with a checklist enforcing
  `flutter analyze`, `flutter test`, the no-Firebase-init test
  invariant, and release-drafter labels.
- GitHub Actions workflows:
  - `flutter.yml` — analyze + test on every PR; grep guard rejects PRs
    that initialize Firebase from `test/`.
  - `web-build.yml` — `flutter build web --release` triggered only when
    `lib/**`, `web/**`, `pubspec.yaml`, `pubspec.lock`, or `firebase.json`
    change.
  - `functions.yml` — `npm ci && npm run build` on Node 22, only when
    `functions/**` or `firebase.json` change.
  - `release-drafter.yml` + `.github/release-drafter.yml` — auto-drafts
    GitHub Releases from PR labels (`feature` / `fix` / `docs` / `chore`
    / `breaking`).
- `CHANGELOG.md` (this file), backfilled with the prior milestones below.

## Backfill — Pre-release milestones

These shipped before the changelog was wired up. Listed here for history;
GitHub Releases will start fresh at the first tagged version.

### Phase 9 (Spec: `tasks-budget-chat-spec.md`) — close-out

- Cloud Functions deployment guide (`docs/cloud-functions-guide.md`)
  with the function registry as the source of truth for every deployed
  CF.

### Phase 8 — urgent push notifications

- `onUrgentMessageCreated` Firestore trigger fans urgent chat messages
  out via FCM with topic-aware suppression.
- `IFcmGateway` test seam wraps `firebase_messaging`; tests use
  `RecordingFcmGateway`.
- Foreground banner suppression keyed on `currentRouteProvider` so
  in-app users on the chat screen don't see redundant banners.

### Phase 7 — chat polish + Drift cache

- `ChatRepository` mirrors the Firestore stream into Drift (last 200
  messages per event) for instant cold-start renders.
- "Unknown member" coalescing for messages from users who left the
  event.

### Phase 6 — settlement dispute path

- `disputeSettlement` Cloud Function posts a tap-to-dispute notice in
  chat after a settle deep-link returns.
- `DisputeSheet` UI with optional reason field.

### Phase 5 — pay handles + deep-link settle

- Profile editor adds Venmo / CashApp handle fields persisted to
  `users/{uid}.paymentHandles`.
- `PayLinkBuilder` produces Venmo / CashApp deep links from
  `BalanceLedger` settlement rows.
- `IUrlLauncher` test seam wraps `package:url_launcher`;
  `PendingSettlementNotifier` confirms / disputes on app return.

### Phase 4 — receipt upload

- Expense receipts upload to Firebase Storage; thumbnails render in the
  expense list.
- Storage rules gate by event membership.

### Phase 3 — per-event currency, splits persistence, live stream

- `EventModel.currency` (default USD) drives display formatting
  throughout Budget.
- Expense splits persisted in Firestore subcollections;
  `BalanceLedger` runs greedy net-balance settlement (no platform deps).

### Phase 2 — task detail + checklist persistence

- Task detail page with checklist editor;
  `TaskChecklistItemsDao` mirrors checklist items into Drift.

### Phase 1 — Tasks vertical slice + foundations

- `TaskRepository` with Firestore source of truth + Drift mirror.
- `markTaskComplete` Cloud Function server-stamps completion metadata.
- RBAC double-enforced: UI gating via `TaskModel.canChangeStatus`,
  rules + CF on the server.

### Earlier milestones

- Promote / demote Cloud Functions for event admins.
- Event delete / archive / leave flows.
- Member management + invite sheet.
- Dashboard wiring + event dashboard + join sheet.
- Initial event Cloud Functions (4).
- Firestore rules RBAC + `deleteUserAccount` clean-up of `memberIds`.
- `EventModel` expansion with RBAC, types, Drift schema migration.
- Reusable image service + profile refresh.
- Storage rules + `firebase.json` deployment wiring.
- Abstract interfaces for all 5 repositories.
- User repository + profile editor redesign.
