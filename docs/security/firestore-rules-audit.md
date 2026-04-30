# Firestore Rules Audit

**Scope**: `firestore.rules` (post Phase 1 + Phase 2 hardening) and `storage.rules`.
**Test coverage**: `functions/test/firestore-rules.test.ts` — 15 emulator-driven tests, all green.

## Access Matrix

Actor abbreviations: **anon** = unauthenticated; **user** = signed-in non-member; **member** = `request.auth.uid in event.memberIds`; **admin** = `request.auth.uid in event.adminIds`; **creator** = `event.creatorId == request.auth.uid`. Membership rules nest, so creator ⊆ admin ⊆ member.

| Path | Read | Create | Update | Delete |
| --- | --- | --- | --- | --- |
| `events/{eventId}` | member | self-as-creator | admin/creator (Fix 1.A field guards block memberIds/adminIds/creatorId mutation) | creator only |
| `events/{eventId}/messages/{messageId}` | member | member (self as senderId) | denied | self (sender) |
| `events/{eventId}/tasks/{taskId}` | member | member (self as createdBy + eventId match) | admin/creator/assignee (Fix 1.C field guards block eventId/createdBy mutation) | creator/admin/createdBy |
| `events/{eventId}/tasks/{taskId}/checklist/{itemId}` | member | admin/creator/createdBy | admin/creator/createdBy/assignee | admin/creator/createdBy |
| `events/{eventId}/expenses/{expenseId}` | member | member (self as payerId) | denied | payerId or event creator |
| `event_invites/{code}` | denied to all clients (Admin SDK only) | denied | denied | denied |
| `users/{uid}` | any signed-in user (display projection only) | self | self | self |
| `users/{uid}/private/{docId}` (Fix 1.B Option A) | self | self | self | self |

## Per-rule findings

### `events/{eventId}` update

- **Fix 1.A applied** (`firestore.rules:21-33`). Without the field-level guard, the previous rule allowed admins to mutate `memberIds`, `adminIds`, and `creatorId` directly — bypassing the `promoteToAdmin`, `demoteAdmin`, `removeEventMember` Cloud Functions. Tests cover admin-self-promotes-other (denied), admin-removes-member (denied), creator-renames-event (allowed).
- Lower-stakes follow-up: write-shape allow-listing on `events` create + update. Currently any field shape is accepted as long as the actor checks pass. Intent-only, deferred.

### `events/{eventId}/tasks/{taskId}` update

- **Fix 1.C applied** (`firestore.rules:67-78`). Without the guard, an assignee could rewrite `eventId` (move the task to a different event) or `createdBy` (claim authorship). Tests cover both bypasses (denied) plus assignee-updates-status (allowed).
- Cost: rule still calls `eventDoc()` which is a single `get()` per request. Acceptable.

### `users/{uid}` (Fix 1.B Option A — projection-split)

- Rule unchanged on the public doc — display fields (`displayName`, `photoUrl`, `paymentMethod`, `paymentHandle`, `venmoHandle`, `cashappHandle`, `currency`) remain readable to every authenticated user. This preserves the chat / tasks / budget co-member display path (`lib/app/features/chat/application/users_by_id_provider.dart`).
- New `users/{uid}/private/{docId}` subcollection match restricts PII (`email`, `providerIds`, `fcmTokens`, `preferences`, `createdAt`, `updatedAt`) to self-only access. Tests cover self-read/write (allowed), non-self-read/write (denied).
- **Migration required**: existing user docs carry PII at the top level until `functions/scripts/migratePiiToPrivate.ts` runs. Sequencing: deploy migration → deploy rules. Without the migration, the new rule does not actually protect existing PII.
- Dart-side support: `lib/app/features/profile/data/firestore_user_repository.dart` reads public + private (graceful fallback for permission-denied on non-self), splits writes accordingly. FCM tokens write into the private subdoc.

### `event_invites/{code}`

- Rule denies all client access (`allow read, write: if false`). Cloud Functions (`joinEvent`, `generateInviteCode`) use the Admin SDK and bypass rules entirely. Spec's request to "audit CF coverage" reframed in plan as "verify no client dart code attempts direct event_invites reads" — grep audit confirms no `lib/` reference except the CFs.

### `users/{uid}/private` write surface

- Self-only `read, write` rule is symmetric — no `create`/`update`/`delete` differentiation. Acceptable for V1 because the only writers are the Dart repo (server-paths through CFs are Admin-SDK and bypass rules anyway).

## `get()` cost flagging

| Path | `get()` count per request | Notes |
| --- | --- | --- |
| `events/{eventId}` read/update/delete | 0 | Direct check on `resource.data` |
| `events/{eventId}/messages/{*}` read/create | 1 | `isEventMember(eventId)` calls `get()` |
| `events/{eventId}/tasks/{*}` read | 1 | `isEventMember(eventId)` |
| `events/{eventId}/tasks/{*}` create | 1 | `isEventMember(eventId)` |
| `events/{eventId}/tasks/{*}` update | 1 | `eventDoc()` |
| `events/{eventId}/tasks/{*}` delete | 1 | `eventDoc()` |
| `events/{eventId}/tasks/{taskId}/checklist/{*}` create/delete | 2 | one for parent task, one for `eventDoc()` |
| `events/{eventId}/tasks/{taskId}/checklist/{*}` update | up to 2 | task doc + `eventDoc()` |
| `events/{eventId}/expenses/{*}` delete | 1 | event doc lookup for creator-fallback |
| `users/{uid}` and `users/{uid}/private/{*}` | 0 | Self-equality check, no lookups |

The 2-`get()` checklist rules are the audit's only flag. Each `get()` is a billed read. For very chatty checklist write workloads, consider denormalizing `task.createdBy` and `event.creatorId`/`event.adminIds` onto the checklist parent doc and reading from `request.resource.data` instead. Out of scope for this audit; revisit if checklist read bills inflate.

## Storage rules (Fix 1.D)

- `users/{uid}/profile.jpg` and `events/{eventId}/receipts/{filename}` previously matched `image/.*`, which admits `image/svg+xml` (XSS surface). Replaced with explicit allow-list `image/(jpeg|png|heic|webp)` (`storage.rules:10`, `storage.rules:31`).
- `users/{uid}/{allPaths=**}` self-only write rule has no MIME guard — acceptable because the only writer is the user's own client and there's no public read for arbitrary paths under this prefix.

## Out of scope (tracked for follow-ups)

- Write-shape allow-listing on `events`, `tasks`, `expenses` create + update. Adding it requires per-feature schema audit so backward-compat client writes don't break.
- DPDP Act (India) compliance clauses on user-doc shape — separate spec.
- Field-level read-time projection (e.g., hide `paymentHandle` from non-co-members). The current public read exposes all display fields; out of scope for V1.

## Sign-off checkpoint

This audit reflects `firestore.rules` and `storage.rules` at the SHA at which Phase 2 commits land. Re-run `npm --prefix functions test` after any rule edit and update the test coverage list above.
