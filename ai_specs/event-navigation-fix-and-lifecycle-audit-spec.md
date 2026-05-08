<goal>
Two deliverables in one spec:

1. **Fix the "Event not found" bug.** Tapping any event tile on the dashboard navigates to a screen that says "Event not found." Root cause: every event route reads `state.extra as EventModel?` (a non-URL payload), but the dashboard navigates with the path only. The fix replaces `extra`-based payload passing with **resolve-by-ID** — every event sub-route looks up the event from `dashboardEventsProvider` using the `:eventId` path param. Web-reload-safe, deep-linkable, aligns with Firestore-Write / Drift-Read.
2. **Event lifecycle audit + prioritized roadmap.** Walk every step of the event lifecycle (create → view → edit → members → tasks → chat → budget → archive → delete) and produce a gap list with file refs and severity. Sequence the follow-up specs needed to close each gap before public launch. Editing the event is explicitly V1.x (per spec discussion); audit treats it as a known deferred item, not a blocker.

Why it matters: the navigation bug makes every event unusable after creation — users can create events but cannot open them. The audit prevents the next round of "I clicked X and nothing happened" bugs from shipping post-launch.
</goal>

<background>
**Tech stack:** Flutter 3.11.5, Riverpod 3, GoRouter 14, Firebase (Auth, Firestore, Functions). The Firestore-Write / Drift-Read architecture for events shipped in commit `748639a` (PR #3); events now stream through `dashboardEventsProvider`.

**Bug evidence — "Event not found" on every event tap:**

- `lib/app/features/dashboard/presentation/dashboard_screen.dart` — the dashboard tile `onTap` calls `context.push('/dashboard/event/${id}')` with **no** `extra:` payload.
- `lib/app/core/router/app_router.dart` — every event-related route builder reads `state.extra as EventModel?` (search the file for `state.extra as EventModel`). When `extra` is null, the builder returns `_PlaceholderScreen(title: 'Event not found')`. The same pattern exists in the parent `event/:eventId` route AND in every child route (`/members`, `/budget`, `/chat`, `/tasks`, `/tasks/:taskId`). Once Stage 1 lands, all of them must use the same resolve-by-ID approach so a web reload anywhere in the event tree continues working.

**Lifecycle gaps from `event_dashboard_screen.dart` (file-only refs to avoid line-drift):**

- `_EventActions` is built with `currentUserId: ''` — the Leave Event and Delete Event buttons branch on `event.isOwner(uid)` / `event.isAdmin(uid)`; with an empty uid neither branch evaluates correctly. Stage 1 of THIS spec bundles the one-line fix (Consumer reading `currentUserIdProvider`) since the bug becomes user-visible the moment navigation works.
- Settings-icon `IconButton` has an empty `onPressed` body. No edit-event screen exists. *V1.x follow-up.*
- Archive toggle's `onChanged` is a TODO — the switch flips visually but nothing persists. *V1 should-ship; separate follow-up spec.*
- `_leaveEvent` calls `removeEventMember` with `targetUserId: widget.currentUserId`; the empty uid would hit the CF's defensive rejection. Resolved by Stage 1's `currentUserId` Consumer wrap.
- `_deleteEvent` calls `deleteEvent` CF; works today for the owner since it doesn't depend on `currentUserId`.

**Files to examine for the fix:**

- `@lib/app/core/router/app_router.dart` (all event-related route builders).
- `@lib/app/features/dashboard/presentation/dashboard_screen.dart` (already navigates by id — no change needed, just verify).
- `@lib/app/features/dashboard/presentation/event_dashboard_screen.dart` (consumes the event; `_EventActions` gets the Consumer-uid wrap in Stage 1).
- `@lib/app/core/providers.dart` (`dashboardEventsProvider` + `currentUserIdProvider` already exist; new `eventByIdProvider` family added here).
- `@lib/app/features/dashboard/presentation/member_management_screen.dart`, `event_budget_page.dart`, `event_chat_page.dart`, `event_tasks_page.dart`, `event_task_detail_page.dart` (consume `event:` directly today; will receive a resolved EventModel from the new route builder — no internal change unless they break under the new lookup).
- `@lib/app/features/dashboard/domain/models/event.dart` (`isOwner`, `isAdmin`, `isMember` helpers used by the action panel).
- `@test/app/core/router/app_router_test.dart` — existing `_wrapWithProviders` + `FakeAuthService` pattern for router tests; reuse it for the new resolve-by-ID tests so the redirect chain doesn't bounce them off the URL.

**Files to examine for the lifecycle audit:**

- `@lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart` (join-by-code flow — verify it works end-to-end after the route fix).
- `@functions/src/events/joinEvent.ts`, `generateInviteCode.ts`, `promoteToAdmin.ts`, `demoteAdmin.ts`, `removeEventMember.ts`, `deleteEvent.ts` (the membership lifecycle CFs — already implemented; audit verifies UI surfaces are wired).
- `@lib/app/features/tasks/`, `@lib/app/features/chat/`, `@lib/app/features/budget/` (sub-feature surfaces — confirm they render correctly under the resolved EventModel).
</background>

<user_flows>
**Primary flow (after Stage 1):**

1. Authenticated user opens `/dashboard`, sees their events from `dashboardEventsProvider`.
2. Tap an event tile → router navigates to `/dashboard/event/{id}`.
3. Route builder reads `eventId` from `state.pathParameters`, looks up the event in `dashboardEventsProvider.value` via `eventByIdProvider(eventId)`.
4. If found → `EventDashboardScreen(event: ...)` renders the hero, members preview, quick links, and action panel.
5. Tap a quick link (Chat / Budget / Tasks) or Members → child route also resolves by ID; renders the corresponding sub-screen.
6. Web user can refresh any of these URLs and land back on the same screen.

**Alternative flows:**

- Deep link / shared URL with an event the user is NOT a member of → friendly "You don't have access to this event" screen with a "Back to events" button. (Firestore rules already block non-members from reading; the UI just needs to handle the null lookup.)
- Direct URL to `/dashboard/event/{nonexistent-id}` → same friendly fallback ("Event not found or no access").
- Provider in the loading state when the route renders → screen shows a centered progress indicator while `dashboardEventsProvider` resolves; then transitions to the resolved or fallback state.

**Error flows:**

- `dashboardEventsProvider` is in `error` state → render a top-level error message with a Retry button (refreshes the provider).
- User loses access to the event mid-session (admin removed them) → the provider emits a snapshot without the event; the route builder's lookup returns null on the next rebuild; the screen redirects to `/dashboard` with a SnackBar ("You no longer have access to this event").
- Network offline + Firestore SDK serving cached events → behavior is identical to online (cache is the read source); writes still queue per the offline-first architecture.

**Per-pillar lifecycle (audit context, not Stage 1 scope):**

- *Create:* `CreateEventScreen` shipped in PR #3 — works.
- *View detail:* `EventDashboardScreen` — Stage 1 fixes the entry point; `currentUserId` wiring is a Stage 2 audit follow-up.
- *Edit info:* No screen exists. V1.x.
- *Archive:* Toggle exists, write is TODO. Audit follow-up.
- *Members:* `MemberManagementScreen` exists; `joinEvent` / `promoteToAdmin` / `demoteAdmin` / `removeEventMember` CFs implemented. Audit confirms wiring.
- *Tasks:* `EventTasksPage` + `CreateTaskScreen`. The `CreateTaskScreen` silent-no-op (V1 audit blocker #3) is a separate spec.
- *Chat:* `EventChatPage` + `FirestoreChatService`. Urgent FCM path verified in V1 audit.
- *Budget:* `EventBudgetPage` + `ExpenseRepository` + `pay_link_builder`. Zelle gap is a separate spec.
- *Leave:* `_EventActions._leaveEvent` calls `removeEventMember` — needs `currentUserId` wired before it works.
- *Delete:* `_EventActions._deleteEvent` calls `deleteEvent` — works today for the owner.
</user_flows>

<requirements>
**Functional — Stage 1 (Navigation by ID):**

1. Add `eventByIdProvider` to `lib/app/core/providers.dart`. Signature: `Provider.family<EventModel?, String>` returning the matching event from `dashboardEventsProvider.value` or `null` when absent or still loading. Re-evaluates whenever the underlying stream emits.
2. Add a shared `_EventGuard` widget in `app_router.dart` (next to `_EventNotFoundScreen`). Signature: `_EventGuard({required String eventId, required Widget Function(EventModel) child})`. Owns the loading / found / not-found contract so every event route reduces to one line: `_EventGuard(eventId: id, child: (event) => EventBudgetPage(event: event))`. This eliminates the 6× duplication risk and gives Finding #1's grace-period logic a single home.
3. **Cold-start grace period** (resolves the user-visible "Event not found" flicker on web reload + multi-device first-load): inside `_EventGuard`, when `dashboardEventsProvider` is `data` but the lookup misses, do NOT render `_EventNotFoundScreen` immediately. Show `CircularProgressIndicator` for 750 ms (a `Future.delayed` triggered when entering the missing branch). If a re-emission resolves the event during that window, render the resolved screen. If 750 ms elapses with the event still missing → fallback. Rationale: web has no Drift persistence (`providers.dart:76-79`), so the first emission on a cold reload is `data: []` before the Firestore listener fires. 750 ms is long enough for the Firestore round-trip on a typical connection, short enough that genuinely-missing IDs still feel responsive.
4. Replace every `state.extra as EventModel?` lookup in the event-related routes (`/dashboard/event/:eventId` and its `/members`, `/budget`, `/chat`, `/tasks`, `/tasks/:taskId` children) with `_EventGuard`. Route builders read `state.pathParameters['eventId']` (GoRouter inherits parent path params into nested route builders).
5. Dashboard `onTap` continues to use `context.push('/dashboard/event/${id}')` (no `extra` needed). Quick links inside `EventDashboardScreen` drop the `extra: event` argument since the child route resolves by ID.
6. Replace the `_PlaceholderScreen(title: 'Event not found')` fallback with a dedicated `_EventNotFoundScreen` widget that renders: an icon, a "We couldn't find that event" headline, an "It may have been deleted, or you may not have access" body, and a primary "Back to events" button keyed `Key('event.notFound.back')` that calls `context.go('/dashboard')`. Logs the missing eventId via `dart:developer log(name: 'router')` for diagnostics.
7. The route builder MUST NOT depend on `state.extra` at all. URL is the source of truth for event identity.
8. **Bundle the `currentUserId` Consumer wrap into Stage 1.** In `event_dashboard_screen.dart`, replace the bare `_EventActions(event: event, currentUserId: '')` with a `Consumer` that reads `currentUserIdProvider` and threads the resolved uid (`?? ''` if the defensive null path fires, since the route's auth redirect already prevents an unauthenticated user from reaching the screen). Justification: without this one-line fix, the navigation bug is replaced by a "tap Leave Event → nothing happens" bug the moment users start opening events. It belongs in the same PR.

**Functional — Stage 2 (Lifecycle Audit):**

9. **Append** a new `## Event Lifecycle Deep Dive` section to the existing `docs/v1-progress-audit.md` (do NOT create a parallel `docs/event-lifecycle-audit.md` — Pillar 2 already covers events). The new section walks each step of the lifecycle (create, view, edit, members, tasks, chat, budget, archive, leave, delete) with columns: *Step*, *Status* (✅ Done / ⚠️ Wired-but-broken / ❌ Missing), *File refs*, *Follow-up* (spec name or "none").
10. Audit MUST flag at minimum:
   - Empty settings icon `onPressed` in `event_dashboard_screen.dart` — no edit-event screen exists.
   - Archive toggle TODO in `_EventActions` — visual only.
   - `member_management_screen.dart` — verify the CF call paths (`promoteToAdmin`, `demoteAdmin`, `removeEventMember`) work end-to-end after Stage 1 + the bundled uid fix.
   - `join_event_sheet.dart` — verify the join-by-code flow works after the route fix.
11. Audit MUST list each gap as one of: *V1 launch blocker*, *V1 should-ship*, or *V1.x follow-up*.
12. The audit MUST cross-reference the V1 audit's Pillar 2 row to keep a single source of truth.

**Functional — Stage 3 (Roadmap):**

13. The audit ends with a "Follow-up specs" section listing each remaining gap that needs its own `/spec` invocation. Suggested names + one-line summaries:
   - `event-archive-toggle-spec.md` — make the archive switch persist `status` to Firestore via a new `EventRepository.archiveEvent(eventId, archived)` method + Cloud Function trigger if needed. **V1 should-ship.**
   - `event-edit-screen-spec.md` — `EditEventScreen` for title/description/eventType/startDate (currency stays immutable). **V1.x follow-up.**

   Note: `event-actions-uid-wiring` is NOT in the roadmap because Stage 1 of this spec resolves it (req #8).

**Error Handling:**

14. The `eventByIdProvider` returns `null` for both "loading" and "missing" cases. `_EventGuard` distinguishes via `dashboardEventsProvider`'s `AsyncValue` state plus the 750 ms grace timer (req #3) — show progress while loading or during the grace window, fallback only when grace elapses with the event still absent.
15. The friendly not-found screen never crashes if `eventId` is missing from `state.pathParameters`; treats null/empty id as "not found" with the same fallback (no grace period — only triggered by malformed URLs).
16. If `dashboardEventsProvider` enters `error` state, route builders surface a Retry button that calls `ref.invalidate(dashboardEventsProvider)` (which cancels and re-establishes the Firestore listener — acceptable cost for an explicit retry).

**Edge Cases:**

17. Race condition: user navigates to `/dashboard/event/{id}` exactly as the Firestore listener emits a snapshot that excludes that event (e.g., admin removed them). Expected: 750 ms grace fires, then fallback renders. The user briefly sees a spinner — acceptable.
18. Web page reload at `/dashboard/event/{id}/budget` (or any sub-route) re-runs the redirect chain → user lands on the same URL after auth → `_EventGuard` shows progress until `dashboardEventsProvider` emits → resolved screen renders.
19. Two events with similar IDs — N/A; UUIDs are unique.

**Validation (input):**

20. `eventId` path param is treated as opaque; no length or format validation in the router (Firestore rules + provider lookup are the gate).
</requirements>

<boundaries>
**Edge cases:**

- Provider in loading state at first render → screen shows progress; route does not redirect.
- Event found but archived → render normally (archive is a status, not an access denial).
- Event found but user is no longer in `memberIds` (rare race) → Firestore rules will block any subsequent write; UI lookup returns null on the next snapshot, fallback renders.

**Error scenarios:**

- `dashboardEventsProvider` errors (e.g., Firestore permission denial) → top-level error widget with Retry.
- Lookup returns null after data loaded → friendly "not found" with `Back to events` action.
- Sub-route accessed without auth → existing router redirect (`app_router.dart:85-89`) sends user to `/auth`.

**Limits:**

- Stage 1 does NOT touch the sub-screen widgets themselves (chat, budget, tasks, members, task detail). They continue to receive `event:` directly from the resolved route builder.
- Stage 1 does NOT add a separate `Stream<EventModel?>` provider per event; we use the in-memory list from `dashboardEventsProvider` since it already streams the user's full event set.
- Stage 2 produces a document; it does NOT execute any code-level fixes. Each follow-up gap gets its own `/spec` later.
</boundaries>

<implementation>
**Stage 1 — Navigation by ID:**

*New code:*

- `lib/app/core/providers.dart` — add:
  ```dart
  /// Looks up a single event by id from the user's dashboard event list.
  /// Returns null when the event isn't in the list (loading, deleted, or
  /// the user lost access). Loading-vs-missing discrimination happens in
  /// `_EventGuard`, not here.
  final eventByIdProvider = Provider.family<EventModel?, String>((ref, id) {
    final asyncEvents = ref.watch(dashboardEventsProvider);
    return asyncEvents.maybeWhen(
      data: (events) {
        for (final e in events) {
          if (e.id == id) return e;
        }
        return null;
      },
      orElse: () => null,
    );
  });
  ```

- `lib/app/core/router/app_router.dart`:
  - Add a private `_EventNotFoundScreen` widget at the bottom of the file (next to `_RouterErrorScreen`). Mirrors its layout: icon, headline ("We couldn't find that event"), body ("It may have been deleted, or you may not have access"), primary `Back to events` button keyed `Key('event.notFound.back')`. Logs the missing eventId via `developer.log(name: 'router')`.
  - Add a private `_EventGuard` ConsumerStatefulWidget — owns the load / found / not-found contract and the cold-start grace period. Sketch:
    ```dart
    class _EventGuard extends ConsumerStatefulWidget {
      const _EventGuard({required this.eventId, required this.child});
      final String eventId;
      final Widget Function(EventModel) child;
      @override
      ConsumerState<_EventGuard> createState() => _EventGuardState();
    }

    class _EventGuardState extends ConsumerState<_EventGuard> {
      Timer? _graceTimer;
      bool _graceElapsed = false;

      @override
      void dispose() { _graceTimer?.cancel(); super.dispose(); }

      void _startGrace() {
        _graceTimer ??= Timer(const Duration(milliseconds: 750), () {
          if (mounted) setState(() => _graceElapsed = true);
        });
      }

      @override
      Widget build(BuildContext context) {
        if (widget.eventId.isEmpty) {
          return _EventNotFoundScreen(eventId: widget.eventId);
        }
        final asyncEvents = ref.watch(dashboardEventsProvider);
        final event = ref.watch(eventByIdProvider(widget.eventId));
        if (event != null) return widget.child(event);
        return asyncEvents.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => _EventNotFoundScreen(eventId: widget.eventId),
          data: (_) {
            // Cold-start grace: provider has emitted but event is still
            // absent. Wait for a re-emission to land before showing the
            // fallback. See spec req #3 for rationale.
            _startGrace();
            return _graceElapsed
                ? _EventNotFoundScreen(eventId: widget.eventId)
                : const Scaffold(body: Center(child: CircularProgressIndicator()));
          },
        );
      }
    }
    ```
  - Replace each `state.extra as EventModel?` block in the `event/:eventId` route and its children with `_EventGuard(eventId: state.pathParameters['eventId'] ?? '', child: (event) => SomeSubScreen(event: event))`. Six call sites total: parent + members + budget + chat + tasks + task detail.
  - Drop `extra: event` from quick-link navigations inside `event_dashboard_screen.dart`.

- `lib/app/features/dashboard/presentation/event_dashboard_screen.dart`:
  - Wrap the `_EventActions(event: event, currentUserId: '')` call in a `Consumer` that reads `currentUserIdProvider`. Result: `Consumer(builder: (_, ref, _) => _EventActions(event: event, currentUserId: ref.watch(currentUserIdProvider) ?? ''))`. The screen itself remains a `StatelessWidget`; only the action panel becomes Riverpod-aware.

*No changes needed:*

- `dashboard_screen.dart` — already navigates by ID.
- Sub-screens (`MemberManagementScreen`, `EventBudgetPage`, etc.) — they accept `event:` and continue to do so; the router is the layer that changes.

**Stage 2 — Audit appended to V1 audit:**

- Output: append a new `## Event Lifecycle Deep Dive` section to `docs/v1-progress-audit.md`. Do NOT create `docs/event-lifecycle-audit.md` — Pillar 2 of the V1 audit already names events; this section deepens that row with a per-step status matrix.
- Format: matrix per lifecycle step (create, view, edit, members, tasks, chat, budget, archive, leave, delete), then a `Follow-up specs` subsection.
- Linked from this spec.

**Patterns to follow:**

- `_EventGuard` lives in `app_router.dart` (private). If it grows beyond ~80 lines or gets reused outside the router, lift it to `lib/app/core/widgets/event_guard.dart`.
- `_EventNotFoundScreen` mirrors `_RouterErrorScreen`'s shape — same icon family, same button-key naming convention (`Key('event.notFound.back')` parallels `Key('router.error.goHome')`).
- Use `context.go('/dashboard')` (not `context.pop`) from the not-found screen — pop would land on `/dashboard/event/{id}` again and re-trigger the same fallback.
- The `Consumer` wrap of `_EventActions` matches the same pattern used at `app_router.dart:155-162` for `MemberManagementScreen`'s uid threading (the fix that shipped in PR #3).

**What to avoid:**

- Do NOT add a separate per-event Firestore listener. The user's events already stream through `dashboardEventsProvider`; per-event listeners would multiply read costs.
- Do NOT update sub-screen widgets to read `eventByIdProvider` themselves. `_EventGuard` resolves once and passes the EventModel down — same DI shape as today.
- Do NOT keep `state.extra` as a backup. Single source of truth = URL.
- Do NOT extend the grace window beyond 750 ms; longer hides genuine not-found states behind an unresponsive spinner. If the Firestore round-trip is consistently slower than this in practice, fix the underlying problem (web persistence) rather than padding the timer.
- Do NOT spin off the Stage 2 follow-up gaps into this PR. Each gets its own spec.
</implementation>

<validation>
**Baseline automated coverage:**

*Logic / unit:*

- New: `eventByIdProvider` resolves to the matching event when present in the dashboard list; returns `null` when absent.
- New: `eventByIdProvider` returns `null` while the underlying provider is in loading or error state.

*UI behavior (widget tests):*

- All new router tests reuse the existing `_wrapWithProviders` + `FakeAuthService` pattern from `test/app/core/router/app_router_test.dart`. Without this, the redirect chain (`app_router.dart:85-89`) bounces the test off the URL before the event route renders.
- **Parameterized sub-route resolution test** — for each event URL (`/dashboard/event/{id}`, `/.../members`, `/.../budget`, `/.../chat`, `/.../tasks`, `/.../tasks/{tid}`):
  - Resolved: with the event present in the overridden `dashboardEventsProvider`, the route renders the corresponding screen (`EventDashboardScreen`, `MemberManagementScreen`, `EventBudgetPage`, `EventChatPage`, `EventTasksPage`, `EventTaskDetailPage`). No-missed-route guarantee.
  - Missing: with the provider emitting an event list that does NOT include the id, after the 750 ms grace the route renders `_EventNotFoundScreen` with `Key('event.notFound.back')`.
  - Tap `Back to events` → router lands at `/dashboard`.
- **`_EventGuard` cold-start grace test** (separate widget test, no router): pump `_EventGuard` with `dashboardEventsProvider` overridden to a `StreamController` that:
  1. Emits `[]` first → assert progress visible (NOT fallback).
  2. Within the 750 ms window, emit `[matchingEvent]` → assert resolved screen renders (no fallback flicker).
  3. Repeat with no second emission → after 750 ms + a pump, assert `_EventNotFoundScreen` renders.
- **Loading state test:** with `dashboardEventsProvider` stuck in loading, route shows `CircularProgressIndicator`.
- **Empty/null eventId test:** `_EventGuard(eventId: '')` renders `_EventNotFoundScreen` immediately (no grace).
- **`currentUserId` Consumer wrap test:** in `event_dashboard_screen_test.dart` (extend or create), pump `EventDashboardScreen` with `currentUserIdProvider` overridden to a uid; assert `_EventActions` receives the same uid (e.g., via the visibility of the owner-only Delete button when `currentUser.uid == event.creatorId`).

*Critical journey (robot):*

- Extend `test/journeys/create_event_journey_test.dart`: create event → tap tile → land on `EventDashboardScreen` showing the title. Closes the user-reported bug end-to-end.

**TDD expectations:**

Strict vertical-slice cycles for Stage 1, in order:

1. RED: `eventByIdProvider` returns the matching event from a controlled `dashboardEventsProvider` override.
2. GREEN: minimal provider implementation.
3. RED: returns null when the id is missing.
4. GREEN.
5. RED: returns null while underlying provider is loading.
6. GREEN.
7. RED: `_EventGuard` shows progress while provider is loading.
8. GREEN: minimal `_EventGuard`.
9. RED: `_EventGuard` shows the resolved screen when the event is in the data emission.
10. GREEN.
11. RED: `_EventGuard` shows progress (NOT fallback) for the first 750 ms after a `data: []` emission.
12. GREEN: add the grace timer.
13. RED: `_EventGuard` resolves the screen if a re-emission lands during the grace window.
14. GREEN.
15. RED: `_EventGuard` shows `_EventNotFoundScreen` after grace elapses with the event still missing.
16. GREEN.
17. RED: parameterized sub-route resolution — six URLs render six screens.
18. GREEN: route-builder rewrites.
19. RED: `currentUserId` Consumer wrap threads uid into `_EventActions`.
20. GREEN.
21. RED: extended journey — create event → tap tile → see EventDashboardScreen.
22. GREEN.
23. REFACTOR.

**Required test seams + selectors:**

- `dashboardEventsProvider`, `currentUserIdProvider`, and `authProvider` are overridden via `ProviderScope` (the established pattern in prior tests).
- New stable widget keys:
  - `Key('event.notFound.back')` on the fallback's primary button.
- The journey robot reuses `find.text(eventTitle)` on the dashboard list → tap → assert the EventDashboardScreen hero text.

**Mocking policy:**

- Prefer `dashboardEventsProvider.overrideWith(...)` over deeper Firestore mocking — the provider is the public seam.
- For the grace-period test, override `dashboardEventsProvider` with a `StreamController.stream` so the test controls emission timing.
- `fake_cloud_firestore` is unnecessary at this layer; the bug + audit are router-level concerns.

**Audit validation (Stage 2):**

- The new `## Event Lifecycle Deep Dive` section is appended to `docs/v1-progress-audit.md`.
- Every "Status" cell cites a file path or function name.
- Every "Follow-up" entry names a future spec or explicitly says "none" or "in this PR" (for the `currentUserId` fix).
- The `Follow-up specs` section identifies which gap is a V1 launch blocker.

**Manual smoke (after Stage 1 lands):**

- iOS sim: create event → tap tile → see hero + quick links → tap each quick link → see the corresponding sub-screen → tap Back; tap Leave Event (if non-owner) or Delete Event (if owner) → action fires (no longer silent).
- Web (`flutter run -d chrome --dart-define=FLAVOR=dev`): same flow + reload at `/dashboard/event/{id}/budget` → spinner briefly visible → same screen renders.
- Web direct URL: paste `/dashboard/event/{nonexistent}` → spinner for 750 ms → friendly not-found screen.
</validation>

<stages>
**Stage 1 — Navigation by ID + uid wiring (code).**
- Output: `eventByIdProvider`, `_EventGuard` (with 750 ms grace), `_EventNotFoundScreen`, six rewritten event route builders, dropped `extra:` from sub-route navigations, `_EventActions` Consumer wrap for `currentUserIdProvider`, new widget + journey tests.
- Verify: tests green; manual smoke confirms tap-and-open works on iOS + web; reload-safe on web with brief spinner before resolution; Leave/Delete buttons fire correctly.

**Stage 2 — Lifecycle Deep Dive (doc).**
- Output: new `## Event Lifecycle Deep Dive` section appended to `docs/v1-progress-audit.md`. Linked from this spec.
- Verify: every status claim opens to a file; every follow-up names a spec, "none", or "in this PR".

**Stage 3 — Roadmap (in audit doc).**
- Output: `Follow-up specs` subsection inside the new audit section, sequenced by V1 priority.
- Verify: at minimum, two follow-up specs are named: event-archive-toggle (should-ship), event-edit-screen (V1.x). The previously-anticipated `event-actions-uid-wiring-spec.md` is NOT named — Stage 1 of THIS spec resolves it.
</stages>

<done_when>
- Tapping any event tile on the dashboard opens `EventDashboardScreen` for the corresponding event — no "Event not found" placeholder anywhere in the happy path.
- All event sub-routes (`/members`, `/budget`, `/chat`, `/tasks`, `/tasks/:taskId`) resolve by ID; web reload at any of them shows a brief spinner then renders the right screen.
- The cold-start race is hidden behind a 750 ms grace window inside `_EventGuard`; users see a spinner instead of "Event not found" during web reload / multi-device first-load.
- A friendly `_EventNotFoundScreen` (with `Key('event.notFound.back')`) replaces the `_PlaceholderScreen` fallback for genuinely-missing IDs.
- `state.extra` is no longer read by any event route builder.
- `_EventActions` is wrapped in a `Consumer` reading `currentUserIdProvider`; Leave Event and Delete Event branches evaluate correctly; `app_router.dart`'s `MemberManagementScreen` uid threading and `event_dashboard_screen.dart`'s `_EventActions` uid threading use the same provider.
- A single shared `_EventGuard` widget owns the loading / found / not-found contract — no per-route duplication.
- New widget tests cover: parameterized resolution across all six event URLs (resolved + missing), grace-period behavior (progress during grace, resolve during grace, fallback after grace), loading state, empty-id, and the `currentUserId` Consumer wrap.
- New robot journey: create → tap tile → EventDashboardScreen.
- `docs/v1-progress-audit.md` has a new `## Event Lifecycle Deep Dive` section covering all 10 lifecycle steps with status + file refs + follow-up.
- Audit identifies at minimum two follow-up specs: event-archive-toggle (should-ship), event-edit-screen (V1.x). The uid-wiring follow-up is removed from the roadmap (resolved by Stage 1).
- `flutter analyze` clean (only the pre-existing `TableMigration` experimental warning); `flutter test` full suite green.
</done_when>
