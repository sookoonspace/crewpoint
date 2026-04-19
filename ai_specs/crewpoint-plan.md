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
- [ ] `lib/app/core/theme/app_theme.dart` — Full Light and Dark `ThemeData` using palette tokens, Poppins/Inter typography
- [ ] `lib/app/core/widgets/primary_button.dart` — `PrimaryButton` widget using constants
- [ ] `lib/app/core/widgets/destructive_button.dart` — `DestructiveButton` (terracotta)
- [ ] `lib/app/core/widgets/custom_text_field.dart` — `CustomTextField` with consistent styling
- [ ] `lib/app/core/widgets/dialog_overlay.dart` — `DialogOverlay` modal component
- [ ] `lib/app/core/widgets/loading_animation.dart` — Lottie-based loading widget (placeholder asset path)
- [ ] TDD: PrimaryButton renders with correct color from AppColors
- [ ] TDD: DestructiveButton uses terracotta color token
- [ ] TDD: CustomTextField displays hint text and handles input
- [ ] TDD: DialogOverlay shows/hides with correct content
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Drift Database & Service Interfaces

- **Goal**: Offline-first local DB as single source of truth; abstract service interfaces for all third-party deps
- [ ] `lib/app/core/services/i_chat_service.dart` — Abstract `IChatService` with TODO for E2EE swap
- [ ] `lib/app/core/services/i_location_service.dart` — Abstract `ILocationService` with TODO for Phase 2
- [ ] `lib/app/core/services/i_auth_service.dart` — Abstract `IAuthService`
- [ ] `lib/app/core/services/i_sync_service.dart` — Abstract `ISyncService`
- [ ] `lib/app/core/database/app_database.dart` — Drift DB with tables: `Events`, `Tasks`, `Users`, `ChatMessages`, `Expenses`
- [ ] `lib/app/core/database/connection/native.dart` — Platform-specific Drift connection (mobile + desktop)
- [ ] `lib/app/core/database/connection/web.dart` — Web connection
- [ ] `lib/app/core/database/daos/events_dao.dart` — CRUD operations for events
- [ ] `lib/app/core/database/daos/tasks_dao.dart` — CRUD operations for tasks
- [ ] `lib/app/core/database/daos/users_dao.dart` — CRUD operations for users
- [ ] TDD: happy path — insert event into Drift, retrieve it by ID
- [ ] TDD: happy path — insert task with event FK, query tasks by event
- [ ] TDD: edge case — query empty table returns empty list
- [ ] TDD: error — insert duplicate primary key throws/handles gracefully
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Firebase Init & Auth Feature

- **Goal**: Firebase per-flavor init + full auth flow (Google, Apple, Email/Password)
- [ ] `lib/app/core/services/firebase_service.dart` — Firebase init per flavor
- [ ] `lib/app/features/auth/domain/models/app_user.dart` — User domain model
- [ ] `lib/app/features/auth/domain/models/auth_failure.dart` — Typed auth failures
- [ ] `lib/app/features/auth/data/firebase_auth_service.dart` — Implements `IAuthService`: Google, Apple, Email/Password sign-in/up
- [ ] `lib/app/features/auth/data/auth_repository.dart` — Catches exceptions, returns typed failures
- [ ] `lib/app/features/auth/application/auth_provider.dart` — Riverpod providers for auth state
- [ ] `lib/app/features/auth/presentation/auth_gate_screen.dart` — Social + email auth UI
- [ ] `lib/app/features/auth/presentation/widgets/social_auth_buttons.dart` — Google/Apple buttons
- [ ] `lib/app/features/auth/presentation/widgets/email_auth_form.dart` — Email/password form
- [ ] `lib/app/core/services/secure_storage_service.dart` — `flutter_secure_storage` wrapper for session tokens
- [ ] TDD: auth repository returns typed failure on invalid credentials
- [ ] TDD: auth repository returns AppUser on successful sign-in
- [ ] TDD: auth provider emits loading → authenticated states
- [ ] TDD: auth provider emits loading → error on failure
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 5: Onboarding & App Shell (Router)

- **Goal**: Carousel onboarding → auth gate → main shell with bottom nav
- [ ] `lib/app/features/onboarding/presentation/onboarding_screen.dart` — 3-page carousel with Lottie slots + "Data Collection Opt-In" toggle (default OFF)
- [ ] `lib/app/features/onboarding/application/onboarding_provider.dart` — Track completion state, persist to secure storage
- [ ] `lib/app/core/router/app_router.dart` — `go_router` config: onboarding → auth → main shell
- [ ] `lib/app/core/router/app_shell.dart` — `StatefulShellRoute` with bottom nav (Dashboard, Tasks, Chat, Budget, Profile)
- [ ] `lib/main.dart` — Replace counter app: `ProviderScope` → `MaterialApp.router` with theme + router
- [ ] TDD: onboarding provider — first launch shows onboarding, subsequent launches skip
- [ ] TDD: router redirects unauthenticated user to auth gate
- [ ] TDD: router redirects authenticated user past auth gate to dashboard
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 6: Dashboard & Event Management

