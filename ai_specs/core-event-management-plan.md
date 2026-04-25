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
- [ ] `lib/app/features/dashboard/domain/models/event.dart` — Add `eventType` (enum: trip/project/social/custom), `adminIds` (List<String>), `memberIds` (List<String>); remove `location`; update `EventStatus` to active/archived; make `startDate` nullable; add role helpers: `isOwner(uid)`, `isAdmin(uid)`, `isMember(uid)`
- [ ] `lib/app/core/database/app_database.dart` — Add columns: `eventType` (text), `adminIds` (text), `memberIds` (text); remove `location`; bump schema version
- [ ] Run `dart run build_runner build -d`
- [ ] `lib/app/features/dashboard/data/event_repository.dart` — Update `_toDomain` and `createEvent` to handle new fields + JSON encode/decode arrays
- [ ] `lib/app/features/dashboard/presentation/create_event_screen.dart` — Remove location field, add event type dropdown, make startDate nullable
- [ ] TDD: EventModel role helpers — isOwner/isAdmin/isMember return correct booleans
- [ ] TDD: EventStatus serialization — active/archived round-trip
- [ ] TDD: EventModel with adminIds/memberIds round-trips through Drift
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Firestore Rules + deleteUserAccount Update

- **Goal**: Align all Firestore/CF references to `memberIds` + RBAC rules
- [ ] `firestore.rules` — Rename `members` → `memberIds` in `isEventMember` helper; update event read/update/delete rules per RBAC; add admin-level update rule (`request.auth.uid in resource.data.adminIds`); add `event_invites/{code}` deny-all rule
- [ ] `functions/src/account/deleteUserAccount.ts` — Rename all `members` → `memberIds`; transfer ownership to first admin in `adminIds` (not first member); remove user from both `memberIds` and `adminIds`
- [ ] `functions/src/utils/batch.ts` — Update `anonymizeUserInEvent` if it references `members`
- [ ] Verify: `npm run build` in functions/; `flutter analyze`

### Phase 3: Cloud Functions (Event Operations)

- **Goal**: 4 callable Cloud Functions for event member management
- [ ] `functions/src/events/generateInviteCode.ts` — Verify caller is admin/owner; generate 6-char code (A-Z, 2-9); check collision; save to `event_invites/{code}` with `expiresAt` (24h); invalidate existing code for event; return code
- [ ] `functions/src/events/joinEvent.ts` — Verify code exists + not expired; check caller not already member; check 50-member limit; add caller to `memberIds`; return event summary
- [ ] `functions/src/events/removeEventMember.ts` — Verify caller is admin/owner; verify target is not owner; remove from `memberIds` + `adminIds`
- [ ] `functions/src/events/deleteEvent.ts` — Verify caller is creatorId; batch delete event + subcollections (messages, expenses, tasks) using `commitInChunks`
- [ ] `functions/src/index.ts` — Export all 4 new functions
- [ ] `npm run build` — verify TypeScript compiles
- [ ] Deploy per flavor: `firebase deploy --only functions --project crewpoint-dev`

### Phase 4: Dashboard Wiring + Event Dashboard Screen

- **Goal**: Wire dashboard to real data; create event detail hub
- [ ] `lib/app/features/dashboard/presentation/dashboard_screen.dart` — Convert to ConsumerWidget; watch events from provider; show "Join Event" action in app bar; pass event tap to navigate to event dashboard
- [ ] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — Sookoon design: charcoal gradient hero with event title/type/dates; member avatars row; quick-link cards for Chat, Budget, Tasks; settings gear icon (owner/admin only); cream bg, flat cards
- [ ] `lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart` — 6-char code input field; "Join" button with loading state; error message display; calls `joinEvent` CF
- [ ] `lib/app/core/router/app_router.dart` — Replace dashboard placeholder with real DashboardScreen; add routes: `/dashboard/:eventId` (event dashboard), `/dashboard/:eventId/members` (member mgmt)
- [ ] `lib/app/core/providers.dart` — Add event-related providers if needed
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 5: Member Management + Invite

- **Goal**: Member list with roles, invite flow, remove flow
- [ ] `lib/app/features/dashboard/presentation/member_management_screen.dart` — Sookoon design: cream bg; member list with avatar + name + role badge (Owner/Admin/Member); swipe-to-remove for admin/owner viewing non-owner; "Invite" FAB; promote/demote via long-press menu (owner only)
- [ ] `lib/app/features/dashboard/presentation/widgets/add_member_sheet.dart` — **CRITICAL: check internet connectivity before calling CF.** If offline → show fallback: "Requires an internet connection to generate a secure join code." If online → call `generateInviteCode` CF on open; loading state; display 6-char code large + centered; share button (clipboard + system share); "Generate New Code" button
- [ ] `lib/app/features/dashboard/application/event_members_provider.dart` — Notifier: fetches member profiles from user repository; computes role from event's adminIds/creatorId; handles remove/promote/demote via Cloud Functions
- [ ] Wire member management route in router
- [ ] TDD: event_members_provider correctly identifies owner/admin/member roles
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 6: Delete Event + Archive + Leave

- **Goal**: Event deletion, archiving, leave event flows
- [ ] Event Dashboard settings: "Archive Event" toggle (admin/owner) → sets status to "archived"
- [ ] Event Dashboard danger zone: "Delete Event" (owner only) → multi-step dialog matching DeleteAccountDialog pattern → calls `deleteEvent` CF → navigates to dashboard
- [ ] "Leave Event" action for members → calls `removeEventMember` CF with self as target → event removed from their dashboard
- [ ] All Cloud Function calls show loading overlay + error snackbar
- [ ] Verify: `flutter analyze` && `flutter test`

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
