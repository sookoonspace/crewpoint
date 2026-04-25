<goal>
Implement the central Event domain for CrewPoint — event creation, categorization (trip/project/social/custom), role-based access control (owner/admin/member), member management (join codes, removal), and offline-first data layer. This is the hub that Tasks, Chat, and Budget attach to.

Benefits all users: event creators get organization tools, members get shared context, and the RBAC model ensures only authorized users modify event settings.
</goal>

<background>
- **State management**: Riverpod (Notifier pattern)
- **Local DB**: Drift (SQLite) — offline-first, synced to Firestore
- **Backend**: Firestore + Cloud Functions (Node.js/TypeScript, 2nd gen)
- **Existing code**:
  - `lib/app/features/dashboard/domain/models/event.dart` — minimal EventModel (missing eventType, adminIds, memberIds)
  - `lib/app/core/database/app_database.dart` — Events table (missing eventType, adminIds, memberIds columns)
  - `lib/app/features/dashboard/data/event_repository.dart` — Drift-based CRUD (implements IEventRepository)
  - `firestore.rules` — uses `members` field name (spec uses `memberIds` — must align)
  - `functions/src/index.ts` — has placeholder for event functions
- **Naming alignment**: Firestore rules currently reference `event.data.members`. Spec uses `memberIds`. Decision: use `memberIds` everywhere (Firestore + Drift + Dart) and update rules.
- **Naming convention**: `camelCase` for all database fields (Firestore + Drift) and Dart variables. No `snake_case` mapping layer. This matches existing codebase conventions and Firestore best practices.
</background>

<user_flows>

## Primary Flow: Create Event
1. User taps "+" FAB on Dashboard
2. Create Event form: title (required), event type dropdown (trip/project/social/custom), description, start date, end date (optional)
3. User taps "Create"
4. Event saved to Drift first (offline-first), then synced to Firestore
5. User is automatically `creatorId`, added to `adminIds` and `memberIds`
6. Redirected to Event Dashboard screen

## Primary Flow: Invite Member
1. Owner/Admin opens Member Management screen
2. Taps "Invite" button
3. Loading indicator while Cloud Function `generateInviteCode` executes
4. Add Member Sheet appears with:
   - Server-generated 6-character join code (returned from Cloud Function)
   - Share button (copies code to clipboard / system share sheet)
5. Invited user opens CrewPoint → enters join code (via Join Event Sheet)
6. Cloud Function `joinEvent` verifies code → adds user to `memberIds`
7. New member sees event in their Dashboard

**Note**: Code generation happens server-side because `event_invites` collection denies all client writes. The Cloud Function generates the code, checks for collisions, saves to Firestore, and returns the code to the client.

## Primary Flow: Remove Member
1. Owner/Admin opens Member Management screen
2. Swipes left on a member row (or taps menu)
3. Confirmation dialog: "Remove [Name] from this event?"
4. Calls Cloud Function `removeEventMember`
5. Member removed from `memberIds` (and `adminIds` if applicable)
6. Their past messages/expenses remain but they lose access

## Primary Flow: Delete Event
1. Owner opens Event Settings
2. Taps "Delete Event" in danger zone
3. Multi-step confirmation dialog (matching existing DeleteAccountDialog pattern)
4. Calls Cloud Function `deleteEvent`
5. Server deletes event + all subcollections (messages, expenses, tasks)
6. All members see event disappear from their Dashboard

## Alternative Flows
- **Promote to Admin**: Owner taps member → "Make Admin" → adds to `adminIds`
- **Demote Admin**: Owner taps admin → "Remove Admin Role" → removes from `adminIds` (stays in `memberIds`)
- **Archive Event**: Owner/Admin sets status to "archived" → event moves to archived section, read-only
- **Leave Event**: Any member can leave voluntarily → same as removal but self-initiated

## Primary Flow: Join Event (Invitee Side)
1. User taps "Join Event" button on Dashboard (top-bar action or empty-state prompt)
2. Join Event Sheet appears with a 6-character code input field
3. User enters code → taps "Join"
4. Loading indicator during Cloud Function call
5. On success: event appears in dashboard, sheet dismisses
6. On error: "Invalid or expired code" / "You're already a member"

