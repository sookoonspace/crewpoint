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

### Phase 1: CF reuse-if-valid (transactional)

- **Goal**: `generateInviteCode` defaults to reuse; explicit `rotate: true` opts into rotation; race-safe via `runTransaction`.

- [ ] **Audit existing tests** in `functions/test/cloud-functions.test.ts`. Any test asserting "two calls → two different codes" must update to either reuse-assertion (the new default) or pass `rotate: true` explicitly. Don't add new cases on top of stale assumptions.
- [ ] `functions/src/events/generateInviteCode.ts` — modify:
  - Strict coercion: `data.rotate === true ? rotate : reuse`. Avoid `Boolean(...)` (treats `'false'` as truthy).
  - **Reuse path** (default): wrap in `db.runTransaction`. Inside: query `event_invites where eventId == eventId orderBy('createdAt', 'desc')`. If non-expired exists → return its id (= the code). If multiple non-expired exist → return most-recent + delete siblings (`logger.warn` for self-heal). Else: delete expired docs + generate new with collision-retry + write inside the transaction.
  - **Rotate path** (`rotate === true`): preserve existing batch behavior. Add a code comment noting simultaneous rotate calls can race; accepted V1.
  - Permission check (admin/owner) BEFORE the transaction.
  - Structured logs: on entry `{op, mode, uid, eventId}`; on success `{code, existingCode}`.
- [ ] TDD: fresh call (no code, rotate unset) → returns a new code; doc persisted at `event_invites/{code}`.
- [ ] TDD: second call (existing non-expired, rotate unset) → returns SAME code; doc unchanged.
- [ ] TDD: third call with `rotate: true` → returns NEW code; existing doc deleted.
- [ ] TDD: existing-but-expired code → reuse path deletes expired doc and issues fresh.
- [ ] TDD: pre-seed two non-expired docs for one eventId → reuse returns most-recent AND deletes the older sibling (warn log fires).
- [ ] TDD: `rotate: 'true'` (string, not boolean) treated as `false` (reuse).
- [ ] TDD: unauthenticated rejection holds for both `rotate: true` and `rotate: false` paths.
- [ ] TDD: non-admin rejection holds for both branches.
- [ ] Verify: `pushd functions && npm test && popd` passes; full suite green (audited + new).

### Phase 2: Invite Members tile on event detail

- **Goal**: Admin/owner sees an Invite Members tile under the Members preview that opens the existing `AddMemberSheet`. End-to-end vertical slice — proves the new CF reuse logic works through the actual UI path.

- [ ] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart`:
  - Add `add_member_sheet.dart` import.
  - Reuse the existing private `_QuickLinkCard` widget (icon / label / subtitle / color / onTap params already match). Don't introduce a new widget class.
  - Wrap in a `Consumer` (don't convert the whole screen to ConsumerWidget — minimal-diff convention).
  - Visibility: `if (uid == null || !event.isAdmin(uid)) return const SizedBox.shrink();` — explicit null guard avoids relying on `event.isAdmin('')` semantics.
  - Place between `_MembersPreview` and the first `_QuickLinkCard` (Chat).
  - Tap: `AddMemberSheet.show(context: context, eventId: event.id)`.
  - Add `Key('eventDashboard.inviteMembers.tile')` for tests.
  - Icon: `Icons.person_add_rounded`; color: `AppColors.terracotta`; label: `'Invite Members'`; subtitle: `'Share a code to add people'`.
- [ ] TDD: tile is visible to admin uid (`currentUserIdProvider` overridden to `event.creatorId`).
- [ ] TDD: tile is hidden to non-admin member uid.
- [ ] TDD: tile is hidden when `currentUserIdProvider` returns null.
- [ ] TDD: tapping the tile opens `AddMemberSheet` (assert `find.byType(AddMemberSheet)` after `pumpAndSettle`; the sheet's offline-error UI is fine because the CF isn't initialized in tests).
- [ ] Robot journey extend (`test/journeys/create_event_journey_test.dart`): after the existing tap-tile → EventDashboardScreen step, tap Invite Members tile → assert `find.byType(AddMemberSheet)` + offline-error text visible. Dismiss sheet to exit cleanly.
- [ ] Verify: `flutter analyze` && `flutter test`.

### Phase 3: Post-create SnackBar action

- **Goal**: After `CreateEventScreen` submits, the SnackBar gains a "Share invite" action that opens `AddMemberSheet` for the just-created event.

- [ ] `lib/app/features/dashboard/presentation/create_event_screen.dart` `_submit()` success branch — replace bare SnackBar with:
  ```dart
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Event created'),
      action: SnackBarAction(
        label: 'Share invite',
        onPressed: () => AddMemberSheet.show(
          context: messenger.context,
          eventId: event.id,
        ),
      ),
      duration: const Duration(seconds: 6),
    ),
  );
  ```
  6s rationale: Material default ~4s; 6s gives reaction time without loitering.
- [ ] Add `add_member_sheet.dart` import.
- [ ] Capture-before-pop discipline preserved (already in place from PR #3).
- [ ] TDD: success SnackBar contains `Event created` text AND `Share invite` action label.
- [ ] TDD: tapping `Share invite` opens `AddMemberSheet` (`find.byType(AddMemberSheet)` after `pumpAndSettle`); assert the sheet is constructed with the just-created event's id.
- [ ] **Contract test for `messenger.context`**: pump CreateEventScreen → tap submit → SnackBar visible → tap `Share invite` → `AddMemberSheet` rendered → dismiss sheet → dashboard intact (`Key('dashboard.events.list')` or `_EmptyState` finder). Proves the navigator-level path resolves cleanly. If this test fails, pivot to a one-shot Riverpod flag the dashboard reads on next build (per spec fallback).
- [ ] Verify: `flutter analyze` && `flutter test`. Manual smoke on iOS sim + web (`flutter run -d chrome`).

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
