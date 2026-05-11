## Overview

Three stages: CF reuse-if-valid (transactional, race-safe) + Invite Members tile on event detail + post-create SnackBar action. No new packages — `share_plus` already in pubspec.

**Spec**: `ai_specs/invite-share-spec.md` (commit `272ea2c`)

## Context

- **Structure**: feature-first under `lib/app/features/`; CFs in `functions/src/events/`.
- **State management**: Riverpod 3 (`currentUserIdProvider` for tile visibility — already wired by PR #3).
- **Reference implementations**:
  - `lib/app/features/dashboard/presentation/widgets/add_member_sheet.dart` — existing share path; `_QuickLinkCard` (private to `event_dashboard_screen.dart`) — reuse for the tile shape.
  - `functions/src/events/generateInviteCode.ts` — current rotate-by-default CF; modify default + add `runTransaction`.
  - `functions/src/account/deleteUserAccount.ts` — pattern for structured logging via `withStructuredLogs`.
  - `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` (existing `_EventActions` Consumer wrap) — Consumer-uid visibility pattern.
  - `test/app/features/dashboard/event_actions_uid_wrap_test.dart` — admin-vs-non-admin visibility test pattern.
  - `test/app/features/dashboard/create_event_screen_test.dart` — happy-path SnackBar testing with `fake_cloud_firestore` + tall viewport.
  - `test/journeys/create_event_journey_test.dart` — extension target for the tile-tap journey step.
- **Assumptions/Gaps**:
  - Existing CF tests in `functions/test/cloud-functions.test.ts` need an audit pass before adding new ones — current rotate-by-default assumptions may break under the new reuse-by-default behavior.
  - `messenger.context` works for `showModalBottomSheet`; Phase 3 has an explicit validation test. If it fails, fall back to a one-shot Riverpod flag the dashboard reads on next build (named in spec).

## Plan

### Phase 1: CF reuse-if-valid (transactional) ✅

- **Goal**: `generateInviteCode` defaults to reuse; explicit `rotate: true` opts into rotation; race-safe via `runTransaction`.

- [x] **Audit existing tests** in `functions/test/cloud-functions.test.ts` — clean. Existing tests cover permission denial + single-call happy path; none assumed rotation. No rewrites needed.
- [x] `functions/src/events/generateInviteCode.ts` — modified: strict `data.rotate === true` coercion, `runTransaction`-wrapped reuse path (all reads before all writes), self-heal for multiple non-expired duplicates, expired-doc cleanup, rotate path preserved with race acceptance comment, structured logs.
- [x] TDD: fresh call returns a new code; doc persisted.
- [x] TDD: second call (existing non-expired) returns SAME code; doc unchanged.
- [x] TDD: `rotate: true` returns NEW code; existing doc deleted.
- [x] TDD: existing-but-expired code → reuse path deletes expired doc and issues fresh.
- [x] TDD: pre-seed two non-expired duplicates → reuse returns most-recent + deletes sibling.
- [x] TDD: `rotate: 'true'` (string) treated as `false` (reuse) — strict-coercion guard.
- [x] TDD: unauthenticated + non-admin rejections already covered by pre-existing tests; uniformly apply to both paths.
- [x] Verify: `npm test` in functions/ passes — 66 tests (61 baseline + 5 new). 100% green per the CRITICAL instruction before Phase 2.

### Phase 2: Invite Members tile on event detail ✅

- **Goal**: Admin/owner sees an Invite Members tile under the Members preview that opens the existing `AddMemberSheet`. End-to-end vertical slice — proves the new CF reuse logic works through the actual UI path.

- [x] `event_dashboard_screen.dart` — added `add_member_sheet.dart` import; reused private `_QuickLinkCard` (added `super.key` to support selector); Consumer-wrap with explicit `if (uid == null || !event.isAdmin(uid)) return SizedBox.shrink()` guard; placed between `_MembersPreview` and the Chat `_QuickLinkCard`; tap → `AddMemberSheet.show(context: context, eventId: event.id)`; `Key('eventDashboard.inviteMembers.tile')`.
- [x] TDD: tile visible to admin uid.
- [x] TDD: tile hidden to non-admin member uid.
- [x] TDD: tile hidden when `currentUserIdProvider` returns null.
- [x] TDD: tapping the tile opens `AddMemberSheet`.
- [x] Robot journey extension: tap tile on event detail → assert sheet visible. CF isn't initialized in tests — sheet renders, that's enough.
- [x] Verify: `flutter analyze` clean; full suite green (318 tests).

### Phase 3: Post-create SnackBar action ✅

- **Goal**: After `CreateEventScreen` submits, the SnackBar gains a "Share invite" action that opens `AddMemberSheet` for the just-created event.

- [x] `create_event_screen.dart` `_submit()` success branch — replaced bare SnackBar with one that has `SnackBarAction(label: 'Share invite')`. Duration 6s.
- [x] **Deviation from spec sketch:** spec said `context: messenger.context`. The contract test caught the predicted issue — `ScaffoldMessenger` sits ABOVE the Navigator, so its context has no Navigator ancestor and `showModalBottomSheet` threw "Navigator operation requested with a context that does not include a Navigator." Fix: use `navigator.context` instead (already captured before pop). The Navigator's own context resolves cleanly. Documented with a code comment.
- [x] Added `add_member_sheet.dart` import to `create_event_screen.dart`.
- [x] Capture-before-pop discipline preserved (from PR #3).
- [x] TDD: success SnackBar contains `Event created` + `Share invite` action.
- [x] TDD: tapping `Share invite` opens `AddMemberSheet`; sheet dismisses → dashboard host intact.
- [x] Contract test passes — `navigator.context` resolves the navigator without the messenger.context issue.
- [x] Verify: `flutter analyze` clean; full suite green (319 tests).
- [ ] Manual smoke iOS sim + web — flagged for user verification.

## Risks / Out of scope

**Risks:**

- **Existing CF test fixture pollution.** The audit step (Phase 1) might reveal that the existing test harness doesn't reset `event_invites` collection state between cases. Under reuse-by-default that pollution shows up as flaky test ordering. Fix: ensure each test seeds + tears down its own fixture state.
- **`messenger.context` navigator-level resolution.** Mitigated by the explicit Phase 3 contract test. If it fails (e.g., the bottom sheet pushes onto the wrong navigator and the dashboard appears wrong after dismiss), pivot to the spec's fallback path (one-shot Riverpod flag). Don't ship until the contract test passes.
- **Rotation race remains.** Two simultaneous `rotate: true` calls from different admin devices can still create duplicate codes — accepted V1 since the rotate path is low-frequency. Reuse path is now race-safe via the transaction.

**Out of scope:**

- Personalization of share text (event title in the message body) — flagged in `docs/v1-utilities-audit.md` Section 2.1 as a future-iteration note.
- QR-code generation — `qr-invite-spec.md` (V1.x).
- Deep-link / universal-link invite URLs — `deep-link-invite-spec.md` (V1.x).
- Navigating directly into the new event after create instead of staying on dashboard — separate UX spec; flagged in spec `<user_flows>`.
- Modifying the share-text format beyond the current "Join my event on CrewPoint! Use code: ABC123."
- New packages — `share_plus` already in pubspec.
- `firestore.rules` changes — `event_invites` stays Admin-SDK-only; all invite logic flows through the CF.