## Error Flows
- **Invalid join code**: Show "Invalid or expired code" message
- **Join code for event user is already in**: Show "You're already a member of this event"
- **Network failure during creation**: Event saved locally in Drift, synced when online
- **Remove last admin (who isn't owner)**: Allowed — owner is always implicit admin
- **Delete event with network failure**: Show error, don't clear local data until server confirms
</user_flows>

<requirements>

## Functional

### Data Model
1. Expand `EventModel` with: `eventType` (enum: trip/project/social/custom), `adminIds` (List<String>), `memberIds` (List<String>), remove `location` (use description instead)
2. Update `EventStatus` enum: `active`, `archived` (remove `completed`/`cancelled` — use `archived` for all non-active states)
3. Drift `Events` table: add `eventType` (text), `adminIds` (text, JSON-encoded), `memberIds` (text, JSON-encoded) columns. Remove `location`. Bump schema version.
4. `startDate` should be nullable (not all events have dates — e.g., ongoing projects)

### Firestore Schema
5. `events/{eventId}` document matches the model: id, title, description, eventType, startDate, endDate, creatorId, adminIds, memberIds, status, createdAt, updatedAt
6. Rename `members` → `memberIds` in Firestore rules to match schema
7. Update `isEventMember` helper to check `memberIds` (which always includes creatorId and adminIds)

### RBAC
8. Permission checks in UI: hide edit/delete/invite buttons based on role
9. Permission checks in Firestore rules (apply to **direct client writes only** — Cloud Functions use Admin SDK and bypass rules):
   - `create`: authenticated user, must set self as creatorId
   - `read`: must be in memberIds
   - `update`: must be in adminIds or be creatorId. Client writes limited to: event details (title, description, dates, eventType, status)
   - `delete`: must be creatorId only
   - `event_invites/{code}`: deny all client reads/writes (managed entirely by Cloud Functions via Admin SDK)
10. Permission checks in Cloud Functions: verify caller role before executing
11. `event_invites` TTL cleanup: use **native Firestore TTL policy** on `expiresAt` field (set in Google Cloud Console → Firestore → TTL Policies). Auto-deletes expired codes for free — no scheduled Cloud Function needed.

### Cloud Functions (Server-Side)
12. `generateInviteCode({eventId})` — caller must be admin/owner → generates unique 6-char code (A-Z, 2-9), saves to `event_invites/{code}` with `expiresAt` (24h), invalidates any existing code for the event, returns code to client
13. `joinEvent({joinCode})` — verifies code from `event_invites/{code}` (not expired) → adds caller to event's `memberIds`
14. `removeEventMember({eventId, targetUserId})` — caller must be admin/owner → removes target from `memberIds`/`adminIds`
15. `deleteEvent({eventId})` — caller must be creatorId → batch delete event + subcollections (using `commitInChunks` from existing `utils/batch.ts`)
16. `event_invites/{code}` Firestore collection: `{ eventId, createdBy, createdAt, expiresAt }` — codes expire after 24 hours via native TTL

### Event Creation
15. Generate UUID for eventId client-side
16. Auto-populate: creatorId = current user, adminIds = [creatorId], memberIds = [creatorId]
17. Save to Drift first → sync to Firestore (offline-first)

### Member Invitation
18. Code generation is **server-side only** via `generateInviteCode` Cloud Function — client cannot write to `event_invites`
19. Code format: 6-character alphanumeric (uppercase, no ambiguous chars: no 0/O, 1/I/L)
20. Stored in `event_invites/{code}` with 24-hour TTL (auto-cleaned by native Firestore TTL policy)
21. Only admins/owner can call `generateInviteCode` (verified server-side)
22. Generating a new code invalidates any existing code for that event
23. Client displays returned code + share via clipboard or system share sheet

## Error Handling
22. Invalid/expired join code → "This code is invalid or has expired"
23. User already a member → "You're already part of this event"
24. Network failure on event creation → saved locally, auto-sync when online
25. Remove member fails → show error snackbar, don't update local state
26. Delete event fails → show error, keep event in UI until server confirms
27. All Cloud Function calls (join/remove/delete/invite) show loading state: button loading indicator or `LoadingAnimation` overlay during execution. Match existing patterns (DeleteAccountDialog processing step).

## Edge Cases
27. Owner cannot be removed from their own event
28. Owner cannot leave their own event (must delete or transfer ownership — V2)
29. Last admin removal is allowed (owner is always implicit admin)
30. Event with 0 admins (besides owner): owner retains all admin permissions
31. Join code reuse: codes are unique, checked for collision before saving
32. Concurrent join attempts with same code: Cloud Function handles atomically

</requirements>

<boundaries>

**Event Limits:**
- Max 50 members per event (V1) — show "Event is full" if exceeded
- Max title length: 200 characters
- Max description length: 2000 characters

**Join Code:**
- 6-character alphanumeric (A-Z, 2-9 only)
- Expires after 24 hours
- One code per event at a time (generating new invalidates old)

**Deletion:**
- Server-side only via Cloud Function
- Batch deletes using 500-doc chunking (existing pattern)
- Auth user deletion during account delete also handles event cleanup (existing `deleteUserAccount` function)

**Offline:**
- Event creation works offline (Drift first)
- Member operations require network (Cloud Functions)
- Show "Requires internet" message for invite/remove/delete when offline

</boundaries>

<implementation>

### Files to Create
- `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — event detail hub (details + member avatars + sub-feature links)
- `lib/app/features/dashboard/presentation/member_management_screen.dart` — member list with roles, remove action
- `lib/app/features/dashboard/presentation/widgets/add_member_sheet.dart` — join code display + share
- `lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart` — 6-char code entry for invitees
- `lib/app/features/dashboard/application/event_members_provider.dart` — member list + role management
- `functions/src/events/generateInviteCode.ts` — server-side code generation + save to event_invites
- `functions/src/events/joinEvent.ts` — join code verification + member addition
- `functions/src/events/removeEventMember.ts` — member removal
- `functions/src/events/deleteEvent.ts` — event + subcollection deletion

### Files to Modify
- `lib/app/features/dashboard/domain/models/event.dart` — add eventType, adminIds, memberIds; update EventStatus
- `lib/app/core/database/app_database.dart` — add columns, bump schema
- `lib/app/features/dashboard/data/event_repository.dart` — update CRUD for new fields
- `lib/app/features/dashboard/presentation/create_event_screen.dart` — remove location field, add event type dropdown
- `lib/app/features/dashboard/presentation/dashboard_screen.dart` — convert to ConsumerWidget, wire to event provider, replace router placeholder
- `lib/app/core/router/app_router.dart` — add event dashboard + member management routes, replace dashboard placeholder with real screen
- `firestore.rules` — update `members` → `memberIds`, add admin-level update rule, add `event_invites` deny-all rule
- `functions/src/index.ts` — export new event functions
- `functions/src/account/deleteUserAccount.ts` — rename all `members` → `memberIds`, transfer ownership to first admin (not first member), handle `adminIds` array removal
- `functions/src/utils/batch.ts` — (if needed) update any `members` references

### Patterns to Follow
- Existing Sookoon design system: cream bg, flat cards, sage/terracotta accents
- Cloud Functions: 2nd gen (`onCall`), `commitInChunks` for batch ops, 120s timeout
- Repository pattern: abstract interface (`IEventRepository`) + concrete implementation
- Riverpod Notifier pattern for state management

### What to Avoid
- Client-side member removal — always use Cloud Functions for authorization-critical operations
- Storing role as a string on each member — use arrays (adminIds) for efficient querying
- Deep-linking for V1 — use manual code entry (deep links are V2)

</implementation>

<validation>

### Unit Tests (TDD)
- EventModel with new fields (eventType, adminIds, memberIds) round-trips correctly
- EventStatus enum serialization (active/archived)
- Role helper: `isOwner(uid)`, `isAdmin(uid)`, `isMember(uid)` return correct booleans
- Join code generation: 6 chars, correct character set, no ambiguous chars

### Widget Tests
- Create event form validates title required, type selection
- Event dashboard shows correct role-based UI (edit button visible for admin, hidden for member)
- Member management shows remove action only for admins viewing non-owner members
- Add member sheet displays join code

### Integration Tests (Robot)
- Create event → appears in dashboard → open event dashboard → see details
- Generate join code → verify it's displayed and copyable

### Testability Seams
- `IEventRepository` interface for repository swapping
- Cloud Functions tested via Firebase emulator
- Join code generation injectable for deterministic testing

</validation>

<done_when>
1. EventModel has eventType, adminIds, memberIds fields
2. Drift schema updated with new columns (schema version bumped)
3. Create event form includes event type dropdown
4. Event Dashboard screen shows details + member avatars + sub-feature links
5. Member Management screen shows roles, remove action for admins
6. Add Member Sheet generates and displays 6-char join code
7. Cloud Functions deployed: joinEvent, removeEventMember, deleteEvent
8. Firestore rules updated with memberIds + admin-level permissions
9. All unit/widget tests pass
10. `flutter analyze` zero warnings
</done_when>
