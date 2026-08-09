# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

CrewPoint — Flutter (Dart SDK `^3.11.5`) collaborative event-management app: events with RBAC, tasks, Splitwise-style budget/settlements, real-time chat, push notifications. Backend is Firebase (Auth, Firestore, Storage, Cloud Functions v2 in TypeScript, Messaging). Three flavors map to three Firebase projects: `crewpoint-dev` / `crewpoint-stg` / `crewpoint-prod`.

## Commands

```bash
# Setup — build_runner is MANDATORY after clone/pull: *.g.dart is gitignored,
# so Drift's generated code does not exist in a fresh checkout.
flutter pub get
dart run build_runner build --delete-conflicting-outputs
cd functions && npm ci && cd ..

# Run (flavor + FLAVOR define must both be passed; .env.<flavor> supplies non-Firebase secrets)
flutter run --flavor dev -t lib/main.dart --dart-define-from-file=.env.dev --dart-define=FLAVOR=dev
flutter run -d chrome -t lib/main.dart --dart-define-from-file=.env.dev --dart-define=FLAVOR=dev  # web: no --flavor

# Test
flutter test
flutter test test/journeys/tasks_journey_test.dart          # single file
flutter test --plain-name 'substring of test name'          # single test
flutter test test/journeys/                                 # robot journey tests only
flutter test --tags screenshots --update-goldens            # regen screenshots/ (skipped by default via dart_test.yaml)

# Lint
flutter analyze          # must be zero issues
dart run custom_lint     # riverpod_lint checks (not covered by flutter analyze)

# Cloud Functions
cd functions && npm run build    # tsc typecheck — a required PR gate
cd functions && npm test         # jest under firebase emulators (firestore + auth)
firebase deploy --only functions --project crewpoint-dev

# Web
flutter build web --release --dart-define=FLAVOR=dev
```

CI (`.github/workflows/flutter.yml`) runs: build_runner → the Firebase-in-tests grep guardrail → `flutter analyze` → `flutter test`. `web-build.yml` additionally does a release web build when `lib/`, `web/`, or pubspec/firebase.json change.

## Architecture

### Layering

`lib/app/core/` (cross-feature) + `lib/app/features/<feature>/` where every feature is split `data/` (repositories, remote services, pure utilities) · `domain/` (models, repository interfaces) · `application/` (Riverpod notifiers/providers) · `presentation/` (screens, widgets). Features: `auth`, `budget`, `chat`, `dashboard`, `onboarding`, `profile`, `tasks`, `dev`.

### Firestore is the source of truth; Drift is a read mirror

`EventRepository`, `TaskRepository`, `ExpenseRepository`, `ChatRepository` all follow the same shape:

- Writes go straight to Firestore (the SDK's offline queue handles reconnect).
- A per-key (`uid`, `eventId`, `eventId/taskId`) Firestore listener mirrors snapshots into Drift; the UI watches the Drift stream so cold starts render instantly.
- **`kIsWeb` forks to the raw Firestore stream** — Drift on web is Wasm/in-memory, so mirroring buys nothing there. Any new mirrored stream needs the same fork.
- Mirror subscriptions are torn down through `ref.onDispose(() => repo.disposeMirror(key))` in the provider, not by the repository itself.

Drift schema is at v7 with explicit migrations in `lib/app/core/database/app_database.dart`; tables are declared inline there, DAOs in `database/daos/`. Bumping the schema means adding a migration step *and* a `test/database/migration_vN_to_vN+1_test.dart`.

### Providers

`lib/app/core/providers.dart` is the composition root — nearly every service, repository, and stream provider is declared there by hand. **Riverpod codegen is not used** despite `riverpod_generator` being in dev_dependencies: notifiers are hand-written `Notifier`/`NotifierProvider`. Follow the existing style rather than introducing `@riverpod`.

### Router

`createRouter(...)` in `lib/app/core/router/app_router.dart` is constructed **once** in `_MyAppState.initState` and driven by a `_RouterRefresh` `ChangeNotifier` passed as `refreshListenable`. Auth/onboarding changes call `refresh()` — never rebuild or recreate the router (the old pattern tore down the route stack). `onRouteChanged` defers its `currentRouteProvider` write onto a microtask because GoRouter's redirect runs during build and Riverpod 3 forbids mid-build mutation. `currentRouteProvider` exists so FCM foreground banners can suppress themselves when the user is already on the target screen.

### Test seams

Every platform call is behind an interface so tests never touch a real SDK: `IAuthService`, `IUserRepository`, `IFcmGateway`, `IChatService`, `IUrlLauncher`, `IFileExporter`, `IAppBadgePlatform`, `INotificationChannels`, `IDeviceTimezone`, `AppLifecycleSource`, and injected `Clock` for time-sensitive logic (e.g. the settle-confirm window). Adding a new platform dependency means adding a seam + provider, not calling the plugin from a widget.

Conditional imports handle compile-time platform splits: `database/connection/native.dart` vs `web.dart`, `services/file_export_service_native.dart` vs `_web.dart` (`if (dart.library.html)`).

### RBAC

Double-enforced. Client gates UI via `Event.isOwner` / `isAdmin` / `isMember` and per-feature predicates (`TaskModel.canChangeStatus`); `firestore.rules` and the Cloud Functions enforce the same contract server-side. Privileged mutations are callables, not direct writes — `joinEvent`, `removeEventMember`, `promoteToAdmin`, `demoteAdmin`, `deleteEvent`, `markTaskComplete`, `disputeSettlement`, `generateInviteCode`, `deleteUserAccount`. Firestore triggers (`onUrgentMessageCreated`, `onTaskAssigned`, `onExpenseCreated`, `onSettlementDisputed`, `onMemberJoined`, `onTaskDueScheduled`, `onDigestSummary`) drive push. All exported from `functions/src/index.ts`; `docs/cloud-functions-guide.md` holds the authoritative Function Registry.

Firestore data model: `events/{eventId}` with `messages`, `tasks` (+ `tasks/{id}/checklist`), `expenses` subcollections; `event_invites/{code}`; `users/{uid}` with `private`, `chatReads`, `eventMutes` subcollections.

### UI conventions

- Design tokens live in `core/constants/` (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppSizes`, `AppIcons`, `Breakpoints`, `wcag.dart`). Screens read themed tokens from `Theme.of(context).colorScheme` — `AppColors` feeds `AppTheme.light()/dark()`; hardcoding a palette constant in a widget defeats dark mode.
- User-facing strings go through `context.strings` (`core/i18n/app_strings.dart`), shaped so an ARB-backed adapter can drop in later. Don't inline literals in UI.
- `ResponsiveShell` switches bottom-nav → NavigationRail at 840 px; `ContentMaxWidth` + `Breakpoints.screenHorizontalPadding(context)` are the canonical page wrappers.
- Dart 3.10+ dot-shorthand enum syntax (`brightness: .light`) is used in newer code.

### Flavors and config

`AppFlavor.current` reads `--dart-define=FLAVOR=` (defaults to `dev` when absent, which is what `flutter test` gets). Firebase config is generated per flavor into `lib/firebase_options_{dev,stg,prod}.dart` by `flutterfire configure` — never hand-edit. `.env*` files are gitignored and currently only hold placeholders; `lib/app/core/env/env.dart` has the envied wiring commented out until a real non-Firebase secret exists.

## Testing

- **Never call `Firebase.initializeApp()` or `FirebaseService.initialize()` from `test/`.** A CI grep fails the build on it. Use Riverpod overrides on the service seams instead.
- Unit tests use `NativeDatabase.memory()` for Drift and `fake_cloud_firestore` for Firestore. Pure utilities (`PayLinkBuilder`, `BalanceLedger`) have no Flutter/Firebase imports at all — keep them that way.
- Widget/journey tests select by stable keys named `domain.feature.action` — `Key('budget.settle.venmo')`, `Key('tasks.tile.{id}.status')`. Adding an interactive widget means adding a key.
- `test/journeys/` drives flows through `*Robot` classes (`test/robots/`) over harnesses (`test/harness/`) that seed Drift + fake Firestore and stub auth. Extend an existing robot/harness rather than pumping widgets ad hoc.
- Robots use bounded pumps instead of `pumpAndSettle` where a Drift/Firestore mirror keeps emitting — `pumpAndSettle` deadlocks there.

## Conventions

Conventional Commits (`feat(scope):`, `fix(scope):`, …), subject ≤ 72 chars, imperative, no trailing period. Branches `feat/` `fix/` `docs/` off `main`. PRs need at least one release-drafter label (`feature`/`fix`/`docs`/`chore`/`breaking`). Lints beyond `flutter_lints`: `always_use_package_imports` and `avoid_print` are **errors**, strict casts/inference/raw-types are on, single quotes and `prefer_final_locals` enforced.

## Where things are documented

- `ai_specs/` — `<feature>-spec.md` (requirements) + `<feature>-plan.md` (phased implementation log) for every major change; `ai_specs/todo.md` is the backlog; `ai_specs/setup-guide.md` is required reading before a first run.
- `docs/cloud-functions-guide.md` — deploy lifecycle, IAM, rollback, emulators, function registry.
- `docs/web-hosting-guide.md`, `docs/firebase-hosting-dev-deploy.md` — Firebase Hosting.
- `docs/guide/` — end-to-end scenario walkthroughs; `docs/guide/GAPS.md` lists known product gaps.
- `docs/qa/` — manual QA + push-notification test guides.

## ACT Workflow

ACT workflow storage for new Specs is configured in `.act/config.yaml`.

ACT workflow semantics, Workflow Storage selection, artifact vocabulary, and domain-doc guidance are defined in `.act/workflow.md`.
