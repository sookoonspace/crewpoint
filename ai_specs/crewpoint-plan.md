## Overview

Full MVP of CrewPoint — collaborative event management app with offline-first Drift + Firebase sync, Riverpod state management, go_router navigation, auth, chat, tasks, budgeting. Feature-first DDD architecture across 10 phases.

**Spec**: `ai_specs/crewpoint-spec.md` (read this file for full requirements)

## Context

- **Structure**: Feature-first with DDD layers (`domain/`, `data/`, `presentation/`, `application/` per feature)
- **State management**: `flutter_riverpod`
- **Navigation**: `go_router` with `StatefulShellRoute`
- **Backend**: Firebase (Auth, Firestore) + Drift (offline-first local DB)
- **Starting point**: Default counter app — everything built from scratch
- **Reference implementations**: None yet (greenfield)
- **Assumptions/Gaps**:
  - Lottie animation assets not yet provided — use placeholder files, wire up later
  - Firebase project assumed pre-configured; `google-services.json` / `GoogleService-Info.plist` must exist per flavor
  - Firestore security rules authored separately (not Dart code)
  - Receipt upload storage (Cloud Storage) not specified — assume Firebase Storage

## Plan

### Phase 1: Project Foundation & Strict Analysis

- **Goal**: Establish directory skeleton, strict linting, dependencies, and build flavors
- [x] `analysis_options.yaml` — Replace with strict config: `always_use_package_imports`, `prefer_const_constructors`, `avoid_print`, and recommended Flutter lints
- [x] `pubspec.yaml` — Add all Phase 1 deps: `flutter_riverpod`, `go_router`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `drift`, `sqlite3_flutter_libs`, `envied`, `flutter_secure_storage`, `google_fonts`, `lottie`, `google_sign_in`, `sign_in_with_apple`, `image_picker`
- [x] `pubspec.yaml` — Add dev deps: `envied_generator`, `build_runner`, `drift_dev`
- [x] `lib/app/core/constants/app_colors.dart` — Charcoal, sage green, terracotta palette tokens
- [x] `lib/app/core/constants/app_spacing.dart` — Spacing scale (4, 8, 12, 16, 24, 32, 48)
- [x] `lib/app/core/constants/app_radius.dart` — Border radius tokens
- [x] `lib/app/core/constants/app_typography.dart` — Poppins headings, Inter body via `google_fonts`
- [x] Create directory skeleton: `lib/app/core/services/`, `lib/app/features/auth/`, `lib/app/features/onboarding/`, `lib/app/features/dashboard/`, `lib/app/features/tasks/`, `lib/app/features/chat/`, `lib/app/features/budget/`, `lib/app/features/profile/` — each with `domain/`, `data/`, `presentation/`, `application/` subdirs
- [x] `.env.dev`, `.env.stg`, `.env.prod` — Template env files with placeholder keys
- [x] `lib/app/core/env/env.dart` — `envied` config class for build-time secrets
- [x] Configure three build flavors (`dev`, `stg`, `prod`) with distinct app IDs (`space.sookoon.crewpoint.{dev,stg,app}`) — native iOS/Android config
- [x] Verify: `flutter analyze` with zero warnings

### Phase 2: Design System & Core Widgets

- **Goal**: Tokenized themes + reusable widget library
- [x] `lib/app/core/theme/app_theme.dart` — Full Light and Dark `ThemeData` using palette tokens, Poppins/Inter typography
- [x] `lib/app/core/widgets/primary_button.dart` — `PrimaryButton` widget using constants
- [x] `lib/app/core/widgets/destructive_button.dart` — `DestructiveButton` (terracotta)
- [x] `lib/app/core/widgets/custom_text_field.dart` — `CustomTextField` with consistent styling
- [x] `lib/app/core/widgets/dialog_overlay.dart` — `DialogOverlay` modal component
- [x] `lib/app/core/widgets/loading_animation.dart` — Lottie-based loading widget (placeholder asset path)
- [x] TDD: PrimaryButton renders with correct color from AppColors
- [x] TDD: DestructiveButton uses terracotta color token
- [x] TDD: CustomTextField displays hint text and handles input
- [x] TDD: DialogOverlay shows/hides with correct content
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Drift Database & Service Interfaces