- **Goal**: Dashboard home screen + event CRUD
- [ ] `lib/app/features/dashboard/domain/models/event.dart` — Event domain model
- [ ] `lib/app/features/dashboard/data/event_repository.dart` — CRUD via Drift DAO, error handling
- [ ] `lib/app/features/dashboard/application/dashboard_provider.dart` — Events list provider (from Drift stream)
- [ ] `lib/app/features/dashboard/presentation/dashboard_screen.dart` — Event list with create FAB
- [ ] `lib/app/features/dashboard/presentation/event_detail_screen.dart` — Event detail view
- [ ] `lib/app/features/dashboard/presentation/widgets/event_card.dart` — Event list tile
- [ ] `lib/app/features/dashboard/presentation/create_event_screen.dart` — Event creation form
- [ ] TDD: event repository saves event to Drift and retrieves it
- [ ] TDD: dashboard provider streams events reactively on insert
- [ ] TDD: edge case — dashboard shows empty state when no events
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 7: Task Management

- **Goal**: Tasks within events — status tracking, assignees, checklists, file attachments
- [ ] `lib/app/features/tasks/domain/models/task.dart` — Task model with status enum, assignee, checklist items
- [ ] `lib/app/features/tasks/domain/models/task_attachment.dart` — Attachment model (file path, type)
- [ ] `lib/app/features/tasks/data/task_repository.dart` — CRUD via Drift DAO, filter by event/status/assignee
- [ ] `lib/app/features/tasks/application/task_provider.dart` — Task list + filter providers
- [ ] `lib/app/features/tasks/presentation/task_list_screen.dart` — Filtered task list per event
- [ ] `lib/app/features/tasks/presentation/task_detail_screen.dart` — Task detail with checklist + attachments
- [ ] `lib/app/features/tasks/presentation/widgets/task_tile.dart` — Task row with status chip
- [ ] `lib/app/features/tasks/presentation/create_task_screen.dart` — Task creation form
- [ ] TDD: task repository creates task linked to event, retrieves by event ID
- [ ] TDD: task status transitions (todo → in_progress → done)
- [ ] TDD: checklist item toggle updates task in Drift
- [ ] TDD: filter provider returns only tasks matching selected status
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 8: Group Chat

- **Goal**: Real-time Firestore chat per event, critical alerts
- [ ] `lib/app/features/chat/data/firestore_chat_service.dart` — Implements `IChatService` via Firestore listeners (TODO comment for E2EE)
- [ ] `lib/app/features/chat/domain/models/chat_message.dart` — Message model (text, sender, timestamp, priority flag)
- [ ] `lib/app/features/chat/data/chat_repository.dart` — Send/receive messages, cache to Drift
- [ ] `lib/app/features/chat/application/chat_provider.dart` — Stream provider for messages per event
- [ ] `lib/app/features/chat/presentation/chat_screen.dart` — Message list + input bar
- [ ] `lib/app/features/chat/presentation/widgets/message_bubble.dart` — Chat bubble widget
- [ ] `lib/app/features/chat/presentation/widgets/critical_alert_modal.dart` — Predefined alert list + custom text modal
- [ ] TDD: chat repository sends message and appears in stream
- [ ] TDD: chat repository caches received messages to Drift
- [ ] TDD: critical alert modal sends high-priority message
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 9: Expense & Budget Tracking

- **Goal**: Expense modal with receipt upload, donation toggle, split calculation
- [ ] `lib/app/features/budget/domain/models/expense.dart` — Expense model (amount, payer, receipt path, isDonation, splits)
- [ ] `lib/app/features/budget/data/expense_repository.dart` — CRUD via Drift, split calculation logic
- [ ] `lib/app/features/budget/application/budget_provider.dart` — Expense list + totals per event
- [ ] `lib/app/features/budget/presentation/budget_screen.dart` — Expense list with totals summary
- [ ] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — Add expense: amount, receipt upload (`image_picker`), "Donate" toggle, dynamic split
- [ ] `lib/app/features/budget/presentation/widgets/expense_tile.dart` — Expense row
- [ ] TDD: split calculation — 3 members, $90 expense → $30 each
- [ ] TDD: donation toggle excludes payer from split
- [ ] TDD: expense repository persists and retrieves by event
- [ ] Verify: `flutter analyze` && `flutter test`

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
