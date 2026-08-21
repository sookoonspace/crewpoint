# CrewPoint

[![Flutter CI](https://github.com/sookoonspace/crewpoint/actions/workflows/flutter.yml/badge.svg?branch=main)](https://github.com/sookoonspace/crewpoint/actions/workflows/flutter.yml)
[![Web Build CI](https://github.com/sookoonspace/crewpoint/actions/workflows/web-build.yml/badge.svg?branch=main)](https://github.com/sookoonspace/crewpoint/actions/workflows/web-build.yml)
[![Functions CI](https://github.com/sookoonspace/crewpoint/actions/workflows/functions.yml/badge.svg?branch=main)](https://github.com/sookoonspace/crewpoint/actions/workflows/functions.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Collaborative event management for crews — tasks, shared expenses, chat, all in one place.**

CrewPoint pairs a project-management mental model (tasks with assignees, statuses,
checklists) with a trip-management one (Splitwise-style balance ledger, deep-link
settlements via Venmo / CashApp) and stitches them together with real-time chat
that includes opt-in urgent push for time-sensitive alerts. Built Firebase-first
with offline-friendly local mirrors so the UI stays responsive even on a flaky
campsite signal.

## Features

- **Events with RBAC** — Owner / admin / member roles enforced server-side via
  Cloud Functions and Firestore rules. Promote, demote, remove, leave, archive,
  delete — every transition is gated.
- **Tasks** — List view with status toggle (To Do / In Progress / Done), assignee,
  due date, and checklist. Server-stamped completion (`markTaskComplete` CF) and
  RBAC enforced both client-side (UI gating) and server-side (rules + CF).
- **Budget & settlements** — Per-event currency, persisted expense splits, receipt
  uploads to Firebase Storage, and a `BalanceLedger` that surfaces the minimum
  set of payments to settle the group. Settle via deep links to Venmo or
  CashApp, confirm on app return, and post a tap-to-dispute notice in chat.
- **Chat** — Live Firestore stream mirrored into Drift (last 200 messages cached
  per event for instant cold-start renders). Urgent toggle (terracotta bubble)
  fans out via FCM through the `onUrgentMessageCreated` Firestore trigger;
  foreground banners suppress when the user is already on the chat screen.

## Tech stack

- **Flutter** 3.47.0 / **Dart** 3.13.0
- **State management** — [Riverpod](https://riverpod.dev) 3 with hand-written
  `Notifier` classes (codegen not yet adopted; matches existing project
  convention)
- **Navigation** — [go_router](https://pub.dev/packages/go_router) 17 with a
  `currentRouteProvider` for context-free FCM suppression checks
- **Firebase** — Auth, Firestore, Storage, Cloud Functions (TypeScript v2),
  Messaging
- **Local persistence** — [Drift](https://drift.simonbinder.eu) (SQLite),
  schema v7 with explicit migrations
- **Other** — `image_picker`, `url_launcher`, `cloud_functions`,
  `fake_cloud_firestore` (tests), `clock` (tests)

## Project layout

```
lib/app/
  core/
    constants/         AppColors, AppSpacing, AppRadius, AppTypography
    database/          Drift tables (inline) + DAOs
    router/            go_router config + currentRouteProvider
    services/          Cross-feature services (FcmGateway, UrlLauncher,
                       AppLifecycleSource, ChatService, ImageService,
                       AccountDeletionService, …)
    widgets/           Shared UI primitives (PrimaryButton, CustomTextField, …)
    providers.dart     Top-level provider wiring
  features/
    auth/              Auth flows; sealed AuthState
    budget/            Expense repo, BalanceLedger, settle flow,
                       PayLinkBuilder, PendingSettlementNotifier
    chat/              ChatRepository (Firestore + Drift mirror),
                       MessageBubble (settlement variant), DisputeSheet
    dashboard/         Events list, event hub, member management
    onboarding/        First-launch flow
    profile/           Profile editor (Venmo + CashApp handles)
    tasks/             TaskRepository, checklist, RBAC-gated tile
functions/             Firebase Cloud Functions (TypeScript)
docs/                  Deployment + ops guides
ai_specs/              Feature specs, plans, roadmap (todo.md)
```

Each feature follows the same four-layer split: `data/` (repositories + remote
services), `domain/` (models + repository interfaces), `application/`
(Riverpod notifiers + providers), `presentation/` (screens + widgets).

## Getting started

```bash
git clone git@github.com:sookoonspace/crewpoint.git
cd crewpoint
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift codegen
flutter test                                               # 859 tests, 4 skipped
flutter run --flavor dev -t lib/main.dart                  # iOS / Android
```

Firebase configuration (project setup, FlutterFire CLI, IAM, flavor switching)
is documented in **[ai_specs/setup-guide.md](ai_specs/setup-guide.md)** — read
that before first run.

### Build flavors

Three Firebase projects, one app:

- `crewpoint-dev` (default for development)
- `crewpoint-stg` (staging)
- `crewpoint-prod` (production)

Launcher icons per flavor: `flutter_launcher_icons-{dev,stg}.yaml` + the
default `flutter_launcher_icons.yaml`. Multi-flavor wiring lives in
`firebase.json` and the platform-specific build configs.

## Cloud Functions

All CFs live under `functions/src/` grouped by feature. Build + deploy:

```bash
cd functions && npm run build && cd ..
firebase deploy --only functions --project crewpoint-dev
```

The full deployment workflow — IAM setup, flavor-aware deploys, rollback,
emulator usage, troubleshooting — is in
**[docs/cloud-functions-guide.md](docs/cloud-functions-guide.md)**. The
Function Registry section there is the source of truth for every deployed
function.

## Testing

```bash
flutter test                                # 859 tests, 4 skipped
flutter test test/journeys/                 # robot journey tests only
cd functions && npm run build && cd ..      # TypeScript typecheck for CFs
flutter analyze                             # lint
```

Test patterns:

- **Unit** — Repositories use in-memory Drift (`NativeDatabase.memory()`) and
  `fake_cloud_firestore`. Pure utilities (e.g. `PayLinkBuilder`,
  `BalanceLedger`) have no Flutter / Firebase imports.
- **Widget** — Pumped with stable `Key('domain.feature.action')` selectors;
  e.g. `Key('budget.settle.venmo')`, `Key('tasks.tile.{id}.status')`.
- **Robot** — `test/journeys/` orchestrates user flows via `*Robot` classes
  (`test/robots/`) with deterministic harnesses (`test/harness/`).

## Architecture pointers

- **Firestore is the source of truth.** Repositories like `TaskRepository`,
  `ExpenseRepository`, and `ChatRepository` subscribe to Firestore streams and
  mirror changes into Drift; the UI reads from the Drift watch so cold starts
  render instantly. Per-`(eventId, …)` mirror subscriptions are torn down via
  `ref.onDispose`.
- **Pure utilities live in `data/`** — `PayLinkBuilder` builds Venmo / CashApp
  URIs without touching Flutter; `BalanceLedger` runs a greedy net-balance
  settlement algorithm with no platform deps.
- **Test seams everywhere a platform call hides.** `IFcmGateway` wraps
  `firebase_messaging`, `IUrlLauncher` wraps `url_launcher`, `AppLifecycleSource`
  wraps `WidgetsBindingObserver`, `Clock` is injected for time-sensitive logic
  (e.g. the 30-second settle confirm window). Tests never call the real SDK.
- **RBAC is double-enforced.** UI hides what the current user can't do (gates
  via `Event.isOwner` / `isAdmin` / `isMember` and per-feature predicates like
  `TaskModel.canChangeStatus`); rules + Cloud Functions enforce the same
  contract server-side regardless of client trust.

## Screenshots

> **Placeholder captures.** Generated by tagged golden-style tests in
> `test/screenshots/` and committed under `screenshots/`. Each carries
> a "PLACEHOLDER — replace before public launch" overlay so they
> cannot accidentally ship as marketing material. Re-generate with
> `scripts/regenerate-screenshots.sh` after editing the helpers; the
> default `flutter test` skips the `screenshots` tag entirely (see
> `dart_test.yaml`).

| Screen | Mobile (375×812) | Desktop (1280×800) |
| --- | --- | --- |
| Dashboard | ![Dashboard mobile](screenshots/dashboard-mobile.png) | ![Dashboard desktop](screenshots/dashboard-desktop.png) |
| Budget | ![Budget mobile](screenshots/budget-mobile.png) | ![Budget desktop](screenshots/budget-desktop.png) |
| Tasks | ![Tasks mobile](screenshots/tasks-mobile.png) | ![Tasks desktop](screenshots/tasks-desktop.png) |
| Chat | ![Chat mobile](screenshots/chat-mobile.png) | ![Chat desktop](screenshots/chat-desktop.png) |

## Contributing

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for branching, commit-message
conventions, and the analyze / test / typecheck gates a PR must clear.

## License

[MIT](LICENSE) © Sookoon Space.

## Roadmap

Deferred items, feature backlog, and known gaps live in
**[ai_specs/todo.md](ai_specs/todo.md)** (Kanban view, multi-currency display,
real settlement reconciliation, full offline-first sync engine, FCM bootstrap
wiring, robot journey coverage for Budget + Chat, and more).

Feature specs and execution plans for each major phase are kept under
`ai_specs/` (`*-spec.md` for requirements, `*-plan.md` for the phased
implementation log).