- **Goal**: Offline-first local DB as single source of truth; abstract service interfaces for all third-party deps
- [x] `lib/app/core/services/i_chat_service.dart` — Abstract `IChatService` with TODO for E2EE swap
- [x] `lib/app/core/services/i_location_service.dart` — Abstract `ILocationService` with TODO for Phase 2
- [x] `lib/app/core/services/i_auth_service.dart` — Abstract `IAuthService`
- [x] `lib/app/core/services/i_sync_service.dart` — Abstract `ISyncService`
- [x] `lib/app/core/database/app_database.dart` — Drift DB with tables: `Events`, `Tasks`, `Users`, `ChatMessages`, `Expenses`
- [x] `lib/app/core/database/connection/native.dart` — Platform-specific Drift connection (mobile + desktop)
- [x] `lib/app/core/database/connection/web.dart` — Web connection
- [x] `lib/app/core/database/daos/events_dao.dart` — CRUD operations for events
- [x] `lib/app/core/database/daos/tasks_dao.dart` — CRUD operations for tasks
- [x] `lib/app/core/database/daos/users_dao.dart` — CRUD operations for users
- [x] TDD: happy path — insert event into Drift, retrieve it by ID
- [x] TDD: happy path — insert task with event FK, query tasks by event
- [x] TDD: edge case — query empty table returns empty list
- [x] TDD: error — insert duplicate primary key throws/handles gracefully
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Firebase Init & Auth Feature

- **Goal**: Firebase per-flavor init + full auth flow (Google, Apple, Email/Password)
- [x] `lib/app/core/services/firebase_service.dart` — Firebase init per flavor
- [x] `lib/app/features/auth/domain/models/app_user.dart` — User domain model
- [x] `lib/app/features/auth/domain/models/auth_failure.dart` — Typed auth failures
- [x] `lib/app/features/auth/data/firebase_auth_service.dart` — Implements `IAuthService`: Google, Apple, Email/Password sign-in/up
- [x] `lib/app/features/auth/data/auth_repository.dart` — Catches exceptions, returns typed failures
- [x] `lib/app/features/auth/application/auth_provider.dart` — Riverpod providers for auth state
- [x] `lib/app/features/auth/presentation/auth_gate_screen.dart` — Social + email auth UI
- [x] `lib/app/features/auth/presentation/widgets/social_auth_buttons.dart` — Google/Apple buttons
- [x] `lib/app/features/auth/presentation/widgets/email_auth_form.dart` — Email/password form
- [x] `lib/app/core/services/secure_storage_service.dart` — `flutter_secure_storage` wrapper for session tokens
- [x] TDD: auth repository returns typed failure on invalid credentials
- [x] TDD: auth repository returns AppUser on successful sign-in
- [x] TDD: auth provider emits loading → authenticated states
- [x] TDD: auth provider emits loading → error on failure
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 5: Onboarding & App Shell (Router)

- **Goal**: Carousel onboarding → auth gate → main shell with bottom nav
- [x] `lib/app/features/onboarding/presentation/onboarding_screen.dart` — 3-page carousel with Lottie slots + "Data Collection Opt-In" toggle (default OFF)
- [x] `lib/app/features/onboarding/application/onboarding_provider.dart` — Track completion state, persist to secure storage
- [x] `lib/app/core/router/app_router.dart` — `go_router` config: onboarding → auth → main shell
- [x] `lib/app/core/router/app_shell.dart` — `StatefulShellRoute` with bottom nav (Dashboard, Tasks, Chat, Budget, Profile)
- [x] `lib/main.dart` — Replace counter app: `ProviderScope` → `MaterialApp.router` with theme + router
- [x] TDD: onboarding provider — first launch shows onboarding, subsequent launches skip
- [x] TDD: router redirects unauthenticated user to auth gate
- [x] TDD: router redirects authenticated user past auth gate to dashboard
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 6: Dashboard & Event Management

- **Goal**: Dashboard home screen + event CRUD
- [x] `lib/app/features/dashboard/domain/models/event.dart` — Event domain model
- [x] `lib/app/features/dashboard/data/event_repository.dart` — CRUD via Drift DAO, error handling
- [x] `lib/app/features/dashboard/application/dashboard_provider.dart` — Events list provider (from Drift stream)
- [x] `lib/app/features/dashboard/presentation/dashboard_screen.dart` — Event list with create FAB
- [x] `lib/app/features/dashboard/presentation/event_detail_screen.dart` — Event detail view
- [x] `lib/app/features/dashboard/presentation/widgets/event_card.dart` — Event list tile
- [x] `lib/app/features/dashboard/presentation/create_event_screen.dart` — Event creation form
- [x] TDD: event repository saves event to Drift and retrieves it
- [x] TDD: dashboard provider streams events reactively on insert
- [x] TDD: edge case — dashboard shows empty state when no events
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 7: Task Management

