<goal>
Close the V1 launch blocker named in the [V1 utilities audit Section 2.1](../docs/v1-utilities-audit.md#21-invite-share-ux-wiring-pre-decided): the existing Share Invite affordance is buried inside `AddMemberSheet` (which is only reachable from the member-management screen), and there's no nudge to share an invite right after creating an event.

This spec ships three changes:

1. **Reuse non-expired invite codes** — `generateInviteCode` Cloud Function returns the existing code when one is still valid for the event, instead of rotating on every call. Codes already shared via text/email continue working until their 24-hour expiry. An explicit `rotate: true` flag preserves the "Generate New Code" path for the leak-suspicion case.
2. **Surface an Invite Members tile on `EventDashboardScreen`** — admins/owner see a dedicated tile between the Members preview and the Quick links; tapping opens the existing `AddMemberSheet`. Non-admin members don't see the tile.
3. **Add a "Share invite" action to the post-create SnackBar** — after `CreateEventScreen` submits successfully, the SnackBar that already announces "Event created" gains a `SnackBarAction(label: 'Share invite')` that opens the `AddMemberSheet` for the just-created event.

Why it matters: the create-and-invite loop is the most-used flow for a consumer event app. Today users have to (a) create an event, (b) tap into it, (c) tap Members, (d) tap +, (e) finally see the share affordance. We compress to one step on the post-create path and one step on the event detail path.
</goal>

<background>
**Tech stack:** Flutter 3.11.5, Riverpod 3, GoRouter 14, Firebase (Auth/Firestore/Functions), `share_plus` 10.x already in `pubspec.yaml`.

**Existing code in scope:**

- `@functions/src/events/generateInviteCode.ts` — Callable Cloud Function. Today: deletes existing codes for the event, generates a new 6-char code from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, persists at `event_invites/{code}` with 24h expiry, returns `{code}`. Permission-checked (admin/owner only).
- `@functions/test/cloud-functions.test.ts` — exists; will gain new test cases.
- `@lib/app/features/dashboard/presentation/widgets/add_member_sheet.dart` — `AddMemberSheet` already calls the CF on `initState`; has Copy / Share / "Generate New Code" actions. `Share.share('Join my event on CrewPoint! Use code: $_code')` at line 109. `_generateCode()` at line 51 calls the CF with `{eventId}` only.
- `@lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — hero, Members preview, three Quick links, action panel. The `_EventActions` widget already wraps in a `Consumer` reading `currentUserIdProvider` (PR #3). The screen is `StatelessWidget`; will gain a new tile + need its own Consumer wrap or full conversion to ConsumerWidget.
- `@lib/app/features/dashboard/presentation/create_event_screen.dart` — `_submit()` shows `SnackBar(content: Text('Event created'))` after `Navigator.pop(context)`. Captures `messenger` and `navigator` before the await. Holds the event id locally as `event.id` (uuid). The post-create SnackBarAction needs that id.
- `@lib/app/features/dashboard/domain/models/event.dart` — `event.isAdmin(uid)` and `event.isOwner(uid)` already exist; reuse for the visibility check on the new tile.
- `@firestore.rules` — `event_invites/{code}` is `allow read, write: if false` (line 122-124); only the Admin SDK (Cloud Function) writes to that collection. Client cannot read or write `event_invites` directly. Implication: code reuse logic MUST live in the CF, not in the Flutter client.

**Test patterns to mirror:**

- `@functions/test/cloud-functions.test.ts` — existing CF integration test scaffolding.
- `@test/app/features/dashboard/event_actions_uid_wrap_test.dart` — Consumer-uid visibility test pattern.
- `@test/app/features/dashboard/create_event_screen_test.dart` — CreateEventScreen widget tests with `fake_cloud_firestore` + `tall viewport` discipline. The post-create SnackBar test plugs in here.
- `@test/journeys/create_event_journey_test.dart` — extension target for the post-create share action robot journey.

**Constraints from prior decisions:**

- Code-rotation default is **reuse-if-valid** (per spec discussion). Explicit `rotate: true` flag preserves the leak-suspicion path.
- Entry point on event detail is a **dedicated tile**, NOT a direct share button (per spec discussion). Tapping the tile opens the existing `AddMemberSheet`.
- Post-create prompt is a **SnackBar with `Share invite` action**, NOT auto-opening the sheet (per spec discussion).
- Visibility: tile + post-create action both visible only to event admin/owner. Non-admins (regular members) see neither. The CF's permission check is the security boundary; the UI hide is UX-only.
- No new packages — `share_plus` is already wired; this spec is wiring + CF logic only.
</background>

<user_flows>
**Primary flow A — share invite from event detail (admin/owner):**

1. Authenticated admin opens an event from the dashboard → lands on `EventDashboardScreen`.
2. Sees the new "Invite Members" tile under the Members preview card (visible because `event.isAdmin(uid)` evaluates true).
3. Taps the tile → existing `AddMemberSheet` opens via `AddMemberSheet.show(context: ..., eventId: event.id)`.
4. The sheet's `initState` calls `generateInviteCode({eventId})` — CF returns the existing non-expired code (no rotation).
5. Code displays. User taps "Share" → `Share.share('Join my event on CrewPoint! Use code: $_code')` → system share sheet appears.
6. User picks a target (Messages / WhatsApp / etc.) → recipient receives the text → enters code in their `JoinEventSheet` → joins the event.

**Primary flow B — share invite immediately after creating an event:**

1. User taps the dashboard FAB → fills the Create Event form → submits.
2. `CreateEventScreen._submit()` writes the event to Firestore, pops back to the dashboard, and shows the SnackBar: `Event created` with a `Share invite` action button.
3. User taps `Share invite` → `AddMemberSheet.show(context: messenger.context, eventId: createdEvent.id)` opens **as a modal over the dashboard** (not over the event detail screen — the user is still on `/dashboard` at this point).
4. CF generates a brand-new code (no existing code yet for this event); user taps "Share" → system share sheet opens. Same path as flow A from there.
5. After the user dismisses the sheet they're back on the dashboard. They tap the new event tile to enter `EventDashboardScreen` — same flow as opening any other event.
6. If the user ignores the SnackBar, it auto-dismisses after the 6-second timeout. The user can still reach Share from the event detail tile later.

*Note on post-create landing:* the user lands on the dashboard, not on the new event's detail screen. This matches the existing `_submit()` behavior (PR #3 popped back to dashboard). A future spec may consider navigating directly into the new event's detail screen after create, with the SnackBar action then opening the sheet over the event detail — that would feel more "I just made this thing, here it is" but is a larger UX change. Out of scope here.

**Alternative flow — non-admin member opens the event:**

- Tile is hidden. The user sees Members preview + Quick links + (if the existing `_EventActions` shows it) the Leave Event tile. No share affordance — only admins can generate codes per CF permission check; surfacing a button that would error on tap is bad UX.

**Alternative flow — admin already has a code from a prior session:**

- Tap the new Invite Members tile → AddMemberSheet opens → CF returns the same code that was issued before (reuse-if-valid). Codes shared yesterday still work. The "Generate New Code" button inside the sheet rotates explicitly when tapped (sends `rotate: true`).

**Error flows:**

- **Offline / Firebase Functions unreachable** — `_generateCode()` catches `FirebaseFunctionsException` (existing path); error UI in the sheet says "Requires an internet connection to generate a secure join code." Retry button works once back online. The post-create SnackBar action just opens the sheet; the sheet handles the offline case.
- **Caller is not an admin** — should never happen for the new tile since visibility hides it. For the post-create SnackBarAction it never happens either (the user just created the event, so they ARE the creator/admin per the create flow's `creatorId = uid`, `adminIds = [uid]`). But if it does happen via a stale auth state, the sheet's existing `permission-denied` error message ("Only admins can generate invite codes.") fires.
- **CF reuse logic surfaces an expired code** — defensive: should never happen because `expiresAt` is checked before reuse. If a code expired between the lookup and the return, the next call will generate a fresh one.
- **Two admins press Share simultaneously on different devices** — first call to the CF either reuses the existing code or creates one; the second call sees the code (if it was created mid-flight) or reuses (if pre-existing). Single-active-code invariant preserved by the CF's transaction semantics.
</user_flows>

<requirements>
**Functional — Stage 1 (Cloud Function: reuse-if-valid):**

1. `functions/src/events/generateInviteCode.ts` — modify to default to **reuse-if-valid** behavior, wrapped in a `runTransaction` to preserve the single-active-code invariant under concurrent calls:
   - Accept an optional `rotate?: boolean` field on the request data. **Strict coercion: only the literal boolean `true` opts into rotation.** `data.rotate === true ? rotate : reuse`. `'true'`, `1`, truthy objects, etc. are all treated as `false`. (Avoids the `Boolean('false') === true` JS pitfall.)
   - **Reuse path (default, `rotate !== true`):** open a Firestore `runTransaction`. Inside the transaction:
     1. Query `event_invites where eventId == eventId orderBy('createdAt', 'desc')`. (Inside a transaction, snapshot reads are consistent.)
     2. If at least one non-expired doc exists (`expiresAt.toMillis() > Date.now()`): return its `id` (= the code). If multiple non-expired docs exist (data-corruption recovery), return the most-recent one and **delete the siblings in the same transaction** as a self-healing measure; emit a `logger.warn` so the team can investigate upstream.
     3. If no non-expired doc exists: delete any expired docs in the same transaction, generate a new code with the existing collision-retry loop, and write the new code doc inside the transaction.
   - **Rotate path (`rotate === true`):** keep existing batch-based behavior — collect all existing codes for the eventId, batch-delete them, generate a new one with collision-retry. Acceptable to leave non-transactional for this lower-frequency path, BUT: comment in the code that simultaneous `rotate: true` calls from two admin devices could race; the spec accepts this for V1 and revisits if it surfaces in user testing.
   - Permission check (admin/owner) applies to BOTH branches and runs BEFORE the transaction.
   - Logging: emit one `logger.info` on entry with `{op: 'generateInviteCode', mode: rotate ? 'rotate' : 'reuse', uid, eventId}`; emit a second log on success with `{code, existingCode: boolean}`.
2. `functions/test/cloud-functions.test.ts` — **two-step task**:
   - **Audit existing tests first.** Any test that asserts "calling generateInviteCode twice returns two different codes" was relying on the rotate-by-default behavior. Such tests must either (a) be updated to assert reuse (the new default), or (b) explicitly pass `rotate: true` if the test is verifying the rotation path. The plan author starts here, not by adding new tests on top of the old assumptions.
   - **Add new cases:**
     - First call (no code exists, `rotate` unset) → CF returns a new code; doc persisted at `event_invites/{code}`.
     - Second call (existing non-expired code, `rotate` unset) → CF returns the SAME code; doc unchanged.
     - Third call (existing non-expired code, `rotate: true`) → CF returns a NEW code; existing doc deleted; new doc persisted.
     - Fourth call (existing code past `expiresAt`, `rotate` unset) → CF deletes the expired doc and issues a fresh one.
     - Self-heal case: pre-seed `event_invites` with two non-expired docs for one eventId → CF returns the most-recent code AND deletes the older sibling.
     - String-coercion guard: `rotate: 'true'` (a JSON string, not a boolean) is treated as `false` (reuse).
   - Permission-denial cases re-run with both `rotate: true` and `rotate: false` to confirm the gate fires uniformly.

**Functional — Stage 2 (Invite Members tile on event detail):**

3. `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — add a new tile between the `_MembersPreview` card and the first `_QuickLinkCard`. Use the same `Card` shape + 0 elevation + light-grey border as the surrounding cards. Leading: `Icons.person_add_rounded` in `AppColors.terracotta`. Title: "Invite Members". Subtitle: "Share a code to add people". Trailing: `Icons.chevron_right`.
4. The tile is wrapped in a `Consumer` reading `currentUserIdProvider` and is conditionally rendered based on `event.isAdmin(uid ?? '')`. Non-admins / unauthenticated users do not see the tile.
5. Tap behavior: `AddMemberSheet.show(context: context, eventId: event.id)`. Same call shape used today by `MemberManagementScreen`.
6. Add a stable widget key `Key('eventDashboard.inviteMembers.tile')` for tests.

**Functional — Stage 3 (Post-create SnackBar action):**

7. `lib/app/features/dashboard/presentation/create_event_screen.dart` `_submit()` success path — replace the bare SnackBar with one that includes a `SnackBarAction`:
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
   Use `messenger.context` (the `ScaffoldMessengerState.context`) so the sheet attaches to the dashboard scaffold the user just popped to. Extend the SnackBar duration from the default 4s to 6s so the user has time to react.
8. Existing capture-before-pop discipline (commit `1b0ec46`) MUST be preserved — `messenger` and `navigator` are read before the `await ref.read(eventRepositoryProvider).createEvent(event)`.
9. Add a stable widget key for the SnackBar action: not required (Material's `SnackBarAction` accepts `key` but tests can locate via `find.text('Share invite')`).

**Error Handling:**

10. CF in `rotate: false` mode that finds an EXPIRED existing code MUST delete the expired doc as part of the same batch that writes the new code, to avoid stale entries piling up in `event_invites`.
11. The Stage 2 tile shows nothing while `currentUserIdProvider` is loading (default null fallback). Once auth resolves, the tile renders or hides based on uid. No flicker beyond what the auth state's natural rebuild produces.
12. The Stage 3 SnackBarAction tap, if `messenger.context` is no longer mounted (rare race — user navigated away before tapping), MUST silently no-op rather than throw. The SnackBar already auto-dismisses if the messenger is disposed; the action's `onPressed` only fires while the SnackBar is visible, which implies the messenger is mounted.

**Edge Cases:**

13. Admin demotes themselves between the tile rendering and the tap → tile is still visible (stale client state) → CF call returns `permission-denied` → AddMemberSheet's existing error UI handles it. Acceptable; the next provider rebuild hides the tile.
14. User creates an event then signs out before tapping the SnackBar action → the action tap calls `AddMemberSheet.show` which calls the CF without auth → CF throws `unauthenticated` → sheet shows the existing offline-shaped error message. Acceptable defensive behavior; not worth a custom branch.
15. Code reuse race: two simultaneous `rotate: true` calls from two admin devices. CF's batch is atomic; whichever batch commits first wins. Second batch sees the freshly-deleted existing code AND the new code; collision-retry loop handles the rare case where the second batch's generated code collides with the first.

**Validation:**

16. CF still rejects unauthenticated callers (existing behavior).
17. CF still rejects non-admin callers (existing behavior; both `rotate: true` and `rotate: false` branches gated by the same permission check).
18. The new `rotate` field MUST be permissive of `undefined` / `null` / missing — treat any falsy value as "default reuse-if-valid."
</requirements>

<boundaries>
**Edge cases:**

- **Stale code in client cache:** the AddMemberSheet's `_code` state is set on initState. Reuse-if-valid means subsequent opens of the same sheet may re-show the same code (no flicker). Acceptable.
- **Expired code mid-display:** if the user opens the sheet, then leaves the phone for >24h, then taps Share, the underlying code may have expired. The CF doesn't enforce post-display expiry — the share-text recipient will get `not-found` on `joinEvent`. Acceptable for V1; revisit if user testing flags it.
- **Multiple admins generate codes around the same time:** CF's batch + collision-retry already handles the race. No additional locking needed.

**Error scenarios:**

- **CF returns `permission-denied` on tile tap:** show the existing in-sheet error UI ("Only admins can generate invite codes."). Don't reveal the tile if the user is not an admin in the first place.
- **CF returns generic error:** sheet shows "Failed to generate code. Please try again." with retry button (existing behavior).
- **Network offline:** sheet shows "Requires an internet connection to generate a secure join code." with retry (existing behavior).

**Limits:**

- 24h code expiry is unchanged. Reuse-if-valid is bounded by that.
- No deep-link generation in this spec — recipients still copy/paste the 6-char code into JoinEventSheet. Deep-link adoption is `deep-link-invite-spec.md` (V1.x per the utilities audit).
- No QR-code generation either — that's `qr-invite-spec.md` (V1.x).
- The share text is hardcoded to "Join my event on CrewPoint! Use code: $_code" — same as today. Personalization (event title in the text) is out of scope for this spec but worth a one-line note in the audit's Section 2.1 for the next iteration.
</boundaries>

<implementation>
**Stage 1 — Cloud Function: reuse-if-valid:**

- `functions/src/events/generateInviteCode.ts`:
  - Add `rotate?: boolean` extraction from request data after the existing `eventId` extraction. Use `Boolean(data.rotate)` for permissive coercion.
  - After the permission check, branch:
    - `if (!rotate)`: query `event_invites where eventId == $eventId`. If result has at least one doc and that doc's `expiresAt.toMillis() > Date.now()`, return `{code: existingDoc.id}` immediately (the doc id IS the code). If the doc has expired, fall through to the generation block but include the expired doc id in a `batch.delete` first.
    - `else (rotate === true)`: existing behavior — collect all existing codes for the eventId, batch-delete them, generate a new one with collision-retry.
  - Emit one structured log line on entry: `{op: 'generateInviteCode', mode: rotate ? 'rotate' : 'reuse', uid, eventId}`. Emit a second log line on success with `{code, existingCode: bool}`.
- `functions/test/cloud-functions.test.ts`:
  - Add four new tests (see req 2). Each seeds Firestore via the existing fake / emulator harness, calls the CF, asserts response + `event_invites` collection state.

**Stage 2 — Invite Members tile:**

- `lib/app/features/dashboard/presentation/event_dashboard_screen.dart`:
  - Wrap only the new tile in a `Consumer` (don't convert the whole screen to `ConsumerWidget` — minimizes the diff and matches the existing `_EventActions` wrap pattern).
  - **Reuse the existing `_QuickLinkCard` widget** (already private to this file; accepts `icon` / `label` / `subtitle` / `color` / `onTap`). Don't introduce a new `_InviteMembersTile` class — saves a class definition and keeps the visual style consistent with the surrounding tiles.
  - Place the new tile between the `_MembersPreview` card and the first `_QuickLinkCard` (Chat).
  - Visibility wrap — guard explicitly against null uid rather than relying on `event.isAdmin('')` returning false:
    ```dart
    Consumer(
      builder: (_, ref, _) {
        final uid = ref.watch(currentUserIdProvider);
        if (uid == null || !event.isAdmin(uid)) {
          return const SizedBox.shrink();
        }
        return _QuickLinkCard(
          key: const Key('eventDashboard.inviteMembers.tile'),
          icon: Icons.person_add_rounded,
          label: 'Invite Members',
          subtitle: 'Share a code to add people',
          color: AppColors.terracotta,
          onTap: () => AddMemberSheet.show(
            context: context,
            eventId: event.id,
          ),
        );
      },
    );
    ```
    The explicit `uid == null` guard is preferred over `event.isAdmin(uid ?? '')` because it doesn't rely on the `isAdmin` helper's empty-string semantics (which could change). If the helper ever defaults empty uids to "admin," this code stays safe.

- Imports needed: `package:flutter_riverpod/flutter_riverpod.dart` (already present from the `_EventActions` Consumer wrap), `package:crewpoint_app/app/features/dashboard/presentation/widgets/add_member_sheet.dart` (new).

**Stage 3 — Post-create SnackBar action:**

- `lib/app/features/dashboard/presentation/create_event_screen.dart` `_submit()`:
  - In the success branch, replace the bare SnackBar with the structure shown in req 7. The `messenger`, `navigator`, and `event` variables are all in scope from the existing flow.
  - Add the `add_member_sheet.dart` import.
  - **Duration: 6 seconds.** Material's default is ~4s; 6s gives the user time to read "Event created" and tap "Share invite" without rushing them, and remains short enough that it doesn't loiter on the dashboard. Tunable based on user testing.

- **`messenger.context` validation contract.** `ScaffoldMessengerState.context` resolves above the GoRouter shell navigator. `showModalBottomSheet(context: messenger.context, ...)` will walk up to find the nearest `Navigator` (the root one). The validation step MUST include a widget test that:
  1. Pumps the create flow.
  2. Triggers the success SnackBar.
  3. Taps the `Share invite` action.
  4. Asserts `find.byType(AddMemberSheet)` is present.
  5. Dismisses the sheet via `Navigator.of(context).pop()` (or by tapping outside).
  6. Asserts the dashboard is intact (`find.byKey(Key('dashboard.events.list'))` or the empty-state finder, depending on test fixture).
  If this test reveals navigator-level oddness, fall back to capturing a one-shot flag in a Riverpod provider that the dashboard reads on next build and surfaces the sheet from the dashboard's own scaffold context. Defer that fallback unless the test fails.

**Patterns to follow:**

- Tile shape: mirror `_QuickLinkCard`'s `Card` + `ListTile` shape with a coloured leading icon.
- The `Consumer` wrap pattern matches `app_router.dart:155-162` and the `_EventActions` wrap that shipped in PR #3.
- `AddMemberSheet.show(context: ..., eventId: ...)` is the canonical entry — already used by `MemberManagementScreen`.
- For the CF, the structured-log shape matches the existing `withStructuredLogs` wrapper style in `deleteUserAccount.ts`.

**What to avoid:**

- Do NOT add a direct `Share.share` call from event detail that bypasses the sheet. Showing the code in the sheet (with copy-to-clipboard) is the canonical UX; the sheet's "Share" button does the share.
- Do NOT modify `firestore.rules` for `event_invites` — the collection stays Admin-SDK-only. All invite-code logic flows through the CF.
- Do NOT add a separate `inviteCodeProvider` Riverpod provider — the AddMemberSheet manages its own ephemeral state. A persistent provider would be over-engineering for an admin-only sheet that lives 30 seconds.
- Do NOT change the share text to include the event title in this spec. That's a small follow-up tracked in the utilities audit's section 2.1 future-iteration note.
- Do NOT auto-rotate the code on every CF call (current default behavior). The `rotate: true` flag is opt-in.
</implementation>

<validation>
**Baseline automated coverage:**

*Logic / unit (Cloud Function tests):*

- New: `generateInviteCode` returns a fresh code when no existing code exists (no `rotate` flag).
- New: `generateInviteCode` returns the SAME existing code when one is non-expired and `rotate` flag is missing or false.
- New: `generateInviteCode` deletes the existing code and returns a new one when `rotate: true`.
- New: `generateInviteCode` deletes an expired code and returns a fresh one when `rotate` is missing or false.
- Existing: unauthenticated rejection, non-admin rejection — re-run with both `rotate: true` and `rotate: false` paths to confirm the permission gate fires uniformly.

*UI behavior (widget tests — new):*

- `event_dashboard_screen` tile visibility:
  - Admin uid → tile visible (`Key('eventDashboard.inviteMembers.tile')` finds one widget).
  - Non-admin member uid → tile hidden (key finds zero).
  - `currentUserIdProvider` overridden null → tile hidden.
- Existing `event_actions_uid_wrap_test.dart` extension: when the new tile is rendered, the existing Leave/Delete branching still works correctly. (Smoke check; not a new test case if the existing assertions already imply this.)
- `create_event_screen_test.dart` extension — happy-path test:
  - After successful submit + pop, the SnackBar contains the text `Event created`.
  - The SnackBar contains the action label `Share invite`.
  - Tapping the action opens an `AddMemberSheet` (assert via `find.byType(AddMemberSheet)` after pumpAndSettle).
  - `addTearDown` to dismiss the sheet so the test exits cleanly.

*Critical journey (robot — new):*

- Extend `test/journeys/create_event_journey_test.dart`: after the existing "tap tile → see EventDashboardScreen" assertion, tap the new Invite Members tile → assert `find.byType(AddMemberSheet)` is present. **Do not stub the Cloud Function.** The CF call will throw because Firebase Functions isn't initialized in the test environment; the sheet's existing offline-error UI catches that and renders "Requires an internet connection to generate a secure join code." Assert that the offline message text is visible. This proves the tile-leads-to-sheet wiring without needing test plumbing for the CF itself (CF logic is covered exhaustively at the unit level in `cloud-functions.test.ts`). Dismiss the sheet to finish the journey cleanly.

**TDD expectations:**

Vertical-slice cycles in order:

1. RED: CF test "fresh call returns a new code when none exists" (no `rotate`).
2. GREEN: minimal CF skeleton with the reuse-if-valid branch.
3. RED: CF test "second call returns the same code as the first (reuse)."
4. GREEN.
5. RED: CF test "rotate: true issues a new code and deletes the old one."
6. GREEN.
7. RED: CF test "expired existing code is deleted and a fresh one is issued."
8. GREEN.
9. RED: widget test "tile is visible to admin uid."
10. GREEN: tile widget + Consumer wrap.
11. RED: widget test "tile is hidden to non-admin uid."
12. GREEN.
13. RED: widget test "tapping the tile opens AddMemberSheet."
14. GREEN.
15. RED: widget test "post-create SnackBar contains a Share invite action."
16. GREEN: SnackBar rewrite in `_submit()`.
17. RED: widget test "tapping Share invite opens AddMemberSheet for the just-created event id."
18. GREEN.
19. RED: extended journey — create → tap tile → tap Invite Members tile → sheet visible.
20. GREEN.
21. REFACTOR: extract any duplicated tile shape into a small private widget; tighten naming.

**Required test seams + selectors:**

- New stable widget key: `Key('eventDashboard.inviteMembers.tile')` on the new tile.
- `currentUserIdProvider` is already overridable (used by the existing `event_actions_uid_wrap_test.dart`).
- `dashboardEventsProvider` overrideable for the create-event widget test (existing pattern).
- For the SnackBar test, the action label `Share invite` is the natural finder; no key needed.

**Mocking policy:**

- Prefer `fake_cloud_firestore` for the CF tests if the existing `cloud-functions.test.ts` harness supports it; otherwise use the established TS harness pattern.
- Widget tests override `currentUserIdProvider` with the established `_StubAuthNotifier` pattern from `tasks_harness.dart`.
- The journey test does NOT mock the CF — it lets the sheet render its offline error UI when the call fails (acceptable for the journey's scope, which is "tile leads to sheet").

**Manual smoke (after Stage 2 + 3 land):**

- iOS sim: create event → SnackBar shows with Share invite action → tap → sheet opens with a fresh code → tap Share → system share sheet → pick Messages → text contains the code.
- Open an existing event → see Invite Members tile → tap → sheet opens → code matches the one shown earlier (reuse). Tap Generate New Code → code rotates.
- Sign in as a non-admin member → open the same event → tile is hidden.
- Web (`flutter run -d chrome --dart-define=FLAVOR=dev`): same flows. `share_plus` on web opens the OS / browser share UI; verify that text is correct.
</validation>

<stages>
**Stage 1 — Cloud Function: reuse-if-valid.**
- Output: modified `functions/src/events/generateInviteCode.ts` + new test cases in `functions/test/cloud-functions.test.ts`.
- Verify: `pushd functions && npm test && popd` passes; new cases assert the reuse, rotate, and expiry-eviction branches.

**Stage 2 — Invite Members tile on EventDashboardScreen.**
- Output: new private `_InviteMembersTile` widget + `Consumer` visibility wrap in `event_dashboard_screen.dart`. Three new widget tests.
- Verify: `flutter test test/app/features/dashboard/event_dashboard_screen_layout_test.dart test/app/features/dashboard/event_actions_uid_wrap_test.dart` plus the new test file. Tile visible for admin, hidden for non-admin, hidden during loading.

**Stage 3 — Post-create SnackBar action.**
- Output: rewritten SnackBar in `CreateEventScreen._submit()`. Two new widget-test cases on `create_event_screen_test.dart`. Robot journey extension.
- Verify: full `flutter test` green; manual smoke confirms the post-create SnackBar action path.
</stages>

<done_when>
- `generateInviteCode` defaults to reuse-if-valid; `rotate: true` opts into rotation. Permission check unchanged.
- CF test suite covers four new branches (fresh / reuse / rotate / expiry-eviction) plus the existing permission-denied cases.
- `EventDashboardScreen` shows an "Invite Members" tile to admins/owner only, between Members preview and Quick links. Tap → `AddMemberSheet` opens.
- `CreateEventScreen` post-create SnackBar shows a `Share invite` action that opens `AddMemberSheet` for the just-created event id. SnackBar duration is 6 seconds.
- All existing tests still pass; new widget tests cover tile visibility (admin / non-admin / loading), tile-tap → sheet, SnackBar action presence, action-tap → sheet.
- Robot journey: create → tile-tap-from-detail → sheet visible.
- `flutter analyze` clean (only the pre-existing `TableMigration` experimental warning).
- No new packages added; `share_plus` already in pubspec.
- Utilities audit Section 2.1 status updated (or has a follow-up note added) to reflect "Resolved in invite-share PR."
</done_when>
