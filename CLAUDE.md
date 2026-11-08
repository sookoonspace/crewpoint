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
flutter test test_acceptance/                               # acceptance suite; red can be a planned gap

# Lint
flutter analyze          # must be zero issues
dart run custom_lint     # riverpod_lint checks (not covered by flutter analyze)

# Cloud Functions
cd functions && npm run build    # tsc typecheck — a required PR gate
cd functions && npm test         # jest under firebase emulators (firestore + auth)
cd functions && npm run test:acceptance   # backend acceptance suite under the emulators
firebase deploy --only functions --project crewpoint-dev

# Web
flutter build web --release --dart-define=FLAVOR=dev
```

CI (`.github/workflows/flutter.yml`) runs: build_runner → the Firebase-in-tests grep guardrail → `flutter analyze` → `flutter test`. `web-build.yml` additionally does a release web build when `lib/`, `web/`, or pubspec/firebase.json change. `functions.yml` runs `npm run build` and `npm test` on changes to `functions/**`, `firestore.rules`, `storage.rules`, `firestore.indexes.json` or `firebase.json`. `acceptance.yml` runs both acceptance suites and fails only if a scenario in `test_acceptance/finished_scenarios.json` goes red.

## Architecture

Keep the Architecture sections below, including RBAC and the Firestore data model, up to date as each Stage 1 slice lands.

### Layering

`lib/app/core/` (cross-feature) + `lib/app/features/<feature>/` where every feature is split `data/` (repositories, remote services, pure utilities) · `domain/` (models, repository interfaces) · `application/` (Riverpod notifiers/providers) · `presentation/` (screens, widgets). Features: `auth`, `budget`, `chat`, `dashboard`, `onboarding`, `profile`, `tasks`, `dev`.

### Firestore is the source of truth; Drift is a read mirror

`EventRepository`, `TaskRepository`, `ExpenseRepository`, `ChatRepository` all follow the same shape:

- Writes go straight to Firestore (the SDK's offline queue handles reconnect).
- A per-key (`uid`, `eventId`, `eventId/taskId`) Firestore listener mirrors snapshots into Drift; the UI watches the Drift stream so cold starts render instantly.
- **`kIsWeb` forks to the raw Firestore stream** — Drift on web is Wasm/in-memory, so mirroring buys nothing there. Any new mirrored stream needs the same fork.
- Mirror subscriptions are torn down through `ref.onDispose(() => repo.disposeMirror(key))` in the provider, not by the repository itself.

Drift schema is at v12 with explicit migrations in `lib/app/core/database/app_database.dart`; tables are declared inline there, DAOs in `database/daos/`. Bumping the schema means adding a migration step *and* a `test/database/migration_vN_to_vN+1_test.dart`.

### Providers

`lib/app/core/providers.dart` is the composition root — nearly every service, repository, and stream provider is declared there by hand. **Riverpod codegen is not used** despite `riverpod_generator` being in dev_dependencies: notifiers are hand-written `Notifier`/`NotifierProvider`. Follow the existing style rather than introducing `@riverpod`.

### Router

`createRouter(...)` in `lib/app/core/router/app_router.dart` is constructed **once** in `_MyAppState.initState` and driven by a `_RouterRefresh` `ChangeNotifier` passed as `refreshListenable`. Auth/onboarding changes call `refresh()` — never rebuild or recreate the router (the old pattern tore down the route stack). `onRouteChanged` defers its `currentRouteProvider` write onto a microtask because GoRouter's redirect runs during build and Riverpod 3 forbids mid-build mutation. `currentRouteProvider` exists so FCM foreground banners can suppress themselves when the user is already on the target screen.

### Test seams

Every platform call is behind an interface so tests never touch a real SDK: `IAuthService`, `IUserRepository`, `IFcmGateway`, `IChatService`, `IUrlLauncher`, `IFileExporter`, `IAppBadgePlatform`, `INotificationChannels`, `IDeviceTimezone`, `IAppInfo`, `IAppConfigSource`, `IPageReloader`, `MemberCalls` (role and member callables; `FakeMemberCalls` in `test/harness/` writes what the server would), `AppLifecycleSource`, and injected `Clock` for time-sensitive logic (e.g. the settle-confirm window). Adding a new platform dependency means adding a seam + provider, not calling the plugin from a widget.

Conditional imports handle compile-time platform splits: `database/connection/native.dart` vs `web.dart`, `services/file_export_service_native.dart` vs `_web.dart` (`if (dart.library.html)`).

### RBAC

Double-enforced through the permission catalogue (#66). The client gates UI with `event.can(uid, permission)`, `event.contributes(uid)` (adding your own expense or task, which Observer and Vendor cannot; they also read only tasks assigned to them and expenses they paid or share in, unless their role holds `tasks.manage`, `money.read` or `expenses.readAll`, so their queries filter on `assigneeId` and `involvedUids`, chosen by `taskReadScopeProvider` and `expenseReadScopeProvider`; without `chat.send` the chat entries are hidden) and `event.isOwner(uid)`. For the signed-in person these read `myPermissions` from their member document, so they update live when a role changes. `firestore.rules` checks one permission with one member-document read (reading chat needs `chat.send`), and functions use `requirePermission` in `functions/src/events/members.ts`. Check the named permission, never `creatorId`, `adminIds` or a role name. Privileged mutations are callables, not direct writes — `createEvent`, `changeEventCurrency`, `setMemberRoles`, `saveEventRole`, `deleteEventRole`, `saveCrew`, `setCrewMembers`, `deleteCrew`, `offerOwnership`, `acceptOwnership`, `cancelOwnershipOffer`, `joinEvent`, `removeEventMember`, `promoteToAdmin`, `demoteAdmin`, `deleteEvent`, `markTaskComplete`, `saveExpense`, `recordSettlement`, `disputeSettlement`, `generateInviteCode`, `deleteUserAccount`. Firestore triggers push only to people who may read the record, through `functions/src/events/access.ts`, which mirrors the rules (`onUrgentMessageCreated`, `onTaskAssigned`, `onExpenseCreated`, `onSettlementDisputed`, `onMemberJoined`, `onTaskDueScheduled`, `onDigestSummary`) drive push. `onEventStatusScheduled` moves events to `live` and `ended`. All exported from `functions/src/index.ts`; `docs/cloud-functions-guide.md` holds the authoritative Function Registry.

Firestore data model: `events/{eventId}` with `messages`, `tasks` (+ `tasks/{id}/checklist`), `expenses`, `members`, `roles`, `crews` and `ownership` (the pending offer) subcollections; `organizers/{uid}` (a person's personal organizer, written only by the server, holding `verified`); `event_invites/{code}`; `config/app` (public read, no client write; `minVersion` and optional `storeUrls.ios` / `storeUrls.android`, set from the console); `users/{uid}` with `private`, `chatReads`, `eventMutes` subcollections.

Events carry `templateId`, `organizerId`, `timeZone`, `venues`, `currency`, `languages`, `status`, `modules`, `labels`, `settings`, `capacity` and `memberLimit`, and need only a title. `eventType` survives on older events as display text only. Older events lack the new fields, so reads must fall back to the same defaults as `createEvent`.

Event dates are calendar dates: with `dateOnly: true` they are stored as midnight UTC on the chosen date, and read through `event.displayStart` and `displayEnd`, never `startDate` directly. Other times show through `event.inZone`, and a chosen day converts with `event.startOfDay`. Helpers are in `core/format/event_time.dart`.

`events/{id}/members/{uid}` holds `uid`, `roleIds`, `crewIds`, `permissions`, `participantId` and `joinedAt`. Only server code writes it, and `permissions` is always worked out from `roleIds` by `computePermissions` in `functions/src/events/permissions.ts`, which holds the catalogue and the twelve presets. The app reads the same presets from `functions/src/shared/role_presets.json`, generated by `npm run gen:roles`; a test fails if it falls behind. An event has exactly one Owner. Ownership moves only by an offer the new owner accepts (`offerOwnership`, `acceptOwnership`), and the old owner becomes a Co-owner; `creatorId` and `organizerId` follow it. Crews (`crews/{crewId}`, a name) are written only by the crew callables, which keep `crewIds` on member documents in step; a task's optional `crewId` must name a crew that exists. An event has one active invite, `event_invites/{code}`, carrying a `roleId` that `joinEvent` applies. The app loads that file into `RoleCatalogue.current` at startup, as it does label defaults, and `resolveRoles` merges it with the event's `roles` documents (`eventRolesProvider`). The Roles (`roles`), Role editor (`roles/:roleId`, `new` for a custom role) Member detail (`members/:uid`), Crews (`crews`) and Transfer ownership (`transfer`) screens live in `dashboard/presentation/roles/`; Transfer is open to the Owner, Co-owners (read-only) and the person offered, who also sees a banner on the event (`ownershipOfferProvider`); Crews needs `members.manage` or `tasks.manage` to open and `members.manage` to change. Tasks carry an optional `crewId`, and the crew picker, filter and grouping show only when the event has crews (`eventCrewsProvider`); seeing them needs `members.manage` or `roles.manage`, and changing roles needs `roles.manage`. An event's own `roles/{roleId}` documents override a preset or add a custom role. "My events" is a collection-group query on member documents (`members.uid` index), then each event document. The arrays stay until a later removal step, so every membership change still writes both, `adminIds` holds anyone with Owner, Co-owner or Admin, and the members list still reads `memberIds`. Functions fall back to the arrays for an event with no member documents. Tests: the fake Firestore sends collection-group results only once, so harnesses override `membershipsSourceProvider` with `fakeMemberships`, and rules tests get member documents from `getTestEnv`.

`modules` turns `tasks`, `budget` and `chat` on and off, and a module missing from the map is on. Turned-off modules keep their data. New server paths and rules for a module must check `isModuleOn`, and routes use `ModuleGuard`.

`status` is `draft`, `published`, `live`, `ended` or `archived`, and new events start as `draft`. Older events may still hold `active` until the #65 migration, which reads as `ended` past the end date, or else `published`. `firestore.rules` and `functions/src/events/eventStatus.ts` enforce what each status allows, and `EventModel` mirrors that for the UI. Plain members must never be in a draft, because list queries cannot filter them out in rules: anything that adds a plain member has to refuse drafts.

Below `config/app.minVersion`, `AppUpdateGate` in `MaterialApp.router`'s `builder` replaces the app with an upgrade screen: a store link on mobile, a reload on web. Android falls back to the Play Store page for the package, while iOS needs `storeUrls.ios`. If the document can't be read within five seconds, the app carries on.

### UI conventions

- Design tokens live in `core/constants/` (`AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppSizes`, `AppIcons`, `Breakpoints`, `wcag.dart`). Screens read themed tokens from `Theme.of(context).colorScheme` — `AppColors` feeds `AppTheme.light()/dark()`; hardcoding a palette constant in a widget defeats dark mode.
- User-facing strings go through `context.strings` (`core/i18n/app_strings.dart`), shaped so an ARB-backed adapter can drop in later. Don't inline literals in UI.
- Words for general concepts (member, group, session and the rest of `GLOSSARY.md`) come from `event.words`, so organizers can rename them. Defaults live in `functions/src/shared/label_defaults.json`, which the app loads as an asset and functions import, so edit only that file. Backend text uses `resolveLabel`.
- `ResponsiveShell` switches bottom-nav → NavigationRail at 840 px; `ContentMaxWidth` + `Breakpoints.screenHorizontalPadding(context)` are the canonical page wrappers.
- Dart 3.10+ dot-shorthand enum syntax (`brightness: .light`) is used in newer code.

### Flavors and config

`AppFlavor.current` reads `--dart-define=FLAVOR=` (defaults to `dev` when absent, which is what `flutter test` gets). Firebase config is generated per flavor into `lib/firebase_options_{dev,stg,prod}.dart` by `flutterfire configure` — never hand-edit. `.env*` files are gitignored and currently only hold placeholders; `lib/app/core/env/env.dart` has the envied wiring commented out until a real non-Firebase secret exists.

### Dependency ceilings

Two dependencies are deliberately held back. **Both have their full reasoning in `pubspec.yaml` comments at the constraint itself — read those before attempting a bump.**

- **`analyzer` is capped below 9** by `custom_lint_core` (`analyzer ^8.0.0`) and `riverpod_lint` (`analyzer >=7.0.0 <9.0.0`). This holds `drift`, `drift_dev`, `build_runner`, and `sqlite3` at their current versions. `drift_dev` is a victim of the cap, not a cause. Lint coverage of the 36 hand-written providers was chosen over version currency.
- **`sqlite3_flutter_libs` is held at 0.5.x.** `0.6.0+eol` is an intentionally emptied package — upstream removed all its code because `sqlite3` 3.x bundles the native libraries. Taking it deletes the iOS/Android native SQLite build integration Drift relies on. The real migration needs `drift >= 2.32.1` → `analyzer >= 10.0.0`, so it is blocked by the ceiling above.

Riverpod codegen (`riverpod_annotation` / `riverpod_generator`) was removed as unused, not rejected on merit — every provider is a hand-written `Notifier`. Adoption is tracked separately and would be its own migration.

## Testing

- **Never call `Firebase.initializeApp()` or `FirebaseService.initialize()` from `test/` or `test_acceptance/`.** A CI grep fails the build on it. Use Riverpod overrides on the service seams instead.
- Backend tests run on the `demo-crewpoint` project, which can only reach emulators. `crewpoint-dev` holds real data, so no automated test may write to a real project.
- `test_acceptance/` holds scenario tests, whose names start with the scenario ID, and one fixture per template (`fixtures/templates.json`). When a scenario is finished, add its ID to `finished_scenarios.json` so CI protects it.
- Unit tests use `NativeDatabase.memory()` for Drift and `fake_cloud_firestore` for Firestore. Pure utilities (`PayLinkBuilder`, `BalanceLedger`) have no Flutter/Firebase imports at all — keep them that way.
- Widget/journey tests select by stable keys named `domain.feature.action` — `Key('budget.settle.venmo')`, `Key('tasks.tile.{id}.status')`. Adding an interactive widget means adding a key.
- `test/journeys/` drives flows through `*Robot` classes (`test/robots/`) over harnesses (`test/harness/`) that seed Drift + fake Firestore and stub auth. Extend an existing robot/harness rather than pumping widgets ad hoc.
- Robots use bounded pumps instead of `pumpAndSettle` where a Drift/Firestore mirror keeps emitting — `pumpAndSettle` deadlocks there.

## Naming

Code uses only the general terms in `GLOSSARY.md`. CI fails if `family`, `meal`, `derod`, `wedding`, `cricket`, `golf` or `tee` appear as whole words in identifiers or user-facing strings in `lib/` or `functions/src/`, including `mealCount` and `meal_count`. Comments, Riverpod's `.family`, `fontFamily` and the template data are exempt. Any other exception goes in `listedExceptions` in `test_acceptance/naming_guardrail.dart`, but first move the word into a template, label or setting.

## Conventions

Conventional Commits (`feat(scope):`, `fix(scope):`, …), subject ≤ 72 chars, imperative, no trailing period. Branches `feat/` `fix/` `docs/` off `main`. PRs need at least one release-drafter label (`feature`/`fix`/`docs`/`chore`/`breaking`). Lints beyond `flutter_lints`: `always_use_package_imports` and `avoid_print` are **errors**, strict casts/inference/raw-types are on, single quotes and `prefer_final_locals` enforced.

**`pubspec.yaml` constraints carry the exact resolved version, never a rounded floor** — `google_fonts: ^8.2.1`, not `^8.0.0`. After `flutter pub get` resolves, read the real version out of `pubspec.lock` and write it back as the caret floor. Keep the caret; this is about the floor being accurate, not about pinning. A rounded floor lets a fresh resolve pick a version nobody tested, so the constraint stops describing what was actually verified. Applies to new packages and upgrades alike.

## Where things are documented

- `ai_specs/` — `<feature>-spec.md` (requirements) + `<feature>-plan.md` (phased implementation log) for every major change; `ai_specs/todo.md` is the backlog; `ai_specs/setup-guide.md` is required reading before a first run.
- `docs/cloud-functions-guide.md` — deploy lifecycle, IAM, rollback, emulators, function registry.
- `docs/web-hosting-guide.md`, `docs/firebase-hosting-dev-deploy.md` — Firebase Hosting.
- `docs/guide/` — end-to-end scenario walkthroughs; `docs/guide/GAPS.md` lists known product gaps.
- `docs/qa/` — manual QA + push-notification test guides.

## ACT Workflow

ACT workflow storage for new Specs is configured in `.act/config.yaml`.

ACT workflow semantics, Workflow Storage selection, artifact vocabulary, and domain-doc guidance are defined in `.act/workflow.md`.