- **Goal**: Tasks within events — status tracking, assignees, checklists, file attachments
- [x] `lib/app/features/tasks/domain/models/task.dart` — Task model with status enum, assignee, checklist items
- [x] `lib/app/features/tasks/domain/models/task_attachment.dart` — Attachment model (file path, type)
- [x] `lib/app/features/tasks/data/task_repository.dart` — CRUD via Drift DAO, filter by event/status/assignee
- [x] `lib/app/features/tasks/application/task_provider.dart` — Task list + filter providers
- [x] `lib/app/features/tasks/presentation/task_list_screen.dart` — Filtered task list per event
- [x] `lib/app/features/tasks/presentation/task_detail_screen.dart` — Task detail with checklist + attachments
- [x] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — Task row with status chip
- [x] `lib/app/features/tasks/presentation/create_task_screen.dart` — Task creation form
- [x] TDD: task repository creates task linked to event, retrieves by event ID
- [x] TDD: task status transitions (todo → in_progress → done)
- [x] TDD: checklist item toggle updates task in Drift
- [x] TDD: filter provider returns only tasks matching selected status
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 8: Group Chat

- **Goal**: Real-time Firestore chat per event, critical alerts
- [x] `lib/app/features/chat/data/firestore_chat_service.dart` — Implements `IChatService` via Firestore listeners (TODO comment for E2EE)
- [x] `lib/app/features/chat/domain/models/chat_message.dart` — Message model (text, sender, timestamp, priority flag)
- [x] `lib/app/features/chat/data/chat_repository.dart` — Send/receive messages, cache to Drift
- [x] `lib/app/features/chat/application/chat_provider.dart` — Stream provider for messages per event
- [x] `lib/app/features/chat/presentation/chat_screen.dart` — Message list + input bar
- [x] `lib/app/features/chat/presentation/widgets/message_bubble.dart` — Chat bubble widget
- [x] `lib/app/features/chat/presentation/widgets/critical_alert_modal.dart` — Predefined alert list + custom text modal
- [x] TDD: chat repository sends message and appears in stream
- [x] TDD: chat repository caches received messages to Drift
- [x] TDD: critical alert modal sends high-priority message
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 9: Expense & Budget Tracking

- **Goal**: Expense modal with receipt upload, donation toggle, split calculation
- [x] `lib/app/features/budget/domain/models/expense.dart` — Expense model (amount, payer, receipt path, isDonation, splits)
- [x] `lib/app/features/budget/data/expense_repository.dart` — CRUD via Drift, split calculation logic
- [x] `lib/app/features/budget/application/budget_provider.dart` — Expense list + totals per event
- [x] `lib/app/features/budget/presentation/budget_screen.dart` — Expense list with totals summary
- [x] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — Add expense: amount, receipt upload (`image_picker`), "Donate" toggle, dynamic split
- [x] `lib/app/features/budget/presentation/widgets/expense_tile.dart` — Expense row
- [x] TDD: split calculation — 3 members, $90 expense → $30 each
- [x] TDD: donation toggle excludes payer from split
- [x] TDD: expense repository persists and retrieves by event
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 10: Profile, Privacy, Sync & Polish

- **Goal**: User profile, privacy dashboard, account deletion, Drift↔Firestore sync engine
- [ ] `lib/app/features/profile/presentation/profile_screen.dart` — User info display + edit
- [ ] `lib/app/features/profile/presentation/privacy_dashboard_screen.dart` — List all dependencies used
- [ ] `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart` — Multi-step dialog with password confirmation → local + remote data erasure
- [ ] `lib/app/features/profile/application/profile_provider.dart` — Profile state management
- [ ] `lib/app/core/services/sync_engine.dart` — Implements `ISyncService`: background Drift↔Firestore bidirectional sync
- [ ] `lib/app/core/services/sync_engine.dart` — Conflict resolution strategy (last-write-wins with timestamps)
- [ ] Phase 2 stubs: TODO in `IChatService` for E2EE, map tab UI shell in dashboard for live location (TODO in `ILocationService`), TODO in app lifecycle for biometric lock
- [ ] TDD: sync engine uploads local Drift changes to Firestore
- [ ] TDD: sync engine downloads Firestore changes to Drift
- [ ] TDD: account deletion clears all local Drift tables
- [ ] TDD: app launches with cached Drift data when offline (offline-first verification)
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**:
  - Firebase flavor config (`google-services.json` per flavor) requires manual setup outside Dart — may block Phase 4
  - Drift↔Firestore sync conflict resolution is complex; last-write-wins may lose data in edge cases
  - Lottie assets not provided — phases referencing animations will use placeholders
- **Out of scope**:
  - E2EE implementation (Phase 2 stub only)
  - Live location / Google Maps SDK (Phase 2 stub only)
  - Biometric lock (Phase 2 stub only)
  - Push notification infrastructure (FCM setup)
  - Firestore security rules (authored outside app code)
  - CI/CD pipeline
  - 80% test coverage target — plan focuses on high-value TDD tests; coverage gap filled iteratively
