## Overview

Fix "Event not found" via resolve-by-ID + `_EventGuard` (ref.listen-scheduled 750ms grace, hardened for timer-lifecycle test failures); bundle `_EventActions` `currentUserIdProvider` Consumer wrap. Append event lifecycle deep dive to V1 audit.

**Spec**: `ai_specs/event-navigation-fix-and-lifecycle-audit-spec.md` (commit `5917d9c`)

## Context

- **Structure**: feature-first under `lib/app/features/`; router at `lib/app/core/router/`.
- **State management**: Riverpod 3.
- **Reference implementations** (mirror exactly):
  - `lib/app/core/router/app_router.dart:155-162` — Consumer-uid threading pattern (used for `MemberManagementScreen` in PR #3 — same shape needed for `_EventActions`).
  - `lib/app/core/router/app_router.dart:280-354` — `_RouterErrorScreen` shape; mirror for `_EventNotFoundScreen` (icon, headline, body copy, primary button keyed `Key('event.notFound.back')`).
  - `test/app/core/router/app_router_test.dart:12-24` — `_wrapWithProviders` + `FakeAuthService` setup; reuse for every new router test.
  - `test/journeys/create_event_journey_test.dart` — extension target for the open-event journey.
- **Existing providers used (already shipped):** `dashboardEventsProvider`, `currentUserIdProvider` in `lib/app/core/providers.dart`.
- **Critical implementation rules from the spec:**
  - Timer scheduling lives in `ref.listen(... fireImmediately: true)` — NOT in `build()`.
  - `didUpdateWidget` MUST reset `_graceTimer` + `_graceElapsed` on `eventId` change.
  - `dispose` MUST cancel `_graceTimer` and null it out (otherwise tests hit "Timer still pending").
  - Tests pick exactly one timer pattern per scenario: A (`tester.pump(750ms)` + `pump()`), B (unmount before exit), or C (eventId switch). See spec `<validation>` for the explicit playbook.
- **Assumptions / Gaps:**
  - GoRouter inherits parent path params into nested route builders. Spec ships a `_resolveEventId(state)` helper with a `RegExp(r'/event/([^/]+)')` fallback against `state.matchedLocation` if the path-params route fails.
  - Riverpod 3 auto-cleans `Provider.family<EventModel?, String>` entries when no listeners remain.

## Plan

### Phase 1: Navigation by ID + `_EventGuard` + uid wiring (vertical slice)

- **Goal**: Tap any event tile → correct screen on iOS + web; reload-safe with brief grace spinner; no flicker; Leave/Delete buttons fire; test suite green with no pending-timer failures.

**Provider:**

- [ ] `lib/app/core/providers.dart` — add `eventByIdProvider` (`Provider.family<EventModel?, String>`) reading `dashboardEventsProvider`'s `AsyncValue.maybeWhen(data: ...)`; returns matching event or null.
- [ ] TDD: returns matching event from `data` emission.
- [ ] TDD: returns null when id absent from `data` emission.
- [ ] TDD: returns null while underlying provider is loading or in error.

**`_EventNotFoundScreen` (router-private):**

- [ ] `lib/app/core/router/app_router.dart` — add `_EventNotFoundScreen({required String eventId})`. Logs eventId in `initState` via `developer.log(name: 'router')` (once per visit). Layout mirrors `_RouterErrorScreen`: icon, headline "We couldn't find that event", body "It may have been deleted, or you may not have access", primary button keyed `Key('event.notFound.back')` calling `context.go('/dashboard')`.

**`_EventGuard` (router-private; the single source of truth for load/found/not-found):**

- [ ] `app_router.dart` — add private `_EventGuard` `ConsumerStatefulWidget` per spec sketch. Fields: `Timer? _graceTimer`, `bool _graceElapsed = false`. Methods: `_cancelGrace`, `_scheduleGrace` (no-op if `_graceTimer != null || _graceElapsed`).
- [ ] Implement `dispose` → cancel + null `_graceTimer`.
- [ ] Implement `didUpdateWidget` → on `eventId` change, cancel timer + reset `_graceElapsed = false`.
- [ ] Implement `build`: empty `eventId` → `_EventNotFoundScreen` immediately. Otherwise `ref.listen<AsyncValue<List<EventModel>>>(dashboardEventsProvider, ..., fireImmediately: true)` schedules/cancels grace based on whether the data emission contains the event. `build` reads `_graceElapsed` and renders progress / resolved / fallback.
- [ ] TDD: shows progress while `dashboardEventsProvider` is loading. *(Pattern B)*
- [ ] TDD: shows resolved screen when `eventByIdProvider(eventId)` returns the event. *(Pattern B)*
- [ ] TDD: empty `eventId` → `_EventNotFoundScreen` immediately, no grace. *(no Timer involved)*
- [ ] TDD: shows progress (NOT fallback) for the first 750ms after `data: []` emission. *(Pattern B — unmount before grace fires)*
- [ ] TDD: re-emission lands during grace → resolved screen renders, `_graceElapsed` clears if it had been set. *(Pattern B)*
- [ ] TDD: 750ms elapses with event still missing → `_EventNotFoundScreen`. *(Pattern A — `tester.pump(750ms)` + `pump()`)*
- [ ] TDD: provider in `error` state → fallback renders, no grace. *(Pattern B)*
- [ ] TDD: `didUpdateWidget` — eventId A in missing state past 750ms (Pattern A) → re-pump same instance with eventId B in resolved state → assert resolved screen renders without waiting another 750ms.
- [ ] TDD: `dispose` cancels in-flight timer — pump with `data: []`, immediately unmount via `pumpWidget(SizedBox.shrink())` BEFORE 750ms; test exits with no "Timer still pending" failure. *(Contract test for the user-flagged failure mode.)*

**Route builder rewrites + `_resolveEventId` helper (6 sites):**

- [ ] `app_router.dart` — add `String _resolveEventId(GoRouterState state)` helper: prefer `state.pathParameters['eventId']`; fall back to `RegExp(r'/event/([^/]+)').firstMatch(state.matchedLocation)?.group(1) ?? ''`.
- [ ] Replace `state.extra as EventModel?` reads at all 6 event routes (parent + members + budget + chat + tasks + task-detail) with `_EventGuard(eventId: _resolveEventId(state), child: (event) => SubScreen(event: event))`.
- [ ] TDD: parameterized router test (reuses `_wrapWithProviders` + `FakeAuthService`) — for each of the 6 URLs: resolved event renders the correct screen; missing-id renders `_EventNotFoundScreen` after grace.

**Quick-link nav cleanup:**

- [ ] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — drop `extra: event` from the three `_QuickLinkCard` `onTap` handlers (Chat / Budget / Tasks).

**`_EventActions` uid wrap (bundled bug-prevention):**

- [ ] `event_dashboard_screen.dart` — replace bare `_EventActions(event: event, currentUserId: '')` with `Consumer(builder: (_, ref, _) => _EventActions(event: event, currentUserId: ref.watch(currentUserIdProvider) ?? ''))`. Same shape as the router's `MemberManagementScreen` wrap.
- [ ] TDD: with `currentUserIdProvider == event.creatorId` → owner-only Delete Event tile renders. With a non-creator uid → Leave Event tile renders, Delete hidden.

**Journey extension:**

- [ ] Extend `test/journeys/create_event_journey_test.dart`: after the existing tile-appears assertion, tap the tile → assert `EventDashboardScreen` hero text matches the event title.

**Verify:**

- [ ] `flutter analyze` clean (only the pre-existing `TableMigration` warning).
- [ ] `flutter test` full suite green — no "Timer still pending" failures anywhere.
- [ ] Manual smoke iOS sim: tap tile → see hero + quick links → tap each → return; tap Leave/Delete → action fires.
- [ ] Manual smoke web (`flutter run -d chrome --dart-define=FLAVOR=dev`): tap tile + reload at `/dashboard/event/{id}/budget` → spinner briefly → resolved screen.
- [ ] Manual smoke web direct URL `/dashboard/event/{nonexistent}` → spinner for 750ms → `_EventNotFoundScreen`.

### Phase 2: Event lifecycle deep dive (audit doc)

- **Goal**: Append `## Event Lifecycle Deep Dive` section to `docs/v1-progress-audit.md`.

- [ ] `docs/v1-progress-audit.md` — append new section. 10-row matrix (*Step* / *Status* ✅⚠️❌ / *File refs* / *Follow-up*): create, view, edit, members, tasks, chat, budget, archive, leave, delete.
- [ ] Mark navigation + `currentUserId` rows as "Resolved in this PR" (Phase 1 of this plan).
- [ ] Cross-reference V1 audit Pillar 2 row at the top.
- [ ] Subsection: *Follow-up specs* — `event-archive-toggle-spec.md` (V1 should-ship), `event-edit-screen-spec.md` (V1.x). Note: uid-wiring follow-up is dropped (resolved here).
- [ ] `ai_specs/event-navigation-fix-and-lifecycle-audit-spec.md` — add a one-line link at the top pointing to the new audit section.
- [ ] Verify: every Status cell opens to a file; every Follow-up names a spec, "none", or "in this PR".

## Risks / Out of scope

**Risks:**

- **`ref.listen(fireImmediately: true)` semantics:** if Riverpod 3 calls the listener synchronously during build (rather than scheduling on a microtask), our listener body could trigger a `setState` during build via the timer's first `_scheduleGrace`. The sketch avoids this by only setting a `Timer` (which fires async). If implementation deviates, watch for "setState called during build" errors.
- **GoRouter parent path-param inheritance:** assumed via `state.pathParameters['eventId']`. The `_resolveEventId` `matchedLocation` regex fallback covers the case where the assumption fails — keep it even if the param works.
- **Riverpod 3 family cleanup:** `eventByIdProvider(id)` accumulates entries as users open events. Acceptable for V1; revisit if profiling shows a leak.

**Out of scope:**

- Edit-event screen — V1.x follow-up spec.
- Archive toggle Firestore wiring — V1 should-ship, separate spec.
- Sub-screen widget internals (chat / budget / tasks / members) — they accept `event:` and remain unchanged.
- Firestore web offline persistence — separate V1 audit launch blocker.
- One-shot Firestore `doc(id).get()` for cross-account deep links — grace + dashboard list is sufficient for V1.
- Lifting `_EventGuard` to `lib/app/core/widgets/` — keep private until reused outside the router.
