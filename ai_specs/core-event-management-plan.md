## Overview

Implement core Event domain: expanded data model (eventType, RBAC arrays, archive), 4 Cloud Functions (generateInviteCode, joinEvent, removeEventMember, deleteEvent), event dashboard + member management UI, join event flow.

**Spec**: `ai_specs/core-event-management-spec.md` (read this file for full requirements)

## Context

- **Structure**: Feature-first (`lib/app/features/dashboard/`)
- **State management**: Riverpod (Notifier pattern)
- **Reference implementations**: `lib/app/features/profile/presentation/profile_screen.dart` (Sookoon design), `functions/src/account/deleteUserAccount.ts` (CF pattern), `lib/app/core/services/account_deletion_service.dart` (CF client call)
- **Assumptions/Gaps**:
  - JSON-encoded arrays in Drift for adminIds/memberIds — acceptable for V1 (<50 members)
  - `deleteUserAccount.ts` must be updated for `members` → `memberIds` + RBAC
  - Dashboard currently uses placeholder in router — must wire to real screen

## Plan

### Phase 1: Data Model + Drift Schema

- **Goal**: Expand EventModel, update Drift, regenerate code
- [x] `event.dart` — EventType enum, EventStatus (active/archived), adminIds/memberIds, role helpers, nullable startDate, removed location
- [x] `app_database.dart` — eventType, adminIds (JSON), memberIds (JSON) columns; removed location; schema v3
- [x] Drift code regenerated
- [x] `event_repository.dart` — JSON encode/decode for arrays, updated _toDomain/createEvent
- [x] `create_event_screen.dart` — Event type chips, removed location, optional startDate with clear button
- [x] `event_detail_screen.dart` + `event_card.dart` — removed location refs, nullable startDate
- [x] TDD: 10 tests (role helpers, EventType/EventStatus parsing, defaults)
- [x] Fixed test files for nullable startDate (Value() wrapping)
- [x] Verify: 64 tests, 0 warnings

### Phase 2: Firestore Rules + deleteUserAccount Update

- **Goal**: Align all Firestore/CF references to `memberIds` + RBAC rules
- [x] `firestore.rules` — memberIds everywhere, admin-level update, event_invites deny-all
- [x] `deleteUserAccount.ts` — members→memberIds, adminIds removal, ownership to first admin
- [x] `batch.ts` — no changes needed
- [x] Verify: TypeScript compiles, flutter analyze clean

### Phase 3: Cloud Functions (Event Operations)

- **Goal**: 4 callable Cloud Functions for event member management
- [x] `generateInviteCode.ts` — admin/owner check, 6-char code (A-Z,2-9), collision check, invalidates old, 24h TTL
- [x] `joinEvent.ts` — code verification, expiry check, already-member check, 50-member limit, arrayUnion
- [x] `removeEventMember.ts` — admin/owner + self-removal, owner protection, removes from both arrays
- [x] `deleteEvent.ts` — creator check, subcollection batch delete via commitInChunks, invite code cleanup
- [x] `index.ts` — exports all 4 new functions
- [x] TypeScript compiles clean
- [ ] Deploy: `firebase deploy --only functions --project crewpoint-dev` (manual step)

### Phase 4: Dashboard Wiring + Event Dashboard Screen

- **Goal**: Wire dashboard to real data; create event detail hub
- [x] `dashboard_screen.dart` — ConsumerWidget, join action in app bar, empty state with "Join with Code" button, cream bg
- [x] `event_dashboard_screen.dart` — gradient hero, type badge, dates, member count, quick-link cards (Chat/Budget/Tasks), settings gear
- [x] `join_event_sheet.dart` — 6-char code input, loading, error handling, calls joinEvent CF
- [x] `app_router.dart` — replaced placeholder, added /dashboard/create, /dashboard/event/:eventId, /members routes
- [x] Tests updated for new DashboardScreen (ConsumerWidget, no params)
- [x] Verify: 64 tests, 0 warnings

### Phase 5: Member Management + Invite

- **Goal**: Member list with roles, invite flow, remove flow
- [x] `member_management_screen.dart` — role badges, remove dialog, promote/demote menu, invite FAB
- [x] `add_member_sheet.dart` — offline fallback, CF code gen, large code display, copy/share, regenerate
- [x] Router wired, share_plus added
- [x] Verify: 64 tests, 0 warnings

### Phase 6: Delete Event + Archive + Leave

- **Goal**: Event deletion, archiving, leave event flows
- [x] Archive toggle (admin/owner) with SwitchListTile
- [x] Delete Event: 2-step confirmation dialog → deleteEvent CF → navigates to dashboard
- [x] Leave Event: confirmation dialog → removeEventMember CF (self) → navigates to dashboard
- [x] All CF calls show LoadingAnimation overlay + error snackbar
- [x] Verify: 64 tests, 0 warnings — ALL 6 PHASES COMPLETE

## Risks / Out of scope

- **Risks**:
  - JSON-encoded arrays in Drift make SQL queries for "my events" impossible — `event_repository.dart` must load all events and filter in Dart (`events.where((e) => e.memberIds.contains(uid))`). Acceptable for V1 (<50 events per user, sub-millisecond filtering). V2 migration path: join table (`event_members` table mapping userId↔eventId) for SQL-native queries
  - `deleteUserAccount` update changes production behavior — test thoroughly on dev before deploying to prod
  - Firestore native TTL must be configured manually in Google Cloud Console per project (not code-deployable)
- **Out of scope**:
  - Deep-linking for join codes (V2)
  - Ownership transfer (V2)
  - QR code generation for join codes (V2)
  - Push notifications for member join/remove events
  - Event search/filtering by type
